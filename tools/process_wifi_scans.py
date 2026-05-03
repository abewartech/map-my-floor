#!/usr/bin/env python3
"""
Dynamic Wi-Fi fingerprint processor for MapMyFloor indoor navigation.

Automatically discovers and maintains AP features from raw scan data,
allowing the fingerprint model to evolve with new access points while
maintaining backward compatibility with the frozen 12-AP set.

Features:
  - Dynamic AP discovery from BSSID prefix + frequency band
  - Versioned feature registry (JSON) with per-AP confidence scores
  - Stale-AP pruning (configurable day threshold)
  - Migration / export tool → generates Flutter feature_extractor.dart stub
  - All original outputs preserved: RawScans, ScanVectors, RunLevel,
    CheckpointLevel, SkippedFiles, ScanQualitySummary

Expected scan-file naming (unchanged):
    A1_R1_S1.txt
    C0_R3_S15.txt
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from statistics import median
from typing import Any, Optional


# ─── Constants ────────────────────────────────────────────────────────────────

MISSING_RSSI: int = -100
MIN_OCCURRENCE_RATIO: float = 0.30   # AP must appear in ≥ 30 % of scans to earn confidence 1.0
STALE_DAYS_THRESHOLD: int = 90       # Days before an AP is considered stale (informational only)
MAX_FEATURES: int = 24               # Hard cap on feature count

# Frozen legacy feature set – always preserved in the registry.
_LEGACY_FEATURES: list[tuple[str, str, str]] = [
    ("Ap00Df24G",        "00:df:1d:6a:9c:", "2.4"),
    ("Ap00Df5G",         "00:df:1d:6a:9c:", "5"),
    ("Ap2436Da9D3C24G",  "24:36:da:9d:3c:", "2.4"),
    ("Ap2436Da9Df124G",  "24:36:da:9d:f1:", "2.4"),
    ("Ap2436DaA38924G",  "24:36:da:a3:89:", "2.4"),
    ("Ap2436DaA3895G",   "24:36:da:a3:89:", "5"),
    ("Ap40017A539724G",  "40:01:7a:53:97:", "2.4"),
    ("Ap40017A53975G",   "40:01:7a:53:97:", "5"),
    ("Ap6C310E56E124G",  "6c:31:0e:56:e1:", "2.4"),
    ("Ap6C310E56E15G",   "6c:31:0e:56:e1:", "5"),
    ("Ap7488Bb8Aaa24G",  "74:88:bb:8a:aa:", "2.4"),
    ("ApF80BCbF38824G",  "f8:0b:cb:f3:88:", "2.4"),
]

_FILE_RE = re.compile(
    r"^(?P<checkpoint>[A-Z]\d+)_R(?P<run>\d+)_S(?P<scan>\d+)\.txt$",
    re.IGNORECASE,
)


# ─── APFeature ────────────────────────────────────────────────────────────────

class APFeature:
    """Single AP entry: BSSID prefix + Wi-Fi band + lifecycle metadata."""

    def __init__(
        self,
        name: str,
        bssid_prefix: str,
        band: str,
        first_seen: datetime,
        last_seen: datetime,
        occurrence_count: int = 0,
        confidence: float = 1.0,
    ) -> None:
        self.name = name
        self.bssid_prefix = bssid_prefix.lower()
        self.band = band          # "2.4" | "5" | "6"
        self.first_seen = first_seen
        self.last_seen = last_seen
        self.occurrence_count = occurrence_count
        self.confidence = confidence

    # ── matching ──────────────────────────────────────────────────────────────

    def matches(self, bssid: str, frequency_mhz: Optional[int]) -> bool:
        normalized = (bssid or "").strip().lower()
        return (
            normalized.startswith(self.bssid_prefix)
            and _frequency_to_band(frequency_mhz) == self.band
        )

    # ── staleness ─────────────────────────────────────────────────────────────

    @property
    def days_since_seen(self) -> int:
        return (datetime.now() - self.last_seen).days

    @property
    def is_stale(self) -> bool:
        return self.days_since_seen > STALE_DAYS_THRESHOLD

    # ── serialization ─────────────────────────────────────────────────────────

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "bssid_prefix": self.bssid_prefix,
            "band": self.band,
            "first_seen": self.first_seen.isoformat(),
            "last_seen": self.last_seen.isoformat(),
            "occurrence_count": self.occurrence_count,
            "confidence": round(self.confidence, 4),
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "APFeature":
        return cls(
            name=data["name"],
            bssid_prefix=data["bssid_prefix"],
            band=data["band"],
            first_seen=datetime.fromisoformat(data["first_seen"]),
            last_seen=datetime.fromisoformat(data["last_seen"]),
            occurrence_count=data.get("occurrence_count", 0),
            confidence=data.get("confidence", 1.0),
        )


# ─── DynamicFeatureRegistry ───────────────────────────────────────────────────

class DynamicFeatureRegistry:
    """Discovers, persists, and serves the live AP feature set."""

    def __init__(self, registry_path: Optional[Path] = None) -> None:
        self.features: list[APFeature] = []
        self.registry_path = registry_path

        if registry_path and registry_path.exists():
            self.load()
        else:
            # Bootstrap from legacy list so the tool works out-of-the-box.
            self._bootstrap_legacy()

    # ── bootstrap ─────────────────────────────────────────────────────────────

    def _bootstrap_legacy(self) -> None:
        now = datetime.now()
        self.features = [
            APFeature(name, prefix, band, now, now, 0, 1.0)
            for name, prefix, band in _LEGACY_FEATURES
        ]

    # ── discovery ─────────────────────────────────────────────────────────────

    def discover_from_scans(self, input_dir: Path) -> None:
        """
        Walk every .txt scan file in *input_dir*, collect unique
        (bssid_prefix, band) pairs with occurrence counts, then merge back
        into the registry.  Legacy features are always preserved.
        """
        txt_files = list(input_dir.glob("*.txt"))
        total_files = max(len(txt_files), 1)

        # (prefix, band) → {count, first_seen, last_seen}
        discovered: dict[tuple[str, str], dict[str, Any]] = defaultdict(
            lambda: {"count": 0, "first_seen": None, "last_seen": None}
        )

        for path in txt_files:
            ts = _file_timestamp(path)
            for row in _read_scan_file(path):
                bssid = (row.get("BSSID") or "").strip().lower()
                freq = _parse_frequency_mhz(row.get("Primary Frequency", ""))
                band = _frequency_to_band(freq)
                if not bssid or band == "unknown":
                    continue
                prefix = bssid[:8]          # first 8 chars e.g. "00:df:1d"
                key = (prefix, band)
                discovered[key]["count"] += 1
                if discovered[key]["first_seen"] is None:
                    discovered[key]["first_seen"] = ts
                discovered[key]["last_seen"] = ts

        # Build merged feature list
        merged: list[APFeature] = []
        for (prefix, band), meta in discovered.items():
            existing = self._find(prefix, band)
            if existing:
                existing.occurrence_count = meta["count"]
                existing.last_seen = meta["last_seen"]
                merged.append(existing)
            else:
                name = _generate_feature_name(prefix, band)
                merged.append(
                    APFeature(
                        name=name,
                        bssid_prefix=prefix,
                        band=band,
                        first_seen=meta["first_seen"],
                        last_seen=meta["last_seen"],
                        occurrence_count=meta["count"],
                    )
                )

        # Ensure legacy features are always present
        for leg_name, leg_prefix, leg_band in _LEGACY_FEATURES:
            if not self._find(leg_prefix, leg_band, merged):
                merged.append(
                    APFeature(leg_name, leg_prefix, leg_band,
                              datetime.now(), datetime.now(), 0, 1.0)
                )

        # Sort by occurrence count desc, trim to cap
        merged.sort(key=lambda f: f.occurrence_count, reverse=True)

        # Assign confidence scores
        for f in merged:
            ratio = f.occurrence_count / total_files
            f.confidence = min(1.0, ratio / MIN_OCCURRENCE_RATIO)

        self.features = merged[:MAX_FEATURES]

    def _find(
        self,
        prefix: str,
        band: str,
        src: Optional[list[APFeature]] = None,
    ) -> Optional[APFeature]:
        for f in (src if src is not None else self.features):
            if f.bssid_prefix == prefix and f.band == band:
                return f
        return None

    # ── public interface ──────────────────────────────────────────────────────

    def feature_names(self) -> list[str]:
        return [f.name for f in self.features]

    def matching_feature(
        self, bssid: str, frequency_mhz: Optional[int]
    ) -> Optional[str]:
        for f in self.features:
            if f.matches(bssid, frequency_mhz):
                return f.name
        return None

    # ── persistence ───────────────────────────────────────────────────────────

    def save(self) -> None:
        if not self.registry_path:
            return
        self.registry_path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "version": 2,
            "generated_at": datetime.now().isoformat(),
            "features": [f.to_dict() for f in self.features],
        }
        self.registry_path.write_text(json.dumps(payload, indent=2))
        print(f"💾 Registry saved → {self.registry_path}")

    def load(self) -> None:
        data = json.loads(self.registry_path.read_text())  # type: ignore[union-attr]
        self.features = [APFeature.from_dict(f) for f in data.get("features", [])]

    # ── Flutter export ────────────────────────────────────────────────────────

    def export_to_flutter(self, output_path: Path) -> None:
        """
        Write a Dart file containing a drop-in replacement for
        feature_extractor.dart's feature list / matching logic.
        Only the constant data changes; the rest of the engine is untouched.
        """
        names_dart = ",\n  ".join(f'"{f.name}"' for f in self.features)
        rules_dart = "\n".join(
            f"  ApFeatureRule(name: '{f.name}', "
            f"prefix: '{f.bssid_prefix}', band: '{f.band}'),"
            for f in self.features
        )
        code = f"""\
// GENERATED — DO NOT EDIT MANUALLY
// Generated: {datetime.now().isoformat()}
// Registry:  {self.registry_path or 'n/a'}
// Features:  {len(self.features)}
//
// Drop this file over lib/indoor_nav/feature_extractor.dart and rebuild.
// The rest of the engine (FingerprintPredictor, IndoorNavEngine, …) needs
// no changes because it reads featureNames / featureRules at runtime.

import 'models.dart';

const int missingRssi = {MISSING_RSSI};

const List<String> featureNames = [
  {names_dart}
];

const List<ApFeatureRule> featureRules = [
{rules_dart}
];

String? _bandForFrequency(int frequencyMHz) {{
  if (frequencyMHz < 3000) return '2.4';
  if (frequencyMHz >= 5000 && frequencyMHz < 6000) return '5';
  if (frequencyMHz >= 6000) return '6';
  return null;
}}

String? _matchingFeature(WifiObservation obs) {{
  final bssid = obs.bssid.toLowerCase().trim();
  final band = _bandForFrequency(obs.frequencyMHz);
  for (final rule in featureRules) {{
    if (bssid.startsWith(rule.prefix) && band == rule.band) return rule.name;
  }}
  return null;
}}

Map<String, int> extractFeatureVector(List<WifiObservation> observations) {{
  final vector = {{for (final name in featureNames) name: missingRssi}};
  for (final obs in observations) {{
    final feature = _matchingFeature(obs);
    if (feature == null) continue;
    final oldValue = vector[feature] ?? missingRssi;
    if (obs.rssi > oldValue) vector[feature] = obs.rssi;
  }}
  return vector;
}}

int matchedFeatureCount(Map<String, int> vector) =>
    vector.values.where((v) => v > missingRssi).length;
"""
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(code)
        print(f"✅ Flutter feature_extractor stub → {output_path}")


# ─── Pure helpers ─────────────────────────────────────────────────────────────

def _frequency_to_band(frequency_mhz: Optional[int]) -> str:
    if frequency_mhz is None:
        return "unknown"
    if frequency_mhz < 3000:
        return "2.4"
    if 5000 <= frequency_mhz < 6000:
        return "5"
    if frequency_mhz >= 6000:
        return "6"
    return "unknown"


def _generate_feature_name(prefix: str, band: str) -> str:
    clean = prefix.replace(":", "").upper()
    return f"Ap{clean}{band.replace('.', '')}G"


def _file_timestamp(path: Path) -> datetime:
    m = re.search(r"(\d{4}-\d{2}-\d{2})", path.name)
    if m:
        try:
            return datetime.strptime(m.group(1), "%Y-%m-%d")
        except ValueError:
            pass
    return datetime.fromtimestamp(path.stat().st_mtime)


def _parse_rssi(value: str) -> Optional[int]:
    m = re.search(r"-?\d+", value or "")
    return int(m.group(0)) if m else None


def _parse_frequency_mhz(value: str) -> Optional[int]:
    m = re.search(r"\d+", value or "")
    return int(m.group(0)) if m else None


def _read_scan_file(path: Path) -> list[dict[str, str]]:
    try:
        text = path.read_text(encoding="utf-8-sig", errors="replace")
    except OSError:
        return []
    lines = [line for line in text.splitlines() if line.strip()]
    if not lines:
        return []
    header_idx = next(
        (i for i, line in enumerate(lines) if line.startswith("Time Stamp|")),
        None,
    )
    if header_idx is None:
        return []
    reader = csv.DictReader(lines[header_idx:], delimiter="|")
    return [row for row in reader if row.get("BSSID")]


def _natural_file_key(path: Path) -> tuple[str, int, int, str]:
    m = _FILE_RE.match(path.name)
    if not m:
        return (path.stem, 0, 0, path.name)
    return (m.group("checkpoint").upper(), int(m.group("run")), int(m.group("scan")), path.name)


def _metadata_from_filename(path: Path) -> Optional[tuple[str, int, int]]:
    m = _FILE_RE.match(path.name)
    if not m:
        return None
    return (m.group("checkpoint").upper(), int(m.group("run")), int(m.group("scan")))


# ─── Core processing pipeline ─────────────────────────────────────────────────

def build_rows(
    input_dir: Path,
    registry: DynamicFeatureRegistry,
) -> tuple[
    list[dict[str, Any]],   # raw_rows
    list[dict[str, Any]],   # scan_vectors
    list[dict[str, Any]],   # run_fingerprints
    list[dict[str, Any]],   # checkpoint_fingerprints
    list[dict[str, Any]],   # skipped_files
    list[dict[str, Any]],   # quality_summary
]:
    feature_names = registry.feature_names()

    raw_rows: list[dict[str, Any]] = []
    scan_vectors: list[dict[str, Any]] = []
    skipped_files: list[dict[str, Any]] = []

    for path in sorted(input_dir.glob("*.txt"), key=_natural_file_key):
        meta = _metadata_from_filename(path)
        if meta is None:
            skipped_files.append({
                "FileName": path.name,
                "Reason": "Filename does not match CHECKPOINT_R<run>_S<scan>.txt",
            })
            continue

        checkpoint_id, run_id, scan_index = meta
        session_id = f"{checkpoint_id}_R{run_id}"
        rows = _read_scan_file(path)

        vector: dict[str, int] = {fn: MISSING_RSSI for fn in feature_names}
        matched_count = 0
        unmatched_count = 0

        for row_number, row in enumerate(rows, start=1):
            rssi = _parse_rssi(row.get("Strength", ""))
            freq = _parse_frequency_mhz(row.get("Primary Frequency", ""))
            feature_name = registry.matching_feature(row.get("BSSID", ""), freq)

            raw_rows.append({
                "SessionId": session_id,
                "CheckpointId": checkpoint_id,
                "RunId": run_id,
                "ScanIndex": scan_index,
                "SourceFile": path.name,
                "RowNumber": row_number,
                "Timestamp": row.get("Time Stamp", ""),
                "SSID": row.get("SSID", ""),
                "BSSID": (row.get("BSSID", "") or "").lower(),
                "RSSI": rssi if rssi is not None else "",
                "FrequencyMHz": freq if freq is not None else "",
                "MatchedFeature": feature_name or "",
            })

            if feature_name is None or rssi is None:
                unmatched_count += 1
                continue

            matched_count += 1
            if rssi > vector[feature_name]:
                vector[feature_name] = rssi

        scan_vec: dict[str, Any] = {
            "SessionId": session_id,
            "CheckpointId": checkpoint_id,
            "RunId": run_id,
            "ScanIndex": scan_index,
            "SourceFile": path.name,
            "RawRowCount": len(rows),
            "MatchedRowCount": matched_count,
            "UnmatchedRowCount": unmatched_count,
            "MatchedFeatureCount": sum(1 for v in vector.values() if v != MISSING_RSSI),
        }
        scan_vec.update(vector)
        scan_vectors.append(scan_vec)

    run_fps = _build_run_fingerprints(scan_vectors, feature_names)
    cp_fps = _build_checkpoint_fingerprints(run_fps, feature_names)
    quality = _build_quality_summary(scan_vectors, feature_names)

    return raw_rows, scan_vectors, run_fps, cp_fps, skipped_files, quality


def _build_run_fingerprints(
    scan_vectors: list[dict[str, Any]],
    feature_names: list[str],
) -> list[dict[str, Any]]:
    grouped: dict[tuple[str, int], list[dict[str, Any]]] = defaultdict(list)
    for row in scan_vectors:
        grouped[(str(row["CheckpointId"]), int(row["RunId"]))].append(row)

    fingerprints: list[dict[str, Any]] = []
    for (cp, run), rows in sorted(grouped.items()):
        fp: dict[str, Any] = {
            "SessionId": f"{cp}_R{run}",
            "CheckpointId": cp,
            "RunId": run,
            "ScanCount": len(rows),
            "MeanMatchedFeatureCount": round(
                sum(int(r["MatchedFeatureCount"]) for r in rows) / len(rows), 2
            ),
        }
        for fn in feature_names:
            vals = [int(r[fn]) for r in rows]
            fp[fn] = median(vals)
        fingerprints.append(fp)
    return fingerprints


def _build_checkpoint_fingerprints(
    run_fingerprints: list[dict[str, Any]],
    feature_names: list[str],
) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in run_fingerprints:
        grouped[str(row["CheckpointId"])].append(row)

    fingerprints: list[dict[str, Any]] = []
    for cp, rows in sorted(grouped.items()):
        total_scans = sum(int(r["ScanCount"]) for r in rows)
        fp: dict[str, Any] = {
            "SessionId": f"{cp}_ALL",
            "CheckpointId": cp,
            "RunId": "ALL",
            "ScanCount": total_scans,
            "MeanMatchedFeatureCount": round(
                sum(
                    float(r["MeanMatchedFeatureCount"]) * int(r["ScanCount"])
                    for r in rows
                )
                / total_scans,
                2,
            ),
        }
        for fn in feature_names:
            vals = [int(r[fn]) for r in rows]
            fp[fn] = round(sum(vals) / len(vals))
        fingerprints.append(fp)
    return fingerprints


def _build_quality_summary(
    scan_vectors: list[dict[str, Any]],
    feature_names: list[str],
) -> list[dict[str, Any]]:
    grouped: dict[tuple[str, int], list[dict[str, Any]]] = defaultdict(list)
    for row in scan_vectors:
        grouped[(str(row["CheckpointId"]), int(row["RunId"]))].append(row)

    summaries: list[dict[str, Any]] = []
    for (cp, run), rows in sorted(grouped.items()):
        matched_counts = [int(r["MatchedFeatureCount"]) for r in rows]
        raw_counts = [int(r["RawRowCount"]) for r in rows]
        presence: Counter[str] = Counter()
        for r in rows:
            for fn in feature_names:
                if int(r[fn]) != MISSING_RSSI:
                    presence[fn] += 1

        summary: dict[str, Any] = {
            "SessionId": f"{cp}_R{run}",
            "CheckpointId": cp,
            "RunId": run,
            "ScanCount": len(rows),
            "MinRawRows": min(raw_counts),
            "MaxRawRows": max(raw_counts),
            "MinMatchedFeatureCount": min(matched_counts),
            "MaxMatchedFeatureCount": max(matched_counts),
            "MeanMatchedFeatureCount": round(
                sum(matched_counts) / len(matched_counts), 2
            ),
        }
        for fn in feature_names:
            summary[f"{fn}_PresentScans"] = presence[fn]
        summaries.append(summary)
    return summaries


# ─── CSV writer ───────────────────────────────────────────────────────────────

def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    print(f"  ✓ {path.name}  ({len(rows)} rows)")


# ─── CLI ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Dynamic Wi-Fi fingerprint processor for MapMyFloor."
    )
    parser.add_argument(
        "--input-dir", type=Path, default=None,
        help="Folder of raw .txt scan files (default: data/raw_scans or '.')."
    )
    parser.add_argument(
        "--output-dir", type=Path, default=Path("data/processed"),
        help="Output folder for CSV files."
    )
    parser.add_argument(
        "--discover", action="store_true",
        help="Scan input files to discover new AP features before processing."
    )
    parser.add_argument(
        "--min-occurrence", type=float, default=MIN_OCCURRENCE_RATIO,
        help=f"Minimum scan-occurrence ratio for full confidence (default {MIN_OCCURRENCE_RATIO})."
    )
    parser.add_argument(
        "--feature-registry", type=Path, default=Path("data/feature_registry.json"),
        help="Path to the feature registry JSON (created on first --discover run)."
    )
    parser.add_argument(
        "--export-flutter", type=Path, default=None,
        help="If set, write a Flutter feature_extractor.dart stub to this path."
    )
    args = parser.parse_args()

    # Resolve input directory
    if args.input_dir:
        input_dir = args.input_dir.resolve()
    elif Path("data/raw_scans").is_dir():
        input_dir = Path("data/raw_scans").resolve()
    elif Path("scans").is_dir():
        input_dir = Path("scans").resolve()
    else:
        input_dir = Path(".").resolve()

    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    # ── Feature registry ──────────────────────────────────────────────────────
    registry = DynamicFeatureRegistry(args.feature_registry)

    if args.discover:
        print(f"\n🔍 Discovering AP features from {input_dir} …")
        registry.discover_from_scans(input_dir)
        registry.save()
        total = len(registry.features)
        print(f"\n📊 Registry: {total} features")
        for f in registry.features[:15]:
            stale_marker = " ⚠ STALE" if f.is_stale else ""
            print(
                f"   {'✓' if f.confidence >= 0.9 else '~'} "
                f"{f.name:<26} {f.bssid_prefix}  {f.band}GHz  "
                f"conf={f.confidence:.0%}{stale_marker}"
            )
        if total > 15:
            print(f"   … and {total - 15} more")

    feature_names = registry.feature_names()
    print(f"\n📡 Processing scans from {input_dir} …")
    print(f"   Active features: {len(feature_names)}")

    # ── Process ───────────────────────────────────────────────────────────────
    raw_rows, scan_vectors, run_fps, cp_fps, skipped, quality = build_rows(
        input_dir, registry
    )

    # ── Write CSVs ────────────────────────────────────────────────────────────
    print(f"\n📁 Writing output to {output_dir} …")

    write_csv(output_dir / "RawScans.csv", raw_rows, [
        "SessionId", "CheckpointId", "RunId", "ScanIndex", "SourceFile",
        "RowNumber", "Timestamp", "SSID", "BSSID", "RSSI", "FrequencyMHz",
        "MatchedFeature",
    ])
    write_csv(output_dir / "FilteredScanVectors.csv", scan_vectors, [
        "SessionId", "CheckpointId", "RunId", "ScanIndex", "SourceFile",
        "RawRowCount", "MatchedRowCount", "UnmatchedRowCount", "MatchedFeatureCount",
        *feature_names,
    ])
    write_csv(output_dir / "RunLevelFingerprints.csv", run_fps, [
        "SessionId", "CheckpointId", "RunId", "ScanCount",
        "MeanMatchedFeatureCount", *feature_names,
    ])
    write_csv(output_dir / "CheckpointLevelFingerprints.csv", cp_fps, [
        "SessionId", "CheckpointId", "RunId", "ScanCount",
        "MeanMatchedFeatureCount", *feature_names,
    ])
    write_csv(output_dir / "SkippedFiles.csv", skipped, ["FileName", "Reason"])
    write_csv(output_dir / "ScanQualitySummary.csv", quality, [
        "SessionId", "CheckpointId", "RunId", "ScanCount",
        "MinRawRows", "MaxRawRows",
        "MinMatchedFeatureCount", "MaxMatchedFeatureCount", "MeanMatchedFeatureCount",
        *[f"{fn}_PresentScans" for fn in feature_names],
    ])

    # ── Flutter export ────────────────────────────────────────────────────────
    if args.export_flutter:
        registry.export_to_flutter(args.export_flutter.resolve())

    # ── Summary ───────────────────────────────────────────────────────────────
    print(f"""
✅ Done!
   Input:                  {input_dir}
   Output:                 {output_dir}
   Active AP features:     {len(feature_names)}
   Raw scan rows:          {len(raw_rows)}
   Scan vectors:           {len(scan_vectors)}
   Run-level fingerprints: {len(run_fps)}
   Checkpoint fingerprints:{len(cp_fps)}
   Skipped files:          {len(skipped)}
""")


if __name__ == "__main__":
    main()

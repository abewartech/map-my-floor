#!/usr/bin/env python3
"""
Convert raw Wi-Fi scan text exports into model-ready fingerprint CSV files.

Expected current file naming:
    A1_R1_S1.txt
    C0_R1_S15.txt

The script is intentionally dependency-free so it can be rerun whenever R2/R3
files are added to the same folder.
"""

from __future__ import annotations

import argparse
import csv
import re
from collections import Counter, defaultdict
from pathlib import Path
from statistics import median


MISSING_RSSI = -100

AP_FEATURES = [
    ("Ap00Df24G", "00:df:1d:6a:9c:", "2.4"),
    ("Ap00Df5G", "00:df:1d:6a:9c:", "5"),
    ("Ap2436Da9D3C24G", "24:36:da:9d:3c:", "2.4"),
    ("Ap2436Da9Df124G", "24:36:da:9d:f1:", "2.4"),
    ("Ap2436DaA38924G", "24:36:da:a3:89:", "2.4"),
    ("Ap2436DaA3895G", "24:36:da:a3:89:", "5"),
    ("Ap40017A539724G", "40:01:7a:53:97:", "2.4"),
    ("Ap40017A53975G", "40:01:7a:53:97:", "5"),
    ("Ap6C310E56E124G", "6c:31:0e:56:e1:", "2.4"),
    ("Ap6C310E56E15G", "6c:31:0e:56:e1:", "5"),
    ("Ap7488Bb8Aaa24G", "74:88:bb:8a:aa:", "2.4"),
    ("ApF80BCbF38824G", "f8:0b:cb:f3:88:", "2.4"),
]

FEATURE_NAMES = [name for name, _prefix, _band in AP_FEATURES]
FILE_RE = re.compile(
    r"^(?P<checkpoint>[A-Z]\d+)_R(?P<run>\d+)_S(?P<scan>\d+)\.txt$",
    re.IGNORECASE,
)


def parse_rssi(value: str) -> int | None:
    match = re.search(r"-?\d+", value or "")
    return int(match.group(0)) if match else None


def parse_frequency_mhz(value: str) -> int | None:
    match = re.search(r"\d+", value or "")
    return int(match.group(0)) if match else None


def band_for_frequency(frequency_mhz: int | None) -> str | None:
    if frequency_mhz is None:
        return None
    if frequency_mhz < 3000:
        return "2.4"
    if frequency_mhz >= 5000:
        return "5"
    return None


def matching_feature(bssid: str, frequency_mhz: int | None) -> str | None:
    normalized_bssid = (bssid or "").strip().lower()
    band = band_for_frequency(frequency_mhz)
    for feature_name, prefix, feature_band in AP_FEATURES:
        if normalized_bssid.startswith(prefix) and band == feature_band:
            return feature_name
    return None


def natural_file_key(path: Path) -> tuple[str, int, int, str]:
    metadata = metadata_from_filename(path)
    if metadata is None:
        return (path.stem, 0, 0, path.name)
    checkpoint_id, run_id, scan_index = metadata
    return (checkpoint_id, run_id, scan_index, path.name)


def metadata_from_filename(path: Path) -> tuple[str, int, int] | None:
    match = FILE_RE.match(path.name)
    if not match:
        return None
    return (
        match.group("checkpoint").upper(),
        int(match.group("run")),
        int(match.group("scan")),
    )


def read_scan_file(path: Path) -> list[dict[str, str]]:
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    lines = [line for line in text.splitlines() if line.strip()]
    if not lines:
        return []

    header_index = next(
        (index for index, line in enumerate(lines) if line.startswith("Time Stamp|")),
        None,
    )
    if header_index is None:
        return []

    reader = csv.DictReader(lines[header_index:], delimiter="|")
    return [row for row in reader if row.get("BSSID")]


def build_rows(
    input_dir: Path,
) -> tuple[
    list[dict[str, object]],
    list[dict[str, object]],
    list[dict[str, object]],
    list[dict[str, object]],
    list[dict[str, object]],
    list[dict[str, object]],
]:
    raw_rows: list[dict[str, object]] = []
    scan_vectors: list[dict[str, object]] = []
    skipped_files: list[dict[str, object]] = []

    txt_files = sorted(input_dir.glob("*.txt"), key=natural_file_key)
    for path in txt_files:
        metadata = metadata_from_filename(path)
        if metadata is None:
            skipped_files.append(
                {
                    "FileName": path.name,
                    "Reason": "Filename does not match CHECKPOINT_R<run>_S<scan>.txt",
                }
            )
            continue

        checkpoint_id, run_id, scan_index = metadata
        session_id = f"{checkpoint_id}_R{run_id}"
        rows = read_scan_file(path)

        vector = {feature_name: MISSING_RSSI for feature_name in FEATURE_NAMES}
        matched_row_count = 0
        unmatched_row_count = 0

        for row_number, row in enumerate(rows, start=1):
            rssi = parse_rssi(row.get("Strength", ""))
            frequency_mhz = parse_frequency_mhz(row.get("Primary Frequency", ""))
            feature_name = matching_feature(row.get("BSSID", ""), frequency_mhz)

            raw_row = {
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
                "FrequencyMHz": frequency_mhz if frequency_mhz is not None else "",
                "MatchedFeature": feature_name or "",
            }
            raw_rows.append(raw_row)

            if feature_name is None or rssi is None:
                unmatched_row_count += 1
                continue

            matched_row_count += 1
            vector[feature_name] = max(vector[feature_name], rssi)

        scan_vector = {
            "SessionId": session_id,
            "CheckpointId": checkpoint_id,
            "RunId": run_id,
            "ScanIndex": scan_index,
            "SourceFile": path.name,
            "RawRowCount": len(rows),
            "MatchedRowCount": matched_row_count,
            "UnmatchedRowCount": unmatched_row_count,
            "MatchedFeatureCount": sum(1 for value in vector.values() if value != MISSING_RSSI),
        }
        scan_vector.update(vector)
        scan_vectors.append(scan_vector)

    run_fingerprints = build_run_fingerprints(scan_vectors)
    checkpoint_fingerprints = build_checkpoint_fingerprints(run_fingerprints)
    quality_summary = build_quality_summary(scan_vectors)
    return raw_rows, scan_vectors, run_fingerprints, checkpoint_fingerprints, skipped_files, quality_summary


def build_run_fingerprints(scan_vectors: list[dict[str, object]]) -> list[dict[str, object]]:
    grouped: dict[tuple[str, int], list[dict[str, object]]] = defaultdict(list)
    for row in scan_vectors:
        grouped[(str(row["CheckpointId"]), int(row["RunId"]))].append(row)

    fingerprints: list[dict[str, object]] = []
    for (checkpoint_id, run_id), rows in sorted(grouped.items()):
        session_id = f"{checkpoint_id}_R{run_id}"
        fingerprint = {
            "SessionId": session_id,
            "CheckpointId": checkpoint_id,
            "RunId": run_id,
            "ScanCount": len(rows),
            "MeanMatchedFeatureCount": round(
                sum(int(row["MatchedFeatureCount"]) for row in rows) / len(rows),
                2,
            ),
        }

        for feature_name in FEATURE_NAMES:
            values = [int(row[feature_name]) for row in rows]
            fingerprint[feature_name] = median(values)

        fingerprints.append(fingerprint)

    return fingerprints


def build_checkpoint_fingerprints(
    run_fingerprints: list[dict[str, object]],
) -> list[dict[str, object]]:
    grouped: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in run_fingerprints:
        grouped[str(row["CheckpointId"])].append(row)

    fingerprints: list[dict[str, object]] = []
    for checkpoint_id, rows in sorted(grouped.items()):
        total_scan_count = sum(int(row["ScanCount"]) for row in rows)
        fingerprint = {
            "SessionId": f"{checkpoint_id}_ALL",
            "CheckpointId": checkpoint_id,
            "RunId": "ALL",
            "ScanCount": total_scan_count,
            "MeanMatchedFeatureCount": round(
                sum(
                    float(row["MeanMatchedFeatureCount"]) * int(row["ScanCount"])
                    for row in rows
                )
                / total_scan_count,
                2,
            ),
        }

        for feature_name in FEATURE_NAMES:
            values = [int(row[feature_name]) for row in rows]
            fingerprint[feature_name] = round(sum(values) / len(values))

        fingerprints.append(fingerprint)

    return fingerprints


def build_quality_summary(scan_vectors: list[dict[str, object]]) -> list[dict[str, object]]:
    grouped: dict[tuple[str, int], list[dict[str, object]]] = defaultdict(list)
    for row in scan_vectors:
        grouped[(str(row["CheckpointId"]), int(row["RunId"]))].append(row)

    summaries: list[dict[str, object]] = []
    for (checkpoint_id, run_id), rows in sorted(grouped.items()):
        matched_feature_counts = [int(row["MatchedFeatureCount"]) for row in rows]
        raw_row_counts = [int(row["RawRowCount"]) for row in rows]
        feature_presence = Counter()

        for row in rows:
            for feature_name in FEATURE_NAMES:
                if int(row[feature_name]) != MISSING_RSSI:
                    feature_presence[feature_name] += 1

        summary = {
            "SessionId": f"{checkpoint_id}_R{run_id}",
            "CheckpointId": checkpoint_id,
            "RunId": run_id,
            "ScanCount": len(rows),
            "MinRawRows": min(raw_row_counts),
            "MaxRawRows": max(raw_row_counts),
            "MinMatchedFeatureCount": min(matched_feature_counts),
            "MaxMatchedFeatureCount": max(matched_feature_counts),
            "MeanMatchedFeatureCount": round(
                sum(matched_feature_counts) / len(matched_feature_counts),
                2,
            ),
        }

        for feature_name in FEATURE_NAMES:
            summary[f"{feature_name}_PresentScans"] = feature_presence[feature_name]

        summaries.append(summary)

    return summaries


def write_csv(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Process raw indoor-navigation Wi-Fi scans into CSV datasets."
    )
    parser.add_argument(
        "--input-dir",
        type=Path,
        default=None,
        help="Folder containing raw .txt scan files. Defaults to ./data/raw_scans when present.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Folder where output CSV files will be written.",
    )
    args = parser.parse_args()

    if Path("data/raw_scans").is_dir():
        default_input_dir = Path("data/raw_scans")
    elif Path("scans").is_dir():
        default_input_dir = Path("scans")
    else:
        default_input_dir = Path(".")
    input_dir = (args.input_dir or default_input_dir).resolve()
    default_output_dir = Path("data/processed")
    output_dir = (args.output_dir or default_output_dir).resolve()

    raw_rows, scan_vectors, run_fingerprints, checkpoint_fingerprints, skipped_files, quality_summary = build_rows(
        input_dir
    )

    raw_fields = [
        "SessionId",
        "CheckpointId",
        "RunId",
        "ScanIndex",
        "SourceFile",
        "RowNumber",
        "Timestamp",
        "SSID",
        "BSSID",
        "RSSI",
        "FrequencyMHz",
        "MatchedFeature",
    ]
    scan_vector_fields = [
        "SessionId",
        "CheckpointId",
        "RunId",
        "ScanIndex",
        "SourceFile",
        "RawRowCount",
        "MatchedRowCount",
        "UnmatchedRowCount",
        "MatchedFeatureCount",
        *FEATURE_NAMES,
    ]
    fingerprint_fields = [
        "SessionId",
        "CheckpointId",
        "RunId",
        "ScanCount",
        "MeanMatchedFeatureCount",
        *FEATURE_NAMES,
    ]
    skipped_fields = ["FileName", "Reason"]
    quality_fields = [
        "SessionId",
        "CheckpointId",
        "RunId",
        "ScanCount",
        "MinRawRows",
        "MaxRawRows",
        "MinMatchedFeatureCount",
        "MaxMatchedFeatureCount",
        "MeanMatchedFeatureCount",
        *[f"{feature_name}_PresentScans" for feature_name in FEATURE_NAMES],
    ]

    write_csv(output_dir / "RawScans.csv", raw_rows, raw_fields)
    write_csv(output_dir / "FilteredScanVectors.csv", scan_vectors, scan_vector_fields)
    write_csv(output_dir / "RunLevelFingerprints.csv", run_fingerprints, fingerprint_fields)
    write_csv(
        output_dir / "CheckpointLevelFingerprints.csv",
        checkpoint_fingerprints,
        fingerprint_fields,
    )
    write_csv(output_dir / "SkippedFiles.csv", skipped_files, skipped_fields)
    write_csv(output_dir / "ScanQualitySummary.csv", quality_summary, quality_fields)

    print(f"Input folder: {input_dir}")
    print(f"Output folder: {output_dir}")
    print(f"Parsed raw rows: {len(raw_rows)}")
    print(f"Scan vectors: {len(scan_vectors)}")
    print(f"Run-level fingerprints: {len(run_fingerprints)}")
    print(f"Checkpoint-level fingerprints: {len(checkpoint_fingerprints)}")
    print(f"Skipped files: {len(skipped_files)}")
    print(f"Quality summary rows: {len(quality_summary)}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
compare_features.py — Migration helper for MapMyFloor.

Compares the frozen 12-AP feature set currently baked into
lib/indoor_nav/feature_extractor.dart with the feature set stored
in the dynamic feature_registry.json produced by process_wifi_scans.py.

Outputs a human-readable diff table and a machine-readable JSON report.

Usage:
    # Compare registry against the frozen set (default)
    python tools/compare_features.py

    # Compare a specific registry against a specific extractor
    python tools/compare_features.py \\
        --registry  data/feature_registry.json \\
        --extractor lib/indoor_nav/feature_extractor.dart \\
        --report    data/feature_migration_report.json
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


# ─── Frozen set (always the ground-truth baseline) ────────────────────────────

FROZEN_FEATURES: list[tuple[str, str, str]] = [
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


# ─── Loaders ──────────────────────────────────────────────────────────────────

def _load_frozen() -> list[dict[str, str]]:
    return [
        {"name": name, "bssid_prefix": prefix, "band": band}
        for name, prefix, band in FROZEN_FEATURES
    ]


def _load_registry(path: Path) -> list[dict[str, Any]]:
    data = json.loads(path.read_text())
    return data.get("features", [])


def _load_extractor_dart(path: Path) -> list[dict[str, str]]:
    """
    Parse ApFeatureRule entries from an existing feature_extractor.dart.

    Looks for lines of the form:
        ApFeatureRule(name: 'Ap00Df24G', prefix: '00:df:1d:6a:9c:', band: '2.4'),
    """
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(
        r"ApFeatureRule\s*\(\s*name:\s*'(?P<name>[^']+)'\s*,\s*"
        r"prefix:\s*'(?P<prefix>[^']+)'\s*,\s*"
        r"band:\s*'(?P<band>[^']+)'\s*\)"
    )
    return [
        {"name": m.group("name"), "bssid_prefix": m.group("prefix"), "band": m.group("band")}
        for m in pattern.finditer(text)
    ]


# ─── Comparison logic ─────────────────────────────────────────────────────────

def _key(feature: dict[str, Any]) -> tuple[str, str]:
    """Canonical (prefix, band) key, case-normalised."""
    return (feature["bssid_prefix"].lower(), feature["band"])


def compare(
    baseline: list[dict[str, Any]],
    candidate: list[dict[str, Any]],
    baseline_label: str = "Frozen",
    candidate_label: str = "Registry",
) -> dict[str, Any]:
    base_map = {_key(f): f for f in baseline}
    cand_map = {_key(f): f for f in candidate}

    base_keys = set(base_map)
    cand_keys = set(cand_map)

    only_in_base = base_keys - cand_keys   # removed / missing in candidate
    only_in_cand = cand_keys - base_keys   # new in candidate
    in_both      = base_keys & cand_keys

    # Check for renames (same prefix+band, different name)
    renamed = []
    unchanged = []
    for key in in_both:
        b_name = base_map[key]["name"]
        c_name = cand_map[key]["name"]
        if b_name != c_name:
            renamed.append({"key": key, "from": b_name, "to": c_name})
        else:
            unchanged.append(base_map[key])

    return {
        "baseline_label": baseline_label,
        "candidate_label": candidate_label,
        "baseline_count": len(baseline),
        "candidate_count": len(candidate),
        "unchanged": unchanged,
        "renamed": renamed,
        "added": [cand_map[k] for k in sorted(only_in_cand)],
        "removed": [base_map[k] for k in sorted(only_in_base)],
    }


# ─── Pretty printer ───────────────────────────────────────────────────────────

_GREEN  = "\033[32m"
_RED    = "\033[31m"
_YELLOW = "\033[33m"
_CYAN   = "\033[36m"
_RESET  = "\033[0m"
_BOLD   = "\033[1m"


def _col(text: str, color: str, width: int = 0) -> str:
    padded = text.ljust(width) if width else text
    return f"{color}{padded}{_RESET}"


def print_report(report: dict[str, Any]) -> None:
    base_lbl = report["baseline_label"]
    cand_lbl = report["candidate_label"]

    print(f"\n{_BOLD}{'─' * 64}{_RESET}")
    print(f"{_BOLD}  Feature Set Comparison{_RESET}")
    print(f"  Baseline  : {base_lbl}  ({report['baseline_count']} features)")
    print(f"  Candidate : {cand_lbl}  ({report['candidate_count']} features)")
    print(f"{'─' * 64}{_RESET}")

    # ── Unchanged ────────────────────────────────────────────────────────────
    print(f"\n{_BOLD}  ✓ Unchanged ({len(report['unchanged'])}):{_RESET}")
    for f in sorted(report["unchanged"], key=lambda x: x["name"]):
        conf = f.get("confidence")
        conf_str = f"  conf={conf:.0%}" if conf is not None else ""
        stale = "  ⚠ STALE" if f.get("is_stale") else ""
        print(
            f"    {_col(f['name'], _GREEN, 28)}"
            f"  {f['bssid_prefix']:<18}  {f['band']}GHz"
            f"{_col(conf_str, _CYAN)}{_col(stale, _YELLOW)}"
        )

    # ── Renamed ──────────────────────────────────────────────────────────────
    if report["renamed"]:
        print(f"\n{_BOLD}  ~ Renamed ({len(report['renamed'])}):{_RESET}")
        for r in report["renamed"]:
            print(
                f"    {_col(r['from'], _YELLOW, 28)} → "
                f"{_col(r['to'], _CYAN)}"
            )

    # ── Added (new in candidate) ──────────────────────────────────────────────
    if report["added"]:
        print(f"\n{_BOLD}  + Added in {cand_lbl} ({len(report['added'])}):{_RESET}")
        for f in report["added"]:
            conf = f.get("confidence")
            conf_str = f"  conf={conf:.0%}" if conf is not None else ""
            print(
                f"    {_col(f['name'], _GREEN, 28)}"
                f"  {f['bssid_prefix']:<18}  {f['band']}GHz"
                f"{_col(conf_str, _CYAN)}"
            )
    else:
        print(f"\n  {_col('+ No new features added.', _CYAN)}")

    # ── Removed (in baseline but not in candidate) ────────────────────────────
    if report["removed"]:
        print(f"\n{_BOLD}  - Removed from {cand_lbl} ({len(report['removed'])}):{_RESET}")
        for f in report["removed"]:
            print(
                f"    {_col(f['name'], _RED, 28)}"
                f"  {f['bssid_prefix']:<18}  {f['band']}GHz"
            )
        print(
            f"\n  {_col('⚠ WARNING:', _YELLOW)} The above APs exist in the frozen Flutter "
            f"model\n    but are absent from the candidate set.\n"
            f"    If you deploy the candidate, those features will read as\n"
            f"    MISSING_RSSI (-100) until fingerprints are retrained."
        )
    else:
        print(f"\n  {_col('- No features removed.', _CYAN)}")

    # ── Summary ───────────────────────────────────────────────────────────────
    print(f"\n{'─' * 64}")
    safe = len(report["removed"]) == 0
    status = _col("SAFE TO DEPLOY", _GREEN) if safe else _col("REQUIRES RETRAINING", _RED)
    print(f"  Migration status: {_BOLD}{status}{_RESET}")
    print(f"{'─' * 64}\n")


# ─── CLI ──────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compare AP feature sets for MapMyFloor migration."
    )
    parser.add_argument(
        "--registry",
        type=Path,
        default=Path("data/feature_registry.json"),
        help="Dynamic feature registry JSON (from process_wifi_scans.py --discover).",
    )
    parser.add_argument(
        "--extractor",
        type=Path,
        default=Path("lib/indoor_nav/feature_extractor.dart"),
        help="Existing Flutter feature_extractor.dart to compare against.",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=None,
        help="Optional: write JSON report to this path.",
    )
    parser.add_argument(
        "--mode",
        choices=["frozen-vs-registry", "extractor-vs-registry", "frozen-vs-extractor"],
        default="frozen-vs-registry",
        help="Which two sets to compare (default: frozen-vs-registry).",
    )
    args = parser.parse_args()

    # ── Load sets ─────────────────────────────────────────────────────────────
    frozen = _load_frozen()

    registry: list[dict[str, Any]] = []
    if args.registry.exists():
        registry = _load_registry(args.registry)
    else:
        print(f"⚠  Registry not found at {args.registry}.")
        print("   Run:  python tools/process_wifi_scans.py --discover")
        print("   then re-run this script.\n")

    extractor: list[dict[str, Any]] = []
    if args.extractor.exists():
        extractor = _load_extractor_dart(args.extractor)
    else:
        print(f"⚠  feature_extractor.dart not found at {args.extractor}.\n")

    # ── Compare ───────────────────────────────────────────────────────────────
    if args.mode == "frozen-vs-registry":
        if not registry:
            print("Cannot compare: registry is empty.")
            return
        report = compare(frozen, registry, "Frozen (12-AP model)", "Dynamic Registry")

    elif args.mode == "extractor-vs-registry":
        if not extractor:
            print("Cannot compare: extractor could not be parsed.")
            return
        if not registry:
            print("Cannot compare: registry is empty.")
            return
        report = compare(extractor, registry, "feature_extractor.dart", "Dynamic Registry")

    elif args.mode == "frozen-vs-extractor":
        if not extractor:
            print("Cannot compare: extractor could not be parsed.")
            return
        report = compare(frozen, extractor, "Frozen (12-AP model)", "feature_extractor.dart")

    else:
        raise ValueError(f"Unknown mode: {args.mode}")

    print_report(report)

    # ── JSON report ───────────────────────────────────────────────────────────
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)

        # Make report JSON-serialisable (remove non-serialisable datetime objects)
        def _sanitize(obj: Any) -> Any:
            if isinstance(obj, dict):
                return {k: _sanitize(v) for k, v in obj.items()}
            if isinstance(obj, list):
                return [_sanitize(i) for i in obj]
            return str(obj) if not isinstance(obj, (str, int, float, bool, type(None))) else obj

        args.report.write_text(json.dumps(_sanitize(report), indent=2))
        print(f"📄 JSON report written → {args.report}\n")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Conservative observational comparison of ESLint cyclomatic complexity."""
import argparse
import collections
import json
import re
from pathlib import Path

PATTERN = re.compile(r"complexity of (\d+)")
NAME = re.compile(r"(?:Method|function|Function) '([^']+)'")


def extract(report):
    result = []
    for item in report:
        path = Path(item["filePath"])
        parts = path.parts
        relative = "/".join(parts[parts.index("Yebenes") + 1:]) if "Yebenes" in parts else path.name
        for issue in item.get("messages", []):
            if issue.get("ruleId") != "complexity":
                continue
            match = PATTERN.search(issue.get("message", ""))
            if not match:
                raise ValueError("Unrecognized complexity diagnostic")
            name = NAME.search(issue["message"])
            result.append({"file": relative, "name": name.group(1) if name else None,
                           "complexity": int(match.group(1)), "line": issue.get("line")})
    return result


def compare(before, after):
    def indexed(entries):
        named = collections.defaultdict(list)
        unnamed = collections.defaultdict(list)
        for item in entries:
            key = (item["file"], item["name"])
            (named if item["name"] else unnamed)[key].append(item)
        return named, unnamed
    old, old_anon = indexed(before)
    new, new_anon = indexed(after)
    regressions, improvements, uncertain = [], [], []
    for key in sorted(set(old) | set(new)):
        a, b = old.get(key, []), new.get(key, [])
        if len(a) != 1 or len(b) != 1:
            uncertain.append({"key": key, "reason": "Added, removed or ambiguous named function"})
        elif b[0]["complexity"] > a[0]["complexity"]:
            regressions.append({"key": key, "from": a[0]["complexity"], "to": b[0]["complexity"]})
        elif b[0]["complexity"] < a[0]["complexity"]:
            improvements.append({"key": key, "from": a[0]["complexity"], "to": b[0]["complexity"]})
    # Anonymous functions cannot be safely matched by line number after edits.
    if old_anon != new_anon:
        uncertain.append({"key": "anonymous functions", "reason": "Manual correlation required"})
    status = "REGRESSION" if regressions else "INCONCLUSIVE" if uncertain else "PASS"
    return {"status": status, "baseline_findings": len(before), "current_findings": len(after),
            "regressions": regressions, "improvements": improvements, "uncertain": uncertain}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    try:
        baseline = json.loads(Path(args.baseline).read_text())
        report = json.loads(Path(args.report).read_text())
        if baseline.get("schema") != 1 or baseline.get("threshold") != 15:
            raise ValueError("Baseline schema or threshold mismatch")
        result = compare(baseline["findings"], extract(report))
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        result = {"status": "ERROR", "reason": str(exc)}
    Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
    print("QUAL-02A:", result["status"], "(observational)")
    return 0  # Informative only: state is carried in JSON.


if __name__ == "__main__":
    raise SystemExit(main())

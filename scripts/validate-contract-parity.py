#!/usr/bin/env python3
"""validate-contract-parity.py: env-var inventory parity test.

Asserts that the set of operator-facing environment variables in
z3-contract.yaml matches reality:

  compose substitutions  ->  env_vars       (every ${VAR} must be contracted)
  env_vars               <->  .env.example  (mutual: no orphans either way)

Complements validate-contract.py, which asserts the per-network port
matrix against resolved compose output.

Exit codes:
  0  all parity checks pass
  1  one or more parity checks failed
  2  prerequisite missing (PyYAML, files)
"""

from __future__ import annotations

import pathlib
import re
import sys

try:
    import yaml
except ImportError:
    print("FAIL: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(2)

ROOT = pathlib.Path(__file__).resolve().parent.parent

COMPOSE_FILES = [
    ROOT / "docker-compose.yml",
    ROOT / "docker-compose.regtest.yml",
]
CONTRACT_FILE = ROOT / "z3-contract.yaml"
ENV_EXAMPLE = ROOT / ".env.example"

VAR_NAME = r"[A-Z][A-Z0-9_]+"

# $${VAR} is Compose's literal-escape (resolved by the container shell, not
# Compose), so the negative lookbehind skips it. ${VAR} and ${VAR:-default}
# both match.
COMPOSE_SUB_RE = re.compile(rf"(?<!\$)\$\{{({VAR_NAME})")

# .env.example lines look like `# VAR=default` or `VAR=value`.
ENV_LINE_RE = re.compile(rf"^#?\s*({VAR_NAME})\s*=", re.MULTILINE)


def read_text(path: pathlib.Path) -> str:
    return path.read_text() if path.exists() else ""


def collect_compose_vars() -> set[str]:
    found: set[str] = set()
    for f in COMPOSE_FILES:
        found |= {m.group(1) for m in COMPOSE_SUB_RE.finditer(read_text(f))}
    return found


def collect_contract_vars(contract: dict) -> set[str]:
    env_vars: set[str] = set()
    for _, entries in contract.get("env_vars", {}).items():
        env_vars |= {e["name"] for e in entries}
    return env_vars


def collect_ecosystem_vars(contract: dict) -> set[str]:
    return {e["name"] for e in contract.get("ecosystem_vars", [])}


def collect_env_example_vars() -> set[str]:
    return {m.group(1) for m in ENV_LINE_RE.finditer(read_text(ENV_EXAMPLE))}


def report_diff(subset_label: str, subset: set[str],
                superset_label: str, superset: set[str]) -> int:
    missing = subset - superset
    if not missing:
        print(f"  OK   every var in {subset_label} is present in {superset_label}")
        return 0
    print(f"  FAIL {len(missing)} var(s) in {subset_label} missing from {superset_label}:")
    for v in sorted(missing):
        print(f"         - {v}")
    return 1


def main() -> int:
    for f in [*COMPOSE_FILES, CONTRACT_FILE, ENV_EXAMPLE]:
        if not f.exists():
            print(f"FAIL: missing {f.relative_to(ROOT)}")
            return 1

    contract = yaml.safe_load(CONTRACT_FILE.read_text())
    compose = collect_compose_vars()
    env_vars = collect_contract_vars(contract)
    ecosystem_vars = collect_ecosystem_vars(contract)
    env_example = collect_env_example_vars()

    documented = env_vars | ecosystem_vars

    failures = 0

    # Compose substitutions may include ecosystem-standard names (RUST_LOG,
    # RUST_BACKTRACE) used as fallback chains; allow them.
    print("== Compose substitutions vs contract (env_vars u ecosystem_vars) ==")
    failures += report_diff("compose substitutions", compose,
                            "z3-contract.yaml (env + ecosystem)", documented)

    # .env.example documents both z3 surface and ecosystem fallbacks the
    # operator may want to set.
    print()
    print("== Contract (env_vars u ecosystem_vars) vs .env.example ==")
    failures += report_diff("z3-contract.yaml env_vars", env_vars, ".env.example", env_example)
    failures += report_diff(".env.example", env_example,
                            "z3-contract.yaml (env + ecosystem)", documented)

    print()
    if failures == 0:
        print("PASS: contract inventory is in sync with compose and .env.example.")
        return 0
    print(f"FAIL: {failures} parity check(s) failed.")
    return 1


if __name__ == "__main__":
    sys.exit(main())

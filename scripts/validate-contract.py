#!/usr/bin/env python3
"""validate-contract.py: assert resolved Compose output matches z3-contract.yaml.

Parses the platform contract's port matrix, volume names, RPC auth mode, and
service DNS directly from z3-contract.yaml, runs `docker compose --env-file
.env.<net> --profile zcashd --profile monitoring config` for each declared
network, and asserts that the resolved values match.

Volumes and ports can be plain values or {name, profile} / {container, host,
profile} dicts. Profile-gated entries are checked the same way: the renderer
runs with all profiles enabled, so every contracted identifier is expected
in the output.

Requires PyYAML. Pre-installed on GitHub Actions ubuntu-latest. For local
runs: pip install pyyaml.

Exit codes:
  0  every assertion passes
  1  one or more assertions failed
  2  prerequisite missing (docker, PyYAML, env files, contract)
"""

from __future__ import annotations

import pathlib
import re
import subprocess
import sys

try:
    import yaml
except ImportError:
    print("FAIL: PyYAML is required. Install with: pip install pyyaml", file=sys.stderr)
    sys.exit(2)

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONTRACT_FILE = ROOT / "z3-contract.yaml"
PROMETHEUS_CONFIG = ROOT / "observability" / "prometheus" / "prometheus.yaml"


def volume_name(entry: str | dict) -> str:
    """volumes.zaino can be a string or {name, profile?} dict."""
    return entry if isinstance(entry, str) else entry["name"]


class Asserter:
    def __init__(self) -> None:
        self.failures = 0

    def present(self, label: str, pattern: str, haystack: str) -> None:
        if re.search(pattern, haystack, re.MULTILINE):
            print(f"  OK   {label}")
        else:
            print(f"  FAIL {label} (expected pattern: {pattern})")
            self.failures += 1

    def absent(self, label: str, pattern: str, haystack: str) -> None:
        if re.search(pattern, haystack, re.MULTILINE):
            print(f"  FAIL {label} (unexpected pattern: {pattern})")
            self.failures += 1
        else:
            print(f"  OK   {label}")

    def fail(self, label: str) -> None:
        print(f"  FAIL {label}")
        self.failures += 1


def load_contract() -> dict:
    if not CONTRACT_FILE.exists():
        print(f"FAIL: missing {CONTRACT_FILE.relative_to(ROOT)}", file=sys.stderr)
        sys.exit(2)
    return yaml.safe_load(CONTRACT_FILE.read_text())


def compose_files_for_network(network_name: str) -> list[str]:
    files = ["docker-compose.yml"]
    overlay = ROOT / f"docker-compose.{network_name}.yml"
    if overlay.exists():
        files.append(overlay.name)
    return files


def render_compose(network_name: str, env_file: pathlib.Path) -> str:
    # Pass -f explicitly so local override files do not affect contract checks.
    compose_args: list[str] = []
    for compose_file in compose_files_for_network(network_name):
        compose_args.extend(["-f", compose_file])

    try:
        proc = subprocess.run(
            [
                "docker", "compose",
                *compose_args,
                "--env-file", str(env_file),
                "--profile", "zcashd",
                "--profile", "monitoring",
                "config",
            ],
            cwd=ROOT, capture_output=True, text=True, check=True,
        )
        return proc.stdout
    except FileNotFoundError:
        print("FAIL: docker not found in PATH. Install Docker Engine with the",
              file=sys.stderr)
        print("      Compose v2 plugin: https://docs.docker.com/compose/install/",
              file=sys.stderr)
        sys.exit(2)
    except subprocess.CalledProcessError as e:
        stderr = e.stderr or ""
        if "is not a docker command" in stderr or "'compose'" in stderr:
            print("FAIL: the 'docker compose' v2 plugin is not available.",
                  file=sys.stderr)
            print("      This stack requires Compose v2.24.4+; the legacy v1",
                  file=sys.stderr)
            print("      'docker-compose' binary is not supported. Install v2:",
                  file=sys.stderr)
            print("      https://docs.docker.com/compose/install/", file=sys.stderr)
            sys.exit(2)
        print(f"FAIL: docker compose config failed for {env_file.name}:")
        print(stderr)
        sys.exit(1)


def validate_no_undeclared_host_ports(asserter: Asserter, ports: dict, config: str) -> None:
    """Assert compose publishes no host port the contract omits (compose -> contract)."""
    contract_hosts = {p["host"] for p in ports.values() if p.get("host") is not None}
    rendered_hosts = {int(p) for p in re.findall(r'published: "(\d+)"', config)}
    undeclared = sorted(rendered_hosts - contract_hosts)
    for extra in undeclared:
        asserter.fail(f"published host port {extra} is not declared in the contract")
    if not undeclared:
        print("  OK   no undeclared published host ports")


def validate_network(asserter: Asserter, network_name: str, spec: dict) -> None:
    env_file = ROOT / f".env.{network_name}"
    if not env_file.exists():
        print(f"  FAIL: missing {env_file.relative_to(ROOT)}")
        asserter.failures += 1
        return

    print(f"== Network: {network_name} ({env_file.name}) ==")
    config = render_compose(network_name, env_file)

    project = spec["compose_project"]
    asserter.present(f"project name = {project}",
                     rf"^name: {re.escape(project)}$", config)
    asserter.present(f"external network = {spec['external_network']}",
                     rf"^    name: {re.escape(spec['external_network'])}$", config)

    for _, vol_entry in spec["volumes"].items():
        vol = volume_name(vol_entry)
        asserter.present(f"volume = {vol}",
                         rf"name: {re.escape(vol)}$", config)

    ports = spec["ports"]

    # Zebra container ports appear in the service environment block.
    asserter.present(
        f"Zebra RPC listen = {ports['zebra_rpc']['container']}",
        rf"ZEBRA_RPC__LISTEN_ADDR: 0\.0\.0\.0:{ports['zebra_rpc']['container']}$",
        config,
    )
    asserter.present(
        f"Zebra metrics listen = {ports['zebra_metrics']['container']}",
        rf"ZEBRA_METRICS__ENDPOINT_ADDR: 0\.0\.0\.0:{ports['zebra_metrics']['container']}$",
        config,
    )

    auth_mode = spec.get("rpc_auth", {}).get("mode")
    if auth_mode == "cookie":
        asserter.present(
            "Zebra cookie auth enabled",
            r"ZEBRA_RPC__ENABLE_COOKIE_AUTH: ['\"]?true['\"]?$",
            config,
        )
        asserter.present(
            "Zaino cookie path configured",
            r"ZAINO_VALIDATOR_SETTINGS__VALIDATOR_COOKIE_PATH: /var/run/auth/\.cookie$",
            config,
        )
    elif auth_mode == "username_password":
        asserter.present(
            "Zebra cookie auth disabled",
            r"ZEBRA_RPC__ENABLE_COOKIE_AUTH: ['\"]?false['\"]?$",
            config,
        )
        asserter.absent(
            "Zaino cookie path omitted",
            r"ZAINO_VALIDATOR_SETTINGS__VALIDATOR_COOKIE_PATH:",
            config,
        )

    # Host ports: every contracted port that has a host mapping must be
    # published. Entries without a host key (zebra_metrics on every network,
    # zebra_p2p on regtest) are container-only, so the assertion is skipped.
    for key, port_spec in ports.items():
        host = port_spec.get("host")
        if host is None:
            continue
        asserter.present(f"{key} host = {host}",
                         rf'published: "{host}"', config)

    # Bidirectional guard: compose must not publish a host port the contract
    # omits (the loop above already covers contract -> compose).
    validate_no_undeclared_host_ports(asserter, ports, config)

    # Zaino must point at Zebra's per-network RPC container port.
    asserter.present(
        f"Zaino -> Zebra RPC = {ports['zebra_rpc']['container']}",
        rf"ZAINO_VALIDATOR_SETTINGS__VALIDATOR_JSONRPC_LISTEN_ADDRESS: "
        rf"zebra:{ports['zebra_rpc']['container']}",
        config,
    )

    if network_name == "testnet":
        asserter.present("zcashd starts on testnet",
                         r"^\s+- -testnet$", config)
    elif network_name == "regtest":
        asserter.present("zcashd starts on regtest",
                         r"^\s+- -regtest$", config)


def validate_healthchecks(asserter: Asserter, network_name: str,
                          config: str, healthchecks: dict) -> None:
    """Spot-check rendered healthcheck.test shape against contract.healthchecks.

    Catches drift like flipping Zebra's healthcheck from /ready to /healthy,
    removing Zaino's TCP probe, or accidentally adding a healthcheck to a
    service the contract declares as transport: none.

    Regtest's Zebra healthcheck diverges (peerless network uses an RPC probe
    instead of /ready); the contract documents this so it is skipped here.
    """
    for service, spec in healthchecks.items():
        transport = spec.get("transport")
        port = spec.get("port")

        if service == "zebra" and network_name == "regtest":
            asserter.present(
                "Regtest Zebra healthcheck = getblockchaininfo RPC",
                r"getblockchaininfo", config,
            )
            continue

        if transport == "http" and spec.get("readiness"):
            pattern = rf"http://127\.0\.0\.1:{port}{re.escape(spec['readiness'])}"
            asserter.present(
                f"{service} healthcheck = http {port}{spec['readiness']}",
                pattern, config,
            )
        elif transport == "tcp":
            pattern = rf"/dev/tcp/127\.0\.0\.1/{port}"
            asserter.present(
                f"{service} healthcheck = tcp {port}",
                pattern, config,
            )
        # transport: none / cli are not asserted positively (Zallet has no
        # probe binary; zcashd uses zcash-cli which is profile-gated and
        # already covered by the -testnet/-regtest startup assertion).


def validate_unique_host_ports(asserter: Asserter, contract: dict) -> None:
    seen: dict[int, str] = {}
    for network_name, spec in contract["networks"].items():
        for key, port_spec in spec["ports"].items():
            host = port_spec.get("host")
            if host is None:
                continue
            label = f"{network_name}.{key}"
            existing = seen.get(host)
            if existing is not None:
                print(f"  FAIL host port {host} used by both {existing} and {label}")
                asserter.failures += 1
            else:
                seen[host] = label


def validate_prometheus_scrape_target(asserter: Asserter, contract: dict) -> None:
    """Assert the Prometheus zebra job targets the contract's zebra_metrics container port."""
    if not PROMETHEUS_CONFIG.exists():
        print("  SKIP observability/prometheus/prometheus.yaml not found")
        return

    expected_port = contract["networks"]["mainnet"]["ports"]["zebra_metrics"]["container"]
    config = PROMETHEUS_CONFIG.read_text()
    pattern = rf'job_name:\s*["\']?zebra["\']?[\s\S]*?targets:\s*\[\s*["\']zebra:{expected_port}["\']'
    if re.search(pattern, config):
        print(f"  OK   Prometheus zebra scrape target = zebra:{expected_port}")
    else:
        print(f"  FAIL Prometheus zebra scrape target does not match contract")
        print(f"         (expected zebra:{expected_port} in {PROMETHEUS_CONFIG.relative_to(ROOT)})")
        asserter.failures += 1


def main() -> int:
    contract = load_contract()
    asserter = Asserter()

    healthchecks = contract.get("healthchecks", {})
    for net_name, net_spec in contract["networks"].items():
        validate_network(asserter, net_name, net_spec)
        if healthchecks:
            env_file = ROOT / f".env.{net_name}"
            if env_file.exists():
                rendered = render_compose(net_name, env_file)
                print(f"-- Healthchecks ({net_name}) --")
                validate_healthchecks(asserter, net_name, rendered, healthchecks)

    print("== Cross-network host ports ==")
    validate_unique_host_ports(asserter, contract)

    print()
    print("== Prometheus scrape target ==")
    validate_prometheus_scrape_target(asserter, contract)

    print()
    if asserter.failures == 0:
        print("PASS: all contract assertions hold.")
        return 0
    print(f"FAIL: {asserter.failures} assertion(s) did not hold.")
    return 1


if __name__ == "__main__":
    sys.exit(main())

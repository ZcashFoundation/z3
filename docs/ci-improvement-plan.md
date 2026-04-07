# CI/CD Improvement Plan

> Context: Issue #28 revealed that the zaino service's docker-compose command was missing
> a required `start` subcommand, causing the service to crash on startup. No CI test
> existed to catch this. This document identifies gaps and proposes improvements.

## Current State

**What exists:**
- `build-z3-images.yaml` — builds Docker images for zebra, zaino, and zallet on GHCR
- `sub-build-docker-image.yaml` — reusable build workflow with provenance/SBOM attestations
- Triggers: `workflow_dispatch`, push to `dev` (only when workflow file changes), PR (same)

**What doesn't exist:**
- No PR-level CI (linting, validation, smoke tests)
- No compose config validation
- No service startup verification
- No integration or smoke tests at the z3 level

## Gap Analysis

### Failure classes not caught by CI

| # | Failure Class | Example | Impact |
|---|---------------|---------|--------|
| 1 | Wrong CLI args in compose | Missing `start` subcommand (#28) | Service crashes on startup |
| 2 | Broken compose YAML | Bad interpolation, typo in env var | Stack won't start |
| 3 | Service fails to start | Bad config, missing mount, wrong port | Silent failure until user reports |
| 4 | Incompatible versions | Zaino built for Zebra 4.2 running against 4.3 | Runtime errors |
| 5 | Config format drift | TOML key renamed in new version | Service rejects config at startup |
| 6 | Weak healthchecks | Zaino checks `--version` not port liveness | Compose reports healthy when service is broken |
| 7 | Image not pullable | GHCR tag deleted or wrong | `docker compose up` fails |

---

## Proposed Improvements

### Critical — Would have prevented #28

#### 1. Compose config validation on PRs

Validate that the compose files parse correctly and all variable interpolation resolves.

```yaml
# Runs on every PR that touches compose, config, or env files
- name: Validate compose config
  run: |
    docker compose config --quiet
    docker compose --env-file .env.regtest config --quiet
```

**Effort:** ~15 min. Single workflow file addition.

#### 2. Service startup smoke tests on PRs

Build the images from submodules and verify each service starts without crashing.
This is the test that would have caught #28 directly.

```yaml
- name: Smoke test zaino
  run: |
    docker compose build zaino
    docker run --rm --entrypoint zainod ghcr.io/zcashfoundation/zaino:sha-$SHA start --help
    # Exits 0 = binary accepts the subcommand

- name: Smoke test zallet
  run: |
    docker run --rm electriccoinco/zallet:v0.1.0-alpha.3 --help

- name: Smoke test zebra
  run: |
    docker run --rm zfnd/zebra:4.3.0 zebrad --help
```

**Effort:** ~1 hour. Requires building zaino image in CI (~15 min build time).

#### 3. PR-triggered CI workflow

Currently nothing runs on PRs. Add a `ci.yaml` triggered on `pull_request` that runs
the above validations plus basic linting.

```yaml
on:
  pull_request:
    paths:
      - 'docker-compose*.yml'
      - '.env*'
      - 'config/**'
      - '.github/workflows/**'
```

**Effort:** ~30 min. New workflow file.

---

### Important — Catches broader failure classes

#### 4. Regtest integration test (post-merge on dev)

After merging to `dev`, spin up the full regtest stack and verify services communicate.
This catches version incompatibilities and dependency ordering issues.

```yaml
- name: Regtest integration test
  run: |
    docker compose build zaino
    docker compose --env-file .env.regtest up -d zebra
    # Wait for zebra healthcheck (regtest is fast, no chain sync)
    docker compose --env-file .env.regtest up -d zaino zallet
    sleep 30
    # Verify all services are running
    docker compose ps --format json | jq -e 'all(.State == "running")'
    # Basic RPC check
    docker compose exec zebra curl -sf http://127.0.0.1:18232 -d '{"jsonrpc":"2.0","method":"getblockchaininfo","params":[],"id":1}'
    docker compose down
```

**Effort:** ~2-3 hours. Requires regtest to work in CI (no external dependencies).

#### 5. Stronger healthchecks

The zaino Dockerfile HEALTHCHECK uses `zainod --version` which only proves the binary
exists, not that the service is listening. Replace with actual port probes.

**Zaino** (in upstream Dockerfile or compose override):
```yaml
healthcheck:
  test: ["CMD-SHELL", "bash -c 'echo > /dev/tcp/127.0.0.1/8137' 2>/dev/null || exit 1"]
```

**Zallet** has no healthcheck at all — add one or note that distroless images
limit healthcheck options (no shell/curl available).

**Effort:** ~1 hour. May require upstream PRs for Dockerfile changes.

#### 6. Pin GitHub Actions to commit SHAs

Current workflows use tag-only pinning (`actions/checkout@v4.2.2`). Tags can be
mutated by upstream maintainers. Pin to full SHA with version comment:

```yaml
# Before
uses: actions/checkout@v4.2.2
# After
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
```

**Effort:** ~30 min. Update all action references in both workflow files.

#### 7. Build image on PR (not just dev push)

Currently `build-z3-images.yaml` only builds images on push to `dev` or when the
workflow file itself changes. Add a PR trigger that builds (but doesn't push) to
validate Dockerfiles aren't broken.

```yaml
on:
  pull_request:
    paths:
      - 'docker-compose*.yml'
      - '.github/workflows/**'
```

With `push: false` in the build step for PR events (load into local runner only).

**Effort:** ~1 hour. Modify existing workflow.

---

### Nice to Have — Defense in depth

#### 8. Nightly full stack integration test

Scheduled workflow that pulls the latest pinned images (not build from source),
runs the full mainnet compose config up through healthchecks passing, then tears down.
Catches image registry issues and version drift.

```yaml
on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 06:00 UTC
```

**Effort:** ~2 hours. New workflow.

#### 9. Config roundtrip validation

Generate a default config with `zainod generate-config`, then verify `zainod start`
accepts it without parse errors. Catches config schema drift.

```yaml
- name: Config roundtrip test
  run: |
    docker run --rm --entrypoint zainod <image> generate-config --output /tmp/test.toml
    docker run --rm -v /tmp/test.toml:/etc/zaino/test.toml --entrypoint zainod <image> \
      start --config /etc/zaino/test.toml &
    sleep 5
    # Service should still be running (not crashed from config parse error)
```

**Effort:** ~1 hour.

#### 10. Workflow security scanning (zizmor)

Both zallet and zebra already run `zizmor` to detect GitHub Actions misconfigurations
(SARIF uploaded to GitHub Security). Add the same for z3's workflows.

**Effort:** ~30 min. Copy pattern from zallet's `zizmor.yml`.

#### 11. Dependabot for GitHub Actions

Auto-update GitHub Actions versions in workflows when new releases are available.

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
```

**Effort:** ~5 min. Single file.

---

## Priority Matrix

```
                    Low Effort          High Effort
                ┌──────────────────┬──────────────────┐
  Critical      │ 1. Compose valid │ 2. Smoke tests   │
  (do first)    │ 3. PR CI workflow│                   │
                ├──────────────────┼──────────────────┤
  Important     │ 6. SHA-pin acts  │ 4. Regtest integ │
                │ 7. PR image build│ 5. Healthchecks  │
                ├──────────────────┼──────────────────┤
  Nice to have  │ 10. zizmor       │ 8. Nightly test  │
                │ 11. Dependabot   │ 9. Config roundtr│
                └──────────────────┴──────────────────┘
```

## Recommended Implementation Order

1. **Compose validation + PR CI workflow** (items 1, 3) — immediate, low effort, high impact
2. **Service startup smoke tests** (item 2) — catches the exact class of bug that prompted this
3. **SHA-pin actions + Dependabot** (items 6, 11) — quick security wins
4. **Regtest integration test** (item 4) — the real end-to-end validation
5. **Stronger healthchecks** (item 5) — may require upstream coordination
6. Everything else as capacity allows

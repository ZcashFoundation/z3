# Z3 Observability Stack

Metrics, alerting, and dashboards for the Z3 stack (Zebra, Zaino, Zallet).

## Quick Start

```bash
# 1. Optional: enable Zebra trace export in .env
ZEBRA_TRACING__OPENTELEMETRY_ENDPOINT=http://jaeger:4318
ZEBRA_TRACING__OPENTELEMETRY_SERVICE_NAME=zebra-mainnet
ZEBRA_TRACING__OPENTELEMETRY_SAMPLE_PERCENT=100

# 2. Start the full stack with monitoring.
# Passing .env as a second env file also applies local port and image overrides.
docker compose --env-file .env.mainnet --env-file .env --profile monitoring up -d

# 3. View logs
docker compose --env-file .env.mainnet --env-file .env logs -f zebra
```

> **Note**: The monitoring profile starts Jaeger, but Zebra only exports spans
> after `ZEBRA_TRACING__OPENTELEMETRY_ENDPOINT` is set. The pinned Zebra image
> and the default local build use `default-release-binaries`, which includes
> OpenTelemetry. If you override `Z3_ZEBRA_BUILD_FEATURES`, keep
> `opentelemetry` in the feature list.

## Components

| Component | Purpose |
|-----------|---------|
| **Zebra** | Zcash node with metrics and tracing (in-network scrape on `:9999`) |
| **Prometheus** | Metrics collection and storage |
| **Grafana** | Dashboards and visualization |
| **Jaeger** | Distributed tracing UI |
| **AlertManager** | Alert routing |

Published host ports for these components are per-network and live in [`z3-contract.yaml`](../z3-contract.yaml) under `networks.<name>.ports` (the `monitoring` profile).

Default Grafana credentials: `admin` / `admin` (you'll be prompted to change on first login)

## Architecture

```text
┌─────────────────────────────────────────────────────────────────────┐
│                         Zebra Node                                  │
│  ┌─────────────────┐              ┌─────────────────────────────┐   │
│  │ Metrics         │              │ Tracing (OpenTelemetry)     │   │
│  │ :9999/metrics   │              │ OTLP HTTP → Jaeger          │   │
│  └────────┬────────┘              └──────────────┬──────────────┘   │
└───────────│──────────────────────────────────────│──────────────────┘
            │                                      │
            ▼                                      ▼
┌───────────────────┐                  ┌───────────────────────────┐
│   Prometheus      │                  │        Jaeger             │
│   :9094           │                  │   :16686 (UI)             │
│                   │◄─────────────────│   :8889 (spanmetrics)     │
│   Scrapes metrics │  Span metrics    │   :4318 (OTLP HTTP)       │
└─────────┬─────────┘                  └───────────────────────────┘
          │                                        │
          ▼                                        │
┌───────────────────┐                              │
│     Grafana       │◄─────────────────────────────┘
│     :3000         │      Trace queries
│                   │
│  Dashboards for   │
│  metrics + traces │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│   AlertManager    │
│   :9093           │
│                   │
│  Routes alerts    │
└───────────────────┘
```

## What Each Component Provides

### Metrics (Prometheus + Grafana)

Quantitative data about Zebra's behavior over time:

- **Network health**: Peer connections, bandwidth, message rates
- **Sync progress**: Block height, checkpoint verification, chain tip
- **Performance**: Block/transaction verification times
- **Resources**: Memory, connections, queue depths

See [grafana/README.md](grafana/README.md) for dashboard details.

### Tracing (Jaeger)

Distributed tracing uses Zebra's OpenTelemetry exporter and the Jaeger collector
from the `monitoring` profile. Jaeger can run without Zebra traces; Zebra begins
exporting spans only after the OTLP endpoint is configured.

Enable tracing in `.env`:

```bash
ZEBRA_TRACING__OPENTELEMETRY_ENDPOINT=http://jaeger:4318
ZEBRA_TRACING__OPENTELEMETRY_SERVICE_NAME=zebra-mainnet
ZEBRA_TRACING__OPENTELEMETRY_SAMPLE_PERCENT=100
```

Then recreate Zebra with the local env file loaded:

```bash
docker compose --env-file .env.mainnet --env-file .env --profile monitoring up -d --force-recreate zebra
```

`ZEBRA_TRACING__OPENTELEMETRY_*` values reach the Zebra container through its
service-level `env_file`. `Z3_*` values such as `Z3_ZEBRA_IMAGE` and
`Z3_JAEGER_OTLP_HTTP_PORT` are Compose interpolation inputs, so they need to be
exported in the shell or loaded with `--env-file .env`.

If you build a custom Zebra image with `Z3_ZEBRA_BUILD_FEATURES`, include
`opentelemetry` or use `default-release-binaries`.

Jaeger provides:

- **Distributed traces**: Follow a request through all components
- **Latency breakdown**: See where time is spent in each operation
- **Error analysis**: Identify failure points and error propagation
- **Service Performance Monitoring (SPM)**: RED metrics for RPC endpoints

See [jaeger/README.md](jaeger/README.md) for tracing details.

### Alerts (AlertManager)

Automated notifications for operational issues:

- Critical: Negative value pools (ZIP-209 violation)
- Warning: High RPC latency, sync stalls, peer connection issues

Configure alert destinations in [alertmanager/alertmanager.yml](alertmanager/alertmanager.yml).

## Configuration

### Environment Variables

Add this to your `.env` file to enable Zebra metrics:

| Variable | Default | Description |
|----------|---------|-------------|
| `ZEBRA_METRICS__ENDPOINT_ADDR` | - | Prometheus metrics endpoint (e.g., `0.0.0.0:9999`) |

### Port Customization

Override default monitoring host ports via the `Z3_*` env vars in your env file or `.env`:

```bash
Z3_GRAFANA_PORT=3000
Z3_PROMETHEUS_PORT=9094
Z3_JAEGER_UI_PORT=16686
Z3_ALERTMANAGER_PORT=9093
```

See [`z3-contract.yaml`](../z3-contract.yaml) for the full env-var schema.

## Common Tasks

### View Zebra's current metrics

```bash
docker compose --env-file .env.mainnet exec zebra \
  curl -sf http://127.0.0.1:9999/metrics | grep zcash
```

Zebra's metrics port is intentionally in-network only; Prometheus scrapes it on
the Compose network.

### Query Prometheus directly

```bash
# Current block height
curl -s 'http://localhost:9094/api/v1/query?query=zcash_state_tip_height'
```

## Troubleshooting

### No metrics in Grafana

1. Verify `ZEBRA_METRICS__ENDPOINT_ADDR=0.0.0.0:9999` is set in `.env`
2. Restart Zebra: `docker compose --env-file .env.mainnet --env-file .env restart zebra`
3. Check Zebra is exposing metrics: `docker compose --env-file .env.mainnet exec zebra curl -sf http://127.0.0.1:9999/metrics | head`
4. Check Prometheus targets: <http://localhost:9094/targets>

### No traces in Jaeger

1. Verify Zebra has the OTLP env vars: `docker inspect z3-mainnet-zebra-1 --format '{{range .Config.Env}}{{println .}}{{end}}' | grep ZEBRA_TRACING__OPENTELEMETRY`
2. Check Zebra installed the tracing layer: `docker logs z3-mainnet-zebra-1 | grep 'installed OpenTelemetry tracing layer'`
3. Check Jaeger has the Zebra service: `curl -s http://127.0.0.1:16686/api/services`
4. Check Prometheus has span metrics: `curl -sG http://127.0.0.1:9094/api/v1/query --data-urlencode 'query=traces_span_metrics_calls_total{service_name="zebra-mainnet"}'`

## Running Without Monitoring

To run the Z3 stack without monitoring:

```bash
docker compose up -d  # Only starts zebra, zaino, zallet
```

To add monitoring later:

```bash
docker compose --profile monitoring up -d
```

# Z3 Dockerization & Orchestration Summary

## Current State

### Zebra
- **Dockerfile:** Multi-stage build with test, runtime stages
  - Build stage installs dependencies and builds binaries
  - Runtime stage uses Debian bookworm-slim base
  - Configurable non-root user (UID 10001 for security)

- **Configuration:**
  - Flexible via multiple methods:
    - Environment variables
    - `.env` files
    - TOML config files
    - Command-line arguments
  - Default config at `$HOME/.config/zebrad.toml`

- **Docker Compose Files:**
  1. `docker-compose.yml`: Base production setup
  2. `docker-compose.grafana.yml`: Monitoring with Prometheus/Grafana
  3. `docker-compose.lwd.yml`: Integration with lightwalletd
  4. `docker-compose.test.yml`: Testing environment

- **Volume Management:**
  - Primary state/cache at `/home/zebra/.cache/zebra`
  - Cookie auth directory configurable
  - Log files (optional) at customizable location

- **Networking:**
  - RPC port: 8232 (mainnet) / 18232 (testnet)
  - Prometheus metrics: 9999
  - Tracing endpoint: 3000
  - P2P network ports configurable

- **Security Features:**
  - Non-root user
  - Cookie authentication
  - TLS support
  - Safe privilege dropping via gosu

### Zaino
- **Dockerfile:** Multi-stage Rust build
  - Build stage with comprehensive Rust dependencies
  - Runtime stage on Debian bookworm-slim
  - Non-root user (UID 2003)

- **Configuration:**
  - TOML config file (`zindexer.toml`)
  - CLI argument `--config` for config path
  - Key settings:
    - `grpc_listen_address` (default: localhost:8137)
    - `validator_listen_address` (Zebra RPC endpoint)
    - `db_path` (default: $HOME/.cache/zaino/)
    - Network selection (Mainnet/Testnet)

- **Volume Management:**
  - Block cache DB at configurable path (default: $HOME/.cache/zaino/)
  - Size configurable via `db_size` setting

- **Networking:**
  - gRPC service on port 8137
  - TLS support available
  - Connects to Zebra's RPC endpoint

## Unified Compose Plan

A unified docker-compose should integrate Zebra and Zaino with the following considerations:

1. **Service Dependencies:**
```yaml
services:
  zebra:
    # Base from zebra/docker/docker-compose.yml
    volumes:
      - zebra-cache:/home/zebra/.cache/zebra
    ports:
      - "18232:18232"  # RPC (testnet)
      - "9999:9999"    # Metrics (optional)

  zaino:
    depends_on:
      - zebra
    volumes:
      - zaino-cache:/home/zaino/.cache/zaino
    ports:
      - "8137:8137"    # gRPC
```

2. **Volume Management:**
```yaml
volumes:
  zebra-cache:
    driver: local
  zaino-cache:
    driver: local
```

3. **Networking:**
```yaml
networks:
  z3net:
    driver: bridge
```

4. **Configuration:**
- Mount custom config files for both services
- Ensure Zaino's validator_listen_address points to Zebra's RPC
- Consider adding Prometheus/Grafana from Zebra's monitoring setup

## Next Steps

1. **Zallet Integration:**
   - Research Zallet's Docker requirements
   - Determine how it connects to Zebra/Zaino
   - Add to unified compose

2. **Testing:**
   - Develop integration tests between services
   - Verify volume persistence
   - Test network connectivity

3. **Production Readiness:**
   - Add health checks
   - Configure logging
   - Set up monitoring
   - Document backup procedures

4. **Documentation:**
   - Document all config options
   - Provide example compose files
   - Add troubleshooting guide

## Related work
Review the Helm charts created by https://github.com/zecrocks/zcash-stack to get a sense of how this project is running Zcash infrastructure in production.
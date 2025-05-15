# Active Context

## Current Focus

1. **Docker Orchestration:**
   - Completed investigation of Zebra and Zaino Docker configurations.
   - Documented Docker/orchestration findings in z3_docker.md.
   - Next: Research Zallet's Docker requirements for full stack integration.

2. **Z3 Stack Integration:**
   - Planning unified Docker Compose for all components.
   - Identifying volume management and networking requirements.
   - Need to verify service communication patterns.

3. **Production Readiness:**
   - Developing monitoring and observability setup.
   - Planning health checks and logging configuration.
   - Exploring backup and recovery procedures.

4. **Documentation:**
   - Maintaining comprehensive Memory Bank updates.
   - Documenting Docker deployment patterns.
   - Creating configuration and troubleshooting guides.

## Recent Changes

1. **Docker Investigation:**
   - Analyzed Zebra's multi-stage Dockerfile and compose configurations.
   - Examined Zaino's Docker setup and runtime requirements.
   - Created z3_docker.md to document findings and orchestration plan.
   - Identified key configuration patterns and integration points.

2. **Zebra Adoption Tracking Script:**
   - Created and debugged `analyze_nodes.sh` to parse zcashexplorer.com HTML for Zebra and MagicBean node counts.

3. **RPC Integration:**
   - Mapped RPC methods to services using [RPC mapping](./data/rpc_mapping.md).
   - Identified service communication paths for Docker networking.
   - Examined Zebra and Zaino configuration for RPC endpoints.

## Active Decisions

1. **Docker Architecture:**
   - Use multi-stage builds for all components
   - Implement secure defaults (non-root users, TLS)
   - Standardize volume management patterns
   - Plan for production monitoring

2. **Configuration Management:**
   - Use TOML configs mounted into containers
   - Implement consistent environment variable patterns
   - Plan for secrets management

## Important Patterns

1. **Memory Bank Maintenance:**
   - Keep documentation synchronized with implementation
   - Document all configuration options and rationale
   - Track deployment patterns and decisions

2. **Docker Best Practices:**
   - Multi-stage builds for efficient images
   - Non-root users for security (UIDs 10001, 2003)
   - Volume management for persistent data
   - Service isolation and clear network boundaries

3. **Configuration Patterns:**
   - TOML files for service configuration
   - Environment variables for runtime settings
   - Consistent volume mount points
   - Standard logging and metrics exposure

## Learnings and Insights

1. **Docker Architecture:**
   - Zebra's Docker setup provides a robust template for production deployment
   - Zaino's configuration allows flexible validator integration
   - Volume management is critical for state persistence
   - Service networking needs careful planning for security

2. **Integration Patterns:**
   - RPC routing determines network architecture
   - Service discovery via Docker DNS
   - Configuration must align across services
   - Monitoring needs coordinated across stack

3. **Project Architecture:**
   - Modular components enable independent scaling
   - Shared patterns improve maintainability
   - Security considerations affect all layers
   - Documentation crucial for successful deployment

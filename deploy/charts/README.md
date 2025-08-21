# z3 Helm Chart - Plug and Play Zcash Ecosystem Deployment

This Helm chart is designed to be a **plug and play solution** for deploying the z3 ecosystem on Kubernetes. With minimal configuration, you can easily deploy `zebra`, `zaino`, `zallet`, and `caddy` to run a fully functional z3 infrastructure.

### Caddy as a Frontend

By default, this chart uses **Caddy** as a web frontend for `zaino`, making it simple to expose the `zaino` service securely over HTTPS. Caddy automatically manages SSL certificates and provides a modern, user-friendly configuration for serving HTTP(S) traffic. This setup allows you to quickly expose `zaino` to external clients, such as mobile wallets, without worrying about complex web server configurations.

### Customization Options

Although the default configuration is ready to deploy and run, this Helm chart is highly customizable. You can easily adapt it to fit your specific infrastructure needs:

- **Ingress or Internal Deployment**: If you prefer not to use `Caddy` or want to integrate the deployment with an existing ingress controller (like NGINX, Traefik, etc.), you can disable Caddy and configure your own ingress to expose `zaino` or other services. This makes the chart suitable for use in internal networks or environments where `Caddy` is not needed.

- **Internal Infrastructure**: For deployments that don’t require public exposure (e.g., running on internal networks or for development purposes), you can modify the chart to adjust how services are exposed, allowing tighter integration with internal load balancers or private networking configurations.

- **Custom Images and Resources**: All Docker images, resource limits, volume sizes, and other Kubernetes objects are fully customizable. You can override any value in the `values.yaml` file or through the `--set` flags in Helm, making it easy to adapt the deployment to your exact specifications.

In summary, this Helm chart provides a turnkey solution to deploy the Zcash ecosystem (z3) quickly and securely. However, it is also flexible enough to be adapted for more advanced use cases, whether for public-facing deployments or internal infrastructures.

## Components Overview

This Helm chart includes several components that work together to create a complete Zcash infrastructure setup. Below is a brief explanation of each component, along with links to their respective GitHub repositories for more information.

### Zebra
`zebra` is a Zcash full node implementation developed by the Zcash Foundation. It is responsible for maintaining the Zcash blockchain, validating transactions, and participating in the Zcash peer-to-peer network. zebra is written in Rust and focuses on security, performance, and modularity. It was developed to promote diversity in Zcash node software, making the network more robust and resilient. zebra is the preferred full node implementation for new deployments, and is configured by default in this Helm chart.

- GitHub: [Zebra Repository](https://github.com/ZcashFoundation/zebra)

### Zaino
TODO

- GitHub: [Zaino Repository](https://github.com/zingolabs/zaino)

### Zallet
TODO

- GitHub: [Zallet Repository](https://github.com/zcash/wallet)

### Caddy
`Caddy` is a modern web server that can be deployed as a frontend for `lightwalletd`. It provides easy HTTPS configuration, automatic certificate management, and other features like routing and reverse proxying. In this setup, Caddy handles incoming HTTP traffic for `lightwalletd`, ensuring secure connections and simplified configuration.

- GitHub: [Caddy Repository](https://github.com/caddyserver/caddy)

## Project Structure

- **Chart.yaml**: Metadata of the Helm chart.
- **values.yaml**: Default values for deploying the Helm chart.
- **templates/**: Helm templates that generate Kubernetes manifests.
- **.gitignore**: Specifies files and directories to be ignored by Git.

## Installation

To use this Helm chart, you need to have [Helm](https://helm.sh/docs/intro/install/) installed.

1. Navigate to the chart directory:

   ```bash
   cd z3/deploy/charts
   ```
2. Add the repo

   ```bash
   helm repo add z3 https://ZcashFoundation.github.io/z3/
   ```

3. Install the chart:

   ```bash
   helm install <release-name> z3/z3-stack
   ```

4. If you need to override the default values, create a custom `values.yaml` and use the following command:

   ```bash
   helm install <release-name> z3/z3-stack --values <custom-values-file.yaml>
   ```

## Configuration

The following table lists the configurable parameters of the z3-stack Helm chart and their default values:

| Parameter                     | Description                                                  | Default                                   | Required | Possible values                          |
|--------------------------------|--------------------------------------------------------------|-------------------------------------------|----------|------------------------------------------|
| `zebra.enabled`                | Enable Zebra node deployment                                 | `True`                                    | True    | `False`, `True`                          |
| `zebra.name`                   | Name of the Zebra instance                                   | `zebra`                                   | True    | Any string                               |
| `zebra.testnet`                | Enable Zebra testnet mode                                    | `False`                                   | True    | `False`, `True`                          |
| `zebra.image.repository`       | Zebra Docker image repository                                | `zfnd/zebra`                              | True    | Any valid image repository               |
| `zebra.image.tag`              | Zebra Docker image tag                                       | `latest`                                  | True    | Any valid image tag                      |
| `zebra.replicas`               | Number of Zebra replicas                                     | `1`                                       | True    | Any integer >= 1                         |
| `zebra.volumes.data.size`      | Size of the Zebra data volume                                | `400Gi`                                   | True    | Any valid size (e.g., `400Gi`)           |
| `zebra.volumes.data.storageClass` | Storage class for the Zebra data volume                   | `defaut`                                  | True    | Any valid storage class                  |
| `zebra.service.type`           | Service type for Zebra                                       | `ClusterIP`                               | True    | `ClusterIP`, `NodePort`, `LoadBalancer`  |
| `caddy.enabled`                | Enable Caddy deployment (frontend for Lightwalletd)          | `False`                                   | True    | `true`, `True`                           |
| `caddy.domain`                 | Domain for Caddy                                             | `"lwd.example.com"`                       | True    | Any valid domain                         |
| `caddy.email`                  | Email for SSL certificates                                   | `"admin@example.com"`                     | True    | Any valid email                          |
| `rpc.credentials.rpcUser`      | RPC username                                                 | `5s3rn4m3`                                | True    | Any string                               |
| `rpc.credentials.rpcPassword`  | RPC password                                                 | `s3cr3tp4ssw0rd`                          | True    | Any string                               |

## Customizing the Deployment

You can override the default values by creating a custom `values.yaml` or using the `--set` flag. For example:

```bash
helm install <release-name> z3/z3-stack
```


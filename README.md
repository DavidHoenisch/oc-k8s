# OpenClaw Kubernetes Helm Chart

A Helm chart for deploying [OpenClaw](https://openclaw.dev) - an AI assistant platform - to Kubernetes clusters.

## Overview

This Helm chart deploys the OpenClaw gateway service with:
- Secure container configuration (non-root, read-only root filesystem)
- Persistent storage for workspace data
- Support for multiple AI providers (Anthropic, OpenAI, Gemini, OpenRouter)
- Health checks and resource limits
- Optional web dashboard (oc-dashboard)

## Quick Start

### Prerequisites

- Kubernetes cluster (1.20+)
- Helm 3.x
- kubectl configured to access your cluster
- At least one AI provider API key

1. **Configure your environment:**
   ```bash
   # Copy the example values file and customize it
   cp openclaw/values.yaml.example openclaw/values.yaml
   
   # Edit values.yaml to add your API keys:
   # secret:
   #   apiKeys:
   #     anthropic: "sk-ant-..."
   #     openai: "sk-..."
   #     gemini: "..."
   #     openrouter: "..."
   ```

2. **Install the chart:**
   ```bash
   helm install openclaw ./openclaw -n openclaw --create-namespace
   ```

3. **Access the service:**
   ```bash
   kubectl port-forward svc/openclaw 18789:18789 -n openclaw
   # Open http://localhost:18789
   ```

## Configuration

### Values File

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of gateway replicas | `1` |
| `image.repository` | Container image repository | `ghcr.io/openclaw/openclaw` |
| `image.tag` | Image tag | `slim` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `namespace.create` | Create namespace | `true` |
| `namespace.name` | Namespace name | `openclaw` |
| `service.port` | Service port | `18789` |
| `serviceAccount.create` | Create a dedicated ServiceAccount for in-cluster auth | `true` |
| `serviceAccount.automountToken` | Mount Kubernetes service account token into the pod | `true` |
| `rbac.create` | Create RBAC binding for the ServiceAccount | `true` |
| `rbac.clusterWide` | Use a ClusterRoleBinding instead of namespace-only binding | `true` |
| `rbac.clusterRole` | ClusterRole to bind, for example `cluster-admin` or `edit` | `cluster-admin` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | PVC storage size | `10Gi` |
| `persistence.storageClass` | Storage class (empty for default) | `""` |

### AI Provider API Keys

Configure at least one AI provider in `values.yaml`:

```yaml
secret:
  enabled: true
  name: openclaw-secrets
  gatewayToken: ""  # Auto-generated if empty
  ghToken: ""       # optional GitHub CLI token
  opServiceAccountToken: ""  # optional 1Password service account token
  apiKeys:
    anthropic: ""   # sk-ant-...
    openai: ""      # sk-...
    gemini: ""      # Google API key
    openrouter: ""  # OpenRouter API key
```

### 1Password service account support

If your image includes the `op` CLI, the chart can inject `OP_SERVICE_ACCOUNT_TOKEN` into both the init container and the gateway container:

```yaml
secret:
  opServiceAccountToken: "ops_..."
```

That gives OpenClaw and local helper scripts a clean headless path to use 1Password-backed secret retrieval.

The chart also sets:

- `OP_CONFIG_DIR=/home/node/.openclaw/config/op`

The init container also locks that directory down to mode `700`, because the 1Password CLI refuses broader permissions.

So the 1Password CLI writes its local state to the PVC-backed writable config path instead of the read-only container home.

### Gateway Configuration

```yaml
config:
  gateway:
    mode: local        # local, remote, or hybrid
    bind: loopback     # loopback or 0.0.0.0
    port: 18789
    auth:
      mode: token      # token or none
    controlUi:
      enabled: true    # Enable web control UI
  agents:
    defaults:
      workspace: ~/.openclaw/workspace
    list:
      - id: default
        name: OpenClaw Assistant
        workspace: ~/.openclaw/workspace
```

### Resource Limits

```yaml
resources:
  limits:
    cpu: "1"
    memory: 2Gi
  requests:
    cpu: 250m
    memory: 512Mi
```

## Cluster Caretaker

The repo includes a simple first-pass caretaker script:

```bash
./scripts/cluster-caretaker.sh openclaw
```

It checks:

- pod and deployment readiness
- container restarts
- recent namespace events
- PVC presence
- runtime disk usage for `~/.openclaw`
- OpenClaw health from inside the running pod
- current container images

This is a practical baseline for "is my assistant home healthy right now?" and a good starting point for future automation.

## Kubernetes Access Model

This chart can grant the OpenClaw pod in-cluster Kubernetes API access using a dedicated ServiceAccount and RBAC binding.

Default example settings:

```yaml
serviceAccount:
  create: true
  automountToken: true

rbac:
  create: true
  clusterWide: true
  clusterRole: cluster-admin
```

This uses native in-cluster auth, so the assistant can use `kubectl` without a separate kubeconfig when the container image includes the client binary.

If you want to reduce access later, change `rbac.clusterRole` to a narrower built-in or custom ClusterRole.

## State Management Model

This chart now uses a split model between immutable, Helm-managed configuration and mutable runtime state on the PVC.

### Immutable, Git/Helm-managed

These are rendered from the chart and mounted read-only into the running container:

- `~/.openclaw/openclaw.json`
- `~/.openclaw/workspace/AGENTS.md` (when provided)
- `~/.openclaw/workspace/SOUL.md` (when provided)
- `~/.openclaw/workspace/USER.md` (when provided)

ConfigMap and Secret changes automatically trigger a pod rollout through checksum annotations.

### Mutable, PVC-backed runtime state

These remain writable and persist across redeploys:

- `~/.openclaw/memory/`
- `~/.openclaw/agents/`
- `~/.openclaw/tasks/`
- `~/.openclaw/devices/`
- `~/.openclaw/credentials/`
- `~/.openclaw/identity/`
- `~/.openclaw/logs/`
- most of `~/.openclaw/workspace/`

### Intentional exception

`IDENTITY.md` and `TOOLS.md` are not mounted read-only by default, so the assistant can evolve local identity and setup notes without requiring a chart redeploy.

## Security

This chart implements security best practices:

- **Non-root container**: Runs as UID 1000
- **Read-only root filesystem**: Prevents runtime modifications
- **No privilege escalation**: `allowPrivilegeEscalation: false`
- **Dropped capabilities**: All capabilities removed
- **Seccomp profile**: RuntimeDefault
- **Secret management**: API keys stored in Kubernetes Secrets
- **Security contexts**: Properly configured for init and main containers

## File Structure

```
.
├── openclaw/
│   ├── Chart.yaml          # Helm chart metadata
│   ├── values.yaml         # Default values (gitignored - create from example)
│   ├── values.yaml.example # Example configuration
│   ├── templates/
│   │   ├── _helpers.tpl    # Helm helper templates
│   │   ├── configmap.yaml  # ConfigMap for OpenClaw configuration
│   │   ├── deployment.yaml # Main gateway deployment
│   │   ├── namespace.yaml  # Namespace definition
│   │   ├── ocdashboarddeployment.yaml  # Dashboard deployment
│   │   ├── ocservice.yaml  # Dashboard service
│   │   ├── pvc.yaml        # PersistentVolumeClaim
│   │   ├── secret.yaml     # API keys and tokens
│   │   └── service.yaml    # Gateway service
│   └── files/              # Configuration files mounted into containers
│       ├── AGENTS.md       # Assistant configuration (gitignored)
│       ├── IDENTITY.md     # Identity configuration (gitignored)
│       ├── SOUL.md         # Core behavior rules (gitignored)
│       ├── TOOLS.md        # Available tools documentation (gitignored)
│       ├── USER.md         # User preferences (gitignored)
│       └── *.md.example    # Example files for customization
├── .gitignore              # Git ignore rules
└── .helmignore             # Helm ignore rules
```

## Git-ignored Files

The following files are excluded from version control (see `.gitignore`):

| File/Pattern | Purpose |
|--------------|---------|
| `values.yaml` | Local configuration with API keys - create from `values.yaml.example` |
| `openclaw/files/*.md` | Local assistant configuration files - create from `.md.example` files |

To set up your environment:
```bash
# Copy example files
cp openclaw/values.yaml.example openclaw/values.yaml
cp openclaw/files/AGENTS.md.example openclaw/files/AGENTS.md
cp openclaw/files/IDENTITY.md.example openclaw/files/IDENTITY.md
cp openclaw/files/SOUL.md.example openclaw/files/SOUL.md
cp openclaw/files/TOOLS.md.example openclaw/files/TOOLS.md
cp openclaw/files/USER.md.example openclaw/files/USER.md

# Edit files with your configuration
```

## Upgrading

To upgrade an existing deployment:

```bash
# Update values.yaml with new configuration
helm upgrade openclaw ./openclaw -n openclaw
```

## Uninstalling

```bash
helm uninstall openclaw -n openclaw
kubectl delete namespace openclaw
```

## Troubleshooting

### Pod fails to start

Check the pod status and logs:
```bash
kubectl get pods -n openclaw
kubectl logs -n openclaw deployment/openclaw
```

### Secret not found

Ensure you have configured your API keys in `values.yaml`:
```yaml
secret:
  apiKeys:
    anthropic: "your-key-here"
```

Then apply the changes:
```bash
helm upgrade openclaw ./openclaw -n openclaw
```

Or check existing secret:
```bash
kubectl get secret openclaw-secrets -n openclaw
```

### Gateway token retrieval

```bash
kubectl get secret openclaw-secrets -n openclaw \
  -o jsonpath='{.data.OPENCLAW_GATEWAY_TOKEN}' | base64 -d && echo
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

See the [OpenClaw project](https://github.com/openclaw/openclaw) for license information.

## Support

- Documentation: https://openclaw.dev
- Issues: https://github.com/openclaw/openclaw/issues
- Email: hello@openclaw.dev

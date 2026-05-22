# GitOps - Flux CD Repository

Centralized GitOps repository for managing all Kubernetes deployments on the Raspberry Pi Homelab cluster using Flux CD.

## 📋 Overview

This repository contains all Flux CD configurations for the following applications:
- **Portfolio** - Personal portfolio application
- **ZetaControl** - Multi-phase control system (Phase 1, 2, 3)
- **Infrastructure** - Monitoring, cert-manager, networking, storage
- **Monitoring** - Prometheus, Grafana, AlertManager

## 🏗️ Repository Structure

```
clusters/
├── raspberry-pi-homelab/           # Cluster-specific configurations
│   ├── flux-system/                # Flux CD system components
│   ├── applications/               # Application deployments
│   │   ├── portfolio/              # Portfolio app configs
│   │   ├── zetacontrol/            # ZetaControl phases
│   │   └── monitoring/             # Monitoring stack
│   └── infrastructure/             # Infrastructure components
│       ├── cert-manager/           # Certificate management
│       ├── traefik/                # Ingress controller
│       └── metallb/                # Load balancer
helm-charts/                        # Custom Helm charts (if needed)
docs/                              # Documentation
├── migration-guide.md              # ArgoCD → Flux CD migration
├── troubleshooting.md              # Common issues & solutions
├── adding-new-app.md               # How to add new applications
└── bootstrap.md                    # Initial setup guide
scripts/                            # Automation scripts
├── bootstrap.sh                    # Initial Flux installation
└── verify-sync.sh                  # Verification script
```

## 🚀 Quick Start

### Prerequisites
- kubectl configured to your cluster
- GitHub CLI (gh) or personal access token
- Flux CLI installed: `curl -s https://fluxcd.io/install.sh | sudo bash`

### Bootstrap Flux CD

```bash
# 1. Clone this repository
git clone https://github.com/Satya-jit/gitops-flux-cd.git
cd gitops-flux-cd

# 2. Create GitHub personal access token with repo scope
# https://github.com/settings/tokens

# 3. Run bootstrap script
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=Satya-jit
bash scripts/bootstrap.sh

# 4. Verify Flux installation
flux check --pre
flux check
```

### Monitor Sync Status

```bash
# Check Flux status
flux status

# Watch logs
flux logs --follow

# Check specific application
flux get kustomizations portfolio
flux get helmreleases -A
```

## 📁 Cluster: Raspberry Pi Homelab

**Nodes:** 5 (1 control-plane + 4 workers)
- zeta-core (control-plane, etcd, master) - 192.168.50.135
- zeta-lite - 192.168.50.115
- zeta-macro - 192.168.50.178
- dietpi - 192.168.50.78
- shark-server - 192.168.50.72

**Ingress IP:** 192.168.50.240 (MetalLB)

**Domains:**
- Portfolio: rootbysatya.in
- Flux/Monitoring: argocd.rootbysatya.in
- Grafana: grafana.rootbysatya.in
- ZetaControl Phase 1: status.rootbysatya.in
- ZetaControl Phase 2: changelog.rootbysatya.in
- ZetaControl Phase 3: dashboard.rootbysatya.in

## 📖 Documentation

- [Migration Guide](docs/migration-guide.md) - Detailed migration from ArgoCD to Flux CD
- [Bootstrap Guide](docs/bootstrap.md) - Initial cluster setup
- [Adding New Apps](docs/adding-new-app.md) - How to add new applications
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions

## 🔄 Git Workflow

1. Create a feature branch
2. Update manifests
3. Commit and push
4. Create PR for review
5. Merge to main
6. Flux automatically syncs to cluster

Example:
```bash
git checkout -b feature/add-new-app
# Make changes
git commit -m "feat: add new application"
git push origin feature/add-new-app
# Create PR on GitHub
```

## 🔐 Access Control

- **Team:** Platform/DevOps engineers
- **Permissions:** Write access for deployments
- **Reviews:** Required before merging to main
- **Secrets:** Use Sealed Secrets or External Secrets

## 📊 Applications Status

| App | Status | Domain | Namespace |
|-----|--------|--------|----------|
| Portfolio | Pending | rootbysatya.in | portfolio |
| ZetaControl Phase 1 | Pending | status.rootbysatya.in | zetacontrol |
| ZetaControl Phase 2 | Pending | changelog.rootbysatya.in | zetacontrol |
| ZetaControl Phase 3 | Pending | dashboard.rootbysatya.in | zetacontrol |
| Monitoring | Pending | grafana.rootbysatya.in | monitoring |

## 🚨 Important Notes

- **Do not manually edit deployments** - Always use this repository as source of truth
- **Secrets:** Use sealed-secrets or external-secrets-operator
- **Images:** Update image tags in kustomization.yaml or values files
- **Sync Intervals:** Check individual Kustomization resources for sync intervals

## 💡 Best Practices

1. Keep manifests DRY using Kustomize overlays
2. Use semantic versioning for releases
3. Tag releases in git when deploying to production
4. Test changes in a dev environment first
5. Document significant changes in commit messages
6. Use pull requests for all changes

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/description`
3. Commit changes: `git commit -m "feat: description"`
4. Push to branch: `git push origin feature/description`
5. Create Pull Request
6. Wait for review and CI checks to pass

## 📞 Support

For issues or questions:
- Check [Troubleshooting Guide](docs/troubleshooting.md)
- Review Flux CD documentation: https://fluxcd.io/docs/
- Check cluster logs: `kubectl logs -n flux-system`

## 📄 License

This project is public and open to use.

---

**Last Updated:** May 2025
**Cluster:** Raspberry Pi Homelab
**GitOps Tool:** Flux CD v2
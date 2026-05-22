# Flux CD Bootstrap Guide

Step-by-step guide to bootstrap Flux CD on your Raspberry Pi Homelab Kubernetes cluster.

## Prerequisites

### 1. Install Required Tools

```bash
# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify installation
flux --version

# Install kubectl (if not already installed)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install git
sudo apt-get install -y git
```

### 2. Create GitHub Personal Access Token

1. Go to https://github.com/settings/tokens
2. Click "Generate new token"
3. Select scopes:
   - `repo` (full control of private repositories)
   - `workflow` (update GitHub Actions and workflows)
4. Copy the token and save it securely

### 3. Configure kubectl

Ensure your kubeconfig is set up:
```bash
kubectl cluster-info
kubectl get nodes
```

## Bootstrap Steps

### Step 1: Clone Repository

```bash
git clone https://github.com/Satya-jit/gitops-flux-cd.git
cd gitops-flux-cd
```

### Step 2: Run Pre-flight Checks

```bash
flux check --pre
```

Expected output:
```
✔ Kubernetes 1.35.1+k3s1 >=1.20.6-0
✔ Kubernetes API is available
✔ prerequisites checks passed
```

### Step 3: Export Environment Variables

```bash
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=Satya-jit
export GITHUB_REPO=gitops-flux-cd
```

### Step 4: Run Bootstrap Script

```bash
bash scripts/bootstrap.sh
```

This script will:
- Create `flux-system` namespace
- Create GitHub credentials secret
- Install Flux components
- Configure GitRepository and Kustomization for syncing

### Step 5: Verify Installation

```bash
# Check Flux components
flux check

# Check pod status
kubectl get pods -n flux-system

# Watch logs
flux logs --follow
```

Expected pods:
- flux-system/source-controller
- flux-system/kustomize-controller
- flux-system/helm-controller
- flux-system/notification-controller
- flux-system/image-reflector-controller
- flux-system/image-automation-controller

### Step 6: Monitor Sync Status

```bash
# Check overall status
flux status

# Check GitRepository
flux get sources git

# Check Kustomizations
flux get kustomizations

# Watch reconciliation
flux logs --follow --all-namespaces
```

## Troubleshooting Bootstrap

### Issue: "Unable to reach cluster"

```bash
# Verify kubeconfig
kubectl cluster-info

# Check kubeconfig path
echo $KUBECONFIG

# Set correct kubeconfig if needed
export KUBECONFIG=/path/to/kubeconfig
```

### Issue: "GitHub token authentication failed"

```bash
# Verify token
echo $GITHUB_TOKEN

# Test token
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Delete and recreate secret
kubectl delete secret flux-system -n flux-system
kubectl create secret generic flux-system \
  --from-literal=username=git \
  --from-literal=password=$GITHUB_TOKEN \
  -n flux-system
```

### Issue: "Insufficient permissions"

```bash
# Create new token with full 'repo' scope
# https://github.com/settings/tokens/new

# Verify organization access
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user/orgs
```

### Issue: "No space left on device"

```bash
# Check disk space
df -h

# Clean up old images
docker image prune -a -f
k3s crictl images prune
```

## Post-Bootstrap Configuration

### 1. Add Applications

Create application configuration files:

```bash
# Portfolio
mkdir -p clusters/raspberry-pi-homelab/applications/portfolio
cat > clusters/raspberry-pi-homelab/applications/portfolio/source.yaml << EOF
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: portfolio
  namespace: portfolio
spec:
  interval: 1m0s
  url: https://github.com/Satya-jit/My-portfolio
  ref:
    branch: main
EOF
```

### 2. Configure Notifications

Add Slack/webhook notifications (see troubleshooting.md)

### 3. Set Up RBAC

Create service accounts and roles for applications

## Next Steps

1. ✅ Flux CD is bootstrapped
2. 📦 Add application configurations
3. 🔐 Configure sealed secrets
4. 📊 Set up monitoring and alerting
5. 📝 Enable pull request automation

## Resources

- [Flux Documentation](https://fluxcd.io/docs/)
- [GitHub Integration](https://fluxcd.io/docs/components/source/github/)
- [Kustomize Guide](https://fluxcd.io/docs/components/kustomize/)
- [Helm Integration](https://fluxcd.io/docs/components/helm/)

## Support

For issues:
1. Check `flux logs --follow`
2. Review [Troubleshooting Guide](troubleshooting.md)
3. Check [Flux Discord](https://discord.gg/B8QR5Z) community
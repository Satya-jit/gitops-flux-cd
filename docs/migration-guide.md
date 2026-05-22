# ArgoCD to Flux CD Migration Guide

Comprehensive guide for migrating from ArgoCD to Flux CD on your Raspberry Pi Homelab cluster.

## Overview

**Current State:** ArgoCD managing portfolio and zetacontrol deployments
**Target State:** Flux CD managing all applications
**Timeline:** 2-3 weeks with proper testing

## Key Differences: ArgoCD vs Flux CD

| Feature | ArgoCD | Flux CD |
|---------|--------|--------|
| **Architecture** | Centralized UI-driven | GitOps pull-based |
| **Configuration** | YAML manifests + UI | Pure GitOps |
| **Sync Model** | Push/Pull hybrid | Pull-based (native) |
| **Learning Curve** | Steeper (UI + CRDs) | Gentler (GitOps native) |
| **Scalability** | Single controller | Distributed |
| **Community** | Large, mature | Growing, modern |
| **Resource Usage** | ~500MB-1GB | ~200-400MB |

## Migration Phases

### Phase 0: Planning & Testing (Week 1)

#### 0.1 Assess Current Deployments

```bash
# List all ArgoCD applications
kubectl get applications -n argocd

# Export application definitions
kubectl get application portfolio -n argocd -o yaml > portfolio-argocd.yaml
kubectl get application zetacontrol -n argocd -o yaml > zetacontrol-argocd.yaml

# Get current sync status
argocd app list
argocd app get portfolio
argocd app get zetacontrol
```

#### 0.2 Document Current State

- Capture current image tags
- Document manual overrides
- List all CRDs and custom resources
- Record webhook configurations
- Note resource limits and requests

#### 0.3 Set Up Test Cluster (Optional)

For safety, test on a separate namespace:

```bash
kubectl create namespace flux-test
kubectl create namespace portfolio-test
kubectl create namespace zetacontrol-test
```

### Phase 1: Flux Installation (Week 1)

#### 1.1 Install Flux

```bash
# Run bootstrap script
cd gitops-flux-cd
export GITHUB_TOKEN=<token>
export GITHUB_USER=Satya-jit
bash scripts/bootstrap.sh
```

#### 1.2 Verify Installation

```bash
flux check
flux status
```

#### 1.3 Verify Source Controller

```bash
flux get sources git
flux logs --follow --labels=source.toolkit.fluxcd.io/name
```

### Phase 2: Application Migration (Week 2)

#### 2.1 Create Flux Sources for Each App

```bash
# Create portfolio GitRepository
cat > clusters/raspberry-pi-homelab/applications/portfolio/source.yaml << 'EOF'
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

# Create zetacontrol GitRepository
cat > clusters/raspberry-pi-homelab/applications/zetacontrol/source.yaml << 'EOF'
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: zetacontrol
  namespace: zetacontrol
spec:
  interval: 1m0s
  url: https://github.com/Satya-jit/zetacontrol
  ref:
    branch: main
EOF
```

#### 2.2 Create Kustomizations

```bash
# Portfolio kustomization
cat > clusters/raspberry-pi-homelab/applications/portfolio/kustomization.yaml << 'EOF'
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: portfolio
  namespace: portfolio
spec:
  interval: 1m0s
  path: ./k8s
  prune: true
  sourceRef:
    kind: GitRepository
    name: portfolio
EOF

# ZetaControl kustomizations (for each phase)
for phase in 1 2 3; do
  cat > clusters/raspberry-pi-homelab/applications/zetacontrol/phase-${phase}-kustomization.yaml << EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: zetacontrol-phase-${phase}
  namespace: zetacontrol
spec:
  interval: 1m0s
  path: ./k8s/phase-${phase}
  prune: true
  sourceRef:
    kind: GitRepository
    name: zetacontrol
EOF
done
```

#### 2.3 Test Applications

```bash
# Monitor reconciliation
flux logs --follow

# Check application status
flux get kustomizations

# Verify pods
kubectl get pods -n portfolio
kubectl get pods -n zetacontrol

# Check events
kubectl describe kustomization portfolio -n portfolio
```

#### 2.4 Parallel Running (Optional)

Run both ArgoCD and Flux for 1-2 weeks:

```bash
# Monitor both systems
argocd app list
flux status

# Compare deployments
kubectl describe deployment portfolio-frontend -n portfolio
kubectl describe deployment portfolio-backend -n portfolio
```

### Phase 3: Cutover (Week 3)

#### 3.1 Final Sync Check

```bash
# Ensure all Flux resources are synced
flux status
flux get sources git
flux get kustomizations
```

#### 3.2 Disable ArgoCD Auto-Sync

```bash
# Pause ArgoCD applications
argocd app set portfolio --sync-policy none
argocd app set zetacontrol --sync-policy none

# Or disable individual repos
kubectl patch application portfolio -n argocd \
  --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}'
```

#### 3.3 Remove ArgoCD Webhooks

```bash
# Check configured webhooks
gh api repos/Satya-jit/My-portfolio/hooks
gh api repos/Satya-jit/zetacontrol/hooks

# Remove ArgoCD webhooks and add Flux webhooks
```

#### 3.4 Uninstall ArgoCD (Optional)

```bash
# Keep for 1 week as backup
# Then decide to remove or keep for rollback

# To uninstall:
kubectl delete namespace argocd
```

## Rollback Plan

If issues occur:

### Immediate Rollback (Hour 0)

```bash
# Re-enable ArgoCD auto-sync
argocd app set portfolio --sync-policy automated
argocd app set zetacontrol --sync-policy automated

# Pause Flux reconciliation
flux suspend kustomization portfolio
flux suspend kustomization zetacontrol
```

### If Needed - Full Rollback (Hour 0-6)

```bash
# Keep ArgoCD and remove Flux
kubectl delete namespace flux-system

# Verify ArgoCD is managing again
argocd app sync portfolio
argocd app sync zetacontrol
argocd app wait portfolio
argocd app wait zetacontrol
```

## Testing Checklist

Before cutover, verify:

- [ ] All pods are running
- [ ] Services have correct endpoints
- [ ] Ingress routes work correctly
- [ ] Environment variables are correct
- [ ] ConfigMaps mounted correctly
- [ ] Secrets mounted correctly
- [ ] Database connections work
- [ ] External services reachable
- [ ] Monitoring and logging work
- [ ] Webhook notifications work

## Validation Commands

```bash
# Test portfolio
curl -H "Host: rootbysatya.in" http://192.168.50.240

# Test zetacontrol phase 1
curl -H "Host: status.rootbysatya.in" http://192.168.50.240

# Test phase 2
curl -H "Host: changelog.rootbysatya.in" http://192.168.50.240

# Test phase 3
curl -H "Host: dashboard.rootbysatya.in" http://192.168.50.240

# Check pod logs
kubectl logs -f deployment/portfolio-frontend -n portfolio
kubectl logs -f deployment/portfolio-backend -n portfolio
```

## Post-Migration Tasks

1. **Update Documentation**
   - Update runbooks
   - Document new procedures
   - Update on-call guides

2. **Training**
   - Train team on Flux CD
   - Document troubleshooting
   - Create runbooks

3. **Monitoring**
   - Set up Flux metrics scraping
   - Create Grafana dashboards
   - Configure alerting

4. **Optimization**
   - Tune sync intervals
   - Optimize resource usage
   - Review and improve manifests

## Troubleshooting During Migration

See [Troubleshooting Guide](troubleshooting.md) for common issues.

## Success Criteria

✅ All applications running under Flux CD
✅ All pods healthy and running
✅ All ingresses working
✅ No manual deployments needed
✅ Monitoring and alerting working
✅ Team trained on new workflow
✅ ArgoCD successfully removed (if desired)

## Timeline Summary

- **Week 1:** Planning, testing, Flux installation
- **Week 2:** Application migration, parallel running
- **Week 3:** Cutover, ArgoCD removal
- **Week 4:** Optimization and team training

## Resources

- [Flux Migration Guide](https://fluxcd.io/docs/)
- [Kustomize Overlays](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [Helm Integration](https://fluxcd.io/docs/components/helm/)
- [Security Best Practices](https://fluxcd.io/docs/security/)

---

**Questions?** Check [Troubleshooting](troubleshooting.md) or [Bootstrap Guide](bootstrap.md)
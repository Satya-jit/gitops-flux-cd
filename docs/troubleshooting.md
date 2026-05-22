# Troubleshooting Guide

Common issues and solutions for Flux CD on Raspberry Pi Homelab.

## General Troubleshooting Commands

```bash
# Check Flux version
flux --version

# Check Flux status
flux check
flux status

# Check Flux system pods
kubectl get pods -n flux-system
kubectl describe pods -n flux-system

# Watch logs
flux logs --follow
flux logs --follow --all-namespaces
flux logs --follow --labels=source.toolkit.fluxcd.io/name=portfolio

# Get events
kubectl get events -n flux-system
kubectl get events -A --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods -n flux-system
```

## Issue 1: Flux Components Not Ready

### Symptoms
```
X 1 node(s) had taints that the pods didn't tolerate
X pod not running (pending)
X port not exposed
```

### Solutions

```bash
# Check pod logs
kubectl logs -n flux-system <pod-name>

# Check pod events
kubectl describe pod <pod-name> -n flux-system

# Check node taints
kubectl describe nodes | grep Taints

# Check available resources
kubectl top nodes
kubectl describe node <node-name>

# Check PVC status
kubectl get pvc -n flux-system

# Restart Flux controller
kubectl rollout restart deployment/source-controller -n flux-system
kubectl rollout restart deployment/kustomize-controller -n flux-system
```

## Issue 2: GitRepository Not Syncing

### Symptoms
```
Ready: False
Status: Failed to acquire lock
Error: authentication failed
```

### Solutions

```bash
# Check GitRepository status
flux get sources git
kubectl describe gitrepository <repo-name> -n <namespace>
flux logs --follow --labels=source.toolkit.fluxcd.io/name=<repo-name>

# Verify GitHub credentials
kubectl get secret github-credentials -n flux-system -o yaml

# Test GitHub connection
kubectl create pod -it --image=alpine:latest --restart=Never -n flux-system -- sh
# Inside pod:
apk add git openssh-client
git clone https://github.com/Satya-jit/gitops-flux-cd.git
exit
kubectl delete pod -n flux-system alpine

# Check SSH key permissions
kubectl get secret github-credentials -n flux-system -o jsonpath='{.data}'

# Recreate GitHub credentials
kubectl delete secret github-credentials -n flux-system
kubectl create secret generic github-credentials \
  --from-literal=username=git \
  --from-literal=password=$GITHUB_TOKEN \
  -n flux-system

# Force reconciliation
flux reconcile source git <repo-name> -n <namespace>
```

## Issue 3: Kustomization Not Syncing

### Symptoms
```
Ready: False
Path not found
Failed to build kustomization
```

### Solutions

```bash
# Check Kustomization status
flux get kustomizations
kubectl describe kustomization <name> -n <namespace>
flux logs --follow --labels=kustomize.toolkit.fluxcd.io/name=<name>

# Verify path exists in GitRepository
flux get sources git
kubectl get gitrepository <name> -n <namespace> -o jsonpath='{.spec.url}'

# Check kustomization.yaml syntax
kubectl apply --dry-run=client -f clusters/raspberry-pi-homelab/applications/<app>/kustomization.yaml

# Build kustomization locally
cd /tmp && git clone https://github.com/Satya-jit/gitops-flux-cd.git
cd gitops-flux-cd
kustomize build clusters/raspberry-pi-homelab/applications/<app>/

# Check for YAML errors
kubectl apply --dry-run=client -k clusters/raspberry-pi-homelab/applications/<app>/

# Force reconciliation
flux reconcile kustomization <name> -n <namespace>
```

## Issue 4: Pod CrashLoopBackOff

### Symptoms
```
CrashLoopBackOff
ImagePullBackOff
Init:ImagePullBackOff
```

### Solutions

```bash
# Check pod logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous

# Check events
kubectl describe pod <pod-name> -n <namespace>

# Verify image exists
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[*].image}'

# Check image pull secrets
kubectl get secrets -n <namespace>

# Verify node has disk space
kubectl describe nodes
df -h

# Clean up old images (if disk full)
docker image prune -a -f
k3s crictl images prune

# Check container resource limits
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 Resources

# Check node memory
free -h
kubectl top nodes
```

## Issue 5: Persistent Volume Issues

### Symptoms
```
Pending
Unbound
Error mounting volume
```

### Solutions

```bash
# Check PVC status
kubectl get pvc -n <namespace>
kubectl describe pvc <pvc-name> -n <namespace>

# Check PV status
kubectl get pv
kubectl describe pv <pv-name>

# Check StorageClass
kubectl get storageclass
kubectl describe storageclass <storage-class-name>

# Check node capacity
kubectl describe nodes
df -h /var/lib/kubelet/pods

# Verify local-path provisioner
kubectl get pods -n kube-system | grep local-path
kubectl logs -n kube-system deployment/local-path-provisioner

# Create test PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: local-path
EOF

kubectl describe pvc test-pvc
```

## Issue 6: Ingress Not Working

### Symptoms
```
404 Not Found
Backend unreachable
SSL_ERROR_BAD_CERT_DOMAIN
```

### Solutions

```bash
# Check Ingress
kubectl get ingress -A
kubectl describe ingress <ingress-name> -n <namespace>

# Check Traefik
kubectl get pods -n kube-system | grep traefik
kubectl logs -n kube-system deployment/traefik

# Check service
kubectl get svc -n <namespace>
kubectl describe svc <service-name> -n <namespace>

# Verify endpoints
kubectl get endpoints -n <namespace>

# Test DNS
kubectl run -it --image=alpine:latest --restart=Never -n default -- sh
# Inside pod:
apk add bind-utils
nslookup rootbysatya.in
nslookup portfolio.portfolio.svc.cluster.local
exit

# Test connectivity
kubectl run -it --image=alpine:latest --restart=Never -n default -- sh
# Inside pod:
apk add curl
curl -v portfolio.portfolio.svc.cluster.local
exit

# Check cert-manager
kubectl get certificaterequests -A
kubectl get certificates -A
kubectl describe certificate <cert-name> -n <namespace>

# Check ClusterIssuer
kubectl describe clusterissuer letsencrypt-prod

# Check MetalLB
kubectl get svc -A | grep LoadBalancer
kubectl logs -n metallb-system deployment/controller
```

## Issue 7: Helm Release Failed

### Symptoms
```
Failed to get Helm repository
Chart not found
Release upgrade failed
```

### Solutions

```bash
# Check HelmRepository
flux get sources helm
kubectl describe helmrepository <name> -n flux-system
flux logs --follow --labels=source.toolkit.fluxcd.io/name=<name>

# Check HelmRelease
flux get helmreleases -A
kubectl describe helmrelease <name> -n <namespace>
flux logs --follow --labels=helm.toolkit.fluxcd.io/name=<name>

# Test Helm repository
helm repo add <name> <url>
helm repo update
helm search repo <name>

# Check values
kubectl get helmrelease <name> -n <namespace> -o yaml | grep -A 20 values

# Force reconciliation
flux reconcile helmrelease <name> -n <namespace>

# Check Helm releases
helm list -n <namespace>
helm status <release-name> -n <namespace>

# Get values
helm get values <release-name> -n <namespace>

# Debug
helm template <release-name> <chart> --values values.yaml
```

## Issue 8: Out of Memory / Disk Space

### Symptoms
```
OOMKilled
No space left on device
Eviction manager
```

### Solutions

```bash
# Check disk usage
df -h
du -sh /var/lib/kubelet
du -sh /var/lib/rancher

# Check node status
kubectl get nodes
kubectl describe nodes

# Clean up images
kubectl run -it --image=alpine:latest --restart=Never -n default -- sh
# Inside pod:
df -h /
exit

# Remove old images
docker image prune -a -f
k3s crictl images
k3s crictl rmi <image-id>

# Remove old containers
k3s crictl ps -a
k3s crictl rm <container-id>

# Clean logs
kubectl logs --tail=1000 -n <namespace> <pod>

# Check pod resource requests/limits
kubectl describe pod <pod-name> -n <namespace>

# Check node kubelet config
kubectl describe node <node-name> | grep -A 10 "Allocated resources"

# Increase swap (if possible)
free -h
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
```

## Issue 9: Network Connectivity

### Symptoms
```
DNS resolution failed
Connection refused
Timeout
```

### Solutions

```bash
# Check CoreDNS
kubectl get pods -n kube-system | grep coredns
kubectl logs -n kube-system deployment/coredns

# Test DNS
kubectl run -it --image=alpine:latest --restart=Never -n default -- nslookup google.com

# Check network policies
kubectl get networkpolicies -A
kubectl describe networkpolicy <name> -n <namespace>

# Check node networking
kubectl get nodes -o wide
ping -c 2 <node-ip>

# Check service networking
kubectl get svc -A
kubectl describe svc <name> -n <namespace>

# Check CNI
kubectl get daemonsets -n kube-system
kubectl logs -n kube-system daemonset/<cni-name>

# Test pod-to-pod communication
kubectl run -it --image=alpine:latest --restart=Never -n default -- sh
# Inside pod:
ping <pod-ip>
exit
```

## Issue 10: RBAC/Permissions

### Symptoms
```
Error: permission denied
Forbidden
Unauthorized
```

### Solutions

```bash
# Check current permissions
kubectl auth can-i get pods --as=system:serviceaccount:flux-system:source-controller -n flux-system

# Check RBAC
kubectl get rolebindings -A
kubectl get clusterrolebindings -A
kubectl describe clusterrole flux-system

# Check ServiceAccount
kubectl get sa -n flux-system
kubectl describe sa source-controller -n flux-system

# Check pod's service account
kubectl get pod <pod-name> -n flux-system -o jsonpath='{.spec.serviceAccountName}'

# Check role
kubectl describe role <role-name> -n <namespace>

# Debug RBAC
kubectl api-resources
kubectl api-resources --verbs=get,list,watch
```

## Issue 11: Webhook Failures

### Symptoms
```
Webhook reconciliation failed
Payload delivery failure
Unauthorized webhook
```

### Solutions

```bash
# Check notification provider
kubectl get notificationproviders -A

# Check alert
kubectl get alerts -A
kubectl describe alert <name> -n flux-system

# Check receiver
kubectl get receivers -A

# Test webhook
curl -X POST https://hooks.slack.com/services/... \
  -H 'Content-type: application/json' \
  --data '{"text":"Test"}'

# Check notification-controller logs
kubectl logs -n flux-system deployment/notification-controller

# Check Alert status
flux logs --follow --labels=notification.toolkit.fluxcd.io/name=<name>
```

## Quick Reference

| Issue | Command |
|-------|----------|
| Check status | `flux status` |
| View logs | `flux logs --follow` |
| Reconcile all | `flux reconcile source git --all` |
| Suspend sync | `flux suspend kustomization <name> -n <ns>` |
| Resume sync | `flux resume kustomization <name> -n <ns>` |
| Force sync | `flux reconcile kustomization <name> -n <ns>` |
| Get resources | `flux get kustomizations` |
| Show events | `kubectl get events -A --sort-by='.lastTimestamp'` |

## Still Need Help?

1. Check [Flux Documentation](https://fluxcd.io/docs/)
2. Review [Bootstrap Guide](bootstrap.md)
3. Check [Kubernetes Docs](https://kubernetes.io/docs/)
4. Ask on [Flux Discord](https://discord.gg/B8QR5Z)
5. Check [GitHub Issues](https://github.com/Satya-jit/gitops-flux-cd/issues)

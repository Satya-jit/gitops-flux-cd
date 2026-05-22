# Adding New Applications to Flux CD

Guide for adding new applications to your Flux CD GitOps repository.

## Directory Structure

For each new application, create the following structure:

```
clusters/raspberry-pi-homelab/applications/<app-name>/
├── namespace.yaml              # Namespace definition
├── source.yaml                 # GitRepository source
├── kustomization.yaml          # Kustomization configuration
├── ingress.yaml               # Ingress (if needed)
├── values.yaml                # Helm values (if using Helm)
└── kustomization/             # Kustomize overlays
    ├── base/
    │   └── kustomization.yaml
    └── overlays/
        └── raspberry-pi/
            └── kustomization.yaml
```

## Option 1: Using GitRepository + Kustomization (YAML)

### Step 1: Create Namespace

```yaml
# clusters/raspberry-pi-homelab/applications/myapp/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
  labels:
    app: myapp
```

### Step 2: Create GitRepository

```yaml
# clusters/raspberry-pi-homelab/applications/myapp/source.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: myapp
  namespace: myapp
spec:
  interval: 1m0s
  url: https://github.com/username/myapp
  ref:
    branch: main
  # Optional: GitHub authentication
  secretRef:
    name: github-credentials
```

### Step 3: Create Kustomization

```yaml
# clusters/raspberry-pi-homelab/applications/myapp/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp
  namespace: myapp
spec:
  interval: 5m0s
  path: ./k8s
  prune: true
  wait: true
  timeout: 5m0s
  sourceRef:
    kind: GitRepository
    name: myapp
  # Health assessment
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: myapp-frontend
      namespace: myapp
  # Post-deployment actions
  postBuild:
    substitute:
      IMAGE_TAG: v1.0.0
      REPLICAS: '2'
```

### Step 4: Create Ingress (if needed)

```yaml
# clusters/raspberry-pi-homelab/applications/myapp/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  namespace: myapp
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - myapp.rootbysatya.in
      secretName: myapp-tls
  rules:
    - host: myapp.rootbysatya.in
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp-frontend
                port:
                  number: 80
```

## Option 2: Using Helm Charts

### Step 1: Add Helm Repository

```yaml
# clusters/raspberry-pi-homelab/applications/myapp/helm-repo.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: myapp-repo
  namespace: flux-system
spec:
  interval: 1h0m0s
  url: https://charts.example.com
  # Optional: authentication
  secretRef:
    name: helm-repo-credentials
```

### Step 2: Create HelmRelease

```yaml
# clusters/raspberry-pi-homelab/applications/myapp/helm-release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: myapp
  namespace: myapp
spec:
  interval: 5m0s
  chart:
    spec:
      chart: myapp
      version: '1.0.0'
      sourceRef:
        kind: HelmRepository
        name: myapp-repo
        namespace: flux-system
  values:
    replicaCount: 2
    image:
      repository: myapp
      tag: v1.0.0
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
    ingress:
      enabled: true
      hosts:
        - host: myapp.rootbysatya.in
          paths:
            - path: /
              pathType: Prefix
  # Health checks
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
```

## Option 3: Using Kustomize Overlays

### Step 1: Create Base

```yaml
# clusters/raspberry-pi-homelab/applications/myapp/kustomization/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

commonLabels:
  app: myapp

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml

replicas:
  - name: myapp
    count: 2

images:
  - name: myapp
    newTag: v1.0.0
```

### Step 2: Create Overlay

```yaml
# clusters/raspberry-pi-homelab/applications/myapp/kustomization/overlays/raspberry-pi/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base

commonLabels:
  environment: production
  cluster: raspberry-pi

patches:
  - target:
      kind: Deployment
      name: myapp
    patch: |-
      - op: replace
        path: /spec/template/spec/resources/limits/memory
        value: 256Mi

resources:
  - ingress.yaml
  - resource-quota.yaml
```

### Step 3: Reference in Kustomization

```yaml
# clusters/raspberry-pi-homelab/applications/myapp/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp
  namespace: myapp
spec:
  interval: 5m0s
  path: ./kustomization/overlays/raspberry-pi
  prune: true
  sourceRef:
    kind: GitRepository
    name: myapp
```

## Option 4: Multiple Applications from Same Repo

For monorepos with multiple applications:

```yaml
# clusters/raspberry-pi-homelab/applications/monorepo/source.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: monorepo
  namespace: flux-system
spec:
  interval: 1m0s
  url: https://github.com/username/monorepo
  ref:
    branch: main
---
# Sync app1
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: app1
  namespace: app1
spec:
  interval: 5m0s
  path: ./apps/app1/k8s
  prune: true
  sourceRef:
    kind: GitRepository
    name: monorepo
---
# Sync app2
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: app2
  namespace: app2
spec:
  interval: 5m0s
  path: ./apps/app2/k8s
  prune: true
  sourceRef:
    kind: GitRepository
    name: monorepo
```

## Common Configurations

### Environment Variables

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: myapp
data:
  DATABASE_URL: "postgres://db:5432/myapp"
  LOG_LEVEL: "info"
  ENVIRONMENT: "production"
```

### Secrets (Using Sealed Secrets)

```yaml
apiVersion: v1
kind: SealedSecret
metadata:
  name: myapp-secrets
  namespace: myapp
spec:
  encryptedData:
    database-password: AgB3x...
    api-key: AgC4y...
```

### Resource Limits

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: myapp
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: myapp
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

## Testing Your Application

### 1. Validate YAML

```bash
kubectl apply --dry-run=client -f clusters/raspberry-pi-homelab/applications/myapp/
```

### 2. Check GitRepository

```bash
flux get sources git
kubectl describe gitrepository myapp -n myapp
```

### 3. Check Kustomization Status

```bash
flux get kustomizations
kubectl describe kustomization myapp -n myapp
```

### 4. Watch Reconciliation

```bash
flux logs --follow
```

### 5. Verify Deployment

```bash
kubectl get pods -n myapp
kubectl get svc -n myapp
kubectl get ingress -n myapp
```

## Deployment Steps

1. **Create feature branch**
   ```bash
   git checkout -b feature/add-myapp
   ```

2. **Add application files**
   ```bash
   mkdir -p clusters/raspberry-pi-homelab/applications/myapp
   # Copy files as shown above
   ```

3. **Commit changes**
   ```bash
   git add clusters/raspberry-pi-homelab/applications/myapp/
   git commit -m "feat: add myapp application"
   ```

4. **Push and create PR**
   ```bash
   git push origin feature/add-myapp
   # Create PR on GitHub
   ```

5. **Review and merge**
   - Review manifests
   - Verify configuration
   - Merge to main

6. **Flux automatically deploys**
   - GitRepository detects new commits
   - Kustomization reconciles changes
   - Application deployed to cluster

## Troubleshooting

### Application not syncing

```bash
# Check GitRepository status
kubectl describe gitrepository myapp -n myapp

# Check Kustomization status
kubectl describe kustomization myapp -n myapp

# View logs
flux logs --follow --labels=kustomize.toolkit.fluxcd.io/name=myapp
```

### YAML validation errors

```bash
kubectl apply --dry-run=client -f clusters/raspberry-pi-homelab/applications/myapp/ -v=8
```

### Image pull errors

```bash
# Check image availability
kubectl describe pod <pod-name> -n myapp

# Verify image secrets
kubectl get secrets -n myapp
```

## Resources

- [Flux Kustomization Docs](https://fluxcd.io/docs/components/kustomize/)
- [Flux Helm Docs](https://fluxcd.io/docs/components/helm/)
- [Kustomize Reference](https://kubectl.docs.kubernetes.io/references/kustomize/)
- [Kubernetes YAML Best Practices](https://kubernetes.io/docs/concepts/)

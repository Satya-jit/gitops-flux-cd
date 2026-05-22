# Beginner's Guide to Implementing Flux CD

Complete step-by-step guide for beginners to set up Flux CD on your Raspberry Pi Homelab cluster.

## 📚 Table of Contents

1. [Prerequisites & Setup](#prerequisites--setup)
2. [Day 1: Understanding Concepts](#day-1-understanding-concepts)
3. [Day 2: Installation & Verification](#day-2-installation--verification)
4. [Day 3: Add First Application](#day-3-add-first-application)
5. [Day 4: Add More Applications](#day-4-add-more-applications)
6. [Day 5: Monitoring & Troubleshooting](#day-5-monitoring--troubleshooting)

---

## Prerequisites & Setup

### Step 1: Install Required Tools

Before you start, make sure you have these tools installed on your machine:

#### 1.1 Install Flux CLI

**On Linux/Mac:**
```bash
# Download and install Flux
curl -s https://fluxcd.io/install.sh | sudo bash

# Verify installation
flux --version
# Expected output: flux version 2.x.x
```

**On Windows (using WSL2):**
```bash
# Use Linux instructions in WSL2
curl -s https://fluxcd.io/install.sh | sudo bash
```

#### 1.2 Verify kubectl

```bash
# Check if kubectl is installed
kubectl --version
# Expected output: kubectl version Client v1.35+ 

# If not installed:
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

#### 1.3 Verify Git

```bash
git --version
# Expected output: git version 2.x+
```

### Step 2: Verify Cluster Access

```bash
# Check if you can access the cluster
kubectl cluster-info

# Expected output:
# Kubernetes control plane is running at https://127.0.0.1:6443
# CoreDNS is running at https://...

# Check nodes
kubectl get nodes

# Expected output:
# NAME           STATUS   ROLES                       AGE
# zeta-core      Ready    control-plane,etcd,master   198d
# zeta-lite      Ready    <none>                      197d
# (and others)
```

**✅ If both commands work, you're good to proceed!**

### Step 3: Create GitHub Personal Access Token

This allows Flux to authenticate with GitHub and pull your configurations.

1. Go to: https://github.com/settings/tokens
2. Click **"Generate new token"** → **"Generate new token (classic)"**
3. Fill in the form:
   - **Token name:** `flux-cd-token`
   - **Expiration:** 90 days (or No expiration for testing)
   - **Scopes to select:**
     - ✅ `repo` (Full control of private repositories)
     - ✅ `workflow` (Update GitHub Actions and workflows)
4. Click **"Generate token"**
5. **⚠️ COPY THE TOKEN IMMEDIATELY** (you won't see it again!)

Save it somewhere safe:
```bash
# Save to a file (for later reference)
echo "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx" > ~/flux-token.txt
chmod 600 ~/flux-token.txt
```

---

## Day 1: Understanding Concepts

### What is GitOps?

**Simple Definition:** Your infrastructure and applications are defined in Git, and a controller automatically keeps your cluster in sync with Git.

**Visual Flow:**
```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  1. You push changes to GitHub                         │
│     (update a deployment manifest)                     │
│                ↓                                        │
│  2. Flux detects the change (every 1 minute)           │
│                ↓                                        │
│  3. Flux applies the changes to your cluster           │
│                ↓                                        │
│  4. Your application is updated automatically!         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Key Concepts

#### 1. **GitRepository**
- Tells Flux which GitHub repository to watch
- Example: `https://github.com/Satya-jit/gitops-flux-cd`

#### 2. **Kustomization**
- Tells Flux which files to apply from the Git repository
- Example: Apply files from `clusters/raspberry-pi-homelab/applications/portfolio/`

#### 3. **Reconciliation**
- The process where Flux checks Git and applies changes
- Runs automatically every 1 minute by default

#### 4. **Source**
- Where Flux gets the configuration (Git repository)
- Can also be Helm charts or other sources

### Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│           Your Cluster (Raspberry Pi Homelab)            │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │         flux-system namespace                      │ │
│  │  ┌──────────────────────────────────────────────┐ │ │
│  │  │ Flux Controllers (running in your cluster)  │ │ │
│  │  │                                              │ │ │
│  │  │ • source-controller                         │ │ │
│  │  │   (watches GitHub every minute)            │ │ │
│  │  │                                              │ │ │
│  │  │ • kustomize-controller                      │ │ │
│  │  │   (applies files to cluster)               │ │ │
│  │  │                                              │ │ │
│  │  │ • helm-controller                           │ │ │
│  │  │   (manages Helm charts)                    │ │ │
│  │  │                                              │ │ │
│  │  └──────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────┘ │
│                          ↑                              │
│                 (pulls from GitHub)                    │
│                          ↑                              │
└──────────────────────────────────────────────────────────┘
                          │
                          │
            ┌─────────────┴──────────────┐
            │                            │
            ↓                            ↓
   ┌────────────────────┐    ┌────────────────────┐
   │  GitHub Repository │    │  Your Manifests    │
   │ gitops-flux-cd     │    │  (in Git)          │
   └────────────────────┘    └────────────────────┘
```

### Your Repository Structure (Recap)

```
gitops-flux-cd/
├── README.md                          ← Read first!
├── docs/
│   ├── BEGINNER_GUIDE.md             ← You are here
│   ├── bootstrap.md                   ← Installation steps
│   ├── migration-guide.md             ← ArgoCD migration
│   ├── adding-new-app.md              ← Add applications
│   └── troubleshooting.md             ← Fix problems
├── clusters/
│   └── raspberry-pi-homelab/          ← Your cluster configs
│       ├── flux-system/               ← (Auto-generated after bootstrap)
│       └── applications/              ← (We'll add apps here)
└── scripts/
    └── bootstrap.sh                   ← Installation script
```

---

## Day 2: Installation & Verification

### Step 1: Clone the Repository

```bash
# Clone your GitOps repository
git clone https://github.com/Satya-jit/gitops-flux-cd.git
cd gitops-flux-cd

# Verify you're in the right directory
pwd
# Expected output: /path/to/gitops-flux-cd

ls -la
# You should see: README.md, docs/, scripts/, clusters/
```

### Step 2: Set Environment Variables

These variables tell Flux which GitHub account and repository to use.

```bash
# Open a terminal and set these variables
export GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx  # Your token from Step 3 above
export GITHUB_USER=Satya-jit                          # Your GitHub username
export GITHUB_REPO=gitops-flux-cd                     # Repository name

# Verify they're set correctly
echo "Token: $GITHUB_TOKEN"
echo "User: $GITHUB_USER"
echo "Repo: $GITHUB_REPO"

# Expected output:
# Token: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxx
# User: Satya-jit
# Repo: gitops-flux-cd
```

**⚠️ Important:** These variables are only set for this terminal session. If you close the terminal, you'll need to set them again!

### Step 3: Run Pre-flight Checks

Before installation, let's verify everything is ready:

```bash
# Check if your tools are installed
flux check --pre

# Expected output:
# ✓ Kubernetes 1.35.1+k3s1 >=1.20.6-0
# ✓ Kubernetes API is available
# ✓ prerequisites checks passed
```

**🔴 If you get an error:**
```bash
# Error: "cannot connect to cluster"
# Solution: Make sure kubectl can access your cluster
kubectl cluster-info

# Error: "flux not found"
# Solution: Install Flux (see Step 1 of Prerequisites)
curl -s https://fluxcd.io/install.sh | sudo bash
```

### Step 4: Run the Bootstrap Script

This script installs Flux and connects it to your GitHub repository.

```bash
# Make the script executable
chmod +x scripts/bootstrap.sh

# Run the bootstrap script
bash scripts/bootstrap.sh

# You'll see output like:
# ========================================
# Flux CD Bootstrap
# ========================================
# ✓ kubectl found: ...
# ✓ flux found: ...
# ... (more checks)
# Ready to install Flux. Continue? (y/n)
```

**Type `y` and press Enter to continue.**

The script will:
1. ✅ Create `flux-system` namespace
2. ✅ Create GitHub credentials secret
3. ✅ Install Flux components
4. ✅ Configure the GitRepository and Kustomization
5. ✅ Wait for pods to be ready

**⏱️ This takes 2-5 minutes. Be patient!**

### Step 5: Verify Installation

After the bootstrap completes, let's verify everything is working:

#### Check 1: Flux System Pods

```bash
# Check if Flux pods are running
kubectl get pods -n flux-system

# Expected output (all should show "Running"):
# NAME                                       READY   STATUS    RESTARTS   AGE
# helm-controller-5b4d4dcb67-lqrz5           1/1     Running   0          3m
# kustomize-controller-5789dbf4b5-8qz7x      1/1     Running   0          3m
# notification-controller-6fcdc44d58-xlbz5   1/1     Running   0          3m
# source-controller-5d95f8fbd8-vxd8m         1/1     Running   0          3m

# If any say "Pending" or "CrashLoopBackOff", wait a minute and try again
```

#### Check 2: Flux Status

```bash
# Check overall Flux status
flux status

# Expected output:
# NAMESPACE   NAME                          READY   MESSAGE                       REVISION            SUSPENDED
# flux-system flux-system                    True    applied revision main/xxxx     main/xxxx            False
```

#### Check 3: GitRepository

```bash
# Check if Flux is connected to GitHub
flux get sources git

# Expected output:
# NAMESPACE   NAME          READY   MESSAGE                                REVISION            SUSPENDED
# flux-system flux-system   True    Fetched revision: main/abcd1234...     main/abcd1234...    False
```

#### Check 4: Watch Logs

```bash
# Watch Flux logs in real-time
flux logs --follow

# You'll see logs like:
# 2026-05-22T14:56:26.123Z info Fetching https://github.com/Satya-jit/gitops-flux-cd.git
# 2026-05-22T14:56:27.456Z info Cloning master, syncing: main
# ... (more logs)

# Press Ctrl+C to stop watching
```

**✅ If you see all 4 checks working, Flux is installed successfully!**

---

## Day 3: Add First Application (Portfolio)

Now let's add your Portfolio application to Flux CD!

### Step 1: Understand the Directory Structure

First, understand where we'll create the configuration:

```
clusters/raspberry-pi-homelab/applications/
└── portfolio/                    ← We'll create this folder
    ├── namespace.yaml            ← Define the namespace
    ├── source.yaml               ← Tell Flux where to find the app code
    └── kustomization.yaml        ← Tell Flux what to deploy
```

### Step 2: Create Portfolio Namespace

Create a new file: `clusters/raspberry-pi-homelab/applications/portfolio/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: portfolio
  labels:
    app: portfolio
```

**What this does:** Creates a namespace called "portfolio" to isolate your app from others.

### Step 3: Create Portfolio Source

Create a new file: `clusters/raspberry-pi-homelab/applications/portfolio/source.yaml`

```yaml
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
```

**What this does:** Tells Flux to watch your Portfolio repository every 1 minute for changes.

### Step 4: Create Portfolio Kustomization

Create a new file: `clusters/raspberry-pi-homelab/applications/portfolio/kustomization.yaml`

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: portfolio
  namespace: portfolio
spec:
  interval: 5m0s
  path: ./k8s
  prune: true
  wait: true
  sourceRef:
    kind: GitRepository
    name: portfolio
```

**What this does:** Tells Flux to apply the files from the `./k8s` directory of your Portfolio repository to the cluster.

### Step 5: Push Changes to GitHub

```bash
# Check what files you created
git status

# You should see:
# Untracked files:
#   clusters/raspberry-pi-homelab/applications/portfolio/

# Add the files
git add clusters/raspberry-pi-homelab/applications/portfolio/

# Create a commit
git commit -m "feat: add portfolio application"

# Push to GitHub
git push origin main
```

### Step 6: Watch Flux Deploy

```bash
# Watch the logs
flux logs --follow

# You'll see something like:
# 2026-05-22T15:10:30.123Z info GitRepository/portfolio created
# 2026-05-22T15:10:31.456Z info Fetching portfolio repository
# 2026-05-22T15:10:35.789Z info Cloning portfolio, syncing: main
# 2026-05-22T15:10:40.012Z info Applying portfolio manifests
# ... (deployment happens automatically!)

# Press Ctrl+C to stop
```

### Step 7: Verify Portfolio is Deployed

```bash
# Check if the namespace was created
kubectl get namespace portfolio
# Expected output:
# NAME       STATUS   AGE
# portfolio  Active   2m

# Check if the pods are running
kubectl get pods -n portfolio
# Expected output:
# NAME                                   READY   STATUS    RESTARTS   AGE
# portfolio-backend-579fc556-wz684       1/1     Running   0          2m
# portfolio-frontend-69f54855c5-lwvxl    1/1     Running   0          2m

# Check services
kubectl get svc -n portfolio
# Expected output:
# NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
# portfolio-backend     ClusterIP   10.43.176.71    <none>        8000/TCP
# portfolio-frontend    ClusterIP   10.43.157.124   <none>        80/TCP

# Check the deployment status
kubectl describe deployment portfolio-frontend -n portfolio
```

**✅ Congratulations! Your first application is now managed by Flux CD!**

### Step 8: Test the Application

```bash
# Test if the frontend is accessible
kubectl port-forward svc/portfolio-frontend 8080:80 -n portfolio
# Now visit: http://localhost:8080

# In another terminal, test the backend
kubectl port-forward svc/portfolio-backend 8000:8000 -n portfolio
# Now visit: http://localhost:8000

# Press Ctrl+C to stop port-forwarding
```

---

## Day 4: Add More Applications

### Add ZetaControl (Phases 1, 2, 3)

Repeat the same process for ZetaControl. This time, we'll create 3 phases.

#### Step 1: Create Phase 1 Configuration

**File:** `clusters/raspberry-pi-homelab/applications/zetacontrol/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: zetacontrol
  labels:
    app: zetacontrol
```

**File:** `clusters/raspberry-pi-homelab/applications/zetacontrol/source.yaml`

```yaml
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
```

**File:** `clusters/raspberry-pi-homelab/applications/zetacontrol/phase-1-kustomization.yaml`

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: zetacontrol-phase-1
  namespace: zetacontrol
spec:
  interval: 5m0s
  path: ./k8s/phase-1
  prune: true
  sourceRef:
    kind: GitRepository
    name: zetacontrol
```

#### Step 2: Create Phase 2 Configuration

**File:** `clusters/raspberry-pi-homelab/applications/zetacontrol/phase-2-kustomization.yaml`

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: zetacontrol-phase-2
  namespace: zetacontrol
spec:
  interval: 5m0s
  path: ./k8s/phase-2
  prune: true
  sourceRef:
    kind: GitRepository
    name: zetacontrol
```

#### Step 3: Create Phase 3 Configuration

**File:** `clusters/raspberry-pi-homelab/applications/zetacontrol/phase-3-kustomization.yaml`

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: zetacontrol-phase-3
  namespace: zetacontrol
spec:
  interval: 5m0s
  path: ./k8s/phase-3
  prune: true
  sourceRef:
    kind: GitRepository
    name: zetacontrol
```

#### Step 4: Push Changes

```bash
# Add files
git add clusters/raspberry-pi-homelab/applications/zetacontrol/

# Commit
git commit -m "feat: add zetacontrol phases 1, 2, 3"

# Push
git push origin main
```

#### Step 5: Verify Deployment

```bash
# Watch logs
flux logs --follow

# Check pods
kubectl get pods -n zetacontrol

# Check all Kustomizations
flux get kustomizations --all-namespaces
```

---

## Day 5: Monitoring & Troubleshooting

### Common Commands for Daily Use

```bash
# ============================================
# MONITORING & STATUS
# ============================================

# Check everything at once
flux status

# List all Git sources
flux get sources git

# List all Kustomizations
flux get kustomizations --all-namespaces

# List all Helm releases
flux get helmreleases --all-namespaces

# Watch logs in real-time
flux logs --follow

# ============================================
# TROUBLESHOOTING
# ============================================

# Check specific application logs
flux logs --follow --labels=kustomize.toolkit.fluxcd.io/name=portfolio

# Detailed status of a specific resource
kubectl describe gitrepository portfolio -n portfolio
kubectl describe kustomization portfolio -n portfolio

# Check Flux system pods
kubectl get pods -n flux-system
kubectl logs -n flux-system deployment/source-controller

# ============================================
# MANUAL OPERATIONS
# ============================================

# Force immediate reconciliation (don't wait 5 minutes)
flux reconcile kustomization portfolio -n portfolio

# Pause syncing (useful for maintenance)
flux suspend kustomization portfolio -n portfolio

# Resume syncing
flux resume kustomization portfolio -n portfolio

# ============================================
# DEBUGGING
# ============================================

# Get detailed status of a resource
kubectl get gitrepository portfolio -n portfolio -o yaml

# Check events
kubectl get events -n flux-system --sort-by='.lastTimestamp'

# View pod logs
kubectl logs -n portfolio deployment/portfolio-frontend
```

### Troubleshooting Common Issues

#### Issue 1: Pod Not Running After Push

**Symptoms:**
```bash
$ kubectl get pods -n portfolio
NAME                              READY   STATUS      RESTARTS   AGE
portfolio-backend-xxx             0/1     Pending     0          5m
```

**Solution:**
```bash
# Check what's wrong
kubectl describe pod portfolio-backend-xxx -n portfolio

# Common causes:
# 1. Insufficient memory/CPU
kubectl top nodes  # Check available resources

# 2. Image pull failed
kubectl logs portfolio-backend-xxx -n portfolio

# 3. PVC not bound
kubectl get pvc -n portfolio
```

#### Issue 2: Flux Not Syncing Changes

**Symptoms:**
```bash
$ flux logs --follow
(no new logs after pushing changes)
```

**Solution:**
```bash
# Force Flux to check for changes
flux reconcile source git portfolio -n portfolio

# Check GitRepository status
kubectl describe gitrepository portfolio -n portfolio

# Verify GitHub credentials are correct
kubectl get secret github-credentials -n flux-system
```

#### Issue 3: "Image not found" Error

**Symptoms:**
```bash
kubectl describe pod portfolio-frontend-xxx -n portfolio
# Events:
#   Type     Reason                 Age                    Message
#   ----     ------                 ----                   -------
#   Warning  Failed                 2m                     Error: image not found
```

**Solution:**
```bash
# Check what image is being used
kubectl get deployment portfolio-frontend -n portfolio -o jsonpath='{.spec.template.spec.containers[0].image}'

# Make sure image tag exists in your repository
# Update the image tag in your kustomization.yaml

# Push changes
git add .
git commit -m "fix: update image tag"
git push origin main

# Force reconciliation
flux reconcile kustomization portfolio -n portfolio
```

### Weekly Checklist

Every week, run these commands to ensure everything is healthy:

```bash
# ✅ Flux system is healthy
flux check

# ✅ All applications are synced
flux status

# ✅ No pending pods
kubectl get pods -A | grep -i pending

# ✅ Check resource usage
kubectl top nodes
kubectl top pods -A

# ✅ Check for errors in logs
flux logs --all-namespaces | grep -i error

# ✅ Verify GitHub connectivity
kubectl describe gitrepository -A

# ✅ Check Flux version (for updates)
flux --version
```

---

## Next Steps After 5 Days

### Week 2: Advanced Features

1. **Add Helm Charts**
   - Monitoring (Prometheus, Grafana)
   - Cert-manager for HTTPS
   - See `docs/adding-new-app.md` for Helm examples

2. **Configure Notifications**
   - Slack alerts when deployments fail
   - See `docs/adding-new-app.md`

3. **Set Up Sealed Secrets**
   - Store secrets securely in Git
   - Instead of plain text credentials

### Week 3: Production Readiness

1. **Enable Pull Request Automation**
   - Automatically update images from GitHub container registry

2. **Set Up Image Scanning**
   - Detect and fix security vulnerabilities

3. **Configure Backup Strategy**
   - Back up your cluster state

---

## Useful Resources

### Documentation
- [Flux CD Official Docs](https://fluxcd.io/docs/) - Complete reference
- [Kustomize Guide](https://kubectl.docs.kubernetes.io/references/kustomize/) - Template management
- [Kubernetes Docs](https://kubernetes.io/docs/) - Core concepts

### Video Tutorials
- [Flux CD Getting Started](https://www.youtube.com/results?search_query=flux+cd+getting+started)
- [Kubernetes Basics](https://www.youtube.com/watch?v=X48VuDVv0Sg)

### Community
- [Flux Discord](https://discord.gg/B8QR5Z) - Ask questions
- [GitHub Issues](https://github.com/Satya-jit/gitops-flux-cd/issues) - Report problems

### Your Repositories
- [gitops-flux-cd](https://github.com/Satya-jit/gitops-flux-cd) - Configurations
- [My-portfolio](https://github.com/Satya-jit/My-portfolio) - Your application
- [zetacontrol](https://github.com/Satya-jit/zetacontrol) - Your application

---

## Quick Reference Card

```bash
# ===============================
# INSTALLATION
# ===============================
export GITHUB_TOKEN=ghp_xxx
export GITHUB_USER=Satya-jit
export GITHUB_REPO=gitops-flux-cd
bash scripts/bootstrap.sh

# ===============================
# VERIFY
# ===============================
flux check
flux status
kubectl get pods -n flux-system

# ===============================
# DEPLOY APP
# ===============================
# 1. Create files in clusters/raspberry-pi-homelab/applications/<app>/
# 2. git push origin main
# 3. flux logs --follow
# 4. kubectl get pods -n <app>

# ===============================
# MONITOR
# ===============================
flux logs --follow
kubectl get pods -A
flux status

# ===============================
# TROUBLESHOOT
# ===============================
flux logs --follow --labels=kustomize.toolkit.fluxcd.io/name=<app>
kubectl describe kustomization <app> -n <app>
kubectl logs -n <app> deployment/<app>

# ===============================
# MANUAL SYNC
# ===============================
flux reconcile kustomization <app> -n <app>
flux suspend kustomization <app> -n <app>
flux resume kustomization <app> -n <app>
```

---

## Summary

You now have a complete 5-day plan to implement Flux CD:

| Day | Task | Time |
|-----|------|------|
| 1 | Understand concepts | 30 min |
| 2 | Install & verify | 1 hour |
| 3 | Add Portfolio app | 30 min |
| 4 | Add ZetaControl phases | 1 hour |
| 5 | Monitor & troubleshoot | 30 min |

**Total: ~3.5 hours over 5 days**

**You've got this! 🚀**

---

**Questions?** Check:
1. `docs/troubleshooting.md` - For common problems
2. `docs/adding-new-app.md` - For more application examples
3. `docs/bootstrap.md` - For detailed installation steps

**Need help?** Open an issue: https://github.com/Satya-jit/gitops-flux-cd/issues

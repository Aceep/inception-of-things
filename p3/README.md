# Part 3: K3d with Argo CD - Continuous Integration

This project sets up a Kubernetes cluster using **k3d** (k3s in Docker) with **Argo CD** for GitOps-based continuous deployment.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Using Argo CD](#using-argo-cd)
- [Switching Application Versions](#switching-application-versions)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

This project implements:

1. **k3d Cluster**: A lightweight Kubernetes cluster running in Docker containers
2. **Two Namespaces**:
   - `argocd`: Contains the Argo CD deployment
   - `dev`: Contains the application deployed via GitOps
3. **Argo CD**: Watches a GitHub repository and automatically deploys changes
4. **Wil Playground App**: A sample application with two versions (v1 and v2)

## ✅ Prerequisites

- Linux-based system (Ubuntu recommended)
- `sudo` access for installing packages
- Internet connection
- GitHub account (for hosting manifests)

## 📁 Project Structure

```
p3/
├── scripts/
│   ├── install.sh          # Installs Docker, k3d, kubectl, argocd CLI
│   └── setup.sh            # Creates cluster, namespaces, deploys Argo CD
├── confs/
│   ├── argocd/
│   │   └── application.yaml  # Argo CD application pointing to GitHub
│   └── dev/
│       └── deployment.yaml   # Application deployment manifest
├── argocd-credentials.txt    # (Generated) Argo CD admin credentials
└── README.md
```

## 🚀 Quick Start

```bash
# 1. Make scripts executable
chmod +x scripts/*.sh

# 2. Install required tools (Docker, k3d, kubectl, argocd CLI)
./scripts/install.sh

# 3. Apply Docker group changes (if fresh Docker install)
newgrp docker

# 4. Setup the cluster with Argo CD
./scripts/setup.sh

# 5. Access Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 1:443 &
# Then open: https://localhost:8081
```

## 📖 Detailed Setup

### Step 1: Install Required Tools

The installation script will install:
- **Docker**: Container runtime required by k3d
- **k3d**: Tool to run k3s (lightweight Kubernetes) in Docker
- **kubectl**: Kubernetes command-line tool
- **argocd CLI**: Argo CD command-line tool

```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

> ⚠️ **Note**: After installing Docker, you may need to log out and back in, or run `newgrp docker` to apply group changes.

### Step 2: Setup the Cluster

The setup script will:
1. Create a k3d cluster with port mappings
2. Create `argocd` and `dev` namespaces
3. Install Argo CD
4. Configure Argo CD access
5. Deploy the Argo CD application configuration

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

### Step 3: Access Argo CD

After setup, you can access the Argo CD UI:

```bash
# Start port-forward in background
kubectl port-forward svc/argocd-server -n argocd 8081:443 &

# Open in browser
echo "Open: https://localhost:8081"
```

**Credentials:**
- Username: `admin`
- Password: Check `argocd-credentials.txt` or run:
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```

## 🔄 Using Argo CD

### View Application Status

```bash
# Using kubectl
kubectl get applications -n argocd

# Using argocd CLI
argocd login localhost:8081 --username admin --password <password> --insecure
argocd app list
```

### Sync Application Manually

```bash
# Using argocd CLI
argocd app sync wil-playground

# Using kubectl
kubectl get all -n dev
```

### View Application in Web UI

1. Open https://localhost:8081
2. Login with admin credentials
3. Click on "wil-playground" application
4. View deployment status, health, and history

## 🔀 Switching Application Versions

The application uses **Wil's playground** image which has two versions:
- `wil42/playground:v1` - First version
- `wil42/playground:v2` - Second version

### To switch versions:

1. **Edit the deployment file** `confs/dev/deployment.yaml`:
   ```yaml
   image: wil42/playground:v2  # Change from v1 to v2
   ```

2. **Commit and push to GitHub**:
   ```bash
   git add confs/dev/deployment.yaml
   git commit -m "Update app to v2"
   git push
   ```

3. **Argo CD automatically detects** the change and deploys v2

4. **Verify the update**:
   ```bash
   kubectl get pods -n dev
   kubectl describe pod -n dev -l app=wil-playground | grep Image
   ```

## 🧹 Cleanup

### Delete the k3d Cluster

```bash
k3d cluster delete iot-cluster
```

### Delete Everything

```bash
# Delete cluster
k3d cluster delete iot-cluster

# Remove generated files
rm -f argocd-credentials.txt
```

## 🔧 Troubleshooting

### Docker Permission Denied

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply changes
newgrp docker
# OR log out and back in
```

### Argo CD Pods Not Starting

```bash
# Check pod status
kubectl get pods -n argocd

# Check pod logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

### Application Not Syncing

```bash
# Check application status
kubectl get application wil-playground -n argocd -o yaml

# Check Argo CD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Force sync
argocd app sync wil-playground --force
```

### Cannot Access Argo CD UI

```bash
# Check if service is running
kubectl get svc -n argocd

# Try NodePort access
NODEPORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
echo "Try: https://localhost:$NODEPORT"

# Or use port-forward
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

### Check Cluster Status

```bash
# Check k3d cluster
k3d cluster list

# Check nodes
kubectl get nodes

# Check all resources
kubectl get all --all-namespaces
```

## 📚 References

- [k3d Documentation](https://k3d.io/)
- [k3s Documentation](https://docs.k3s.io/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

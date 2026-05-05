# Phase 2 — Cluster bootstrap

[← Phase 1](phase-01-terraform-foundation.md) · [Index](README.md) · [Phase 3 →](phase-03-first-service-frontend.md)

**Goal:** Ingress, TLS stack, DNS sync, metrics, Argo CD running; cluster ready for GitOps.

---

## Implementation

> **Use:** Terminal (`kubectl`, `helm`), **Helm** repos, optional **Terraform** if you install platform via code, **Azure Portal** (managed identities, DNS zone IAM), **Argo CD UI** or CLI after install.

1. **CSI Secrets Store** — Install driver + Azure provider if not using an AKS add-on that already provides it. Confirm OIDC / Workload Identity on the cluster matches your Terraform (`kubectl` / Azure Portal).

2. **NGINX Ingress** — Install to `ingress-nginx`. Set the Service `LoadBalancer` to use the **static public IP** from Phase 1 (Helm values: Azure annotations for PIP name / IP — check current NGINX Ingress + AKS docs).

3. **cert-manager** — Install to `cert-manager`. Apply `ClusterIssuer` manifests for Let’s Encrypt **DNS-01** against your Azure DNS zone (identity needs permission to create TXT records).

4. **external-dns** — Install to `external-dns`. Grant the workload identity **DNS Zone Contributor** on the public zone (or equivalent for your setup).

5. **kube-prometheus-stack** — Install to `monitoring`. Ensure a default **StorageClass** exists for Prometheus PVC or adjust values.

6. **Argo CD** — Install to `argocd`. Initial admin: `argocd admin initial-password -n argocd` (or use your chart’s flow). Expose via **Ingress + cert** (e.g. `argocd.<your-domain>`) or temporarily `kubectl port-forward svc/argocd-server -n argocd 8080:443`.

7. **Repo credential in Argo CD** — **Settings → Repositories**: add SSH key, HTTPS token, or Azure DevOps PAT so Argo CD can pull this mono-repo.

8. **Bootstrap app (when child apps exist)** — Copy `gitops/bootstrap/root-app.yaml.example` → `root-app.yaml`, set `repoURL`, apply: `kubectl apply -n argocd -f gitops/bootstrap/root-app.yaml`.

---

## Detailed step-by-step guide (practical)

Follow these steps in order. Do not continue to the next component until the current one is healthy.

### 0) Pre-checks (before any install)

1. Ensure your cluster context is correct:
   ```bash
   kubectl config current-context
   kubectl get nodes -o wide
   ```
2. Confirm Helm is ready:
   ```bash
   helm version
   ```
3. Create namespaces up front:
   ```bash
   kubectl create ns ingress-nginx --dry-run=client -o yaml | kubectl apply -f -
   kubectl create ns cert-manager --dry-run=client -o yaml | kubectl apply -f -
   kubectl create ns external-dns --dry-run=client -o yaml | kubectl apply -f -
   kubectl create ns monitoring --dry-run=client -o yaml | kubectl apply -f -
   kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -
   ```
4. Check DNS zone is delegated to Azure NS from Phase 1:
   ```bash
   nslookup -type=ns <your-domain>
   ```

### 1) CSI Secrets Store (driver + Azure provider)

1. Add repos:
   ```bash
   helm repo add csi-secrets-store https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
   helm repo add csi-azure https://azure.github.io/secrets-store-csi-driver-provider-azure/charts
   helm repo update
   ```
2. Install driver:
   ```bash
   helm upgrade --install csi-secrets-store csi-secrets-store/secrets-store-csi-driver \
     -n kube-system
   ```
3. Install Azure provider:
   ```bash
   helm upgrade --install csi-azure csi-azure/csi-secrets-store-provider-azure \
     -n kube-system
   ```
4. Verify:
   ```bash
   kubectl get pods -n kube-system | grep -E "secrets-store|csi"
   ```

### 2) NGINX Ingress with static public IP

1. Add repo:
   ```bash
   helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
   helm repo update
   ```
2. Get the static IP created in Phase 1:
   ```bash
   cd infra/terraform/envs/shared
   terraform output ingress_public_ip
   ```
3. Install NGINX using that IP:
   ```bash
   helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
     -n ingress-nginx \
     --set controller.service.loadBalancerIP="<INGRESS_PUBLIC_IP>"
   ```
4. Verify external IP:
   ```bash
   kubectl get svc -n ingress-nginx ingress-nginx-controller -w
   ```

### 3) cert-manager + Let's Encrypt (DNS-01 with Azure DNS)

1. Add repo and install:
   ```bash
   helm repo add jetstack https://charts.jetstack.io
   helm repo update
   helm upgrade --install cert-manager jetstack/cert-manager \
     -n cert-manager \
     --set crds.enabled=true
   ```
2. Wait until ready:
   ```bash
   kubectl rollout status deploy/cert-manager -n cert-manager
   kubectl rollout status deploy/cert-manager-webhook -n cert-manager
   kubectl rollout status deploy/cert-manager-cainjector -n cert-manager
   ```
3. Create a `ClusterIssuer` manifest for Azure DNS solver (workload identity principal needs DNS Zone Contributor on your zone), then apply:
   ```bash
   kubectl apply -f <your-clusterissuer-file>.yaml
   ```
4. Verify issuer:
   ```bash
   kubectl get clusterissuer
   ```

### 4) external-dns

1. Add repo:
   ```bash
   helm repo add external-dns https://kubernetes-sigs.github.io/external-dns
   helm repo update
   ```
2. Install with your domain filter:
   ```bash
   helm upgrade --install external-dns external-dns/external-dns \
     -n external-dns \
     --set provider=azure \
     --set txtOwnerId=boutique \
     --set domainFilters[0]="<your-domain>"
   ```
3. Verify:
   ```bash
   kubectl logs deploy/external-dns -n external-dns --tail=100
   ```

### 5) kube-prometheus-stack

1. Add repo and install:
   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
     -n monitoring
   ```
2. Verify:
   ```bash
   kubectl get pods -n monitoring
   kubectl get pvc -n monitoring
   ```
3. If PVCs stay Pending, check default StorageClass:
   ```bash
   kubectl get sc
   ```

### 6) Argo CD

1. Add repo and install:
   ```bash
   helm repo add argo https://argoproj.github.io/argo-helm
   helm repo update
   helm upgrade --install argocd argo/argo-cd -n argocd
   ```
2. Get initial admin password:
   ```bash
   argocd admin initial-password -n argocd
   ```
3. Temporary local access:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
4. Login via UI at `https://localhost:8080`.

### 7) Connect repo to Argo CD

1. In Argo CD UI: `Settings -> Repositories -> Connect Repo`.
2. Add your GitHub/Azure DevOps repository credentials (PAT/SSH).
3. Run connection test until it succeeds.

### 8) Bootstrap root app

1. Create bootstrap manifest:
   ```bash
   cp gitops/bootstrap/root-app.yaml.example gitops/bootstrap/root-app.yaml
   ```
2. Edit `repoURL`, `targetRevision`, and path values.
3. Apply:
   ```bash
   kubectl apply -n argocd -f gitops/bootstrap/root-app.yaml
   ```
4. Verify app tree in Argo CD UI and sync status.

### 9) Final validation

Run these checks:

```bash
kubectl get pods -A
kubectl get ingress -A
kubectl get certificate -A
kubectl get applications -n argocd
```

Success criteria:
- No CrashLoopBackOff in platform namespaces.
- Ingress has external address.
- Certificates become `Ready=True`.
- Argo CD app sync succeeds.

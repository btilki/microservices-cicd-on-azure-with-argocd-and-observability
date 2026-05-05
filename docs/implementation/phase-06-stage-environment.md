# Phase 6 — Stage environment

[← Phase 5](phase-05-fan-out-services.md) · [Index](README.md) · [Phase 7 →](phase-07-prod-environment.md)

**Goal:** Stage namespace(s) + Argo CD project + GitOps for **stage** ACR; URL works after promotion.

---

## Implementation

> **Use:** Editor, **Git/PRs**, **Argo CD** (Projects, Applications, sync), **Helm values**, **Phase 4** promote pipeline to fill stage ACR.

1. **GitOps** — Add `gitops/apps/stage/*.yaml` and `gitops/envs/stage/*.yaml` (stage ACR login server, digests from promotion, replicas/resources for stage).

2. **Argo CD** — Create **AppProject** `boutique-stage` (allowed repos, namespaces, cluster). Point stage Applications at `project: boutique-stage`.

3. **Scheduling** — Values: `nodeSelector` / `tolerations` for `env=stage` (match AKS node pool taints).

4. **Docs** — Short note in repo or wiki: who approves promote PRs, link to pipeline.

5. **Run promote-to-stage** — Merge GitOps PRs; **Sync** in Argo CD if needed.

---

## Detailed step-by-step guide (practical)

This phase activates a real **stage** runtime path using:
- stage GitOps manifests
- Argo CD stage project/apps
- promoted images from **stage ACR**

### 0) Pre-checks

1. Confirm shared cluster and stage infrastructure are healthy:
   ```bash
   kubectl get nodes
   kubectl get ns
   ```
2. Confirm stage ACR exists:
   ```bash
   az acr list -o table
   ```
3. Confirm promotion pipeline from Phase 4 exists (`promote-to-stage`).

### 1) Create stage namespace and baseline policies

1. Create namespace (if missing):
   ```bash
   kubectl create ns stage --dry-run=client -o yaml | kubectl apply -f -
   ```
2. (Recommended) Add ResourceQuota and LimitRange manifests for `stage`.
3. (Recommended) Add default NetworkPolicy to restrict cross-namespace traffic.

Commit these baseline manifests under your GitOps structure (for example under `gitops/platform/stage/` or equivalent path used by your repo).

### 2) Create Argo CD AppProject for stage

Create an AppProject manifest (example file: `gitops/apps/stage/project-boutique-stage.yaml`) with:
- `metadata.name: boutique-stage`
- allowed source repos: your mono-repo URL
- allowed destination:
  - cluster: in-cluster API
  - namespace: `stage`
- optional sync windows/policy as needed

Apply and verify:
```bash
kubectl apply -f gitops/apps/stage/project-boutique-stage.yaml -n argocd
kubectl get appproject -n argocd
```

### 3) Add stage service Applications and values

For each service from Phase 5, create stage equivalents:

- `gitops/apps/stage/<service>.yaml`
- `gitops/envs/stage/values-<service>.yaml`

Required stage values:
- `image.repository: <stage-acr-login-server>/<service>`
- `image.digest: sha256:<promoted-digest>`
- stage-specific replicas/resources
- stage scheduling:
  - `nodeSelector` matching stage node labels
  - `tolerations` matching stage taints (`env=stage:NoSchedule`)

Do not copy dev hosts directly; set stage hostnames separately.

### 4) Register stage apps in bootstrap/app-of-apps

Add stage child application entries under your bootstrap folder (`gitops/bootstrap/applications/`) so root sync includes stage apps.

Then sync root:
```bash
kubectl get applications -n argocd
```

If autosync is off, sync from Argo CD UI manually.

### 5) Configure stage ingress and TLS hostnames

For stage-exposed services (usually frontend):
- set `host: stage.<your-domain>` (or your naming)
- ensure Ingress class matches nginx controller
- ensure cert-manager issuer reference is correct

Verify:
```bash
kubectl get ingress -n stage
kubectl get certificate -n stage
```

### 6) Run promote-to-stage and merge GitOps PR

1. Execute promotion pipeline with selected digest.
2. Review PR changes:
   - repository points to **stage ACR**
   - digest equals promoted digest
3. Merge PR to `main`.

Verify digest exists in stage ACR:
```bash
az acr repository show-manifests \
  --name <STAGE_ACR_NAME> \
  --repository frontend \
  --orderby time_desc \
  -o table
```

### 7) Verify stage deployment health

Commands:
```bash
kubectl get applications -n argocd
kubectl get pods -n stage
kubectl get svc -n stage
kubectl get ingress -n stage
```

Check running image references:
```bash
kubectl get pod -n stage -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.spec.containers[*].image}{"\n"}{end}'
```

Confirm they point to stage registry and digest form `@sha256:...`.

### 8) Functional verification in stage

1. External test:
   ```bash
   curl -I https://stage.<your-domain>/
   ```
2. Basic journey test in browser:
   - open frontend
   - browse products
   - add to cart
   - checkout path
3. If failures occur, inspect logs:
   ```bash
   kubectl logs deploy/frontend -n stage --tail=200
   kubectl logs deploy/checkoutservice -n stage --tail=200
   ```

### 9) Operational controls for stage

Document these in repo docs (short and explicit):
- who can run `promote-to-stage`
- who approves stage PRs
- rollback method (revert digest PR to previous known digest)
- SLO/checklist before promoting to prod

### 10) Definition of done for Phase 6

- Stage namespace is managed by GitOps and Argo CD project `boutique-stage`.
- Stage apps sync successfully and are healthy.
- Stage workloads pull images from **stage ACR** only.
- Stage URL is reachable with valid TLS.
- Promotion process (`dev -> stage`) is repeatable with digest-based PR updates.

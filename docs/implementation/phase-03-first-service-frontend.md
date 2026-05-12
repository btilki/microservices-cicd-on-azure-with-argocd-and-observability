# Phase 3 — First service (`frontend`)

[← Phase 2](phase-02-cluster-bootstrap.md) · [Index](README.md) · [Phase 4 →](phase-04-promotion-pipeline.md)

**Goal:** Build → dev ACR → GitOps digest → Argo CD → HTTPS on dev hostname.

## Process (brief)

> **Use: Git** (branches, PRs), **Helm**, **Azure DevOps Pipelines** (or GitHub Actions), **Azure Portal/CLI** (ACR, service connections), **Argo CD UI**, browser for HTTPS test.

1. **Source** — Add `apps/frontend` (copy from [microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) or use subtree; see `apps/README.md`).

2. **Helm** — Create `charts/frontend` (Deployment, Service, ServiceAccount; Ingress for dev; values for registry + **digest**, tolerations/nodeSelector for `env=dev`).

3. **GitOps** — Add `gitops/apps/dev/frontend-dev.yaml` (Argo CD `Application`, `metadata.name: frontend-dev`) and `gitops/envs/dev/values-frontend.yaml` (dev ACR login server + placeholder digest).

4. **Register app** — Add `gitops/apps/dev/frontend-dev.yaml`; the **`apps-dev`** umbrella (`gitops/bootstrap/applications/apps-dev.yaml`) syncs that directory so the root app picks it up.

5. **Azure DevOps** — New pipeline from YAML: `pipelines/ci/frontend.yml` (create file): build image, run tests/lint, **Trivy**, push to **dev** ACR, output digest, script or task to open PR updating `gitops/envs/dev/values-frontend.yaml`. Configure **service connection** (ACR push, federated identity if used).

6. **Merge** GitOps PR — In Argo CD: app syncs; **Applications** → `frontend-dev` healthy.

7. **TLS** — Ingress host matches cert (e.g. `dev.boutique.<domain>`); fix DNS/cert-manager if browser shows cert errors.

## Detailed step-by-step guide (practical)

Use this as a concrete path from source code to a live HTTPS endpoint in `dev`.

### 0) Pre-checks (run once)

1. Confirm these are working:
   ```bash
   az account show
   kubectl get nodes
   kubectl get applications -n argocd
   ```
2. Confirm `dev` infrastructure exists (from Phase 1):
   ```bash
   cd infra/terraform/envs/dev
   terraform output
   ```
3. Confirm cluster bootstrap components from Phase 2 are healthy:
   ```bash
   kubectl get pods -n ingress-nginx
   kubectl get pods -n cert-manager
   kubectl get pods -n argocd
   ```

### 1) Add frontend source code

1. Put app code under:
   - `apps/frontend`
2. Ensure it can build locally:
   ```bash
   cd apps/frontend
   # use your runtime toolchain here (npm/mvn/go/etc.)
   ```
3. Add/update Dockerfile if missing:
   - Build artifact
   - Expose app port
   - Set non-root user if possible

### 2) Create Helm chart for frontend

1. Create chart:
   ```bash
   mkdir -p charts/frontend/templates
   ```
2. Add minimum templates:
   - `Deployment`
   - `Service`
   - `ServiceAccount`
   - `Ingress` (dev host)
3. In chart values, include:
   - `image.repository`
   - `image.digest` (preferred)
   - `ingress.host`
   - scheduling fields for dev pool:
     - `nodeSelector`
     - `tolerations`
4. Render check:
   ```bash
   helm template frontend charts/frontend -f gitops/envs/dev/values-frontend.yaml
   ```

### 3) Add GitOps app manifests

1. Create Argo CD `Application`:
   - `gitops/apps/dev/frontend-dev.yaml`
2. Create env values file:
   - `gitops/envs/dev/values-frontend.yaml`
3. Put initial image settings in values file:
   - `repository: <dev-acr-login-server>/frontend`
   - `digest: sha256:<placeholder>`
4. Register for Argo CD (this repo’s pattern):
   - add **`gitops/apps/dev/frontend-dev.yaml`** (and merge to `main`). The umbrella Application **`apps-dev`** in `gitops/bootstrap/applications/apps-dev.yaml` syncs the whole `gitops/apps/dev/` directory, so you normally **do not** add one file per service under `bootstrap/applications/`.

### 4) Add CI pipeline for frontend

1. Create pipeline file:
   - `pipelines/ci/frontend.yml`
2. Pipeline stages should do:
   - checkout
   - app tests/lint
   - container build
   - Trivy scan
   - push image to dev ACR
   - capture pushed image digest
   - update `gitops/envs/dev/values-frontend.yaml` with new digest
   - open PR with that GitOps change
3. Configure Azure DevOps service connection:
   - rights to push to dev ACR
   - repo permissions to open PR
4. Azure checks before first pipeline run:
   ```bash
   az account show -o table
   az acr show -n acrboutiquedevweu -o table
   az acr repository list -n acrboutiquedevweu -o table
   ```
5. GitHub token checks for PR automation:
   - store token in Azure DevOps secret variable `GITHUB_TOKEN`
   - token needs `repo` scope for branch push + pull request creation
   - protect variable group permissions so only trusted pipelines can use it

### 5) Validate pipeline output

After pipeline runs, confirm:

1. Image exists in ACR:
   ```bash
   az acr repository show-tags --name <DEV_ACR_NAME> --repository frontend -o table
   ```
2. GitOps PR contains digest update:
   - `image.digest: sha256:...`
3. Merge GitOps PR to `main`.
4. Optional verification of digest in ACR:
   ```bash
   az acr manifest list-metadata --registry acrboutiquedevweu --name frontend -o table
   ```

### 6) Argo CD deployment verification

1. In Argo CD UI:
   - `frontend-dev` app should become `Healthy` + `Synced`
2. CLI checks:
   ```bash
   kubectl get deploy,po,svc,ing -n dev
   kubectl describe ingress -n dev
   ```
3. Confirm running image uses digest (not only mutable tag):
   ```bash
   kubectl get pod -n dev -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.spec.containers[*].image}{"\n"}{end}'
   ```

### 7) HTTPS and DNS checks

1. Confirm DNS record for frontend host:
   ```bash
   nslookup <dev-frontend-host>
   ```
2. Confirm TLS certificate ready:
   ```bash
   kubectl get certificate -A
   kubectl get challenges.acme.cert-manager.io -A
   ```
3. Browser/curl test:
   ```bash
   curl -I https://<dev-frontend-host>
   ```
   Expect `200` or application redirect, and valid cert chain.

### Boutique App Frontend Development is healthy and synced on Argo CD:

![alt text](./../diagrams/boutique-frontend-dev.png)

### Boutique Apps Frontend Development:

![alt text](./../diagrams/boutique-frontend-dev-hot-products.png)


### 8) Definition of done for Phase 3

- `frontend` is managed by Argo CD from GitOps manifests.
- CI pipeline pushes image to dev ACR and updates digest in GitOps via PR.
- `https://<dev-frontend-host>` is reachable with valid TLS.
- Workload runs on intended `dev` nodes via selectors/tolerations.

---

[← Phase 2](phase-02-cluster-bootstrap.md) · [Index](README.md) · [Phase 4 →](phase-04-promotion-pipeline.md)

# Phase 4 — Promotion pipeline

[← Phase 3](phase-03-first-service-frontend.md) · [Index](README.md) · [Phase 5 →](phase-05-fan-out-services.md)

**Goal:** One-click (or manual) **dev → stage** and **stage → prod** image copy via `az acr import` + GitOps PRs with the same digest.

---

## Implementation

> **Use:** **Azure DevOps** (new pipelines, **Environments**, **approvals**, **service connections**), terminal (`az acr import` in scripts), **Git** (PRs to `gitops/envs/stage` and `prod`), **Azure Portal** (ACR IAM if debugging).

1. **Service connection** — Identity that can read source ACR and write/import to target ACR (federated credential or secret-based SP). Test from a manual pipeline: `az login` / `az acr import --help` flow.

2. **`pipelines/promote/promote-to-stage.yml`** — Parameters or script: read digest from `gitops/envs/dev/` (or variables). Steps: `az acr import` from dev registry to stage registry; clone repo; branch; patch `gitops/envs/stage/*.yaml` (registry + digest); push branch; create PR (Azure DevOps **Create Pull Request** task or REST).

3. **`pipelines/promote/promote-to-prod.yml`** — Same for stage → prod and `gitops/envs/prod/`. Add **manual validation** / **environment approval** on prod.

4. **Branch policies** — On `main`, require reviewers for `gitops/envs/prod/**` (Azure DevOps **Path filters** in policy).

5. **Run** — Execute promote-to-stage manually; merge PR; confirm Argo CD updates stage. Repeat pattern for prod.

---

## Detailed step-by-step guide (practical)

This phase creates two manual promotion pipelines:
- `dev -> stage`
- `stage -> prod`

The key rule: **promote by digest, not by rebuilding image**.

### 0) Pre-checks

1. Confirm all three ACRs exist:
   ```bash
   az acr list -o table
   ```
2. Confirm frontend image exists in `dev` ACR and note digest:
   ```bash
   az acr repository show-manifests \
     --name <DEV_ACR_NAME> \
     --repository frontend \
     --orderby time_desc \
     -o table
   ```
3. Confirm GitOps env files exist:
   - `gitops/envs/dev/values-frontend.yaml`
   - `gitops/envs/stage/values-frontend.yaml`
   - `gitops/envs/prod/values-frontend.yaml`

### 1) Azure DevOps service connection (promotion identity)

Create or reuse one service connection that can:
- read from source ACR
- import/write to target ACR
- (if pipeline edits repo directly) push branch + create PR

Minimum role guidance:
- Source ACR: `AcrPull`
- Target ACR: `AcrPush` (or equivalent import-capable permissions)

Quick validation from a test pipeline step:
```bash
az account show
az acr import --help
```

### 2) Add promote-to-stage pipeline YAML

Create `pipelines/promote/promote-to-stage.yml`.

Required pipeline inputs:
- image name (example: `frontend`)
- digest to promote (or path to read from dev values file)
- source ACR (`dev`)
- target ACR (`stage`)

Pipeline logic:
1. Resolve digest (`sha256:...`).
2. Import image:
   ```bash
   az acr import \
     --name <STAGE_ACR_NAME> \
     --source <DEV_ACR_LOGIN_SERVER>/frontend@sha256:<DIGEST> \
     --image frontend@sha256:<DIGEST>
   ```
3. Create branch.
4. Update `gitops/envs/stage/values-frontend.yaml`:
   - `repository: <stage-acr-login-server>/frontend`
   - `digest: sha256:<DIGEST>`
5. Commit, push branch.
6. Open PR to `main`.

### 3) Add promote-to-prod pipeline YAML

Create `pipelines/promote/promote-to-prod.yml`.

Use same pattern as stage, but:
- source ACR = `stage`
- target ACR = `prod`
- values file = `gitops/envs/prod/values-frontend.yaml`

Add protection before import/PR:
- Azure DevOps **Environment approval** (recommended), or
- Manual validation task in the pipeline.

### 4) Configure Azure DevOps Environments + approvals

1. Create environments:
   - `promote-stage`
   - `promote-prod`
2. Add checks:
   - stage: optional approver
   - prod: required approver(s)
3. Link pipelines to corresponding environment.

### 5) Branch policies for GitOps safety

On `main`:
- Require reviewers for all PRs.
- Add stricter path policy for:
  - `gitops/envs/prod/**`
- Optional: require successful promotion pipeline check before merge.

### 6) Run promote-to-stage end to end

1. Run `promote-to-stage` manually with selected digest.
2. Verify import in stage ACR:
   ```bash
   az acr repository show-manifests \
     --name <STAGE_ACR_NAME> \
     --repository frontend \
     --orderby time_desc \
     -o table
   ```
3. Review and merge generated PR.
4. Verify Argo CD stage app syncs and becomes healthy.

### 7) Run promote-to-prod end to end

1. Run `promote-to-prod` with same digest now in stage.
2. Approval step must pass.
3. Verify import in prod ACR:
   ```bash
   az acr repository show-manifests \
     --name <PROD_ACR_NAME> \
     --repository frontend \
     --orderby time_desc \
     -o table
   ```
4. Merge generated prod GitOps PR.
5. Verify Argo CD prod app sync and health.

### 8) Verify digest parity across environments

Check dev/stage/prod values files all reference expected digest and environment-specific registries.

Acceptance rule:
- The digest promoted to stage/prod is exactly the tested dev digest.
- No rebuild occurs during promotion.

### 9) Troubleshooting quick map

- `az acr import` permission denied:
  - check service connection identity roles on both ACRs.
- Import succeeds but pull fails in cluster:
  - ensure AKS kubelet identity has `AcrPull` on target ACR.
- PR not created:
  - verify repo write permissions/token scopes for pipeline identity.
- Argo CD not updating:
  - check app path, values file path, and sync policy.
- Different digest across envs:
  - enforce digest-only parameter and block tag-only promotions.

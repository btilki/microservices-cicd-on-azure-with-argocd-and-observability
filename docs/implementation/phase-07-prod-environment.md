# Phase 7 — Prod environment

[← Phase 6](phase-06-stage-environment.md) · [Index](README.md) · [Phase 8 →](phase-08-hardening.md)

**Goal:** Prod GitOps, **manual** Argo CD sync for prod, alerts, short runbooks.

---

## Implementation

> **Use:** **Argo CD** (projects, sync policy manual, RBAC), **Git** (strict PR rules for `gitops/envs/prod/**`), **Helm values**, **Alertmanager** config (YAML + reload), **Grafana** UI optional, `docs/runbooks/`.

1. **GitOps** — `gitops/apps/prod/*`, `gitops/envs/prod/*`: prod ACR, turn off `loadgenerator`, higher replicas/PDBs.

2. **Argo CD** — **AppProject** `boutique-prod`: disable auto-sync; restrict who can **Sync** (Argo CD **RBAC** / SSO groups).

3. **Alertmanager** — In Prometheus stack values: set **receiver** (email, Slack webhook, etc.); apply; send test alert.

4. **Runbooks** — Add `docs/runbooks/` entries: rollback = revert GitOps PR + sync; cert expiry; ingress 5xx.

5. **Promote-to-prod** — Run pipeline with approvals; merge prod GitOps PR; **operator clicks Sync** in Argo CD for prod.

---

## Detailed step-by-step guide (practical)

This phase creates a controlled production path with human approvals and explicit sync actions.

### 0) Pre-checks before enabling prod

1. Confirm stage is stable and recently tested.
2. Confirm prod namespace and ACR exist:
   ```bash
   kubectl get ns
   az acr list -o table
   ```
3. Confirm promote pipeline for prod is configured with approvals.
4. Confirm DNS target and certificate issuer strategy for prod host.

Do not proceed if stage is unstable.

### 1) Create prod namespace + baseline guardrails

1. Create namespace:
   ```bash
   kubectl create ns prod --dry-run=client -o yaml | kubectl apply -f -
   ```
2. Add baseline manifests for `prod`:
   - `ResourceQuota`
   - `LimitRange`
   - default `NetworkPolicy`
   - optional `PriorityClass` usage for critical services
3. Commit these to GitOps-managed paths.

### 2) Create Argo CD AppProject for prod

Create `boutique-prod` AppProject manifest with:
- source repo restriction to your mono-repo
- destination restriction to `prod` namespace only
- optional deny-list for dangerous cluster-scoped resources

Apply and verify:
```bash
kubectl apply -n argocd -f gitops/apps/prod/project-boutique-prod.yaml
kubectl get appproject -n argocd
```

### 3) Enforce manual sync for prod apps

For each prod `Application`:
- set `project: boutique-prod`
- remove/disable automated sync policy (`automated`) so sync is operator-triggered
- keep self-heal/prune behavior aligned with your change control policy

Verify with:
```bash
kubectl get applications -n argocd -o yaml | grep -n "prod\\|syncPolicy"
```

Expected: prod apps require manual Sync in Argo CD UI/CLI.

### 4) Create prod service manifests and values

For each service:
- `gitops/apps/prod/<service>.yaml`
- `gitops/envs/prod/values-<service>.yaml`

Prod-specific values:
- `image.repository: <prod-acr-login-server>/<service>`
- `image.digest: sha256:<promoted-digest>`
- higher replicas (relative to stage/dev)
- stronger resources and probes
- PodDisruptionBudget for critical services
- `nodeSelector` / `tolerations` for prod pool
- `loadgenerator.enabled: false`

### 5) Configure strict Git protections for prod paths

On `main` branch policies:
- require >=2 reviewers for `gitops/envs/prod/**` and `gitops/apps/prod/**`
- require successful pipeline checks
- enforce comment resolution
- disallow direct push to `main`

Document approver group names in repo docs.

### 6) Configure Alertmanager notifications

In monitoring values (kube-prometheus-stack):
- set receiver channel (email/Slack/Teams/webhook)
- route at least:
  - high error rate
  - pod crash loops
  - ingress 5xx burst
  - cert expiry warning

Apply and verify:
```bash
kubectl get pods -n monitoring
```

Trigger test notification (example):
- use Alertmanager test route or temporary test alert rule
- confirm message reaches your on-call channel

### 7) Runbooks (minimum operational set)

Add concise runbooks in `docs/runbooks/`:
- prod rollback
- ingress 5xx triage
- certificate renewal/expiry incident
- failing Argo sync in prod

Each runbook should include:
- symptoms
- immediate checks
- rollback or mitigation steps
- owner/escalation path

### 8) Promote image to prod (controlled release)

1. Run `promote-to-prod` pipeline with approvals.
2. Verify PR updates:
   - prod values files
   - digest-only change
   - repository points to prod ACR
3. Merge PR after approvals.

Verify digest exists in prod ACR:
```bash
az acr repository show-manifests \
  --name <PROD_ACR_NAME> \
  --repository frontend \
  --orderby time_desc \
  -o table
```

### 9) Manual Argo CD sync (human gate)

After PR merge:
1. Open Argo CD UI.
2. Select prod app(s).
3. Click **Sync** intentionally (manual gate).
4. Watch rollout and health.

CLI checks:
```bash
kubectl get applications -n argocd
kubectl get pods -n prod
kubectl get ingress -n prod
```

### 10) Post-release verification

1. External checks:
   ```bash
   curl -I https://<prod-host>/
   ```
2. App journey test in browser.
3. Observe dashboards/alerts for 15-30 minutes.
4. Confirm no unexpected restart spikes:
   ```bash
   kubectl get pods -n prod
   kubectl top pods -n prod
   ```

### 11) Rollback procedure (must be rehearsed)

If release is bad:
1. Revert the prod GitOps PR (or create a new PR pinning previous digest).
2. Merge rollback PR with expedited approvals.
3. Manual Sync in Argo CD for prod app.
4. Validate service recovery.

Keep previous known-good digest documented for fast rollback.

### 12) Definition of done for Phase 7

- Prod apps are managed via GitOps with `boutique-prod` project controls.
- Prod deployment requires both PR approval and manual sync action.
- Prod images are promoted digests from stage/prod pipeline (no rebuild).
- Alert notifications are tested and received.
- Runbooks exist and rollback flow is proven.

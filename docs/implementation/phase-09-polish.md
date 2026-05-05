# Phase 9 — Polish

[← Phase 8](phase-08-hardening.md) · [Index](README.md) · [Phase 10 →](phase-10-destroy-infrastructure.md)

**Goal:** Dashboards, automated smoke test, README demo path.

---

## Implementation

> **Use:** **Grafana** UI (import JSON dashboards), **Azure DevOps** (smoke step in pipeline) or **scripts/** with `curl`, editor for **README**, optional screen recording.

1. **Grafana** — Import or build dashboards: cluster capacity, ingress latency/errors, key service metrics, cert expiry.

2. **Smoke test** — Script or pipeline step: `curl -sf https://<prod-or-stage-host>/` and any critical API checks; fail pipeline on non-200.

3. **README** — Short “happy path”: commit → CI → dev → promote → stage → promote → prod → manual sync.

4. **Optional** — Demo recording or screenshots for handover.

---

## Detailed step-by-step guide (practical)

This phase turns the project into a handover-ready platform: clear observability, repeatable smoke checks, and a clean operator/developer README path.

### 0) Pre-checks

1. Confirm stage/prod are healthy:
   ```bash
   kubectl get applications -n argocd
   kubectl get pods -n stage
   kubectl get pods -n prod
   ```
2. Confirm monitoring stack is running:
   ```bash
   kubectl get pods -n monitoring
   ```
3. Confirm one stable release digest is already in production.

### 1) Build a minimum dashboard pack in Grafana

Create (or import) dashboards for:
- cluster/node capacity (CPU/memory/pods)
- workload health (restarts, unavailable replicas)
- ingress traffic, error rate, p95 latency
- certificate expiry window
- app-level golden signals for frontend + checkout flow

Recommended process:
1. Start with kube-prometheus default dashboards.
2. Clone and customize for your namespaces (`dev`, `stage`, `prod`).
3. Save JSON exports in repo (example folder: `docs/observability/dashboards/`) so setup is reproducible.

Validation:
- each dashboard has usable defaults
- time range 15m/1h/24h views are readable
- prod and stage filters work

### 2) Add automated smoke script

Create a script (example: `scripts/smoke.sh`) that checks:
- public homepage
- one or two critical API/business paths
- optional health endpoints

Example logic:
1. `curl -sf` homepage
2. check expected text/status
3. return non-zero on failure

Run locally first:
```bash
bash scripts/smoke.sh https://stage.<your-domain>
```

Script requirements:
- clear output lines (`PASS` / `FAIL`)
- non-zero exit code on failure
- timeout/retry handling

### 3) Wire smoke test into pipeline

Add smoke stage/job to Azure DevOps pipeline:
- after stage deploy sync
- optionally after prod manual sync

Pipeline behavior:
- fail pipeline if smoke script fails
- publish smoke logs/artifacts
- optional notification on failure

This makes promotion quality visible and enforceable.

### 4) Add release verification checklist document

Create short checklist file (example: `docs/runbooks/release-verification.md`) with:
- Argo app synced/healthy
- smoke checks pass
- no critical active alerts
- key dashboards normal for N minutes after release

Use this checklist before prod approval.

### 5) Improve README “happy path”

Update `README.md` with a concise end-to-end path:
1. code change and PR
2. CI build + scan + push to dev ACR
3. GitOps digest PR and Argo sync to dev
4. promote to stage + stage validation
5. promote to prod + manual sync
6. rollback pointer (link to runbook)

Keep it short, command-oriented, and link to phase docs for detail.

### 6) Add troubleshooting quick links

In README and/or runbooks index, add links to:
- ingress/TLS issues
- Argo sync failures
- image pull errors (ACR/RBAC)
- pod crashloop triage
- rollback runbook

Goal: reduce mean-time-to-diagnosis for new team members.

### 7) Optional handover assets

Create optional artifacts:
- architecture screenshot with namespaces and flow
- 3-5 minute demo video:
  - commit to dev
  - promote to stage
  - promote to prod
  - show dashboard + smoke pass

Store links in README for onboarding.

### 8) Final acceptance pass

Run an end-to-end dry run:
1. small non-breaking change
2. CI and digest PR in dev
3. stage promotion and smoke
4. prod promotion and manual sync
5. confirm dashboards and alerts

Capture timings and friction points; update docs where users get stuck.

### 9) Definition of done for Phase 9

- Dashboard pack exists and is reusable.
- Smoke tests are automated in pipeline and fail correctly on bad release.
- README explains the full delivery path for a new engineer.
- Release verification checklist and troubleshooting links are available.
- Team can execute one full release without tribal knowledge.

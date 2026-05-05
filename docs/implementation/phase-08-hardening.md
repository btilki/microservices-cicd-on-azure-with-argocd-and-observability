# Phase 8 — Hardening

[← Phase 7](phase-07-prod-environment.md) · [Index](README.md) · [Phase 9 →](phase-09-polish.md)

**Goal:** NetworkPolicies, PSS, quotas, CI image gate, cost alert.

---

## Implementation

> **Use:** Editor + `kubectl apply`, **Helm** (chart hooks optional), **Azure DevOps** (fail Trivy on HIGH/CRITICAL), **Azure Portal** → **Cost Management** → **Budgets**.

1. **NetworkPolicies** — Add YAML under `policies/` (or embed in charts); apply per namespace; default deny then allow lists between required services.

2. **Pod Security** — Label namespaces: `pod-security.kubernetes.io/enforce` = `baseline` (dev), `restricted` (stage/prod). Fix workloads that fail admission.

3. **Quotas** — `ResourceQuota` + `LimitRange` per env namespace (`kubectl` or GitOps).

4. **Trivy** — In CI templates, set exit code on HIGH/CRITICAL; run a known-bad image to verify pipeline fails.

5. **Budget** — Portal: create **Budget** on subscription or RG scope; **alert** at 80% (email/action group).

---

## Detailed step-by-step guide (practical)

This phase makes your platform safer by enforcing least privilege at runtime, build time, and cost controls.

### 0) Pre-checks and safety approach

1. Confirm cluster + namespaces:
   ```bash
   kubectl get ns
   ```
2. Confirm current policies (if any):
   ```bash
   kubectl get networkpolicy -A
   kubectl get resourcequota -A
   kubectl get limitrange -A
   ```
3. Apply hardening in this order to avoid outages:
   1) observe traffic
   2) add allow rules
   3) enable default deny
   4) enforce Pod Security
   5) tighten CI gates

Do rollout first in `dev`, then `stage`, then `prod`.

### 1) NetworkPolicies (default deny + explicit allow)

1. Create policy folder convention (example):
   - `policies/network/dev/`
   - `policies/network/stage/`
   - `policies/network/prod/`
2. Add baseline policies per namespace:
   - default deny ingress
   - default deny egress
3. Add allow-list policies for required paths only:
   - frontend -> checkout/cart/productcatalog
   - service -> redis (only needed callers)
   - namespace -> kube-dns (`kube-system`)
   - ingress-nginx -> app backends
4. Apply in `dev` first:
   ```bash
   kubectl apply -f policies/network/dev/
   ```
5. Validate app still works before promoting policy to stage/prod.

Verification commands:
```bash
kubectl get networkpolicy -n dev
kubectl describe networkpolicy -n dev
```

### 2) Validate traffic with a debug pod

1. Start temporary pod:
   ```bash
   kubectl run net-debug -n dev --rm -it --image=curlimages/curl -- sh
   ```
2. Test expected allowed traffic:
   ```bash
   curl -sv http://frontend:80
   curl -sv http://checkoutservice:5050/health
   ```
3. Test expected denied traffic (should fail/time out).

Do this for stage/prod before and after enforcement changes.

### 3) Pod Security Standards (PSS) labels

Apply namespace labels:

- dev:
  - `pod-security.kubernetes.io/enforce=baseline`
- stage/prod:
  - `pod-security.kubernetes.io/enforce=restricted`

Commands:
```bash
kubectl label ns dev pod-security.kubernetes.io/enforce=baseline --overwrite
kubectl label ns stage pod-security.kubernetes.io/enforce=restricted --overwrite
kubectl label ns prod pod-security.kubernetes.io/enforce=restricted --overwrite
```

Recommended warning/audit labels too:
```bash
kubectl label ns dev pod-security.kubernetes.io/audit=baseline pod-security.kubernetes.io/warn=baseline --overwrite
kubectl label ns stage pod-security.kubernetes.io/audit=restricted pod-security.kubernetes.io/warn=restricted --overwrite
kubectl label ns prod pod-security.kubernetes.io/audit=restricted pod-security.kubernetes.io/warn=restricted --overwrite
```

If workloads fail admission, fix securityContext in charts:
- `runAsNonRoot: true`
- `allowPrivilegeEscalation: false`
- drop Linux capabilities
- read-only root filesystem when possible

### 4) ResourceQuota and LimitRange per env

Create/apply per namespace manifests:
- `ResourceQuota`: caps total requests/limits, object counts
- `LimitRange`: default requests/limits per container/pod

Apply:
```bash
kubectl apply -f policies/quotas/dev/
kubectl apply -f policies/quotas/stage/
kubectl apply -f policies/quotas/prod/
```

Verify:
```bash
kubectl get resourcequota,limitrange -n dev
kubectl get resourcequota,limitrange -n stage
kubectl get resourcequota,limitrange -n prod
```

### 5) CI vulnerability gate with Trivy

For each service CI pipeline/template:
1. Run Trivy image scan after build.
2. Fail pipeline on HIGH/CRITICAL findings (exit code non-zero).
3. Optionally allowlist accepted findings with expiry.

Validation test:
- Run pipeline on a known vulnerable image/package.
- Confirm pipeline fails before image promotion.

Keep gate policy explicit in pipeline docs.

### 6) Admission policy extension (optional but recommended)

If you want stronger guardrails beyond PSS:
- add Kyverno or Gatekeeper policies for:
  - required labels/annotations
  - disallow `latest` tag
  - required resource requests/limits
  - block privileged containers

Roll out in audit mode first, then enforce.

### 7) Azure cost budget + alerts

In Azure Portal:
1. Scope budget to subscription or resource group(s).
2. Create monthly budget.
3. Add alert thresholds (recommended: 50%, 80%, 100%).
4. Route notifications to email/action group.

For this project, minimum threshold:
- alert at 80% to catch runaway spend before month end.

### 8) Hardening runbook updates

Add or update runbooks in `docs/runbooks/`:
- network policy lockout recovery
- pod security admission failures
- CI vulnerability gate break/fix process
- budget alert response playbook

Each runbook should include owner, severity, and first 15-minute actions.

### 9) Rollout strategy across environments

Promote hardening changes like app changes:
1. apply and test in dev
2. promote to stage via PR
3. promote to prod with approvals

Never apply new deny policies directly to prod first.

### 10) Definition of done for Phase 8

- Default-deny network posture is active with explicit allow rules.
- PSS is enforced (`baseline` dev, `restricted` stage/prod).
- Quotas and limits are active in all env namespaces.
- CI fails on HIGH/CRITICAL image vulnerabilities.
- Azure budget alerts are configured and recipients confirmed.

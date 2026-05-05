# Phase 5 — Fan-out remaining services

[← Phase 4](phase-04-promotion-pipeline.md) · [Index](README.md) · [Phase 6 →](phase-06-stage-environment.md)

**Goal:** All boutique services (+ Redis) running in **dev**; only `frontend` has Ingress.

---

## Implementation

> **Use:** Copy-paste from `frontend` pattern: editor, **Helm**, **Azure DevOps** (clone pipeline per service or parameterized template), **Argo CD** (many Applications), terminal for quick checks.

1. **Service list** — `cartservice`, `productcatalogservice`, `currencyservice`, `paymentservice`, `shippingservice`, `emailservice`, `checkoutservice`, `recommendationservice`, `adservice`, `redis-cart`, `loadgenerator` (disable in prod later via values).

2. **Per service:** `charts/<name>/`, `gitops/apps/dev/<name>.yaml`, `gitops/envs/dev/values-<name>.yaml`, `pipelines/ci/<name>.yaml` (or shared template with matrix).

3. **Build templates** — Reuse `pipelines/templates/` for Go, .NET, Node, Python, Java as needed.

4. **Argo CD** — Register each child Application under `gitops/bootstrap/applications/`.

5. **Smoke** — `kubectl get pods -n dev`; port-forward or internal curl between services if something fails.

---

## Detailed step-by-step guide (practical)

This phase scales your Phase 3 pattern from one service (`frontend`) to all remaining services in `dev`.

### 0) Decide service rollout order

Do not fan out all services at once. Use this safe order:

1. data/cache: `redis-cart`
2. core backends: `productcatalogservice`, `currencyservice`, `cartservice`
3. business flow: `shippingservice`, `paymentservice`, `emailservice`, `checkoutservice`
4. recommendation/ads: `recommendationservice`, `adservice`
5. traffic generator: `loadgenerator` (optional in dev)

Deploy 1-2 services at a time and verify before continuing.

### 1) Prepare one reusable service template set

Use `frontend` artifacts as your source pattern and template these files:

- `charts/<service>/`
- `gitops/apps/dev/<service>.yaml`
- `gitops/envs/dev/values-<service>.yaml`
- `pipelines/ci/<service>.yml` (or a single matrix/template pipeline)

Minimum chart templates per service:
- `Deployment`
- `Service`
- `ServiceAccount`

Only `frontend` should have `Ingress` in this phase.

### 2) Define per-service configuration contract

For each service, decide and document in values:

- container port
- service port
- environment variables
- upstream dependency endpoints (Kubernetes service DNS names)
- resource requests/limits
- readiness/liveness probes
- `nodeSelector` and `tolerations` for dev scheduling

If a service needs secrets:
- mount via CSI + SecretProviderClass, or
- use Kubernetes Secret (less preferred for this project)

### 3) Add first batch of non-frontend services

Start with `redis-cart`, `productcatalogservice`, `currencyservice`, `cartservice`.

For each service:
1. add `charts/<service>`
2. add `gitops/envs/dev/values-<service>.yaml` with:
   - `image.repository` (dev ACR)
   - `image.digest` placeholder
3. add `gitops/apps/dev/<service>.yaml` (Argo CD Application)
4. register child app under:
   - `gitops/bootstrap/applications/`

Then commit and push.

### 4) Set up CI for each service image + digest update

Choose one approach:

- one pipeline per service (`pipelines/ci/<service>.yml`), or
- one reusable template with parameters (`serviceName`, `dockerContext`, `valuesFile`)

Each CI run should:
1. build/test service
2. scan image (Trivy)
3. push image to dev ACR
4. get pushed digest
5. open PR updating `gitops/envs/dev/values-<service>.yaml` with that digest

Rule: GitOps values must always use digest (`sha256:`), not mutable tags only.

### 5) Merge GitOps PRs in small batches

For each batch:
1. merge digest PRs
2. watch Argo CD sync
3. verify pods in `dev` namespace

Commands:
```bash
kubectl get applications -n argocd
kubectl get pods -n dev
kubectl get svc -n dev
```

If one service fails, stop adding new services and fix before continuing.

### 6) Verify internal service-to-service traffic

Use temporary debug pod:
```bash
kubectl run net-debug -n dev --rm -it --image=curlimages/curl -- sh
```

From inside debug shell, test cluster DNS/service access:
```bash
curl -sv http://productcatalogservice:3550/health
curl -sv http://cartservice:7070/health
```

Adjust host/port/path per service implementation.

### 7) Add business-flow services batch

Add and verify:
- `shippingservice`
- `paymentservice`
- `emailservice`
- `checkoutservice`

Then run end-to-end from `frontend`:
- browse app
- add to cart
- checkout flow

Check logs when failures occur:
```bash
kubectl logs deploy/checkoutservice -n dev --tail=200
kubectl logs deploy/cartservice -n dev --tail=200
```

### 8) Add recommendation + ads + optional loadgenerator

Deploy:
- `recommendationservice`
- `adservice`
- `loadgenerator` (dev only)

For `loadgenerator`, keep a toggle in values for later stages:
- `enabled: true` in dev
- set `enabled: false` in stage/prod later

### 9) Resource and reliability tuning

After all services run:

1. detect restarts/OOM:
   ```bash
   kubectl get pods -n dev
   kubectl top pods -n dev
   ```
2. tune CPU/memory requests/limits
3. ensure probes are not too aggressive
4. verify no CrashLoopBackOff remains

### 10) Definition of done for Phase 5

- All target services are deployed via Argo CD in `dev`.
- Every service image comes from dev ACR and is pinned by digest.
- `frontend` works end-to-end with backend dependencies.
- Only `frontend` is publicly exposed by Ingress.
- `loadgenerator` is clearly marked as dev-only in values.

# Phase 5 — Fan-out remaining services

[← Phase 4](phase-04-promotion-pipeline.md) · [Index](README.md) · [Phase 6 →](phase-06-stage-environment.md)

**Goal:** Complete **v1** application coverage in `dev`: all **owned** services use this repo’s CI/GitOps; the **rest of the boutique path** uses **upstream Google** images.

## v1 scope (explicit)

- **Owned here (v1 = 5 workloads: 4 services + Redis):** `frontend`, `cartservice`, `currencyservice`, `productcatalogservice`, `redis-cart` — each has a chart under `charts/`; values under `gitops/envs/*/`, and CI under `pipelines/ci/` where applicable.
- **Upstream Google (5 + loadgen):** `checkoutservice`, `emailservice`, `paymentservice`, `shippingservice`, `recommendationservice`, and `loadgenerator` — run from published microservices-demo images (not promoted through this repo’s service pipelines). **`adservice`** is optional / later for v1.

## Process (brief)

For **owned** services, repeat the frontend pattern: chart → env values → Argo app → CI digest PR. Deploy **upstream** workloads from Google’s manifests or Helm when you need a full end-to-end demo. Roll out in small batches and validate service-to-service traffic.

**Dev baseline:** `gitops/platform/dev/` (Application **`platform-dev`**) applies `namespace.yaml` and **`networkpolicy-baseline.yaml`** (same ingress posture as stage/prod: in-namespace + `ingress-nginx`).

## Step-by-step

### Prerequisites

1. Confirm Phase 4 promotion flow works for `frontend`.
2. Confirm `dev` namespace and Argo root app are healthy:
   ```bash
   kubectl get ns dev
   kubectl get applications -n argocd
   ```

### Azure

3. Confirm dev ACR is reachable and contains existing promoted images:
   ```bash
   az acr list -o table
   az acr repository list --name acrboutiquedevweu -o table
   ```

### Azure DevOps

4. For each **owned** service, create or verify CI pipeline:
   - `pipelines/ci/<service>.yml` (or shared template reference)
   - stages: build -> scan -> push dev ACR -> update GitOps digest -> open PR
5. Validate service connections and secrets:
   - ACR push permission on dev ACR
   - `GITHUB_TOKEN` (or equivalent) for PR creation

### GitHub / GitOps

6. Define rollout order for **owned** services (recommended):
   - `redis-cart`
   - `productcatalogservice`, `currencyservice`, `cartservice`
7. Deploy **upstream** slice when needed for full journeys:
   - `checkoutservice`, `emailservice`, `paymentservice`, `shippingservice`, `recommendationservice`
   - `loadgenerator` (non-prod only)
   - omit `adservice` in v1 unless needed
8. For each **owned** service, maintain repo structure:
   - Helm chart: `charts/<service>/`
   - Argo app: `gitops/apps/dev/<service>-dev.yaml`
   - values: `gitops/envs/dev/values-<service>.yaml`
9. Ensure each **owned** service is registered in `gitops/bootstrap/applications/`.
10. Run CI and review/merge digest PRs in small batches (2-3 services per wave).

### Argo CD / Kubernetes validation

11. After each PR batch merge, verify deployment health:
    ```bash
    kubectl get applications -n argocd
    kubectl get pods -n dev
    kubectl get svc -n dev
    ```
12. Validate service-to-service traffic with a debug pod when needed.
13. Keep only `frontend` (or ingress entrypoint) exposed publicly in this phase.
14. Keep `loadgenerator` on upstream images and disabled in prod.

### Troubleshooting

- PR not created:
  - check Azure DevOps token permissions and branch protection requirements.
- Pods fail with image pull errors:
  - verify repository path and digest in `gitops/envs/dev/values-<service>.yaml`.
- Argo app stays OutOfSync:
  - verify chart path and values file reference in `gitops/apps/dev/<service>-dev.yaml`.

## Done checklist

- Core services are deployed and healthy in `dev`.
- Images are pinned by digest in GitOps values.
- End-to-end storefront flow works in `dev`.

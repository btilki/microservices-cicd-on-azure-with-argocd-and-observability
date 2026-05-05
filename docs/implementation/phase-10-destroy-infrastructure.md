# Phase 10 — Destroy infrastructure (teardown)

[← Phase 9](phase-09-polish.md) · [Index](README.md)

**Goal:** Remove Azure resources created by this repo’s Terraform stacks in a safe order, without leaving orphaned dependencies or losing control of state mid-way.

---

## Before you destroy

1. **Subscription & intent** — Confirm you are on the correct Azure subscription (`az account show`). Teardown is destructive.

2. **GitOps / workloads (optional but cleaner)** — If Argo CD or Helm releases are still running, uninstall applications or delete the cluster’s workloads first so load balancers, PVCs, and finalizers do not block deletes. This repo’s Terraform does not manage those app resources.

3. **DNS (optional)** — If you delegated your domain to Azure name servers in Phase 1, revert or update **NS** records at your registrar when the zone is gone, or you will have broken DNS.

---

## Implementation

> **Use:** Terminal (`az`, `terraform`) from the same machine where you applied. Use the same `backend.hcl` and `terraform.tfvars` (or equivalent) you used for `apply`.

**Destroy order (reverse of apply):** `dev` / `stage` / `prod` (any order among the three) → `shared` → `bootstrap` last.

`bootstrap` holds the remote state storage; destroying it before the other stacks makes later `terraform destroy` in those directories impossible without recovery.

### 1. Environment stacks (ACR, Key Vault per env)

For each of **dev**, **stage**, **prod**:

```bash
cd infra/terraform/envs/dev   # then stage, prod
terraform init -backend-config=backend.hcl
terraform destroy
```

Repeat until all three complete without errors. If destroy fails (dependency, lock, or API timeout), fix the reported issue and run `terraform destroy` again in the same directory.

### 2. Shared stack (VNet, AKS, DNS zone, public IP, …)

```bash
cd infra/terraform/envs/shared
terraform init -backend-config=backend.hcl
terraform destroy
```

This removes the cluster and shared networking; it can take several minutes.

### 3. Bootstrap (Terraform state storage)

Only after **all** other stacks that use the remote backend are destroyed (or you accept that you cannot run Terraform against them anymore):

```bash
cd infra/terraform/envs/bootstrap
terraform init
terraform destroy
```

This removes the resource group and storage account used for Terraform state blobs (and the containers inside).

---

## After destroy

- **Local files** — You may delete local copies of `backend.hcl`, `terraform.tfvars`, and `.terraform/` under each env if you no longer need them; they are usually gitignored or secrets.

- **Portal** — Spot-check **Resource groups** in Azure Portal that names matching this project (`rg-boutique-*`) are gone or empty.

- **Soft-delete** — Key Vault and some resources may use Azure soft-delete; if Portal still shows recoverable vaults, purge them only if your organization allows it (see Azure docs for Key Vault purge).

---


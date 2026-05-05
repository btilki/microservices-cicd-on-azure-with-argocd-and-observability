# Phase 1 — Terraform foundation

[← Phase 0](phase-00-repo-scaffolding.md) · [Index](README.md) · [Phase 2 →](phase-02-cluster-bootstrap.md)

**Goal:** State storage, shared Azure stack (VNet, AKS, DNS zone, …), three env stacks (ACR + Key Vault each), `kubectl` works.

---

## Implementation

> **Use:** Terminal (`az`, `terraform`, `kubectl`), **Azure Portal** (optional checks), domain registrar for NS delegation. Install Azure CLI and Terraform if missing.

1. **See Azure account, login & subscription**
   ```bash
   az account show
   ```
   
   ```bash
   az login
   az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"
   ```

2. **Unique names** — If defaults are taken, edit ACR names in `infra/terraform/envs/dev|stage|prod/main.tf` and Key Vault names in the same files (KV max 24 chars, globally unique).

3. **Bootstrap state (once)**
   ```bash
   cd infra/terraform/envs/bootstrap
   cp terraform.tfvars.example terraform.tfvars
   # terraform.tfvars: set storage_account_name (globally unique, lowercase, 3–24 chars)
   terraform init && terraform apply
   ```
   Note outputs: resource group name, storage account name, container names.

4. **Shared stack — backend file**
   ```bash
   cd ../shared
   cp backend.hcl.example backend.hcl
   ```
   Edit `backend.hcl` with bootstrap outputs. Optional: add `terraform.tfvars` for `kubernetes_version`, `dns_zone_name`, `api_server_authorized_ip_ranges` (your public IP CIDRs).

5. **Shared stack — apply**
   ```bash
   terraform init -backend-config=backend.hcl
   terraform apply
   ```
   Save outputs: name servers, ingress public IP, AKS name. Sensitive: `terraform output -raw kube_config_raw` when needed.

6. **DNS** — At your registrar for the zone (e.g. `biroltilki.art`), set **NS** records to the Azure name servers from Terraform output. Wait for propagation.

7. **Env stacks (`dev`, `stage`, `prod`)** — For each:
   ```bash
   cd infra/terraform/envs/dev   # then stage, prod
   cp backend.hcl.example backend.hcl
   cp terraform.tfvars.example terraform.tfvars
   ```
   Fill `backend.hcl` and `terraform.tfvars` (state storage + shared state pointers). Then:
   ```bash
   terraform init -backend-config=backend.hcl
   terraform apply
   ```

8. **Kubeconfig**
   ```bash
   cd ../shared
   terraform output -raw kube_config_raw > ~/.kube/config-boutique
   export KUBECONFIG=~/.kube/config-boutique
   kubectl get nodes
   ```

**Apply order:** `bootstrap` → `shared` → `dev` / `stage` / `prod`.

**Private ACR/KV:** If images or Key Vault are private-endpoint-only, pushing images or running Terraform against KV from your laptop may require VPN/Bastion/self-hosted agent in the VNet.

---

## Detailed step-by-step guide (practical)

Use this runbook when executing Terraform foundation from scratch.

### 0) Tooling and account checks

1. Verify tools:
   ```bash
   az --version
   terraform --version
   kubectl version --client
   ```
2. Login and choose correct subscription:
   ```bash
   az login
   az account list -o table
   az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"
   az account show -o table
   ```
3. Confirm you are at repo root before running phase commands:
   ```bash
   pwd
   git status
   ```

### 1) Plan unique resource names before apply

Azure naming constraints you must satisfy:
- Storage account: lowercase, 3-24 chars, globally unique
- ACR name: alphanumeric, globally unique
- Key Vault name: 3-24 chars, globally unique

If defaults clash, edit:
- `infra/terraform/envs/dev/main.tf`
- `infra/terraform/envs/stage/main.tf`
- `infra/terraform/envs/prod/main.tf`

Tip: keep a naming map in your notes before changing files.

### 2) Bootstrap remote state (must be first)

1. Go to bootstrap env:
   ```bash
   cd infra/terraform/envs/bootstrap
   ```
2. Create tfvars file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
3. Edit `terraform.tfvars`:
   - set `storage_account_name` to a unique value
4. Validate and apply:
   ```bash
   terraform init
   terraform validate
   terraform plan
   terraform apply
   ```
5. Capture outputs:
   ```bash
   terraform output
   ```

Record these values safely:
- state resource group
- state storage account
- container names (`tfstate-shared`, `tfstate-dev`, `tfstate-stage`, `tfstate-prod`)

### 3) Configure and apply shared stack

1. Move to shared env:
   ```bash
   cd ../shared
   ```
2. Create backend config:
   ```bash
   cp backend.hcl.example backend.hcl
   ```
3. Edit `backend.hcl` using bootstrap outputs.
4. Optional: create `terraform.tfvars` for:
   - `kubernetes_version` (or leave null/default behavior)
   - `dns_zone_name`
   - `api_server_authorized_ip_ranges`
5. Run:
   ```bash
   terraform init -backend-config=backend.hcl
   terraform validate
   terraform plan
   terraform apply
   ```
6. Save key outputs:
   ```bash
   terraform output
   terraform output ingress_public_ip
   terraform output dns_zone_name_servers
   ```

### 4) Delegate DNS zone at registrar

1. Copy Azure NS values from shared outputs.
2. At your registrar, update NS records for your domain to those Azure nameservers.
3. Wait for propagation (can take minutes to hours).
4. Verify:
   ```bash
   nslookup -type=ns <your-domain>
   ```

### 5) Configure and apply environment stacks

Apply `dev`, `stage`, `prod` one by one (recommended order: dev -> stage -> prod).

For each env:

1. Enter env folder:
   ```bash
   cd infra/terraform/envs/dev   # repeat for stage and prod
   ```
2. Create config files:
   ```bash
   cp backend.hcl.example backend.hcl
   cp terraform.tfvars.example terraform.tfvars
   ```
3. Edit `backend.hcl`:
   - same state RG/storage account as bootstrap
   - env-specific container/key (`tfstate-dev`, etc.)
4. Edit `terraform.tfvars`:
   - pointers to shared state backend values
5. Run:
   ```bash
   terraform init -backend-config=backend.hcl
   terraform validate
   terraform plan
   terraform apply
   ```

Repeat for `stage` and `prod`.

### 6) Build kubeconfig and validate cluster access

1. Go back to shared:
   ```bash
   cd ../shared
   ```
2. Export kubeconfig:
   ```bash
   terraform output -raw kube_config_raw > ~/.kube/config-boutique
   export KUBECONFIG=~/.kube/config-boutique
   ```
3. Validate:
   ```bash
   kubectl get nodes -o wide
   kubectl get ns
   ```

### 7) Verify Azure resources and Terraform state

Check expected resource groups:
```bash
az group list --query "[?contains(name, 'rg-boutique')].name" -o table
```

Check state containers/blobs:
```bash
az storage container list \
  --account-name <STATE_STORAGE_ACCOUNT_NAME> \
  --auth-mode login -o table
```

Expected:
- shared RG + env RGs exist
- ACR + Key Vault per env exist
- state blobs created in all containers after apply

### 8) Common failure fixes

- **Unsupported Terraform argument errors**
  - likely AzureRM provider version mismatch; align field names with pinned provider.
- **AKS version not supported**
  - use supported regional version or allow region default.
- **vCPU quota errors**
  - lower node pool size/sku or request quota increase.
- **ACR public access disabled error**
  - private-only ACR requires Premium SKU.
- **DNS not resolving**
  - verify registrar NS delegation and propagation time.

### 9) Definition of done for Phase 1

- Bootstrap, shared, dev, stage, and prod applies succeed.
- Remote state is working for all stacks.
- `kubectl get nodes` works against created AKS cluster.
- Domain NS delegation points to Azure DNS nameservers.
- Core resources exist in Azure and match Terraform state.

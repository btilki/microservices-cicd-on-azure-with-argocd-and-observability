# Phase 0 — Repo scaffolding

[← Index](README.md) · [Phase 1 →](phase-01-terraform-foundation.md)

**Goal:** Remote Git repo configured; branch rules and ownership set.

---

## Implementation

> **Use:** Git (terminal), GitHub or **Azure DevOps** (Repos → **Branches** / **Policies**), editor for `CODEOWNERS`.

1. **Push this repo** to your Git host (new empty repo, then `git remote add origin …`, `git push -u origin main`).
2. **Edit `CODEOWNERS`** at repo root — replace placeholder handles with real users or teams.
3. **Protect `main`**
   - *GitHub:* Repo → **Settings** → **Branches** → Add rule for `main` (require PR, reviewers, optional status checks).
   - *Azure DevOps:* **Project settings** → **Repositories** → your repo → **Policies** → branch `main` (minimum reviewers; add build policy when pipelines exist).
4. **Optional:** Extra policy for path `gitops/envs/prod/**` (more reviewers).

---

## Detailed step-by-step guide (practical)

This phase sets the collaboration guardrails before any infrastructure or app work begins.

### 0) Pre-checks

1. Confirm you are inside the correct local repo:
   ```bash
   pwd
   git status
   ```
2. Ensure your default branch is `main`:
   ```bash
   git branch --show-current
   ```
3. Verify you can authenticate to your Git host (GitHub or Azure DevOps).

### 1) Create remote repository

Create an empty repository in your Git host UI:
- name: your project repo name
- initialize with README/gitignore: **No** (because local repo already exists)
- visibility: private/public based on your needs

Copy the remote URL (`https` or `ssh`).

### 2) Connect local repo to remote and push

From local repo root:
```bash
git remote -v
git remote add origin <REMOTE_URL>
git push -u origin main
```

If `origin` already exists but points wrong:
```bash
git remote set-url origin <REMOTE_URL>
git push -u origin main
```

Verification:
```bash
git remote -v
git branch -vv
```

### 3) Configure CODEOWNERS

1. Open `CODEOWNERS` at repo root.
2. Replace placeholder users/teams with real identities.
3. Add ownership by path where useful, for example:
   - platform/infra paths
   - `gitops/envs/prod/**` for stricter reviewers
   - pipeline files
4. Commit and push CODEOWNERS update.

Tip: keep ownership explicit and minimal; avoid one giant wildcard owner for all critical paths.

### 4) Protect `main` branch (GitHub)

If repository is on GitHub:

1. Go to: `Settings -> Branches -> Add rule` for `main`.
2. Enable:
   - Require pull request before merging
   - Required approvals (at least 1, preferably 2 for shared repos)
   - Dismiss stale approvals on new commits
   - Require conversation resolution
   - Block force pushes
   - Block branch deletion
3. Later, when CI exists, enable required status checks.

### 5) Protect `main` branch (Azure DevOps)

If repository is Azure Repos:

1. Go to: `Project settings -> Repositories -> Branches -> main -> Branch policies`.
2. Configure:
   - minimum reviewers
   - comment resolution required
   - linked work item policy (optional)
   - build validation policy (after pipeline exists)

If your source of truth is GitHub, keep primary branch protection there and use Azure DevOps mainly for pipelines/approvals.

### 6) Add stricter policy for production GitOps paths

For path:
- `gitops/envs/prod/**`

Set stronger controls than regular code:
- more reviewers
- no self-approval
- optional required reviewer group (platform/SRE)

Purpose: reduce accidental production config changes.

### 7) Validate protection behavior

Run a quick test:
1. create a small branch
2. open PR to `main`
3. ensure direct push to `main` is blocked
4. ensure required reviews/checks appear

If checks are missing now, that is expected until CI pipeline is connected in later phases.

### 8) Document team workflow rules

Add a short section in README or contributing docs:
- branch naming (`feature/*`, `fix/*`)
- PR expectations
- who can approve prod GitOps changes
- merge strategy (squash/rebase/merge)

This avoids process confusion as team grows.

### 9) Definition of done for Phase 0

- Local repo is connected to remote and `main` is pushed.
- `CODEOWNERS` uses real users/teams.
- `main` is protected against direct risky changes.
- prod GitOps paths have stricter reviewer policy.
- Team workflow rules are documented and discoverable.

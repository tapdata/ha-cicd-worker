# Multi-Repo Multi-Tenant Mode: Setup Guide

Each team (tenant) owns an independent GitHub repository for their TapData configuration files. A shared `ha-cicd-worker` repository serves as the unified deployment engine for all tenants.

```
ha-cicd-worker      ← Shared deployment engine (centrally maintained)
├── patient-team    ← Tenant repo (patient project config files)
└── case-team       ← Tenant repo (case project config files)
```

---

## Part 1: Resources to Request from Your IT/Ops Team

> These items require internal approval processes and should be arranged **before go-live**. Please confirm all items below are in place before proceeding.

### 1.1 GitHub Organization

Provide a GitHub Organization under which all repositories will be created. Note the organization name — it will be used throughout this setup (referred to as `{org}`).

- If an Organization already exists, confirm you have **Owner** access to it
- If not, request one to be created

### 1.2 GitHub User Accounts

> Customer team members already have their own GitHub accounts. Only the following TapData-side accounts need to be requested and added to the Organization.

| Account | Quantity | Organization Role | Repository Access | Purpose |
|---|---|---|---|---|
| TapData implementation engineer | 1–2 | **Owner** | All repositories (admin) | Push code, configure environments, manage secrets, install Runner |

**Note on deployment approvers**: Approvers are customer-side personnel who review and approve each deployment on the GitHub Actions page. They use their existing GitHub accounts — just add them to the Organization as **Member** and assign them as reviewers in the `deploy` Environment (done in Part 2, no IT request needed).

### 1.3 GitHub Repositories

Request the following **private** repositories to be created under `{org}`:

| Repository Name | Purpose |
|---|---|
| `ha-cicd-worker` | Shared deployment engine — holds all CI/CD scripts and workflows |
| `{project}-team` (one per team) | Tenant repository — holds TapData export files for that team, e.g. `patient-team`, `case-team` |

### 1.4 Self-hosted Runner Machine

Request a server/VM to act as the GitHub Actions Runner. This machine will execute all deployment jobs.

**Requirements:**

| Item | Requirement |
|---|---|
| OS | Linux (Ubuntu 20.04+ recommended) |
| Network access | Must reach the GitHub instance (outbound HTTPS) |
| Network access | Must reach the TapData server (host + port) |
| Disk | ≥ 20 GB free |
| User | A dedicated service account (non-root) is recommended |

> Only **one** Runner machine is needed — it handles deployments for all tenant repositories.

---

## Part 2: Configuration Done by Our Team

> Once we have the GitHub accounts and repositories, the following can be set up and adjusted at any time — no IT approval required.

### 2.1 Push Code to the Worker Repository

Push the `ha-cicd-worker` project code to the `main` branch of the `ha-cicd-worker` repository.

> Before pushing, replace all occurrences of the default organization name `tapdata` with the actual `{org}` name in the workflow files:
> - `ha-cicd-worker/.github/workflows/tapdata-deploy.yml`
> - Each tenant repo's `.github/workflows/tapdata-deploy.yml`

### 2.2 Install the Self-hosted Runner

> **Why Organization-level?** Tenant workflows call the worker's reusable workflow via `workflow_call`. GitHub runs those jobs in the context of the **caller** repository (e.g., `patient-team`), not the worker. A repository-level runner registered only to `ha-cicd-worker` is invisible to tenant repositories. Registering at the Organization level makes the runner available to all repositories under `{org}`.

1. Go to **`{org}` Organization** → **Settings** → **Actions** → **Runners** → **New self-hosted runner**
2. Follow the on-screen instructions to register the Runner on the target machine
3. During registration, add the custom label **`tapdata`** (in addition to the default `self-hosted` label):
   ```
   # When the setup script prompts for extra labels:
   Enter any additional labels (comma separated): tapdata
   ```
4. Verify the Runner status shows **Idle** in the Organization's runner list

> **Do not** register the runner under `ha-cicd-worker` → Settings → Actions → Runners (repository-level). A repository-level runner only accepts jobs from that one repository.

### 2.3 Configure Environments in the Worker Repository

Go to `ha-cicd-worker` → **Settings** → **Environments** and create:

| Environment | Purpose |
|---|---|
| `dev` | Development |
| `sit` | Testing |
| `lpt` | Performance testing |
| `aat` | Acceptance testing |
| `prod` | Production |

> These environments are used for deployment **protection rules** (e.g., required reviewers, wait timers). Do not configure `TAPDATA_URL` here — in `workflow_call` mode the worker's environment variables are not accessible to jobs. See section 2.5 for where to configure variables.

### 2.4 Configure Each Tenant Repository

For each tenant repository (e.g., `patient-team`):

**a. Create Environments**

Go to the tenant repository → **Settings** → **Environments**:

| Environment | Requires Reviewers |
|---|---|
| `dev` | No |
| `sit` | No |
| `lpt` | No |
| `deploy` | **Yes** — add the designated approvers |

> The `deploy` Environment is the manual approval gate. Every deployment pauses here until an approver clicks **Review deployments** on the GitHub Actions page.

**b. Add the Workflow File**

Create `.github/workflows/tapdata-deploy.yml` in the tenant repository (replace `{org}` and `{project}` with actual values):

```yaml
name: TapData Deploy

on:
  push:
    branches: [main]
    paths:
      - '{project}_tapdata_export/**'
    tags:
      - '{project}-*'
  workflow_dispatch:
    inputs:
      target_env:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - dev
          - sit
          - lpt

jobs:
  deploy:
    uses: {org}/ha-cicd-worker/.github/workflows/tapdata-deploy.yml@main
    with:
      project: {project}
      target_env: ${{ inputs.target_env || '' }}
      caller_repo: ${{ github.repository }}
      caller_sha: ${{ github.sha }}
      caller_event: ${{ github.event_name }}
      caller_ref: ${{ github.ref }}
    secrets: inherit
```

**c. Place TapData Export Files**

Add the exported TapData JSON files into the tenant repository:

```
{project}_tapdata_export/
├── Connection/
├── Task/
├── API/
├── User/
└── GroupInfo.json
```

### 2.5 Configure Secrets and Variables

> **Why this split?** When a tenant workflow calls the worker via `workflow_call`, GitHub resolves `vars.*` and `secrets.*` from the **caller (tenant) repository**, not from `ha-cicd-worker`. Secrets and variables stored only in `ha-cicd-worker` are invisible to tenant jobs. This determines exactly where each item must be placed.

#### Organization level

Configure once at Organization → **Settings** → **Secrets and variables** → **Actions**. Automatically inherited by all tenant repositories.

| Type | Name | Description |
|---|---|---|
| Secret | `GH_DEPLOY_TOKEN` | Fine-grained personal access token with read access to all repositories under `{org}` |
| Secret | `DEV_TAPDATA_ACCESS_CODE` | TapData access credentials for the `dev` environment |
| Secret | `SIT_TAPDATA_ACCESS_CODE` | TapData access credentials for the `sit` environment |
| Secret | `LPT_TAPDATA_ACCESS_CODE` | TapData access credentials for the `lpt` environment |
| Secret | `AAT_TAPDATA_ACCESS_CODE` | TapData access credentials for the `aat` environment |
| Secret | `PROD_TAPDATA_ACCESS_CODE` | TapData access credentials for the `prod` environment |
| Variable | `DEV_TAPDATA_URL` | TapData server address for the `dev` environment, e.g. `http://10.0.0.1:3030` |
| Variable | `SIT_TAPDATA_URL` | TapData server address for the `sit` environment |
| Variable | `LPT_TAPDATA_URL` | TapData server address for the `lpt` environment |
| Variable | `AAT_TAPDATA_URL` | TapData server address for the `aat` environment |
| Variable | `PROD_TAPDATA_URL` | TapData server address for the `prod` environment |

#### Tenant repository — repository-level credentials

For each tenant repository, go to repo → **Settings** → **Secrets and variables** → **Actions**.

| Type | Name | Description |
|---|---|---|
| Secret | Database passwords | Named by connection (see rules below) |
| Variable | Database URLs / Users | Named by connection (see rules below) |

**Database credential naming rules** (`{NAME}` = TapData connection name, uppercased):

| Priority | Type | Name | Example |
|---|---|---|---|
| 1 (highest) | Secret | `{NAME}_URI` | `MYSQL_PROD_URI` = `mysql://user:pass@host:3306/db` |
| 2 | Variable + Secret | `{NAME}_URL` / `{NAME}_USER` / `{NAME}_PASSWORD` | Split credentials |
| 3 | Variable + Secret | `{PREFIX}_URL` / `{PREFIX}_USER` / `{PREFIX}_PASSWORD` | Shared by prefix group |
| 4 (fallback) | Variable + Secret | `DEFAULT_URL` / `DEFAULT_USER` / `DEFAULT_PASSWORD` | Global default |

---

## Checklist for Adding a New Tenant

**IT/Ops to provide (Part 1):**
- [ ] Private repository `{project}-team` created under `{org}`
- [ ] CI/CD admin account has write access to the new repository

**Our team to configure (Part 2):**
- [ ] Create a project named `{project}` on the TapData platform
- [ ] Copy `.github/workflows/tapdata-deploy.yml` from an existing tenant repo into the new tenant repository (update `{project}` value)
- [ ] Confirm `GH_DEPLOY_TOKEN` and `TAPDATA_ACCESS_CODE` are configured at the Organization level
- [ ] Configure `TAPDATA_URL` in each environment (`dev`, `sit`, `lpt`, `aat`, `prod`) of the tenant repository
- [ ] Configure database credential Secrets and Variables in the tenant repository (see naming rules in section 2.5)

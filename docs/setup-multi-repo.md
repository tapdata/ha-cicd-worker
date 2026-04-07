# Multi-Repo Multi-Tenant Mode: Setup Guide

Each team (tenant) owns an independent GitHub repository containing their TapData configuration files, and triggers automated deployments via the shared `ha-cicd-worker` repository. The Worker repository serves as a unified deployment engine reused by all tenants.

```
ha-cicd-worker      ← Shared deployment engine (Workflows + Scripts, centrally maintained)
├── patient-team    ← Tenant repo (TapData config files for the patient project)
└── case-team       ← Tenant repo (TapData config files for the case project)
```

When the Worker is updated, all tenant repositories automatically use the latest pipeline without any changes needed.

---

## Prerequisites

- An existing GitHub Organization (this project uses `tapdata`)
- A Self-hosted Runner machine with access to GitHub and the target TapData server
- An SSH key pair already generated

---

## Part 1: Configure the Worker Repository

The Worker repository is the core of the system and only needs to be configured once.

### 1. Create the Repository and Push Code

Create a private repository named `ha-cicd-worker` under the target GitHub Organization and push the project code to the `main` branch.

### 2. Verify and Update the Organization Name

The Workflow files in this repository default to the organization name `tapdata` (Demo environment). When deploying to an actual customer environment, confirm whether this value matches the real GitHub organization name and replace it globally if needed.

Files involved:

```
ha-cicd-worker/.github/workflows/tapdata-deploy.yml   # multiple occurrences of tapdata/ha-cicd-worker
case-team/.github/workflows/tapdata-deploy.yml         # uses: tapdata/ha-cicd-worker/...
patient-team/.github/workflows/tapdata-deploy.yml      # uses: tapdata/ha-cicd-worker/...
```

Run the following command from the repository root to batch-replace the organization name (replace `your-actual-org` with the real organization name):

```bash
grep -rl 'tapdata/ha-cicd-worker' .github */. github | xargs sed -i 's|tapdata/ha-cicd-worker|your-actual-org/ha-cicd-worker|g'
```

Alternatively, use your editor's global find-and-replace to search for `tapdata/ha-cicd-worker` and replace it.

### 3. Install the Self-hosted Runner

Go to the `ha-cicd-worker` repository → **Settings** → **Actions** → **Runners** → **New self-hosted runner**, and follow the instructions to install the Runner on the target machine.

> **Important**: The Runner is registered under the Worker repository. All tenant-triggered deployments run on this Runner — no separate Runner installation is needed in each tenant repository.

### 4. Configure Environments

Go to the `ha-cicd-worker` repository **Settings** → **Environments** and create the following Environments:

| Environment Name | Purpose |
|---|---|
| `dev` | Development environment |
| `sit` | Testing environment |
| `lpt` | Performance testing environment |
| `aat` | Acceptance testing environment |
| `prod` | Production environment |

> These Environments hold Worker-level configuration. No approval reviewers need to be configured here — the approval gate is set up in the `deploy` Environment of each tenant repository.

### 5. Configure Repository Variables

Go to `ha-cicd-worker` **Settings** → **Secrets and variables** → **Actions** → **Variables**:

| Variable Name | Description | Example |
|---|---|---|
| `TAPDATA_URL` | TapData server address | `http://10.0.0.1:3030` |

> If each environment uses a different TapData server address, configure an Environment-level Variable with the same name to override the repository-level value.

### 6. Configure Repository Secrets

Go to `ha-cicd-worker` **Settings** → **Secrets and variables** → **Actions** → **Secrets**:

| Secret Name | Description |
|---|---|
| `SSH_PRIVATE_KEY` | SSH private key used by the Runner to access all repositories (the corresponding public key must be added to the GitHub account or Organization) |

> `SSH_PRIVATE_KEY` must have read access to both the Worker repository and all tenant repositories. It is recommended to use a GitHub Organization Deploy Key or an account-level SSH key.

---

## Part 2: Configure Organization-Level Secrets (Optional)

If `TAPDATA_ACCESS_CODE` is the same for all tenants, you can configure it at the Organization level so all repositories inherit it automatically, eliminating the need to configure it in each tenant repository individually.

Go to GitHub **Organization** → **Settings** → **Secrets and variables** → **Actions** and add:

| Secret Name | Description |
|---|---|
| `TAPDATA_ACCESS_CODE` | Access credentials for the TapData platform |
| `SSH_PRIVATE_KEY` | (Can also be configured here for centralized management) |

Set the Secret's **Repository access** to **All repositories** or a specific whitelist of repositories.

---

## Part 3: Configure Each Tenant Repository

For each new tenant, follow the steps below to configure their repository. Using `patient-team` as an example (project name: `patient`):

### 1. Create the Repository

Create a tenant repository (e.g., `patient-team`, private) under the `tapdata` organization.

### 2. Configure Environments

Go to the tenant repository **Settings** → **Environments** and create the following Environments:

| Environment Name | Purpose | Requires Reviewers |
|---|---|---|
| `dev` | Development environment | No |
| `sit` | Testing environment | No |
| `lpt` | Performance testing environment | No |
| `deploy` | Approval gate for connection/task/API deployments | **Yes** — configure reviewers |

> **Note**: The `deploy` Environment is the manual approval gate in the pipeline. Deploying TapData connections, tasks, or APIs to this tenant requires a reviewer to confirm on the GitHub page before execution continues.

### 3. Configure Repository Secrets

Go to the tenant repository **Settings** → **Secrets and variables** → **Actions** → **Secrets**:

| Secret Name | Description |
|---|---|
| `SSH_PRIVATE_KEY` | Add here if not configured at the Organization level |
| `TAPDATA_ACCESS_CODE` | Add here if not configured at the Organization level |
| Database connection passwords (see below) | Private database credentials for this tenant |

**Database connection Secret naming rules** (`{NAME}` is the connection name in TapData, converted to uppercase):

| Priority | Secret Name | Description |
|---|---|---|
| 1 (highest) | `{NAME}_URI` | Full database connection URI |
| 2 | `{NAME}_PASSWORD` | Used with `{NAME}_URL` and `{NAME}_USER` Variables of the same name |
| 3 | `{PREFIX}_PASSWORD` | Grouped by prefix (connection name `A_B_C` automatically tries prefix `A_B`) |
| 4 (fallback) | `DEFAULT_PASSWORD` | Used with `DEFAULT_URL` and `DEFAULT_USER` |

### 4. Configure Repository Variables

Go to the tenant repository **Settings** → **Secrets and variables** → **Actions** → **Variables**:

Based on the database connection naming rules, configure the corresponding URL and USER (passwords are configured separately as Secrets):

| Variable Name | Example Value |
|---|---|
| `{NAME}_URL` | `mysql://10.0.0.2:3306/patient_db` |
| `{NAME}_USER` | `deploy_user` |

### 5. Add the Trigger Workflow File

Create `.github/workflows/tapdata-deploy.yml` in the tenant repository with the following content (replace `tapdata` and `patient` with the actual values):

```yaml
name: TapData Deploy

on:
  push:
    branches: [main]
    paths:
      - 'patient_tapdata_export/**'
    tags:
      - 'patient-*'
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
    uses: tapdata/ha-cicd-worker/.github/workflows/tapdata-deploy.yml@main
    with:
      project: patient
      target_env: ${{ inputs.target_env || '' }}
      caller_repo: ${{ github.repository }}
      caller_sha: ${{ github.sha }}
      caller_event: ${{ github.event_name }}
      caller_ref: ${{ github.ref }}
    secrets: inherit
```

> **Tag naming convention**: When creating tags in a tenant repository, use the `{project}-v{version}` format (e.g., `patient-v1.0.0`) to distinguish them from the Worker repository's version tags.

### 6. Prepare TapData Export Files

Place the JSON files exported from the TapData platform into the `{project}_tapdata_export/` directory at the root of the tenant repository:

```
patient_tapdata_export/
├── Connection/       # Database connection configuration JSON files
├── Task/             # Data migration/sync task JSON files
├── API/              # API endpoint JSON files
├── User/             # User configuration JSON files
└── GroupInfo.json    # Group information
```

---

## Part 4: Verify Triggers

| Action | Target Environment |
|---|---|
| Push to `main` in the tenant repository (with changes in `{project}_tapdata_export/`) | `dev` |
| Create a `{project}-*` tag in the tenant repository | `sit` |
| Manually trigger from the tenant repository's Actions page | Select `dev` / `sit` / `lpt` |

Go to the tenant repository's **Actions** tab to view the run status. When the pipeline reaches the `deploy` approval gate, reviewers will receive a notification and can click **Review deployments** on the GitHub page to confirm and continue.

---

## Quick Checklist for Adding a New Tenant

For each new tenant, complete the following:

- [ ] Create the tenant GitHub repository
- [ ] Configure Environments: `dev`, `sit`, `lpt`, `deploy` (set reviewers for `deploy`)
- [ ] Configure Secrets: database connection passwords (add `TAPDATA_ACCESS_CODE` and `SSH_PRIVATE_KEY` if not configured at the Org level)
- [ ] Configure Variables: database connection URL and USER
- [ ] Add `.github/workflows/tapdata-deploy.yml` (confirm whether the org name `tapdata` needs to be replaced, and replace the `project` name)
- [ ] Place the `{project}_tapdata_export/` directory and JSON files
- [ ] Push to `main` to verify the pipeline triggers

# Multi-Repo Multi-Tenant: Setup Checklist

> **Purpose: Pre-Go-Live Environment Preparation and Configuration Verification**

> Each team (tenant) owns an independent GitHub repository for their TapData configuration files.
> A shared `cicd-worker` repository serves as the unified deployment engine.

---

## Part 1: Customer IT/Ops Preparation

> The following items require internal approval and should be completed **before go-live**.

### 1.1 GitHub Organization

- [ ] Provide a GitHub Organization (or confirm an existing one can be used)
- [ ] Confirm Organization name: `___________` (referred to as `{org}`, recommended value: `tapdata`)

### 1.2 GitHub Repositories

Create the following **private** repositories under `{org}`:

- [ ] `cicd-worker` — shared deployment engine (CI/CD scripts and workflows)
- [ ] `patient-case-team` — tenant repository (holds TapData export files for patient-case project)

> Repository names above are suggestions — can be adjusted based on the actual project naming conventions.

### 1.3 GitHub User Account for TapData Engineer

- [ ] Create **1 GitHub account** for TapData implementation engineer
- [ ] Add to `{org}` as **Owner** role

> **Note:** Owner access is required for the current trial/test phase so the TapData team can independently complete all configuration in Part 2. For future production go-live, a more restricted permission model can be discussed and adopted.

> Customer-side deployment approvers use their existing GitHub accounts — no additional account requests needed. They will be added as **Member** and assigned as Environment reviewers in Part 3.

### 1.4 Self-hosted Runner Machine (Organization Level)

Provide **one** server/VM and register it as an **Organization-level** GitHub Actions Runner (shared across all repositories under `{org}`):

- [ ] OS: Linux (Ubuntu 20.04+ recommended)
- [ ] Disk: >= 20 GB
- [ ] Network (outbound): can reach GitHub (HTTPS)
- [ ] Network (internal): can reach the TapData server (host + port)
- [ ] Dependencies installed: `git`, `bash`, `jq`
- [ ] Register the Runner: go to `{org}` > **Settings** > **Actions** > **Runners** > **New self-hosted runner**, follow the instructions to install and start the Runner on the machine
- [ ] Add custom label **`tapdata`** during registration
- [ ] Verify Runner status shows **Idle** in the Organization's runner list

### 1.5 TapData Local Dev Server

Provide **one** server for the TapData local development environment — TapData and MongoDB will be installed on this machine:

- [ ] CPU: 16 cores
- [ ] Memory: 128 GB
- [ ] Disk: 300 GB
- [ ] OS: Linux (Ubuntu 20.04+ recommended)

---

## Part 2: GitHub Configuration (TapData Team)

> Once Part 1 is complete, the following is done by the TapData deployment team.

### 2.1 Worker Repository (`cicd-worker`)

- [ ] Push `cicd-worker` code to the `main` branch
- [ ] Replace all occurrences of the default org name `tapdata` with `{org}` in workflow files _(skip if the org name is already `tapdata`)_:
  - [ ] `.github/workflows/tapdata-deploy.yml`

### 2.2 Organization-level Secrets & Variables

Configure at `{org}` > **Settings** > **Secrets and variables** > **Actions**:

**Secrets:**

- [ ] `GH_DEPLOY_TOKEN` — fine-grained PAT for cross-repo checkout and `workflow_call`; scoped to all repos under `{org}` with `Actions`, `Workflows`, `Contents`: Read and Write
- [ ] `SIT_TAPDATA_ACCESS_CODE`
- [ ] `LPT_TAPDATA_ACCESS_CODE`

**Variables:**

- [ ] `SIT_TAPDATA_URL` (e.g. `http://10.0.0.1:3030`)
- [ ] `LPT_TAPDATA_URL`

### 2.3 Per-Tenant Repository Configuration

> Repeat the following for each tenant repository (e.g. `patient-case-team`).

**Environments:**

- [ ] Create Environment: `sit`
- [ ] Create Environment: `lpt`
- [ ] Create Environment: `deploy` — **add designated approvers as reviewers**

**Workflow file:**

- [ ] Create `.github/workflows/tapdata-deploy.yml` (replace `{org}` and `{project}`):

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
          - sit
          - lpt

jobs:
  deploy:
    uses: {org}/cicd-worker/.github/workflows/tapdata-deploy.yml@main
    with:
      project: {project}
      target_env: ${{ inputs.target_env || '' }}
      caller_repo: ${{ github.repository }}
      caller_sha: ${{ github.sha }}
      caller_event: ${{ github.event_name }}
      caller_ref: ${{ github.ref }}
    secrets: inherit
```

**Database credentials (repo-level):**

Configure at tenant repo > **Settings** > **Secrets and variables** > **Actions**:

**MongoDB connections** (`FDM`, `MDM`) — use URI format:

| Type | Name | Example |
|---|---|---|
| Secret | `FDM_URI` | `mongodb://user:pass@host:27017/db` |
| Secret | `MDM_URI` | `mongodb://user:pass@host:27017/db` |

**PostgreSQL connections** (all others) — use split format:

| Type | Name |
|---|---|
| Variable | `{NAME}_URL` |
| Variable | `{NAME}_USER` |
| Secret | `{NAME}_PASSWORD` |

- [ ] `sit` environment database credentials configured
- [ ] `lpt` environment database credentials configured

**TapData platform:**

- [ ] Create a project on TapData platform with the name matching the tenant repository name (e.g. repository `patient-case-team` → project name `patient-case-team`)

---

## Part 3: Local Dev Environment Setup (TapData Team)

> Once the Local Dev Server (1.5) is ready, the TapData team will install and configure the software.

### 3.1 Install & Configure

- [ ] Install MongoDB on the Local Dev Server
- [ ] Install TapData on the Local Dev Server
- [ ] Configure all required parameters (database connection, ports, credentials, etc.)
- [ ] Verify TapData starts successfully and is accessible

### 3.2 TapData Platform Configuration

- [ ] Configure Connections on the TapData platform (local dev)
- [ ] Configure and start Migration / Sync Tasks on the TapData platform (local dev)
- [ ] Publish APIs on the TapData platform (local dev)

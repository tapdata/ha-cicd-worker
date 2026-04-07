# Single-Repo Mode: Setup Guide

All TapData configuration files and CI/CD scripts are stored in a single GitHub repository (`ha-cicd-worker`). Suitable for a single team or project.

---

## Part 1: Resources to Request from Your IT/Ops Team

> These items require internal approval processes and should be arranged **before go-live**. Please confirm all items below are in place before proceeding.

### 1.1 GitHub Account and Repository

| Item | Requirement |
|---|---|
| GitHub account (personal or organization) | With permission to create repositories |
| One **private** repository named `ha-cicd-worker` | For storing all CI/CD scripts and TapData config files |

> If multiple team members need access, request a GitHub Organization and invite members accordingly. The CI/CD administrator account needs **Owner** or **Admin** access to the repository.

### 1.2 Self-hosted Runner Machine

Request a server/VM to act as the GitHub Actions Runner. This machine will execute all deployment jobs.

**Requirements:**

| Item | Requirement |
|---|---|
| OS | Linux (Ubuntu 20.04+ recommended) |
| Network access | Must reach the GitHub instance (outbound HTTPS) |
| Network access | Must reach the TapData server (host + port) |
| Disk | ≥ 20 GB free |
| User | A dedicated service account (non-root) is recommended |

---

## Part 2: Configuration Done by Our Team

> Once we have the GitHub account and repository access, the following can be set up and adjusted at any time — no IT approval required.

### 2.1 Push Code to the Repository

Push the `ha-cicd-worker` project code to the `main` branch.

### 2.2 Install the Self-hosted Runner

1. Go to `ha-cicd-worker` → **Settings** → **Actions** → **Runners** → **New self-hosted runner**
2. Follow the on-screen instructions to register the Runner on the target machine
3. During registration, add the custom label **`tapdata`** (in addition to the default `self-hosted` label):
   ```
   # When the setup script prompts for extra labels:
   Enter any additional labels (comma separated): tapdata
   ```
4. Verify the Runner status shows **Idle**

### 2.3 Configure GitHub Environments

Go to **Settings** → **Environments** and create the following:

| Environment | Purpose | Requires Reviewers |
|---|---|---|
| `dev` | Development (auto-triggered on push to main) | No |
| `sit` | Testing (auto-triggered on tag creation) | No |
| `lpt` | Performance testing (manually triggered) | No |
| `aat` | Acceptance testing (manually triggered) | No |
| `prod` | Production (manually triggered) | No |
| `deploy` | Approval gate before any deployment | **Yes** — add reviewers |

> The `deploy` Environment is the manual approval gate. Every deployment (connections, tasks, APIs) pauses here until an approver clicks **Review deployments** on the GitHub Actions page.

### 2.4 Place TapData Export Files

Add the exported TapData JSON files into the repository:

```
{project}_tapdata_export/
├── Connection/
├── Task/
├── API/
├── User/
└── GroupInfo.json
```

### 2.5 Configure Secrets and Variables

Go to **Settings** → **Secrets and variables** → **Actions**:

**Secrets:**

| Name | Description |
|---|---|
| `GH_DEPLOY_TOKEN` | Fine-grained personal access token for accessing the repository |
| `TAPDATA_ACCESS_CODE` | TapData platform access credentials |
| Database passwords | Named by connection (see rules below) |

**Variables:**

| Name | Description | Example |
|---|---|---|
| `TAPDATA_URL` | TapData server address | `http://10.0.0.1:3030` |
| Database URLs / Users | Named by connection (see rules below) | |

> If each environment uses a different TapData server, configure `TAPDATA_URL` as an Environment-level Variable inside each environment to override the repository-level value.

**Database credential naming rules** (`{NAME}` = TapData connection name, uppercased):

| Priority | Type | Name | Example |
|---|---|---|---|
| 1 (highest) | Secret | `{NAME}_URI` | `MYSQL_PROD_URI` = `mysql://user:pass@host:3306/db` |
| 2 | Variable + Secret | `{NAME}_URL` / `{NAME}_USER` / `{NAME}_PASSWORD` | Split credentials |
| 3 | Variable + Secret | `{PREFIX}_URL` / `{PREFIX}_USER` / `{PREFIX}_PASSWORD` | Shared by prefix group |
| 4 (fallback) | Variable + Secret | `DEFAULT_URL` / `DEFAULT_USER` / `DEFAULT_PASSWORD` | Global default |

---

## Deployment Triggers

| Action | Target Environment |
|---|---|
| Push to `main` (with changes in `{project}_tapdata_export/`) | `dev` |
| Create a Git Tag | `sit` |
| Manually trigger from the Actions page | Select `sit` / `lpt` / `aat` / `prod` |

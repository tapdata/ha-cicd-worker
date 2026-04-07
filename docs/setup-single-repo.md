# Single-Repo Mode: Setup Guide

All TapData configuration files and CI/CD scripts are stored in a single GitHub repository (`ha-cicd-worker`). This mode is suitable for a single team or project.

---

## Prerequisites

- A GitHub account with permission to create repositories
- A Self-hosted Runner machine with access to GitHub and the target TapData server
- An SSH key pair already generated for the Runner to access the repository

---

## Step 1: Create the Repository

1. Create a repository named `ha-cicd-worker` on GitHub (private or public)
2. Push the project code to the `main` branch of that repository

---

## Step 2: Install the Self-hosted Runner

1. Go to the repository page → **Settings** → **Actions** → **Runners** → **New self-hosted runner**
2. Follow the on-screen instructions to download and install the Runner on the target machine
3. Once registered, the Runner status should show as **Idle**

---

## Step 3: Configure GitHub Environments

Environments are used to control deployment approvals and manage environment-specific variables.

Go to repository **Settings** → **Environments** and create the following:

| Environment Name | Purpose | Requires Reviewers |
|---|---|---|
| `dev` | Development environment (auto-triggered on push to main) | No |
| `sit` | Testing environment (auto-triggered on tag creation) | No |
| `lpt` | Performance testing environment (manually triggered) | No |
| `aat` | Acceptance testing environment (manually triggered) | No |
| `prod` | Production environment (manually triggered) | No |
| `deploy` | Manual approval gate before deploying connections/tasks/APIs | **Yes** — configure reviewers |

> **Note**: The `deploy` Environment is the approval gate in the pipeline. Every time connections, migration tasks, sync tasks, or APIs are deployed, a reviewer must confirm on the GitHub page before execution continues.

---

## Step 4: Configure Repository Secrets

Go to repository **Settings** → **Secrets and variables** → **Actions** → **Secrets** tab and add the following:

### Required Secrets

| Secret Name | Description |
|---|---|
| `SSH_PRIVATE_KEY` | SSH private key content for the Runner to access the repository (the corresponding public key must be added to your GitHub account or the repository's Deploy Keys) |
| `TAPDATA_ACCESS_CODE` | Access credentials for the TapData platform, used to obtain an API token |

### Database Connection Secrets (based on your actual connections)

During deployment, `generate-vault.sh` automatically extracts database connection information from Secrets using the following priority order (`{NAME}` is the connection name in TapData, converted to uppercase):

**Priority 1**: Provide a full URI directly

| Secret Name | Example |
|---|---|
| `{NAME}_URI` | `MYSQL_PROD_URI` = `mysql://user:pass@host:3306/db` |

**Priority 2**: Provide URL + username + password separately

| Type | Name | Example |
|---|---|---|
| Variable | `{NAME}_URL` | `MYSQL_PROD_URL` = `mysql://host:3306/db` |
| Variable | `{NAME}_USER` | `MYSQL_PROD_USER` = `admin` |
| Secret | `{NAME}_PASSWORD` | `MYSQL_PROD_PASSWORD` = `secret123` |

**Priority 3**: Group by prefix (connection name `A_B_C_D` automatically tries prefix `A_B`)

> For example, if the connection name is `MYSQL_PROD_ORDERS`, it will automatically try `MYSQL_PROD_URL` / `MYSQL_PROD_USER` / `MYSQL_PROD_PASSWORD`

**Priority 4**: Default fallback

| Type | Name |
|---|---|
| Variable | `DEFAULT_URL` |
| Variable | `DEFAULT_USER` |
| Secret | `DEFAULT_PASSWORD` |

---

## Step 5: Configure Repository Variables

Go to repository **Settings** → **Secrets and variables** → **Actions** → **Variables** tab and add:

| Variable Name | Description | Example |
|---|---|---|
| `TAPDATA_URL` | TapData server address (including protocol and port) | `http://10.0.0.1:3030` |

> If each environment uses a different TapData server address, configure an Environment-level Variable with the same name to override the repository-level value.

---

## Step 6: Prepare TapData Export Files

Place the JSON files exported from the TapData platform into the `{project}_tapdata_export/` directory at the root of the repository. The directory structure should look like this:

```
{project}_tapdata_export/
├── Connection/       # Database connection configuration JSON files
├── Task/             # Data migration/sync task JSON files
├── API/              # API endpoint JSON files
├── User/             # User configuration JSON files
└── GroupInfo.json    # Group information
```

---

## Step 7: Verify Triggers

After completing the above configuration, trigger a deployment using one of the following methods:

| Action | Target Environment |
|---|---|
| Push to `main` branch (with changes in `{project}_tapdata_export/`) | `dev` |
| Create a Git Tag | `sit` |
| Manually trigger from GitHub Actions page (Workflow dispatch) | Select `sit` / `lpt` / `aat` / `prod` |

Go to the repository's **Actions** tab to view the Workflow run status. When the pipeline reaches the `deploy` approval gate, reviewers will receive an email notification and can click **Review deployments** on the GitHub page to confirm and continue execution.

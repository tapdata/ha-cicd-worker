# 多仓库多租户模式：首次配置指南

每个团队（租户）拥有独立的 GitHub 仓库，存放各自的 TapData 配置文件，通过调用共享的 `ha-cicd-worker` 仓库完成自动化部署。Worker 仓库作为统一的部署引擎被所有租户复用。

```
ha-cicd-worker      ← 共享部署引擎（Workflows + Scripts，统一维护）
├── patient-team    ← 租户仓库（存放 patient 项目的 TapData 配置文件）
└── case-team       ← 租户仓库（存放 case 项目的 TapData 配置文件）
```

Worker 更新后，所有租户仓库无需任何操作即可自动使用最新流水线。

---

## 前提条件

- 已有 GitHub Organization（本项目使用 `tapdata`）
- 已有 Self-hosted Runner 机器，可连接 GitHub 和目标 TapData 服务器
- 已生成 SSH 密钥对

---

## 第一部分：配置 Worker 仓库

Worker 仓库是整个系统的核心，只需配置一次。

### 1. 创建仓库并推送代码

在目标 GitHub Organization 下创建名为 `ha-cicd-worker` 的私有仓库，将本项目代码推送到 `main` 分支。

### 2. 确认并更新组织名称

本仓库的 Workflow 文件中，组织名称默认为 `tapdata`（Demo 环境）。部署到实际客户环境时，需确认该值是否与真实 GitHub 组织名一致，若不同则需要全局替换。

涉及文件：

```
ha-cicd-worker/.github/workflows/tapdata-deploy.yml   # 多处 tapdata/ha-cicd-worker
case-team/.github/workflows/tapdata-deploy.yml         # uses: tapdata/ha-cicd-worker/...
patient-team/.github/workflows/tapdata-deploy.yml      # uses: tapdata/ha-cicd-worker/...
```

在仓库根目录执行以下命令完成批量替换（将 `your-actual-org` 替换为真实组织名）：

```bash
grep -rl 'tapdata/ha-cicd-worker' .github */. github | xargs sed -i 's|tapdata/ha-cicd-worker|your-actual-org/ha-cicd-worker|g'
```

或直接在编辑器中全局搜索 `tapdata/ha-cicd-worker` 并替换。

### 3. 安装 Self-hosted Runner

进入 `ha-cicd-worker` 仓库 → **Settings** → **Actions** → **Runners** → **New self-hosted runner**，按提示在目标机器上安装 Runner。

> **重要**：Runner 注册在 Worker 仓库下。所有租户触发的部署任务均运行在此 Runner 上，无需在租户仓库单独安装。

### 4. 配置 Environments

进入 `ha-cicd-worker` 仓库 **Settings** → **Environments**，创建以下 Environment：

| Environment 名称 | 用途 |
|---|---|
| `dev` | 对应开发环境 |
| `sit` | 对应测试环境 |
| `lpt` | 对应性能测试环境 |
| `aat` | 对应验收测试环境 |
| `prod` | 对应生产环境 |

> 这些 Environment 用于承载 Worker 仓库级别的配置，无需配置审批人（审批门在租户仓库的 `deploy` Environment 中配置）。

### 5. 配置 Repository Variables

进入 `ha-cicd-worker` **Settings** → **Secrets and variables** → **Actions** → **Variables**：

| Variable 名称 | 说明 | 示例 |
|---|---|---|
| `TAPDATA_URL` | TapData 服务器地址 | `http://10.0.0.1:3030` |

> 如果各环境 TapData 地址不同，可在对应 Environment 下配置同名 Variable 覆盖。

### 6. 配置 Repository Secrets

进入 `ha-cicd-worker` **Settings** → **Secrets and variables** → **Actions** → **Secrets**：

| Secret 名称 | 说明 |
|---|---|
| `SSH_PRIVATE_KEY` | Runner 访问各仓库的 SSH 私钥（对应公钥需添加到 GitHub 账户或 Organization） |

> `SSH_PRIVATE_KEY` 需对 Worker 仓库和所有租户仓库均有读取权限（建议使用 GitHub Organization 的 Deploy Key 或账号级 SSH Key）。

### 7. 配置环境映射

编辑 `conf/env.conf`，填写各环境的 TapData 服务器地址：

```ini
dev=http://<dev-server>:3030
sit=http://<sit-server>:3030
lpt=http://<lpt-server>:3030
aat=http://<aat-server>:3030
prod=http://<prod-server>:3030
```

---

## 第二部分：配置 Organization 级别 Secrets（可选）

如果 `TAPDATA_ACCESS_CODE` 对所有租户相同，可将其配置在 Organization 级别，所有仓库自动继承，无需在每个租户仓库重复配置。

进入 GitHub **Organization** → **Settings** → **Secrets and variables** → **Actions**，添加：

| Secret 名称 | 说明 |
|---|---|
| `TAPDATA_ACCESS_CODE` | TapData 平台的访问凭证 |
| `SSH_PRIVATE_KEY` | （也可在此配置，统一管理） |

将 Secret 的 **Repository access** 设置为 **All repositories** 或指定白名单仓库。

---

## 第三部分：配置每个租户仓库

每新增一个租户，按以下步骤配置其仓库。以 `patient-team` 为例（`project` 名称为 `patient`）：

### 1. 创建仓库

在 `tapdata` 下创建租户仓库（如 `patient-team`，私有）。

### 2. 配置 Environments

进入租户仓库 **Settings** → **Environments**，创建以下 Environment：

| Environment 名称 | 用途 | 是否需要审批人 |
|---|---|---|
| `dev` | 开发环境 | 否 |
| `sit` | 测试环境 | 否 |
| `lpt` | 性能测试环境 | 否 |
| `deploy` | 连接/任务/API 部署审批门 | **是**，配置审批人 |

> **说明**：`deploy` Environment 是流水线的人工审批节点。当部署到此租户的 TapData 连接、任务、API 时，必须由审批人在 GitHub 页面确认后才会继续执行。

### 3. 配置 Repository Secrets

进入租户仓库 **Settings** → **Secrets and variables** → **Actions** → **Secrets**：

| Secret 名称 | 说明 |
|---|---|
| `SSH_PRIVATE_KEY` | 如未在 Organization 级别配置，在此添加 |
| `TAPDATA_ACCESS_CODE` | 如未在 Organization 级别配置，在此添加 |
| 数据库连接密码（见下方） | 该租户私有的数据库凭证 |

**数据库连接 Secrets 命名规则**（`{NAME}` 为 TapData 中的连接名称，转换为大写）：

| 优先级 | Secret 名称 | 说明 |
|---|---|---|
| 1（最高） | `{NAME}_URI` | 完整数据库连接 URI |
| 2 | `{NAME}_PASSWORD` | 配合同名 Variable 中的 `{NAME}_URL` 和 `{NAME}_USER` |
| 3 | `{PREFIX}_PASSWORD` | 按前缀分组（连接名 `A_B_C` 自动尝试前缀 `A_B`） |
| 4（兜底） | `DEFAULT_PASSWORD` | 配合 `DEFAULT_URL` 和 `DEFAULT_USER` |

### 4. 配置 Repository Variables

进入租户仓库 **Settings** → **Secrets and variables** → **Actions** → **Variables**：

根据数据库连接命名规则，配置对应的 URL 和 USER（密码作为 Secret 单独配置）：

| Variable 名称 | 示例值 |
|---|---|
| `{NAME}_URL` | `mysql://10.0.0.2:3306/patient_db` |
| `{NAME}_USER` | `deploy_user` |

### 5. 添加触发 Workflow 文件

在租户仓库中创建 `.github/workflows/tapdata-deploy.yml`，内容如下（替换 `tapdata` 和 `patient` 为实际值）：

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

> **Tag 命名规范**：租户仓库创建 Tag 时，建议使用 `{project}-v{版本}` 格式（如 `patient-v1.0.0`），与 Worker 仓库的版本 Tag 区分。

### 6. 准备 TapData 导出文件

将从 TapData 平台导出的 JSON 文件放入租户仓库根目录下的 `{project}_tapdata_export/` 目录：

```
patient_tapdata_export/
├── Connection/       # 数据库连接配置 JSON 文件
├── Task/             # 数据迁移/同步任务 JSON 文件
├── API/              # API 端点 JSON 文件
├── User/             # 用户配置 JSON 文件
└── GroupInfo.json    # 分组信息
```

---

## 第四部分：验证触发

| 操作 | 目标环境 |
|---|---|
| 在租户仓库 Push 到 `main`（`{project}_tapdata_export/` 目录有变更） | `dev` |
| 在租户仓库创建 `{project}-*` Tag | `sit` |
| 在租户仓库 Actions 页面手动触发 | 选择 `dev` / `sit` / `lpt` |

进入租户仓库 **Actions** 标签页查看运行状态。到达 `deploy` 审批节点时，审批人收到通知后在 GitHub 页面点击 **Review deployments** 确认。

---

## 新增租户的快速清单

每新增一个租户，需完成以下操作：

- [ ] 创建租户 GitHub 仓库
- [ ] 配置 Environments：`dev`、`sit`、`lpt`、`deploy`（`deploy` 设置审批人）
- [ ] 配置 Secrets：数据库连接密码（`TAPDATA_ACCESS_CODE` 和 `SSH_PRIVATE_KEY` 若未在 Org 配置则补充）
- [ ] 配置 Variables：数据库连接 URL 和 USER
- [ ] 添加 `.github/workflows/tapdata-deploy.yml`（确认组织名 `tapdata` 是否需要替换，替换 `project` 名称）
- [ ] 放入 `{project}_tapdata_export/` 目录及 JSON 文件
- [ ] Push 到 `main` 验证流水线触发

# TapData Deploy 运行前准备

本文档用于说明在 GitHub 上运行 `TapData Deploy` 之前，需要提前完成的配置和检查项。

## 1. 仓库内配置准备

### 1.1 配置目标环境地址

部署脚本会从 `conf/env.conf` 读取目标环境地址。

- 需要为要部署的环境配置可访问的 base URL
- 例如手动执行 `dev` 时，`conf/env.conf` 中的 `dev=` 不能留空

当前支持的环境：

- `dev`
- `sit`
- `lpt`
- `aat`
- `prod`

如果目标环境未配置地址，workflow 会报错：

- `No base URL configured for environment 'xxx' in env.conf`

### 1.2 准备导出目录

当前 workflow 会根据项目名读取 `${PROJECT}_tapdata_export` 目录。

例如：

- 项目选择 `dmp`
- 则仓库根目录下需要存在 `dmp_tapdata_export`

目录中的文件命名约定：

- 连接：`*_connection.json`
- 连接元数据：`*_connection_metadata.json`
- 任务：`*_task.json`
- API：`*_api.json`

## 2. GitHub Secrets 配置

在仓库的 `Settings -> Secrets and variables -> Actions` 中，至少需要配置以下 Secret。

### 2.1 `{env}_TAPDATA_ACCESSCODE`

用途：

- `get-token.sh` 会用这个值调用 TapData 的 `/api/users/generatetoken` 接口
- 用于换取部署时使用的访问令牌

Secret 需要按环境分别配置，例如：

- `dev_TAPDATA_ACCESSCODE`
- `sit_TAPDATA_ACCESSCODE`
- `lpt_TAPDATA_ACCESSCODE`
- `aat_TAPDATA_ACCESSCODE`
- `prod_TAPDATA_ACCESSCODE`

说明：

- 手动触发时，会按你选择的 `target_env` 读取对应 Secret
- PR 自动触发时，当前固定使用 `dev`，因此会读取 `dev_TAPDATA_ACCESSCODE`

如果未配置，workflow 会报错：

- `TAPDATA_ACCESSCODE is not set or empty`

### 2.2 `SSH_PRIVATE_KEY`

用途：

- `actions/checkout@v4` 会使用该私钥拉取仓库代码

如果未配置或权限不正确，checkout 步骤会失败。

### 2.3 连接相关 Secrets（按需）

如果 `dmp_tapdata_export` 中存在连接文件 `*_connection.json`，则还需要为每个连接配置对应的 Secret。

命名规则：

- `{连接名}_host`
- `{连接名}_port`
- `{连接名}_user`
- `{连接名}_password`

注意：

- 连接名来自连接 JSON 文件中的 `name` 字段
- 后缀必须是小写：`_host`、`_port`、`_user`、`_password`
- 名称必须完全匹配，否则 `generate-vault.sh` 会报缺少 Secret

## 3. GitHub Environment 配置

### 3.1 目标环境

`deploy-connections` job 会绑定到所选的目标环境：

- `dev`
- `sit`
- `lpt`
- `aat`
- `prod`

建议在 `Settings -> Environments` 中提前创建对应环境，便于后续配置审批规则或环境级变量/Secret。

### 3.2 `rollback-approval` 环境

当连接、任务或 API 部署失败时，workflow 会进入 `rollback-approval` 环境等待审批。

需要提前在 `Settings -> Environments` 中创建：

- `rollback-approval`

建议配置：

- Required reviewers（需要审批人）

说明：

- 当前仓库里的 `tapdata-rollback.yml` 还只是占位实现
- 现在主要作用是提供失败后的审批入口和回滚流程入口

## 4. Self-hosted Runner 准备

workflow 的所有 job 当前都运行在：

- `runs-on: self-hosted`

因此需要保证仓库绑定的 self-hosted runner 处于在线状态。

### 4.1 基本要求

- 在 `Settings -> Actions -> Runners` 中能看到 runner 为 `Online`
- runner 进程必须持续运行，不能只注册不启动
- runner 需要能访问 GitHub 和目标 TapData 地址

### 4.2 机器依赖

runner 所在机器建议提前安装并可直接使用以下命令：

- `bash`
- `git`
- `curl`
- `jq`
- `tar`
- `find`
- `ssh`

如果缺少这些命令，脚本执行时会失败。

## 5. 手动执行 Deploy 的实际步骤

1. 确认代码已经推送到要运行的分支（例如 `main`）
2. 确认 `conf/env.conf` 中目标环境地址已填写
3. 确认对应环境的 `*_TAPDATA_ACCESSCODE`、`SSH_PRIVATE_KEY` 已配置
4. 如果包含连接文件，确认连接相关 Secrets 已配置
5. 确认 self-hosted runner 在线且正在运行
6. 确认已创建 `rollback-approval` environment
7. 进入 GitHub Actions 页面，选择 `TapData Deploy`
8. 点击 `Run workflow`
9. 选择：
   - Branch：例如 `main`
   - Target environment：例如 `dev`
   - Project：例如 `dmp`

## 6. 常见问题排查

### 6.1 `Failed to queue workflow run. Please try again.`

优先检查：

- workflow YAML 是否已修复并推送到远端分支
- GitHub 页面选择的是否是最新分支
- workflow 文件本身是否有语法或表达式配置问题

### 6.2 `No base URL configured for environment 'dev' in env.conf`

说明 `conf/env.conf` 中对应环境地址为空，需要补齐后重新提交。

### 6.3 `TAPDATA_ACCESSCODE is not set or empty`

说明对应环境的 access code Secret 未配置，或命名不符合约定。

例如：

- 部署 `dev` 时，需要存在 `dev_TAPDATA_ACCESSCODE`

### 6.4 `Missing secrets for connection`

说明连接 Secret 名称和连接 JSON 中的 `name` 字段不匹配，或者有缺失项。
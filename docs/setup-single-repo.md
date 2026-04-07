# 单仓库模式：首次配置指南

所有 TapData 配置文件与 CI/CD 脚本均存放在同一个 GitHub 仓库（`ha-cicd-worker`）中，适合单一团队或项目场景。

---

## 前提条件

- 已有 GitHub 账号，具备创建仓库的权限
- 已有 Self-hosted Runner 机器，可连接 GitHub 和目标 TapData 服务器
- 已生成 SSH 密钥对，用于 Runner 访问仓库

---

## 步骤一：创建仓库

1. 在 GitHub 创建名为 `ha-cicd-worker` 的仓库（私有或公开均可）
2. 将本项目代码推送到该仓库的 `main` 分支

---

## 步骤二：安装 Self-hosted Runner

1. 进入仓库页面 → **Settings** → **Actions** → **Runners** → **New self-hosted runner**
2. 按页面提示在目标机器上下载并安装 Runner
3. 注册完成后，Runner 状态应显示为 **Idle**

---

## 步骤三：配置 GitHub Environments

Environments 用于控制部署审批和管理环境变量。

进入仓库 **Settings** → **Environments**，按以下说明创建：

| Environment 名称 | 用途 | 是否需要审批人 |
|---|---|---|
| `dev` | 开发环境（push 到 main 自动触发） | 否 |
| `sit` | 测试环境（打 tag 自动触发） | 否 |
| `lpt` | 性能测试环境（手动触发） | 否 |
| `aat` | 验收测试环境（手动触发） | 否 |
| `prod` | 生产环境（手动触发） | 否 |
| `deploy` | 连接/任务/API 部署前的人工审批门 | **是**，配置审批人 |

> **说明**：`deploy` Environment 是流水线的审批节点。每次部署连接、迁移任务、同步任务、API 时，必须由审批人在 GitHub 页面确认后才会继续执行。

---

## 步骤四：配置 Repository Secrets

进入仓库 **Settings** → **Secrets and variables** → **Actions** → **Secrets** 标签页，添加以下 Secrets：

### 必填 Secrets

| Secret 名称 | 说明 |
|---|---|
| `SSH_PRIVATE_KEY` | Runner 访问仓库的 SSH 私钥内容（对应公钥已添加到 GitHub 账户或仓库的 Deploy Keys） |
| `TAPDATA_ACCESS_CODE` | TapData 平台的访问凭证，用于获取 API Token |

### 数据库连接 Secrets（按实际连接配置）

部署时，`generate-vault.sh` 会自动从 Secrets 中提取数据库连接信息，按以下优先级匹配（`{NAME}` 为 TapData 中的连接名称，转换为大写）：

**优先级 1**：直接提供完整 URI

| Secret 名称 | 示例 |
|---|---|
| `{NAME}_URI` | `MYSQL_PROD_URI` = `mysql://user:pass@host:3306/db` |

**优先级 2**：分开提供 URL + 用户名 + 密码

| 类型 | 名称 | 示例 |
|---|---|---|
| Variable | `{NAME}_URL` | `MYSQL_PROD_URL` = `mysql://host:3306/db` |
| Variable | `{NAME}_USER` | `MYSQL_PROD_USER` = `admin` |
| Secret | `{NAME}_PASSWORD` | `MYSQL_PROD_PASSWORD` = `secret123` |

**优先级 3**：按前缀分组（连接名 `A_B_C_D` 自动截取前缀 `A_B`）

> 例如连接名为 `MYSQL_PROD_ORDERS`，自动尝试 `MYSQL_PROD_URL` / `MYSQL_PROD_USER` / `MYSQL_PROD_PASSWORD`

**优先级 4**：默认兜底

| 类型 | 名称 |
|---|---|
| Variable | `DEFAULT_URL` |
| Variable | `DEFAULT_USER` |
| Secret | `DEFAULT_PASSWORD` |

---

## 步骤五：配置 Repository Variables

进入仓库 **Settings** → **Secrets and variables** → **Actions** → **Variables** 标签页，添加：

| Variable 名称 | 说明 | 示例 |
|---|---|---|
| `TAPDATA_URL` | TapData 服务器地址（包含协议和端口） | `http://10.0.0.1:3030` |

> 如果各环境的 TapData 服务器地址不同，可在对应的 Environment 下配置同名 Variable 覆盖仓库级别的值。

---

## 步骤六：配置环境映射

编辑 `conf/env.conf`，按实际情况填写各环境的 TapData 服务器地址：

```ini
dev=http://<dev-server>:3030
sit=http://<sit-server>:3030
lpt=http://<lpt-server>:3030
aat=http://<aat-server>:3030
prod=http://<prod-server>:3030
```

---

## 步骤七：准备 TapData 导出文件

将从 TapData 平台导出的 JSON 文件放入仓库根目录下的 `{project}_tapdata_export/` 目录，目录结构如下：

```
{project}_tapdata_export/
├── Connection/       # 数据库连接配置 JSON 文件
├── Task/             # 数据迁移/同步任务 JSON 文件
├── API/              # API 端点 JSON 文件
├── User/             # 用户配置 JSON 文件
└── GroupInfo.json    # 分组信息
```

---

## 步骤八：验证触发

完成以上配置后，通过以下方式触发部署：

| 操作 | 目标环境 |
|---|---|
| Push 到 `main` 分支（`{project}_tapdata_export/` 目录有变更） | `dev` |
| 创建 Git Tag | `sit` |
| 在 GitHub Actions 页面手动触发（Workflow dispatch） | 选择 `sit` / `lpt` / `aat` / `prod` |

进入仓库 **Actions** 标签页，可查看 Workflow 运行状态。当流水线到达 `deploy` 审批节点时，审批人会收到邮件通知，在 GitHub 页面点击 **Review deployments** 确认后继续执行。

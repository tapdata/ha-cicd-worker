# ha-cicd

[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![Self-Hosted Runner](https://img.shields.io/badge/Runner-Self--Hosted-green)](https://docs.github.com/en/actions/hosting-your-own-runners)

## 📖 项目简介

这是一个专门用于运行 GitHub Actions 的 CI/CD 自动化仓库。

该仓库主要用于集中管理和执行 CI/CD 自动化流程，作为自动化执行中枢，负责触发、编排并运行各类流水线任务。

**核心特点：**
- 🎯 **职责单一**：仅负责 CI/CD 流程编排，不承载业务代码
- 🔄 **集中管理**：统一管理所有自动化工作流和脚本
- 🚀 **自托管运行**：使用 self-hosted runner，支持内网环境
- 📦 **配置驱动**：通过配置文件灵活管理多环境、多项目

---

## 📁 项目结构

```
ha-cicd/
├── ha-cicd-worker/              # CI/CD 工作流和脚本
│   ├── conf/                    # 配置文件目录
│   │   ├── env.conf            # 环境配置（dev/lpt/preprod/prod）
│   │   └── project.conf        # 项目分组配置
│   ├── scripts/                 # 自动化脚本
│   │   ├── tapdata_utils.py    # Tapdata 工具模块（共享函数）
│   │   ├── tapdata-get-token.py # 获取 Access Token 脚本
│   │   ├── tapdata-import.py   # Tapdata 配置导入脚本
│   │   └── tapdata-check.py    # Tapdata 导入状态检查脚本
│   ├── requirements.txt         # Python 依赖
│   └── README.md               # 本文档
├── ha-cicd-patient/             # 患者端配置仓库（示例）
└── .github/
    └── workflows/               # GitHub Actions 工作流定义
        ├── deploy.yml          # Tapdata 配置部署工作流
        └── deploy-README.md    # 工作流详细文档
```

---

## 🚀 主要功能

### 1. Tapdata 配置部署

自动化部署配置到 Tapdata 平台，支持多环境、多项目分组。

**支持的环境：**
- `dev` - 开发环境
- `lpt` - 测试环境
- `preprod` - 预生产环境
- `prod` - 生产环境

**支持的项目分组：**
- `patient` - 患者端项目
- `hospital` - 医院端项目

**使用方式：**
1. 进入 GitHub Actions 页面
2. 选择 "tapdata配置部署" workflow
3. 点击 "Run workflow"
4. 选择环境和项目分组
5. 点击 "Run workflow" 开始执行

详细文档请参考：[Tapdata 配置部署 Workflow 文档](.github/workflows/deploy-README.md)

---

## ⚙️ 配置文件说明

### 1. 环境配置 (`conf/env.conf`)

定义各环境的 Tapdata 服务地址。

**格式：** `环境=Tapdata地址`

**示例：**
```properties
dev=http://dev.tapdata.com:3030
lpt=http://111.229.51.170:3030
preprod=http://preprod.tapdata.com:3030
prod=http://prod.tapdata.com:3030
```

### 2. 项目配置 (`conf/project.conf`)

定义项目分组与配置仓库的映射关系。

**格式：** `项目分组=仓库名称`

**示例：**
```properties
patient=tapdata/ha-cicd-patient
hospital=tapdata/ha-cicd-hospital
```

---

## 🛠️ 脚本说明

### 1. tapdata_utils.py

**功能：** Tapdata 工具模块，提供共享函数

**主要函数：**
- `get_access_token(base_url)`: 获取 Tapdata access_token

**特点：**
- 被其他脚本导入使用
- 统一的 token 获取逻辑
- 完整的错误处理

### 2. tapdata-get-token.py

**功能：** 获取 Access Token 并输出到标准输出

**使用方式：**
```bash
python scripts/tapdata-get-token.py <BASE_URL>
```

**参数：**
- `BASE_URL`: Tapdata 服务地址

**输出：**
- stdout: access_token（用于 shell 捕获）
- stderr: 日志信息

### 3. tapdata-import.py

**功能：** 导入配置到 Tapdata 平台

**主要步骤：**
1. 验证输入参数
2. 上传配置 tar 包
3. 返回导入任务 record_id

**使用方式：**
```bash
python scripts/tapdata-import.py <BASE_URL> <ACCESS_TOKEN> <TAR_FILE>
```

**参数：**
- `BASE_URL`: Tapdata 服务地址
- `ACCESS_TOKEN`: Tapdata 访问令牌
- `TAR_FILE`: 配置 tar 包路径

### 4. tapdata-check.py

**功能：** 检查 Tapdata 导入任务状态

**主要步骤：**
1. 验证输入参数
2. 循环检查导入状态（每5秒一次）
3. 处理不同状态：importing（导入中）、completed（成功）、failed（失败）
4. 格式化输出错误信息

**使用方式：**
```bash
python scripts/tapdata-check.py <BASE_URL> <ACCESS_TOKEN> <RECORD_ID>
```

**参数：**
- `BASE_URL`: Tapdata 服务地址
- `ACCESS_TOKEN`: Tapdata 访问令牌
- `RECORD_ID`: 导入任务 ID

---

## 🔧 技术栈

- **CI/CD 平台**: GitHub Actions
- **运行环境**: Self-Hosted Runner
- **脚本语言**: Python 3
- **依赖管理**: pip + requirements.txt
- **数据传递**: 共享文件系统 + Job Outputs
- **HTTP 客户端**: requests

---

## 📋 工作流程

以 Tapdata 配置部署为例：

```mermaid
graph TB
    Start([开始部署]) --> Prepare[准备配置 Job]

    Prepare --> P1[检出代码]
    P1 --> P2[创建共享目录]
    P2 --> P3[获取配置仓库名称<br/>从 project.conf]
    P3 --> P4[检出配置仓库]
    P4 --> P5[压缩为 tar.gz]
    P5 --> P6[获取 Tapdata 地址<br/>从 env.conf]
    P6 --> P7[安装 Python 依赖]
    P7 --> P8[🔑 获取 Access Token]
    P8 --> PrepareOut{输出}

    PrepareOut -->|config_repo| Import
    PrepareOut -->|base_url| Import
    PrepareOut -->|tar_path| Import
    PrepareOut -->|access_token| Import

    Import[导入配置 Job] --> I1[检出代码]
    I1 --> I2[安装 Python 依赖]
    I2 --> I3[调用 tapdata-import.py<br/>使用 access_token]
    I3 --> ImportOut{输出}

    ImportOut -->|record_id| Verify
    PrepareOut -->|access_token| Verify
    PrepareOut -->|base_url| Verify

    Verify[验证结果 Job] --> V1[检出代码]
    V1 --> V2[安装 Python 依赖]
    V2 --> V3[调用 tapdata-check.py<br/>使用 access_token]
    V3 --> V4[清理共享目录]
    V4 --> Report

    Report[生成报告 Job] --> R1[汇总执行结果]
    R1 --> R2[输出部署信息]
    R2 --> End([部署完成])

    style P8 fill:#90EE90,stroke:#333,stroke-width:3px
    style PrepareOut fill:#FFD700,stroke:#333,stroke-width:2px
    style I3 fill:#87CEEB,stroke:#333,stroke-width:2px
    style V3 fill:#87CEEB,stroke:#333,stroke-width:2px
```

### 详细步骤说明

**1. 准备配置 (prepare)**
- 检出当前仓库代码
- 创建共享目录
- 获取配置仓库名称（从 project.conf）
- 检出配置仓库代码
- 压缩配置仓库为 tar.gz
- 获取 Tapdata 地址（从 env.conf）
- 安装 Python 依赖
- 🔑 获取 Access Token（一次性获取，传递给后续 jobs）
- **输出**: `config_repo`, `base_url`, `tar_path`, `access_token`

**2. 导入配置 (import)**
- 检出当前仓库代码
- 安装 Python 依赖
- 调用 `tapdata-import.py`
  - 接收 `access_token`（来自 prepare job）
  - 上传 tar 文件
  - 返回 `record_id`
- **输出**: `record_id`

**3. 验证结果 (verify)**
- 检出当前仓库代码
- 安装 Python 依赖
- 调用 `tapdata-check.py`
  - 接收 `access_token`（来自 prepare job）
  - 接收 `record_id`（来自 import job）
  - 循环检查导入状态（每5秒一次）
- 清理共享目录

**4. 生成报告 (report)**
- 汇总执行结果
- 输出部署信息
- 显示相关链接

### 🔑 Access Token 优化

**优化前：** 每个 job 都独立获取 token（3次 API 调用）

```mermaid
graph LR
    P[Prepare Job] --> PT[获取 Token 1]
    I[Import Job] --> IT[获取 Token 2]
    V[Verify Job] --> VT[获取 Token 3]

    style PT fill:#ffcccc,stroke:#333
    style IT fill:#ffcccc,stroke:#333
    style VT fill:#ffcccc,stroke:#333
```

**优化后：** 只在 prepare job 获取一次，传递给后续 jobs（1次 API 调用）

```mermaid
graph LR
    P[Prepare Job] --> PT[🔑 获取 Token]
    PT --> |传递 token| I[Import Job]
    PT --> |传递 token| V[Verify Job]
    I --> IU[使用 Token]
    V --> VU[使用 Token]

    style PT fill:#90EE90,stroke:#333,stroke-width:3px
    style IU fill:#87CEEB,stroke:#333
    style VU fill:#87CEEB,stroke:#333
```

**优势：**
- ⚡ 减少 66% 的 API 调用次数（3次 → 1次）
- 🔒 保证整个工作流使用同一个 token
- 🚀 提升执行效率，减少网络开销
- 📦 更清晰的职责分离

---

## ⚠️ 注意事项

1. **权限要求**
   - **必须配置 PAT Token**：需要创建 `PAT_TOKEN` Secret 用于访问配置仓库
     - 默认的 `GITHUB_TOKEN` 只有当前仓库权限，无法访问其他仓库
     - 详细配置步骤请参考：[PAT Token 配置指南](docs/PAT-TOKEN-SETUP.md)
   - 确保 self-hosted runner 有文件系统读写权限

2. **配置文件**
   - 确保 `env.conf` 中配置了所有环境的 Tapdata 地址
   - 确保 `project.conf` 中配置了所有项目分组的仓库名称

3. **超时设置**
   - 准备配置：5分钟
   - 导入配置：20分钟
   - 验证结果：5分钟
   - 生成报告：2分钟

4. **错误处理**
   - 导入失败时会打印详细的错误信息
   - 共享目录会在最后一个 job 完成后自动清理
   - 可以通过 GitHub Actions 界面重试失败的 job

---

## 📚 相关文档

- [Tapdata 配置部署 Workflow 详细文档](.github/workflows/deploy-README.md)
- [GitHub Actions 官方文档](https://docs.github.com/en/actions)
- [Self-Hosted Runner 配置指南](https://docs.github.com/en/actions/hosting-your-own-runners)

---
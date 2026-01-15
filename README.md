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

### 仓库组织结构

```
tapdata/
├── ha-cicd-worker/              # CI/CD 工作流运行仓库（本仓库）
├── ha-cicd-patient/             # 患者端项目分组配置文件仓库
├── ha-cicd-hospital/            # 医院端项目分组配置文件仓库
└── ha-cicd-xxx/                 # 后续可继续添加新项目分组的配置文件仓库
```

**说明：**
- `ha-cicd-worker`：负责 CI/CD 工作流运行，包含所有自动化脚本和工作流定义
- `ha-cicd-patient`：存放 patient 项目分组的 Tapdata 配置文件
- `ha-cicd-hospital`：存放 hospital 项目分组的 Tapdata 配置文件
- `ha-cicd-xxx`：后续可继续添加新项目分组的配置文件仓库

### 当前仓库目录结构

```
ha-cicd-worker/
├── .github/
│   └── workflows/               # GitHub Actions 工作流定义
│       └── deploy.yml          # Tapdata 配置部署工作流
├── conf/                        # 配置文件目录
│   ├── env.conf                # 环境配置（dev/lpt/preprod/prod）
│   └── project.conf            # 项目分组配置
├── docs/                        # 文档目录
│   ├── deploy-README.md        # Tapdata 配置部署详细文档
│   ├── add-new-group.md        # 如何添加新的项目分组
│   └── add-new-env.md          # 如何添加新的Tapdata环境
├── scripts/                     # 自动化脚本
│   ├── tapdata_utils.py        # Tapdata 工具模块（共享函数）
│   ├── tapdata-get-token.py    # 获取 Access Token 脚本
│   ├── tapdata-import.py       # Tapdata 配置导入脚本
│   └── tapdata-check.py        # Tapdata 导入状态检查脚本
├── requirements.txt             # Python 依赖
└── README.md                   # 本文档
```

---

## 🚀 主要功能

### 1. Tapdata 配置部署

自动化部署配置到 Tapdata 平台，支持多环境、多项目分组。

**相关文档：**
- 📖 [Tapdata 配置部署文档](docs/deploy-README.md) - 详细的部署流程和使用说明
- ➕ [如何添加新的项目分组](docs/add-new-group.md) - 添加新项目分组的完整指南
- 🌍 [如何添加新的Tapdata环境](docs/add-new-env.md) - 添加新Tapdata环境的完整指南

---

## 🔧 技术栈

- **CI/CD 平台**: GitHub Actions
- **运行环境**: Self-Hosted Runner
- **脚本语言**: Python 3
- **依赖管理**: pip + requirements.txt
- **数据传递**: 共享文件系统 + Job Outputs
- **HTTP 客户端**: requests

---

## 📚 相关文档

- [Tapdata 配置部署文档](docs/deploy-README.md)
- [如何添加新的项目分组](docs/add-new-group.md)
- [如何添加新的Tapdata环境](docs/add-new-env.md)
- [GitHub Actions 官方文档](https://docs.github.com/en/actions)
- [Self-Hosted Runner 配置指南](https://docs.github.com/en/actions/hosting-your-own-runners)

---
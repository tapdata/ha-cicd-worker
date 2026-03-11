# ha-cicd-worker

## 项目简介

Tapdata 通过 CI/CD 自动化部署。本仓库是 CI/CD 工作流的执行中枢，负责编排和运行自动化部署流水线。

## 目录结构

```
ha-cicd-worker/
├── .github/
│   └── workflows/                    # GitHub Actions 工作流定义
│       ├── tapdata-deploy.yml        # Tapdata 部署工作流
│       └── tapdata-rollback.yml      # Tapdata 回滚工作流
├── conf/                             # 配置文件目录
│   ├── env.conf                      # 环境配置
│   └── project.conf                  # 项目分组配置
├── scripts/                          # 自动化脚本
│   └── tapdata-deploy/              # 部署相关脚本
│       ├── compress-files.sh         # 文件压缩
│       ├── generate-report.sh        # 生成部署报告
│       ├── generate-vault.sh         # 生成密钥配置
│       ├── get-last-stable-tag.sh    # 获取最近稳定标签
│       ├── get-token.sh              # 获取访问令牌
│       ├── import-resource.sh        # 导入资源
│       └── validate-inputs.sh        # 输入参数校验
├── requirements.txt                  # Python 依赖
└── README.md                        # 本文档
```
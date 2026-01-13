# Tapdata 配置部署 Workflow

## 概述

这个 workflow 用于将配置仓库的文件压缩并导入到 Tapdata 平台。

## 使用方法

1. 在 GitHub Actions 页面，选择 "tapdata配置部署" workflow
2. 点击 "Run workflow"
3. 选择参数：
   - **环境**: dev, lpt, preprod, prod
   - **项目分组**: patient, hospital
4. 点击 "Run workflow" 开始执行

## Job 命名说明

| Job ID | Job 名称 | 核心职责 |
|--------|---------|---------|
| `prepare` | 准备配置 | 准备配置文件和环境信息 |
| `import` | 导入配置 | 将配置导入到 Tapdata 平台 |
| `verify` | 验证结果 | 验证导入是否成功 |

> 💡 **设计理念**：Job 名称反映其核心职责，而非实现细节。例如 `prepare` 的核心是"准备配置"，虽然需要检出代码，但那只是实现手段。

## Workflow 流程

### Job 1: 准备配置 (prepare)
**核心职责**：准备配置文件和环境信息
- 检出当前仓库代码
- 创建共享目录（`/tmp/tapdata-deploy-{run_id}`）
- 从 `ha-cicd-worker/conf/project.conf` 读取配置仓库名称
- 检出配置仓库代码（main 分支）
- 压缩配置仓库为 tar.gz 文件，保存到共享目录
- 从 `ha-cicd-worker/conf/env.conf` 获取 Tapdata 地址
- **输出**：`config_repo`（配置仓库名）、`base_url`（Tapdata 地址）、`tar_path`（tar 文件路径）

### Job 2: 导入配置 (import)
**核心职责**：将配置导入到 Tapdata 平台
- 检出当前仓库代码（获取脚本）
- 从共享目录读取 tar 包
- 调用 Tapdata API 获取 access_token
- 上传 tar 文件到 Tapdata
- **输出**：`record_id`（导入任务 ID）

### Job 3: 验证结果 (verify)
**核心职责**：验证导入是否成功
- 检出当前仓库代码（获取脚本）
- 循环检查导入状态（每5秒检查一次）
- 状态处理：
  - `importing`: 继续等待
  - `completed`: 导入成功，退出
  - `failed`: 导入失败，打印错误信息并退出
- 清理共享目录（无论成功或失败都会执行）

## 配置文件

### project.conf
格式：`项目分组=仓库名称`

示例：
```
patient=tapdata/ha-cicd-patient
hospital=tapdata/ha-cicd-hospital
```

### env.conf
格式：`环境=Tapdata地址`

示例：
```
dev=http://dev.tapdata.com:3030
lpt=http://111.229.51.170:3030
preprod=http://preprod.tapdata.com:3030
prod=http://prod.tapdata.com:3030
```

## 脚本说明

### tapdata-import.sh
负责：
- 获取 access_token
- 上传 tar 文件
- 返回 record_id

### tapdata-check.sh
负责：
- 循环检查导入状态
- 处理不同的状态结果
- 格式化输出错误信息

## 超时设置

- 整体超时：30分钟（各 job 超时总和）
  - Job 1 (准备配置): 5分钟
  - Job 2 (导入配置): 20分钟
  - Job 3 (验证结果): 5分钟

## 数据传递方式

由于所有 job 都运行在同一个 `self-hosted` runner 上，使用**共享文件系统**传递数据：

- **共享目录**: `/tmp/tapdata-deploy-{run_id}`
  - 每次运行使用唯一的 run_id，避免冲突
  - 存储 tar 包文件（config.tar.gz）
  - 在最后一个 job 完成后自动清理

- **Job Outputs**: 传递简单数据（仓库名、URL、路径、ID 等）
  - `prepare.outputs.config_repo` → 配置仓库名称
  - `prepare.outputs.base_url` → Tapdata 地址
  - `prepare.outputs.tar_path` → tar 文件路径
  - `import.outputs.record_id` → 导入任务 ID

## 优势

1. **逻辑清晰**：每个 job 职责单一，易于理解
2. **便于调试**：可以清楚看到哪个阶段失败
3. **可以重试**：GitHub Actions 支持单独重试失败的 job
4. **高效传递**：使用共享文件系统，无需 artifacts 上传/下载
5. **自动清理**：使用 `if: always()` 确保共享目录被清理

## 注意事项

1. 确保 `GITHUB_TOKEN` 有权限访问配置仓库
2. 确保 env.conf 中配置了所有环境的 Tapdata 地址
3. 确保 project.conf 中配置了所有项目分组的仓库名称
4. 导入失败时会打印详细的错误信息，请查看日志


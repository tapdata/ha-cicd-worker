

# ha-cicd

这是一个专门用于运行 GitHub Actions 的仓库。

该仓库主要用于集中管理和执行 CI/CD 自动化流程，其中包含：

- `workflows/`：所有 GitHub Actions 工作流定义（YAML）
- `scripts/`：被工作流调用的脚本（构建、测试、发布、运维等）

该仓库本身不承载业务代码，而是作为自动化执行中枢，负责触发、编排并运行各类流水线任务。
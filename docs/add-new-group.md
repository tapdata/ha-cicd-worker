# 如何添加新的项目分组

本文档介绍如何在 CI/CD 系统中添加一个新的项目分组。

---

## 📋 前置条件

在开始之前，请确保：
- 你有 GitHub 组织的管理员权限
- 你了解新项目分组的业务需求
- 你已经准备好 Tapdata 配置文件

---

## 🚀 添加步骤

### 步骤 1：创建配置文件仓库

1. **在 GitHub 组织中创建新仓库**
   - 仓库名称格式：`ha-cicd-{项目分组名称}`
   - 例如：`ha-cicd-doctor`（医生端）、`ha-cicd-admin`（管理端）
   - 可见性：根据需要选择 Private 或 Public

2. **初始化仓库结构**
   ```bash
   # 克隆新创建的仓库
   git clone https://github.com/tapdata/ha-cicd-{项目分组名称}.git
   cd ha-cicd-{项目分组名称}
   
   # 添加 README
   echo "# {项目分组名称} Tapdata 配置文件" > README.md
   
   # 提交初始化
   git add .
   git commit -m "Initial commit"
   git push origin main
   ```

3. **添加 Tapdata 配置文件**
   - 将 Tapdata 导出的配置文件解压，可以看到一些json文件，直接放入仓库
   - 提交并推送
   ```bash
   git add .
   git commit -m "Add Tapdata config files"
   git push origin main
   ```

---

### 步骤 2：更新项目配置

在 `ha-cicd-worker` 仓库中更新配置文件：

1. **编辑 `conf/project.conf`**
   ```bash
   cd ha-cicd-worker
   vim conf/project.conf
   ```

2. **添加新的项目分组映射**
   ```properties
   # 在文件末尾添加新行
   {项目分组名称}=tapdata/ha-cicd-{项目分组名称}
   ```

   **示例：**
   ```properties
   patient=tapdata/ha-cicd-patient
   hospital=tapdata/ha-cicd-hospital
   doctor=tapdata/ha-cicd-doctor
   ```

3. **编辑 `.github/workflows/deploy.yml`**
   ```bash
   vim .github/workflows/deploy.yml
   ```

4. **添加新的项目分组选项**

   找到 `project_group` 的 `options` 部分（大约在第 15-21 行），添加新的分组选项：

   ```yaml
   project_group:
     description: '项目分组'
     required: true
     type: choice
     options:
       - patient
       - hospital
       - doctor        # 添加新的分组选项
   ```

5. **提交配置更改**
   ```bash
   git add conf/project.conf .github/workflows/deploy.yml
   git commit -m "Add new project group: {项目分组名称}"
   git push origin main
   ```

---

### 步骤 3：配置访问权限

确保 CI/CD 系统可以访问新的配置仓库：

1. **检查 PAT Token 权限**
   - 确认 `PAT_TOKEN` Secret 有访问新仓库的权限
   - 如果使用的是 Fine-grained token，需要添加新仓库的访问权限

2. **验证 Self-Hosted Runner 权限**
   - 确保 runner 有足够的权限克隆新仓库

---

### 步骤 4：测试新分组

1. **进入 GitHub Actions 页面**
   - 打开 `ha-cicd-worker` 仓库
   - 进入 Actions 标签页

2. **运行部署工作流**
   - 选择 "tapdata配置部署" workflow
   - 点击 "Run workflow"
   - 选择环境（如 `dev`）
   - 选择新添加的项目分组（如 `doctor`）
   - 点击 "Run workflow" 开始执行

3. **验证执行结果**
   - 查看工作流执行日志
   - 确认配置成功导入到 Tapdata
   - 检查 Tapdata 平台上的配置是否正确

---

## ✅ 完成检查清单

在完成添加新项目分组后，请确认以下事项：

- [ ] 新的配置仓库已创建并初始化
- [ ] Tapdata 配置文件已添加到新仓库
- [ ] `conf/project.conf` 已更新并提交
- [ ] `.github/workflows/deploy.yml` 已更新并提交
- [ ] PAT Token 有访问新仓库的权限
- [ ] 在 GitHub Actions 界面可以看到新的分组选项
- [ ] 已成功运行一次部署工作流测试
- [ ] Tapdata 平台上的配置验证正确

---

## 📝 示例：添加 doctor 分组

以下是添加 `doctor`（医生端）项目分组的完整示例：

### 1. 创建仓库
```bash
# 在 GitHub 上创建仓库：tapdata/ha-cicd-doctor
git clone https://github.com/tapdata/ha-cicd-doctor.git
cd ha-cicd-doctor
echo "# 医生端 Tapdata 配置文件" > README.md
# 添加配置文件...
git add .
git commit -m "Initial commit"
git push origin main
```

### 2. 更新配置
```bash
cd ha-cicd-worker

# 更新 project.conf
echo "doctor=tapdata/ha-cicd-doctor" >> conf/project.conf

# 更新 deploy.yml（手动编辑）
vim .github/workflows/deploy.yml
# 在 project_group 的 options 中添加 "- doctor"

# 提交更改
git add conf/project.conf .github/workflows/deploy.yml
git commit -m "Add new project group: doctor"
git push origin main
```

### 3. 测试部署
- 进入 GitHub Actions
- 运行 "tapdata配置部署" workflow
- 选择环境：`dev`
- 选择项目分组：`doctor`
- 验证执行结果

---

## ⚠️ 注意事项

1. **命名规范**
   - 仓库名称必须以 `ha-cicd-` 开头
   - 项目分组名称应简洁明了，使用小写字母
   - 避免使用特殊字符和空格

2. **配置文件管理**
   - 建议为每个环境维护独立的配置文件
   - 定期备份重要配置
   - 使用有意义的 commit message

3. **权限管理**
   - 严格控制配置仓库的访问权限
   - 定期审查 PAT Token 的权限范围
   - 生产环境配置需要额外的审批流程

4. **测试建议**
   - 先在 dev 环境测试新分组
   - 确认无误后再部署到其他环境
   - 保持配置文件的版本控制

---

## 🔗 相关文档

- [Tapdata 配置部署文档](deploy-README.md)
- [如何添加新的Tapdata环境](add-new-env.md)
- [PAT Token 配置指南](PAT-TOKEN-SETUP.md)
- [GitHub Actions 官方文档](https://docs.github.com/en/actions)


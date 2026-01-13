# Personal Access Token (PAT) 配置指南

## 问题背景

在 GitHub Actions 中检出其他仓库时，默认的 `GITHUB_TOKEN` 只有当前仓库的访问权限，无法访问组织内的其他仓库。这会导致 `actions/checkout` 在尝试检出配置仓库时返回 `404: Not Found` 错误。

## 错误日志示例

```
The repository will be downloaded using the GitHub REST API
To create a local Git repository instead, add Git 2.18 or higher to the PATH
Downloading the archive
404: Not Found
Waiting 11 seconds before trying again
Downloading the archive
404: Not Found
```

## 解决方案：创建 Personal Access Token

### 步骤 1：创建 PAT Token

1. 登录 GitHub，点击右上角头像 → **Settings**
2. 左侧菜单滚动到底部，点击 **Developer settings**
3. 点击 **Personal access tokens** → **Tokens (classic)**
4. 点击 **Generate new token** → **Generate new token (classic)**
5. 填写以下信息：
   - **Note**: `ha-cicd-workflow-token`（或其他描述性名称）
   - **Expiration**: 建议选择 `90 days` 或 `No expiration`（根据安全策略）
   - **Select scopes**: 勾选以下权限
     - ✅ `repo` (Full control of private repositories)
       - 这会自动勾选所有子选项

6. 滚动到底部，点击 **Generate token**
7. **重要**：复制生成的 token（格式类似 `ghp_xxxxxxxxxxxxxxxxxxxx`），离开页面后将无法再次查看

### 步骤 2：添加 Secret 到仓库

1. 进入 `tapdata/ha-cicd-worker` 仓库
2. 点击 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **New repository secret**
4. 填写以下信息：
   - **Name**: `PAT_TOKEN`
   - **Secret**: 粘贴刚才复制的 token
5. 点击 **Add secret**

### 步骤 3：验证配置

重新运行失败的 workflow，应该能够成功检出配置仓库。

## 替代方案：使用 GitHub App Token（企业推荐）

如果你的组织使用 GitHub Enterprise，建议使用 GitHub App Token，它提供更细粒度的权限控制和更好的安全性。

### 优势
- 更细粒度的权限控制
- 可以限制访问特定仓库
- 更好的审计日志
- Token 自动轮换

### 配置步骤
1. 创建 GitHub App
2. 安装到组织
3. 使用 `actions/create-github-app-token` action 生成临时 token

详细步骤请参考：[GitHub App Token 配置指南](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/making-authenticated-api-requests-with-a-github-app-in-a-github-actions-workflow)

## 安全建议

1. **定期轮换 Token**：建议每 90 天更换一次 PAT
2. **最小权限原则**：只授予必要的权限（本例中只需要 `repo` 权限）
3. **使用 Secret**：永远不要在代码中硬编码 token
4. **监控使用情况**：定期检查 token 的使用日志

## 常见问题

### Q1: 为什么不能使用默认的 GITHUB_TOKEN？
**A**: `GITHUB_TOKEN` 是 GitHub Actions 自动生成的临时 token，出于安全考虑，它只有当前仓库的访问权限，无法访问其他仓库（即使在同一个组织下）。

### Q2: PAT Token 过期后会怎样？
**A**: Workflow 会再次失败并返回 401 或 403 错误。你需要重新生成 token 并更新 Secret。

### Q3: 可以使用组织级别的 Secret 吗？
**A**: 可以！如果多个仓库需要访问配置仓库，建议在组织级别创建 Secret，这样所有仓库都可以使用。

步骤：
1. 进入组织页面 → **Settings** → **Secrets and variables** → **Actions**
2. 点击 **New organization secret**
3. 选择哪些仓库可以访问这个 Secret

### Q4: 如何验证 Token 是否有效？
**A**: 可以使用以下命令测试：
```bash
curl -H "Authorization: token YOUR_PAT_TOKEN" \
     https://api.github.com/repos/tapdata/ha-cicd-patient
```
如果返回仓库信息，说明 token 有效且有权限访问。

## 相关文档

- [GitHub Personal Access Tokens 官方文档](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [GitHub Actions Secrets 官方文档](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [actions/checkout 官方文档](https://github.com/actions/checkout)


# 如何添加新的Tapdata环境

本文档介绍如何在 CI/CD 系统中添加一个新的 Tapdata 部署环境。

---

## 📋 前置条件

在开始之前，请确保：
- 你有 GitHub 仓库的管理员权限
- 新环境的 Tapdata 服务已经部署并可访问
- 你了解新环境的网络配置和访问方式

---

## 🚀 添加步骤

### 步骤 1：更新环境配置

在 `ha-cicd-worker` 仓库中更新环境配置文件：

1. **编辑 `conf/env.conf`**
   ```bash
   cd ha-cicd-worker
   vim conf/env.conf
   ```

2. **添加新的环境映射**
   ```properties
   # 在文件末尾添加新行
   {环境名称}={Tapdata服务地址}
   ```
   
   **示例：**
   ```properties
   dev=http://dev.tapdata.com:3030
   lpt=http://111.229.51.170:3030
   preprod=http://preprod.tapdata.com:3030
   prod=http://prod.tapdata.com:3030
   uat=http://uat.tapdata.com:3030
   ```

3. **编辑 `.github/workflows/deploy.yml`**
   ```bash
   vim .github/workflows/deploy.yml
   ```

4. **添加新的环境选项**
   
   找到 `env` 的 `options` 部分（大约在第 6-14 行），添加新的环境选项：
   
   ```yaml
   env:
     description: '环境'
     required: true
     type: choice
     options:
       - dev
       - lpt
       - preprod
       - prod
       - uat          # 添加新的环境选项
   ```

5. **提交配置更改**
   ```bash
   git add conf/env.conf .github/workflows/deploy.yml
   git commit -m "Add new environment: {环境名称}"
   git push origin main
   ```

---

### 步骤 2：配置网络访问

确保 CI/CD 系统可以访问新环境的 Tapdata 服务：

1. **检查网络连通性**
   ```bash
   # 在 self-hosted runner 上测试连接
   curl -I {Tapdata服务地址}/api/health
   ```

2. **配置防火墙规则**（如果需要）
   - 确保 self-hosted runner 的 IP 地址在新环境的白名单中
   - 开放必要的端口（通常是 3030）

3. **配置 VPN 或内网访问**（如果需要）
   - 确保 runner 可以访问内网环境
   - 配置必要的路由规则

---

### 步骤 3：验证 Tapdata 服务

确认新环境的 Tapdata 服务配置正确：

1. **检查服务状态**
   - 访问 Tapdata 管理界面
   - 确认服务正常运行

2. **验证 API 访问**
   ```bash
   # 测试 API 是否可访问
   curl {Tapdata服务地址}/api/health
   ```

3. **确认认证配置**
   - 确保 Tapdata 的认证方式与脚本兼容
   - 验证用户名密码等凭证

---

### 步骤 4：测试新环境

1. **进入 GitHub Actions 页面**
   - 打开 `ha-cicd-worker` 仓库
   - 进入 Actions 标签页

2. **运行部署工作流**
   - 选择 "tapdata配置部署" workflow
   - 点击 "Run workflow"
   - 选择新添加的环境（如 `uat`）
   - 选择一个测试项目分组（如 `patient`）
   - 点击 "Run workflow" 开始执行

3. **验证执行结果**
   - 查看工作流执行日志
   - 确认可以成功获取 access token
   - 确认配置成功导入到 Tapdata
   - 检查 Tapdata 平台上的配置是否正确

---

## ✅ 完成检查清单

在完成添加新环境后，请确认以下事项：

- [ ] 新环境的 Tapdata 服务已部署并正常运行
- [ ] `conf/env.conf` 已更新并提交
- [ ] `.github/workflows/deploy.yml` 已更新并提交
- [ ] Self-hosted runner 可以访问新环境的 Tapdata 服务
- [ ] 在 GitHub Actions 界面可以看到新的环境选项
- [ ] 已成功运行一次部署工作流测试
- [ ] Tapdata 平台上的配置验证正确
- [ ] 网络连接稳定，无超时问题

---

## 📝 示例：添加 uat 环境

以下是添加 `uat`（用户验收测试）环境的完整示例：

### 1. 更新配置
```bash
cd ha-cicd-worker

# 更新 env.conf
echo "uat=http://uat.tapdata.com:3030" >> conf/env.conf

# 更新 deploy.yml（手动编辑）
vim .github/workflows/deploy.yml
# 在 env 的 options 中添加 "- uat"

# 提交更改
git add conf/env.conf .github/workflows/deploy.yml
git commit -m "Add new environment: uat"
git push origin main
```

### 2. 验证网络连接
```bash
# 在 runner 上测试连接
curl -I http://uat.tapdata.com:3030/api/health

# 预期输出：HTTP/1.1 200 OK
```

### 3. 测试部署
- 进入 GitHub Actions
- 运行 "tapdata配置部署" workflow
- 选择环境：`uat`
- 选择项目分组：`patient`
- 验证执行结果

---

## ⚠️ 注意事项

1. **环境命名规范**
   - 使用小写字母
   - 使用简短、有意义的名称
   - 常见环境名称：`dev`（开发）、`test`/`lpt`（测试）、`uat`（用户验收）、`preprod`（预生产）、`prod`（生产）

2. **网络安全**
   - 生产环境应配置严格的访问控制
   - 使用 HTTPS 而不是 HTTP（如果可能）
   - 定期审查防火墙规则和访问日志

3. **配置管理**
   - 不同环境的配置应该隔离
   - 生产环境的部署需要额外的审批流程
   - 建议使用不同的 Tapdata 实例

4. **测试建议**
   - 先在非生产环境测试
   - 确认所有功能正常后再添加生产环境
   - 保持环境配置的文档更新

5. **故障排查**
   - 如果连接失败，检查网络连通性
   - 如果认证失败，检查 Tapdata 服务配置
   - 查看 GitHub Actions 日志获取详细错误信息

---

## 🔗 相关文档

- [Tapdata 配置部署文档](deploy-README.md)
- [如何添加新的项目分组](add-new-group.md)
- [GitHub Actions 官方文档](https://docs.github.com/en/actions)


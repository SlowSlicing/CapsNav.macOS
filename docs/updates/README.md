# 更新检查目录说明

这个目录用于托管 Caps Nav 给客户端读取的在线更新元数据。

## 文件说明

- `latest.json`
  - 当前最新版本的更新描述
  - 由 GitHub Release 发布 workflow 自动生成
  - 默认不建议手工修改

## `latest.json` 字段

- `version`
  - 严格三段数字版本号，例如 `0.0.2`
- `publishedAt`
  - Release 发布时间，使用 ISO 8601
- `minimumSystemVersion`
  - 当前版本最低支持的 macOS 版本
- `pageURL`
  - GitHub Release 页面地址
- `downloadURL`
  - 当前 DMG 资产下载地址
- `notesMarkdown`
  - GitHub Release 中手写的 Markdown 更新说明

## 发布方式

正常情况下，维护者先手动创建 GitHub Release 和 tag，再由 workflow 自动：

1. 构建未正式签名的 dev DMG
2. 上传资产到该 Release
3. 生成或更新 `latest.json`
4. 提交回 `main` 分支

由于 GitHub Pages 来源配置为 `main/docs`，一旦 `latest.json` 被提交到 `docs/updates/`，页面会自动重新部署。

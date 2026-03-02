---
globs: "**/*.swift,**/*.kt,**/*.dart,**/Podfile,**/build.gradle*,**/pubspec.yaml,**/*.xcodeproj/**"
description: "移动端规则 — 编辑移动应用代码时自动注入"
---

## 移动端开发纪律

### 平台意识
- 修改前确认是 iOS only / Android only / 跨平台共享代码
- 平台特有 API 调用要检查最低版本支持
- 权限请求（相机、位置、通知等）必须有对应的用途说明

### 性能与体验
- UI 操作必须在主线程，耗时操作必须在后台线程
- 列表渲染注意复用机制（UITableView reuse / RecyclerView / ListView.builder）
- 内存敏感 — 图片加载要考虑缓存和缩放策略

### 禁止事项
- 禁止硬编码字符串 — 使用本地化机制
- 禁止忽略应用生命周期 — 后台、前台切换时资源的释放与恢复
- 禁止不经确认就修改 Info.plist / AndroidManifest.xml

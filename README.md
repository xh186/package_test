# Ledger Mobile

Flutter 安卓端迁移工程，采用暖纸色 Ledger 视觉风格。

## 运行

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://your-ledger.example.com
```

`API_BASE_URL` 默认要求 HTTPS。请把现有 C++ 服务部署在 HTTPS 反向代理之后，再替换为实际地址；这也符合 Android 的默认网络安全策略。

## 数据策略

- 首屏先读取 `shared_preferences` 中的本地账目和子账本。
- 云端请求携带上次响应的 `ETag`；服务端返回 `304` 时不替换本地数据。当前 C++ 服务尚未提供 `ETag` 时，客户端会以响应 JSON 作为版本标识，内容相同则不重写缓存。
- 新增、编辑、删除先写本地，再进入待同步队列；同步成功后逐项移除队列。会话 Cookie 使用平台安全存储，账目缓存使用本地偏好存储。
- 网络不可用时仍可记账，页面会显示离线缓存状态。

## 当前范围

已迁移总账本、全部账目搜索/筛选、快速记账、编辑/删除、子账本、统计柱状图、日历和当日账目入口。登录页面和服务端认证沿用现有 API，待后续接入产品化登录流程。

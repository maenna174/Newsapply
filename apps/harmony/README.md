# 今日十条 HarmonyOS NEXT

这是新闻 App 的纯血 HarmonyOS NEXT 第一版骨架，使用 ArkTS + ArkUI。

当前版本包含：

- 今日十条列表
- 新闻详情页
- 入选理由展示
- 非个性化原则说明
- 本地 mock 数据

后续接入后端时，保持客户端只读取服务端发布的每日版本，不在本端按用户行为重排。

## 本机检查

```bash
NODE_HOME=/Applications/DevEco-Studio.app/Contents/tools/node \
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw tasks --no-daemon
```

也可以直接用 DevEco Studio 打开 `apps/harmony` 目录预览和运行。当前版本先使用本地 mock 数据，下一步再接入 `GET /editions/today`。

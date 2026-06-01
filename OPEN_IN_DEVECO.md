# DevEco 打开方式

优先在 DevEco Studio 里选择打开这个独立目录：

```text
/Users/mac/news-harmony
```

这是从工作区复制出来的纯 HarmonyOS 工程，路径更短，DevEco 更容易识别。

源码主目录仍保留在：

```text
/Users/mac/news/apps/harmony
```

不要打开 `/Users/mac/news`，因为它是总工作区，里面还放了产品文档和其他端的目录，不是 HarmonyOS 工程根目录。

如果 DevEco 仍提示依赖未同步，先在工程根目录执行：

```bash
NODE_HOME=/Applications/DevEco-Studio.app/Contents/tools/node \
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw tasks --no-daemon
```

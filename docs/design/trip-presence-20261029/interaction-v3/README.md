# Roamorrow 交互 V3：打开就是对话

本轮方向来自用户明确选择的 Muse 对话结构：聊天为首页，地图为辅助呈现，输入框下面保留清楚的内容导航。

- [完整交互说明](../interaction-v3.md)
- [可点击稿](prototype.html)
- [三状态设计板](renders/conversation-first.png)
- [12秒 UI 状态演示](renders/conversation-first.mp4)
- [HyperFrames 短片源](film/index.html)
- [设计 QA](design-qa.md)
- [验证范围](verification.json)
- [素材来源](CREDITS.md)

预览复用当前上级目录的本机服务；独立查看时可在此目录启动 `python3 -m http.server 8343 --bind 127.0.0.1`，使用空闲端口，不终止别人的服务。

可以输入并连续发消息、在四个导航间切换、收藏体验、展开地图、查看来源、预览/确认/撤销一站、新建和恢复当前页面内的对话。资料、权限和语音转写有说明性弹层；没有读取任何文件或调用系统权限。

键盘图是位置示意，文字仍在输入框中编辑。原型是既有设计资料的迭代，继续使用轻量 HTML，没有创建新的产品运行时或接入后端。演示商家、来源、路线和时间都不构成真实出行建议，刷新会恢复初始状态。

设计板可用 `hyperframes snapshot . --at 0.5 --no-end` 导出；短片使用 `hyperframes render film --workers 1 --low-memory-mode --fps 30`，12秒、1920×1080、无音轨。检查给可滚动消息区和实际覆盖它的固定栏标记了有意裁切/遮挡；没有将正文错误隐藏来通过检查。

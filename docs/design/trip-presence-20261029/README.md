# Roamorrow — 下一步，已经在这里

[Linear GET-324](https://linear.app/getyak/issue/GET-324/redesign-the-ios-trip-companion-around-truth-presence-and-spending)

围绕 Trip truth → Presence → 花钱确认重新组织 iPhone 主场景。包含设计方案、六屏设计板、可点击的 HTML 原型和 46 秒 1080p UI 概念视频。所有行程、航班、票价、退款条款与系统确认区域均为演示数据或设计示意。

- [完整设计方案](design.md)
- [首页、侧栏与行程真相设计板](renders/design-structure.png)
- [花钱、记忆与锁屏设计板](renders/design-control.png)
- [46 秒 UI 视频](renders/roamorrow-presence.mp4)
- [可点击原型源码](prototype.html)
- [分镜与视频脚本](video-script.md)
- [审查与边界](REVIEW.md)
- [验证摘要](verification.json)
- [素材署名](CREDITS.md)

## 2026-10-30 对话优先 V3（当前方向）

用户明确选择打开即对话，地图作为辅助呈现。V3 采用“对话 / 行程 / 收藏 / 我的”四项导航，输入框独立在上方，键盘出现时导航让位。

- [完整交互规范 V3](interaction-v3.md)
- [V3 可点击稿、设计板和短片](interaction-v3/README.md)

以下 V1 / V2 保留为探索记录，当前入口与导航以 V3 为准。

## 2026-10-30 交互深化 V2

本轮围绕现有 iOS 进一步明确“地图 + 当前任务面板 + 低频资料侧栏”。AI 作为输入与解释方式，候选查看、调整预览、确认写入和实际执行分别表达。V2 的地图首页方向已被用户否定，由上面的 V3 替代。V1 / V2 仅作过程资料保留。

- [完整交互规范 V2](interaction-v2.md)
- [V2 三状态设计板](interaction-v2/renders/interaction-overview.png)
- [V2 可点击稿及使用说明](interaction-v2/README.md)

## 查看与编辑

在本目录执行 `python3 -m http.server 8341 --bind 127.0.0.1`，然后用浏览器打开 `http://127.0.0.1:8341/prototype.html`。如端口正在被使用，选择空闲端口，不要关闭其他任务的服务。

界面入口可切换此刻、功能侧栏、行程、真相、付款、记忆和锁屏。侧栏里的预算页区分计划金额与已支付金额。确认、删除和归档仅改变当前浏览器内存中的演示状态；刷新后重置。没有真实支付、出票、定位、邮件连接或模型调用。

视频使用 HyperFrames 0.8.216，可运行：

```sh
npx --yes hyperframes@0.8.216 check --json
npx --yes hyperframes@0.8.216 preview --background
npx --yes hyperframes@0.8.216 render --quality delivery --workers 1 --output renders/roamorrow-presence.mp4
```

入口为 `index.html`，场景在 `compositions/`，共享 UI 与交互在 `assets/`。字体引用本机 PingFang SC / Helvetica Neue，未分发字体文件；在其他系统编辑时需提供有授权的字体替换。视频图标采用源 Lucide SVG 的 data URI，避免渲染器对相对路径的改写。

## 验证范围

HyperFrames 的 lint、浏览器运行、布局、时间轴和音频检查通过。人工检查了关键帧和真实成片解码帧，并在浏览器点验主要确认流程。独立审查发现的两项 P1 已修复并复核。小字号原生信息、阅读停留和支付遮罩下的非活动内容有已解释的工艺/对比度警告，见 `REVIEW.md`。

此交付没有修改 SwiftUI 产品代码，没有进行 Simulator、真机、完整 VoiceOver、ActivityKit、真实离线持久化或供应商支付验收。原生实施需按设计方案另行推进。

音乐署名："Dream Culture" Kevin MacLeod (incompetech.com)，[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)。本视频使用裁剪并淡入淡出的片段；发布或分享时保留此署名。地图与图标来源详见 `CREDITS.md`。

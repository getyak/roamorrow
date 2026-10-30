# 素材与参考

- 方向依据：用户已确认的 V4 产品选择；视觉延续 [V3](../interaction-v3/README.md)。V4 没有读取或复制私人参考图、聊天内容或账号信息。
- 旅行伙伴：仓库现有 iOS `CompanionCharacter.imageset/character-c.png`；咖啡图：现有 `StudioCoffee.imageset/coffee.png`。通过 V3 的本地素材链接复用，未重新生成。
- 图标：Lucide 0.468.0（ISC）。V3 从官方 npm 包 `lucide-static` 的 SVG 转为 data URI，V4 复用同一 `data.js` 与 [许可证](assets/LUCIDE-LICENSE.txt)。
- 地图：© OpenStreetMap contributors。9 张既有栅格瓦片及 [元数据](assets/maps/metadata.json) 从 V3 复用；[OpenStreetMap 版权说明](https://www.openstreetmap.org/copyright)。底图是真实地图，图钉、虚构商家及演示范围不构成地点、路线或营业核验；渲染期间不请求在线瓦片。
- 键盘占位图：V3 已有素材，来自本机 Product Design 插件 mobile-app 模板的 `public/assets/iphone/Keyboard.png`。它仅表示屏幕占用区域，不是原生系统键盘录屏或可用输入法的证据。
- 字体：沿用系统字体回退，不分发 Apple 字体文件；中文按本机可用字体呈现，不承诺跨系统逐像素一致。
- 演示运行库：既有 GSAP 3.14.2 本地文件，无新增网络运行库、音乐、音效、配音或音轨。

V4 设计板和短片直接使用同一套 HTML 状态。它们是可评审的 UI 设计源，不是已上线 App、原生录屏、真实定位或服务执行结果。

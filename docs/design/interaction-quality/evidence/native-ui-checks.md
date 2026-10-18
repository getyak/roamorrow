# 原生实际界面与点击

版本：snapshot-03；Primary iPhone/iPhone17Pro/iOS26.5；同一 dev-ios-session 单设备会话。这里只记录实际观察，不代表全部892候选已测试。

1. Debug 启动参数 `-devSkipOnboarding -startCity cmi`：实际地图显示5个体验、地图/问问/发现稳定Dock；首屏不再有独立收藏/行程整行。`ios-after-map.png`。
2. 点击“地图选项与资料库”：菜单实际显示我的收藏、我的行程、标准/卫星/混合，标准有选中语义。
3. 菜单“我的收藏”打开真实收藏页，实际读回1个现有收藏；未修改收藏数据。点击完成返回地图。

注意：before-map使用无效调试城市slug `chiang-mai`，after使用canonical `cmi`；城市标题变化来自启动参数，不记作产品修复。after初始没有诊断卡也可能由当日启动提示预算决定；不能把提示缺席当作诊断版式优化的证明，后续用显式synthetic launch argument单独验证。

4. 地图选项→我的行程打开真实行程列表，保留既有记录，点击完成返回。
5. Ask Solo输入实际键盘文字 `UI QA draft`；地图→问问切换后AX读回相同全文。无AI配置时点发送，显示去设置的提示，草稿仍在；随后用实际键盘 Command+A、Backspace 清空本任务文字，地图→问问再次读回为空（AX setValue 不会提交 SwiftUI binding，未将其作为成功证据）。没有调用实际AI或发送好友消息。


## Snapshot04b 复测

- 56文件源码快照/完整补丁与build-for-testing独立核对一致；AdaptiveActionContrastTests实际3例通过，分别覆盖明色前景、暗色卡片/底板前景、白字深棕填充对比。未把它们当作触控测试。
- Primary iPhone、同一dev-ios-session：`-forceDiagnosticsMulti`显式合成诊断截图 `ios-after-map-diagnostics.png`，提示位于滤栏下方，关闭和CTA分别可见；合成的“定位被拒”不代表当前真实系统权限。
- `-openChatMedium`调试入口渲染问问；深色/最大辅助字号（accessibility-extra-extra-extra-large）截图 `ios-after-ask-dark-axxxl.png`：城市文字与加号采用浅琥珀前景，输入框和Dock不重叠，配置提示在独立滚动区，设置CTA可随内容滚动。对照 `ios-before-axxxl-fix.png`。
- 独立复核发现名为dark/light-final的两张即时截图字节相同，画面仍为暗色AXXXL，已从正式证据移除；没有04b默认large或明色通过结论。只记录暗色AXXXL渲染E2：这一轮Simulator的CUA原生AX连接丢失，未把调试入口当成实际点击，也未声称设置CTA/新配置后恢复已获得E3；调用链由独立review确认不会自动开启麦克风。
- 本轮测试前appearance=light、content_size=large；结束的复原命令均返回0；这不代表截图已切到目标状态，未另外读回模式，不作为明色/默认字号验收。helper关闭本任务启动的Primary并释放会话。未触碰辅助设备或其他任务服务。

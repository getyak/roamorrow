# Web 实际操作验收

日期：2026-10-16，隔离分支 `codex/interaction-quality`。通过 Codex 内置浏览器 CUA 操作本机 Next 15.5.27，未使用私密生产配置。最终源码清单：`snapshot-web-final-files.json`；补丁：`snapshot-web-final.patch.gz`。下述操作发生于实现过程中，最后文案/格式修改由源码复核与最终构建补充；不是所有路径均在最终冻结后重跑。

## 已观察的行为

| 范围 | 实际操作与结果 | 边界 |
| --- | --- | --- |
| 官网首屏 | 1280桌面、390手机、320中英文渲染；主CTA在首屏可见，320无横向页面溢出 | 浏览器截图显示在工具记录，未保存为独立PNG；不是用户满意度测试 |
| 移动导航 | 打开菜单→Tab到Features→Escape；菜单收起，焦点回到Open menu；中文切换后实际 `/zh` 与中文h1 | 测试键盘路径，未运行真实屏幕阅读器 |
| 深色与减少动效 | 仿真prefers-color-scheme=dark、prefers-reduced-motion=reduce；深底浅字、琥珀主CTA；reveal animationName=none。边框修复后读回#3A3329 | 仿真作用于测试标签；结束已清除仿真与viewport覆盖 |
| 真实地图入口 | 官网打开地图→`/app`；缺Mapbox token时仍能读取5个开发样本，明确样本/地图暂不可用 | 没有有效token场景或真实定位权限验收 |
| 附近面板 | 320×740输入Quiet cafe draft→ArrowUp展开→输入隐藏且值保留→Escape收起→输入恢复原值；随后清空测试草稿。main不再aria-hidden，收起时不挂载不可见列表 | 旧Vaul常驻Drawer曾将main设为aria-hidden=true；已改为非模态语义section。没有用隐藏节点充当可用功能 |
| 体验打卡失败 | 打开样本体验→4分→明确提交→Saving禁用→服务缺配置返回502；显示保存失败与保留评分，Retry为44px，仍可重试 | 这是负向验收；没有写入真实完成记录，不等于后端保存成功 |
| 详情焦点 | 实际Close关闭详情，dialog消失，main可访问，焦点返回原Ristr8to推荐按钮 | 实际键盘/焦点读回 |
| 手机城市指南 | 320宽；Experiences列表铺满→选第一张卡→Illustrated map选中、地图320宽、详情x12/w296且可滚动→View experience→真实`/experience/miradouro-graca?lang=en`→View in city guide→带experience参数回到正确详情 | 地图、位置与步行时间明确为指南示意，不冒充实时位置/导航 |
| 城市排序与入口 | 官网手机菜单Cities→Lisbon；Walk time→URL sort=walk且首项Tram28/4min；1280桌面恢复480列表+800地图双栏 | 数据为指南固定样本；没有实时步行路线验收 |
| 命令面板 | 打开→Tab移动到Lisbon guide动作→Enter；面板关闭，实际导航Lisbon而非旧activeIdx的首页 | Enter只在输入框执行搜索选项；按钮保留原生激活 |
| 分发与政策说明 | Pricing入口实际到/download；未配置商店链接时明确网页地图可用。实际打开/privacy，正文包含DeepSeek/Overpass且无Paddle承诺 | 未配置真实App Store/TestFlight URL；没有购买/发布/法律有效性验收 |
| 手机交互预览 | 最后冻结前320×740实际刷新：scrollWidth=320、main存在、地图marker按钮数0，7个可见按钮高度均44。点两个演示打卡→选中与明确预览提示；刷新→aria-pressed=true数量0 | 预览只保留React内存状态；不写真实打卡、无自动记录承诺 |

## 验收约束

- 未授予定位、相机或麦克风权限，未向真实联系人发消息，未购买订阅，未使用其他账号。
- 未实测有效Mapbox token下的error→retry重建和新markers绑定；源码已修复mapReady复位，仍记运行待验。
- 没有E4代表性用户任务证据，因此不能认证全部控件体验超过96分。
- 最终编译/测试结果另见 `web-final-validation.md`；开发服务器成功渲染不代替生产构建。

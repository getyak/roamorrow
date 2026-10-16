# 本机实际交互抽样 · round02

Primary iPhone，最新build-final（后续视觉/付款修订前），通过共享dev-ios-session持有会话。

- 打开空城市工具包，点击“填入境日”，表单显示日期和空天数输入，Save禁用。
- 填30，Save可用；保存后回工具包，剩余29天（到达日按第1天计）、183天计数182，提醒开关关闭。没有请求通知/定位/录音权限。
- 点击修改，重开读回2026-10-16和30；Cancel保留已保存值。
- 最大辅助字号accessibility-extra-extra-extra-large下，标题两行、计数、提醒和修改均可见，没有遮挡；截图为round02-kit-saved-ax5-live.png。结束恢复large字号。
- 三张live PNG是实际模拟器截图，round02-native-snapshots/是UIHostingController渲染。两者不混称完整点击验收。
- 后续付款/表单字段及视觉修订需另读新验收证据，不复用此图声称新版已测。


## 新版首次使用与商品加载（Primary iPhone）

实际用DEBUG的forceOnboarding/onboardingStep7进入末步，未点击绑定条款确认。查看Pro方案→共享Paywall，真实StoreKit当前没有商品时显示价格不可用与重试。点击重试只请求加载，失败仍保留方案页；修正后alert标题实际读回“方案加载失败”，不是“购买未完成”。关闭子页实际返回首次使用第7步，未冒充购买成功/完成引导。没有点击Subscribe，没有触发Apple购买确认或发送消息。

正式截图：round02-onboarding-neutral-live.png、round02-paywall-no-catalog-live.png、round02-onboarding-after-plans-close-live.png、round02-paywall-load-error-live.png。前3图属于visual-accepted构建，最后错误标题图属于visual-correction构建；后续badge修正不涉及此调用链。

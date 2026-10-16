# 原生检查点 03

- 基线：924f09a4；51文件快照SHA和补丁经独立评审核对。
- 完整补丁SHA-256：c962cf1135d3d3e7708dbd3f876ef1a302694c77e2a95bbc29fa8087fa1c843c。
- build-for-testing：TEST BUILD SUCCEEDED；两次编译前一轮私有setter错误已修在SubscriptionService恢复入口，未放宽setter。
- test-without-building：11个受影响测试类，实际80例，80通过、0失败、0跳过。读回xcresult汇总见checkpoint-03-tests.json。
- 关键回归：实际ChatService失败/部分成功/空文字附件重试、过长消息拒绝、扫码排队启动守卫、可见性恢复、购买恢复结果、真实归档记录、撤销时限和滤栏逻辑。
- 设备：仅Primary iPhone /iPhone17Pro /iOS26.5，由dev-ios-session持有测试会话。未启动辅助设备、创建克隆或发送真实好友消息。
- 80个逻辑测试不等于所有按钮已实测，不代表真实用户满意度96。当前源码无未解决确认P0/P1；仪式仍有明确预览/只读业务范围，法律URL待用户提供。

后续截图和实际点击记录单独保存；不把源码修复或编译当作视觉认证。

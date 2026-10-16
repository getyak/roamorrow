# 原生检查点 01

- 源基线：924f09a4；当前补丁 SHA-256：0c71706b0dc6f0722894bf44ce87f3111a65515b69b1bdb5c09fd31b79b374cf。
- 19个导入文件的SHA经独立reviewer逐一核对；不包括后续仍在实现的改动。
- 设备：Primary iPhone /iPhone17Pro/iOS26.5；仅单设备，禁止并发克隆；由dev-ios-session持锁，结束关闭本任务启动设备。
- Xcode `build-for-testing`：TEST BUILD SUCCEEDED。
- `test-without-building`：VisibilityOffRecoveryTests实际运行3例，3通过、0失败。结果读回见checkpoint-01-tests.json。
- Pressable测试的类名已由实现者改成PressableButtonStyleFeedbackTests，旧过滤名未命中，故本次不算它通过；下一检查点使用新名。
- 仍有本地化键、恢复/购买互斥、旧错误、点击shape等待修；构建/3测试不能证明所有交互达标。

正式测试日志与结果暂存于登记产物目录，最终源码验收后归档必要证据并精确清理；未将先前基线当成最终版通过。

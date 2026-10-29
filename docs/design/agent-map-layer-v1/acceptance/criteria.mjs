// Versioned acceptance points, not a statistical uptime/reliability estimate.
export const rubricVersion = "map-chain-v1.0";
const c = (id, points, title, kinds, critical = true) => ({ id, points, title, kinds, critical });
export const segments = [
  {
    id: "agent",
    title: "Agent 与 MCP 接入",
    points: 12,
    cases: [
      c("A1", 5, "目标 Grok API 真实远程 MCP 调用", ["grok_remote"]),
      c("A2", 3, "模型独立完成创建与后续编辑，未由脚本补全调用", ["agent_journey"]),
      c("A3", 2, "工具发现、schema 与授权真实兼容", ["mcp_live"]),
      c("A4", 2, "模型只返回实际地图 URL，读回正确版本", ["agent_journey"]),
    ],
  },
  {
    id: "places",
    title: "地点与来源可信度",
    points: 20,
    cases: [
      c("B1", 6, "全部地点来自真实 provider，保留实体与来源证据", ["places_live"]),
      c("B2", 4, "坐标轴序、东京边界与重复点核验", ["places_live"]),
      c("B3", 3, "歧义地名不静默选错地点", ["places_live"]),
      c("B4", 3, "不存在地点不编造，不回退演示坐标", ["places_live"]),
      c("B5", 4, "来源修订/获取时间与营业信息未知如实显示", ["places_live"]),
    ],
  },
  {
    id: "routing",
    title: "路线与时间排程",
    points: 20,
    cases: [
      c("C1", 7, "真实指定交通模式的路网与耗时", ["routes_live"]),
      c("C2", 4, "日期/时区/日窗口与行程可行性", ["routes_live"]),
      c("C3", 4, "换天自动顺路重排，明确插入保留手排", ["routes_live"]),
      c("C4", 3, "预约锁日、未知交通与已知时长下界", ["routes_live"]),
      c("C5", 2, "实际 geometry 跟随街道且坐标与时间轴一致", ["routes_live", "browser_live"]),
    ],
  },
  {
    id: "persistence",
    title: "持久化与分享",
    points: 14,
    cases: [
      c("D1", 4, "重启后地图/授权持久化，事务正确", ["persistence_live"]),
      c("D2", 3, "新浏览器从分享 URL 读取实际结果", ["browser_live"]),
      c("D3", 2, "访客副本有新身份且不修改原图", ["browser_live"]),
      c("D4", 3, "独立并发请求的版本与幂等保护", ["concurrency_live"]),
      c("D5", 2, "分享链接只读最新公开集合，不泄漏新私有点", ["persistence_live"]),
    ],
  },
  {
    id: "interaction",
    title: "地图操作",
    points: 16,
    cases: [
      c("E1", 5, "真实指针拖动，两天原子更新同版本", ["browser_live"]),
      c("E2", 3, "地图/时间轴/路线双向选中与更新", ["browser_live"]),
      c("E3", 3, "撤销/刷新/后续冲突行为正确", ["browser_live"]),
      c("E4", 3, "手机宽度、键盘替代、触控目标通过", ["browser_live"]),
      c("E5", 2, "提供商失败回滚并可重试", ["browser_live"]),
    ],
  },
  {
    id: "privacy",
    title: "权限与隐私",
    points: 12,
    cases: [
      c("F1", 3, "所有者与访客/其他租户隔离", ["security_live"]),
      c("F2", 3, "公开 stop allowlist 与几何投影一致", ["security_live"]),
      c("F3", 3, "链接撤销、过期和重复使用真实验证", ["security_live"]),
      c("F4", 3, "URL/日志/截图不包含凭据与私有旅行资料", ["security_live"]),
    ],
  },
  {
    id: "stability",
    title: "稳定性与速度",
    points: 6,
    cases: [
      c("G1", 3, "同候选 10 个端到端场景全部通过关键关卡", ["repeat_live"]),
      c("G2", 2, "实际 p95：snapshot≤500ms、更新≤2s、反馈≤100ms", ["performance_live"]),
      c("G3", 1, "格式、空态、错误信息与无 console error", ["browser_live"], false),
    ],
  },
];
export const allCases = segments.flatMap((s) => s.cases.map((x) => ({ ...x, segment: s.id })));
if (
  segments.reduce((n, s) => n + s.points, 0) !== 100 ||
  segments.some((s) => s.cases.reduce((n, c) => n + c.points, 0) !== s.points)
)
  throw Error("rubric weights must sum to 100");

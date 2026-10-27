import { SUPPORT_EMAIL } from "@/lib/legal";
import { BRAND } from "@/lib/brand";

/**
 * Marketing copy — English + Simplified Chinese.
 * Doc: WEB_LANDING_DESIGN.md §6
 *
 * Nothing here is machine-translated. The Chinese version keeps
 * the same voice (editorial, non-marketing, honest) but not the
 * same sentence structure — parallel translation would sound
 * stiff. See WEB_LANDING_DESIGN.md §6.3 for CN discipline.
 */

export type Locale = "en" | "zh";

export interface Copy {
  nav: {
    features: string;
    pricing: string;
    cities: string;
    blog: string;
    manifesto: string;
    signIn: string;
    getApp: string;
  };
  hero: {
    eyebrow: string;
    h1Lines: string[];
    sub: string;
    ctaPrimaryStore: string;
    ctaPrimaryWeb: string;
    iosStatus: string;
    ctaSecondary: string;
  };
  problem: {
    eyebrow: string;
    paragraphs: { text: string; muted?: string[] }[];
  };
  pillars: {
    eyebrow: string;
    title: string;
    sub: string;
    items: { dot: "sun" | "omen" | "accent"; title: string; body: string }[];
  };
  trust: {
    eyebrow: string;
    title: string;
    items: { heading: string; body: string }[];
  };
  capabilities: {
    eyebrow: string;
    title: string;
    sub: string;
    intro: string;
  };
  askSolo: {
    eyebrow: string;
    title: string;
    body: string;
    bullets: string[];
    demoUser: string;
    demoAgent: string;
    demoReason: string;
  };
  blindbox: {
    eyebrow: string;
    title: string;
    body: string;
    bullets: string[];
    cardHint: string;
    cardReveal: string;
    cardReason: string;
  };
  capsule: {
    eyebrow: string;
    title: string;
    body: string;
    bullets: string[];
    sealTitle: string;
    sealMeta: string;
    sealBody: string;
  };
  omen: {
    eyebrow: string;
    title: string;
    body: string;
    bullets: string[];
    cardDate: string;
    cardTitle: string;
    cardLine: string;
  };
  bestNow: {
    eyebrow: string;
    title: string;
    body: string;
    bullets: string[];
    peakLabel: string;
    peakWindow: string;
    peakReason: string;
  };
  brag: {
    eyebrow: string;
    title: string;
    body: string;
    bullets: string[];
    cardName: string;
    cardMeta: string;
    cardLine: string;
    cardStat1: string;
    cardStat2: string;
    cardStat3: string;
  };
  pricing: {
    eyebrow: string;
    title: string;
    sub: string;
    priceNote: string;
    monthly: {
      name: string;
      price: string;
      pricePer: string;
      tagline: string;
      cta: string;
      features: string[];
    };
    yearly: {
      badge: string;
      name: string;
      price: string;
      pricePer: string;
      tagline: string;
      cta: string;
      features: string[];
    };
    free: string;
  };
  footer: {
    tagline: string;
    columns: { heading: string; links: { label: string; href: string }[] }[];
    bottom: string;
  };
  langSwitch: string;
}

export const copy: Record<Locale, Copy> = {
  en: {
    nav: {
      features: "Features",
      pricing: "Pricing",
      cities: "Cities",
      blog: "Journal",
      manifesto: "Manifesto",
      signIn: "Sign in",
      getApp: "Get on App Store",
    },
    hero: {
      eyebrow: "Roamorrow · a map for solo travelers",
      h1Lines: ["What can you", "do nearby?"],
      sub: "Open the map, choose an experience, and see how to get there. Browse first. Ask for help when you want it. You decide where to go.",
      ctaPrimaryStore: "Get on App Store",
      ctaPrimaryWeb: "Open the web map",
      iosStatus: "The iPhone app is built but not publicly listed yet — the web map is open today.",
      ctaSecondary: "See how it works",
    },
    problem: {
      eyebrow: "Why we built this",
      paragraphs: [
        {
          text: "It's 4 PM.",
        },
        {
          text: "You're alone in a city you don't know.",
        },
        {
          text: "You could open Google Maps — but the top-rated café will be full of couples on dates.",
          muted: ["Google Maps"],
        },
        {
          text: 'You could open 小红书 — but the "instagrammable" spot is a queue of tripods.',
          muted: ["小红书"],
        },
        {
          text: "You could ask ChatGPT — but it will confidently invent a place that closed last year.",
          muted: ["ChatGPT"],
        },
        {
          text: "We built Roamorrow because none of those felt like what an old friend who knew the city would tell you.",
        },
      ],
    },
    pillars: {
      eyebrow: "Three non-negotiables",
      title: "How Roamorrow is different.",
      sub: "Three design pillars from day one. If a feature pulls away from any of them, it doesn't ship.",
      items: [
        {
          dot: "sun",
          title: "Map-first",
          body: "The map is the home screen. No tabs, no drawer. A short setup picks your city and your pace — then everything happens on the map.",
        },
        {
          dot: "omen",
          title: "Experience-as-unit",
          body: 'Not places — verb-bound, time-anchored things to do. "Watch sunset paint the stupas at 5:30" beats "Wat Suan Dok."',
        },
        {
          dot: "accent",
          title: "AI doesn't decide",
          body: "AI narrows a thousand options to five, cites its sources, and shows its uncertainty. You make the call.",
        },
      ],
    },
    trust: {
      eyebrow: "How we treat you",
      title: "Three promises we don't break.",
      items: [
        {
          heading: "What leaves your phone.",
          body: "Confirming exploration sends the selected coordinates and radius to OpenStreetMap/Overpass. AI requests can include city and experience context. Review the data-use page for service details.",
        },
        {
          heading: "AI is a filter, not an oracle.",
          body: "Every AI suggestion shows its sources and how confident it is. Freshness signals: verified this month, fading, questioned. You know what you're trusting.",
        },
        {
          heading: "Pricing is honest.",
          body: "Pro is a monthly or yearly subscription, priced live in the App Store — no invented numbers on this page. No ads ever. No selling your data ever. No free-then-paywall bait.",
        },
      ],
    },
    capabilities: {
      eyebrow: "Start on the map",
      title: "Choose something. See how to get there.",
      sub: "A few experiences to consider, with the details you need before leaving. No prompt or account required to browse. Opening hours and availability are not live.",
      intro: "Illustrations, not live results or product screenshots.",
    },
    askSolo: {
      eyebrow: "01 · Ask",
      title: "The friend in every city, in your pocket.",
      body: "Ask a question about your city or a selected experience. Roamorrow uses the available map context and returns suggestions you can inspect before deciding.",
      bullets: [
        "Type a question or choose voice input",
        "Keep the selected place in context",
        "Inspect available sources and confidence",
      ],
      demoUser: "Somewhere quiet I can read for 2 hours. Not a chain.",
      demoAgent: "Three candidates within 8 min walk.",
      demoReason:
        "Compare the available experience details, reported solo scores, and estimated walking times.",
    },
    blindbox: {
      eyebrow: "02 · Blindbox",
      title: "For the days you can't choose.",
      body: "A direction for days when choosing feels difficult: reveal one experience from the available city collection. Some reveal and archive views are still previews.",
      bullets: [
        "A quieter way to narrow the choice",
        "Suggestions come from available experiences",
        "Preview availability is shown in the app",
      ],
      cardHint: "Chiang Mai · 4:12 PM · sunny",
      cardReveal: "A rooftop nobody's told you about.",
      cardReason: "Golden hour hits the mountains at 5:47. You're 12 min away. Café closes at 8.",
    },
    capsule: {
      eyebrow: "03 · Time Capsule",
      title: "Leave a note for a future you.",
      body: "Write a note tied to a place and a future opening time. The current compose flow supports text; available opening conditions are shown in the app.",
      bullets: [
        "A text note with a place and time",
        "Keep the draft if saving fails",
        "Read the opening conditions before sealing",
      ],
      sealTitle: "Sealed at Nimman corner café",
      sealMeta: "opens in 6 months · when you're here",
      sealBody: '"You were tired today. You almost skipped this walk. Remember it was worth it."',
    },
    omen: {
      eyebrow: "04 · Daily Omen",
      title: "One small prompt, every morning.",
      body: "A short city prompt for the start of a day. The example shows the intended reading experience, rather than a verified event or weather report.",
      bullets: [
        "One small prompt, with room to ignore it",
        "An illustrative city moment",
        "Some archive views remain previews",
      ],
      cardDate: "Tuesday · Chiang Mai",
      cardTitle: "Today, take the long way.",
      cardLine:
        "The mango tree at Wat Suan Dok drops fruit around 3 PM. Nobody's told the algorithm.",
    },
    bestNow: {
      eyebrow: "05 · Best Now",
      title: "See the available windows for an experience.",
      body: "Experience cards can include reported best-time windows. They help plan a visit; they do not confirm that a place is open, quiet, safe or at an exact astronomical peak.",
      bullets: [
        "Read the available time windows",
        "Keep reported timing separate from live opening status",
        "Check current conditions before a trip",
      ],
      peakLabel: "Peak in 42 min",
      peakWindow: "5:47 – 6:15 PM · golden hour",
      peakReason: "Light hits the stupas at this angle exactly 28 minutes a day.",
    },
    brag: {
      eyebrow: "06 · Brag Card",
      title: "A travel passport, not a highlight reel.",
      body: "Bring the experiences you have recorded into one view. The passport here is an illustration; some archive and export actions remain previews or read-only.",
      bullets: [
        "Read the records already available",
        "Keep example statistics clearly marked",
        "Export availability is shown in the app",
      ],
      cardName: "Nikita · Solo Traveler",
      cardMeta: "Chiang Mai · 8 days · Feb 2026",
      cardLine: "Walked 47.2 km. Wrote 3 capsules. Found 1 place nobody had marked.",
      cardStat1: "Experiences",
      cardStat2: "Kilometers",
      cardStat3: "Rare finds",
    },
    pricing: {
      eyebrow: "Pricing",
      title: "One product. Two ways to pay.",
      sub: "Explore the free map and experiences first. Pro is monthly or yearly; some ritual and archive views remain previews or read-only.",
      priceNote:
        "Prices vary by region. The App Store shows the live price and any free-trial eligibility before you pay — nothing is invented here.",
      monthly: {
        name: "Pro · Monthly",
        price: "App Store price",
        pricePer: "per month",
        tagline: "Everything Pro, month to month.",
        cta: "See it in the App Store",
        features: [
          "Ask AI — up to 30 answers a day (60 explanations)",
          "Available route tools",
          "Some rituals and archive views remain previews",
          "Current entitlements are shown before purchase",
          "Sync across devices (beta)",
        ],
      },
      yearly: {
        badge: "Best value",
        name: "Pro · Yearly",
        price: "App Store price",
        pricePer: "per year",
        tagline: "The same Pro, one yearly payment.",
        cta: "See it in the App Store",
        features: [
          "Everything in Pro Monthly",
          "One payment instead of twelve",
          "Cancel anytime — no lock-in",
        ],
      },
      free: "Or explore the web map first — free, no account",
    },
    footer: {
      tagline:
        "A map, the evidence behind each experience, and a clearer next step for solo travel.",
      columns: [
        {
          heading: "Product",
          links: [
            {
              label: "Features",
              href: "/#features",
            },
            {
              label: "Pricing",
              href: "/pricing",
            },
            {
              label: "Download",
              href: "/download",
            },
          ],
        },
        {
          heading: "Company",
          links: [
            {
              label: "Manifesto",
              href: "/manifesto",
            },
            {
              label: "Contact",
              href: `mailto:${SUPPORT_EMAIL}`,
            },
          ],
        },
        {
          heading: "Legal",
          links: [
            {
              label: "Privacy",
              href: "/privacy",
            },
            {
              label: "Terms",
              href: "/terms",
            },
            { label: "Support", href: "/support" },
          ],
        },
      ],
      bottom: "© 2026 Roamorrow · Made with respect for solo travelers.",
    },
    langSwitch: "中文",
  },
  zh: {
    nav: {
      features: "功能",
      pricing: "价格",
      cities: "城市",
      blog: "刊物",
      manifesto: "宣言",
      signIn: "登录",
      getApp: "App Store 下载",
    },
    hero: {
      eyebrow: "since 2026 · 面向 iOS 17+",
      h1Lines: ["现在，", "去哪里走走？"],
      sub: "打开地图，选一件想做的事，再看看怎么去。先浏览，需要时再提问。去哪里，由你决定。",
      ctaPrimaryStore: "App Store 下载",
      ctaPrimaryWeb: "打开网页地图",
      iosStatus: "iPhone 版已开发完成，尚未公开上架 —— 网页地图今天就能用。",
      ctaSecondary: "看看它是什么样",
    },
    problem: {
      eyebrow: "为什么我们做这个",
      paragraphs: [
        {
          text: "下午 4 点。",
        },
        {
          text: "你独自在一座陌生的城市。",
        },
        {
          text: "你可以打开 Google 地图 —— 但热门咖啡馆里全是情侣约会。",
          muted: ["Google 地图"],
        },
        {
          text: '你可以刷小红书 —— 但"出片圣地"排着三脚架的长队。',
          muted: ["小红书"],
        },
        {
          text: "你可以问 ChatGPT —— 但它会自信地给你一个去年就关门的店。",
          muted: ["ChatGPT"],
        },
        {
          text: "我们做 Roamorrow，是因为以上都不像一个熟悉这座城的本地朋友会告诉你的话。",
        },
      ],
    },
    pillars: {
      eyebrow: "三条不可动摇的原则",
      title: "Roamorrow 和别人不一样，在哪。",
      sub: "从第一天起就定下三条设计准则。任何功能只要偏离其一，就不会被做进产品。",
      items: [
        {
          dot: "sun",
          title: "地图为家",
          body: "地图就是首页。没有 tab，没有抽屉。简短的初始设置选好城市和节奏 —— 之后一切都在地图上发生。",
        },
        {
          dot: "omen",
          title: '以"体验"为单位',
          body: "不是地点，是带动词、带时间、带感官的具体事。「下午 5:30 看夕阳把白塔染成蜜色」比「双龙寺」更有信息。",
        },
        {
          dot: "accent",
          title: "AI 不替你决定",
          body: "AI 把一千个选项收敛到五个，标注来源，展示不确定性。选哪个，由你。",
        },
      ],
    },
    trust: {
      eyebrow: "我们怎么对你",
      title: "三个不会破的承诺。",
      items: [
        {
          heading: "哪些数据会离开你的手机。",
          body: "确认探索后，选定坐标和半径会发送至 OpenStreetMap/Overpass。AI 请求可能包含城市与体验上下文；数据使用页说明各项服务。",
        },
        {
          heading: "AI 是过滤器，不是神谕。",
          body: "每条 AI 建议都标注来源和置信度。新鲜度信号：本月已核实、正在褪色、被质疑。你知道自己在信什么。",
        },
        {
          heading: "定价是诚实的。",
          body: "Pro 是按月或按年订阅，价格以 App Store 实时显示为准 —— 本页不编造数字。永远不接广告，永远不卖数据，永远不做“免费然后付费墙”的诱饵。",
        },
      ],
    },
    capabilities: {
      eyebrow: "从地图开始",
      title: "选一件想做的事，看看怎么去。",
      sub: "先看几张体验卡，出发前查看地点、时段和来源。浏览无需提问或注册；营业时间与可用情况并非实时信息。",
      intro: "以下均为示意，不是实时结果或产品截图。",
    },
    askSolo: {
      eyebrow: "01 · 问",
      title: "每座城市都有的那个懂行朋友。",
      body: "围绕所在城市或选定体验提问。Roamorrow 使用已有地图上下文提供建议，你可以先查看依据，再决定下一步。",
      bullets: ["文字与语音均有入口", "保留选定地点的上下文", "查看已有来源和置信度"],
      demoUser: "找个安静地方读书 2 小时，别是连锁店。",
      demoAgent: "8 分钟步行内 3 个候选。",
      demoReason: "比较已有体验详情、记录的一人友好评分，以及预计步行时间。",
    },
    blindbox: {
      eyebrow: "02 · 盲盒",
      title: "选择困难的时候，交给它。",
      body: "不想反复比较时，从当前城市已有体验中揭晓一个方向。部分揭晓与归档页面仍为预览。",
      bullets: ["少一点比较，更容易做决定", "建议来自已有的体验集合", "可用范围以应用内页面为准"],
      cardHint: "清迈 · 下午 4:12 · 晴",
      cardReveal: "一个没人告诉过你的天台。",
      cardReason: "5:47 山头开始泛金。你走 12 分钟能到。咖啡馆 8 点打烊。",
    },
    capsule: {
      eyebrow: "03 · 时光胶囊",
      title: "给未来的自己写一张便条。",
      body: "给一个地点写下一段文字，选好未来的开启时间。当前编辑流程支持文字，具体开启条件会在应用内说明。",
      bullets: ["给文字记录关联地点与时间", "保存失败时保留草稿", "封存前查看开启条件"],
      sealTitle: "封存于宁曼路转角咖啡馆",
      sealMeta: "6 个月后 · 你回来时开启",
      sealBody: "「你今天很累。差点就没走完这条路。记住这一趟值得。」",
    },
    omen: {
      eyebrow: "04 · 每日签",
      title: "每天早上，一句轻推。",
      body: "用一段简短的城市提示开始一天。这里展示阅读体验，不把示例当作已验证的活动或天气报告。",
      bullets: ["一个可以自由接受或跳过的小提示", "以城市片刻作为示意", "部分归档页面仍为预览"],
      cardDate: "周二 · 清迈",
      cardTitle: "今天，绕远路。",
      cardLine: "双龙寺那棵芒果树下午 3 点会落果。没人告诉过算法。",
    },
    bestNow: {
      eyebrow: "05 · 此刻最佳",
      title: "先看体验已有的时间窗口。",
      body: "体验卡可包含记录的适合时段，用来辅助安排。它不证明场所此刻营业、安静、安全，也不承诺精确到分钟的天文峰值。",
      bullets: ["查看已有的适合时段", "区分记录的时段与实时营业状态", "出发前再确认当前情况"],
      peakLabel: "42 分钟后最佳",
      peakWindow: "17:47 – 18:15 · 金光时段",
      peakReason: "光线以这个角度照到白塔，一天正好 28 分钟。",
    },
    brag: {
      eyebrow: "06 · 旅记名片",
      title: "旅行护照，不是精彩集锦。",
      body: "把已经记录的体验放在一起回看。这里的旅行护照是示意，部分归档与导出操作仍为预览或只读。",
      bullets: ["回看已有记录", "清楚区分示例统计", "导出范围以应用内说明为准"],
      cardName: "Nikita · 独行者",
      cardMeta: "清迈 · 8 天 · 2026 年 2 月",
      cardLine: "走了 47.2 公里。封了 3 个胶囊。找到 1 个没被标记过的地方。",
      cardStat1: "体验数",
      cardStat2: "公里",
      cardStat3: "稀有发现",
    },
    pricing: {
      eyebrow: "价格",
      title: "一个产品。两种付法。",
      sub: "免费版包含地图与体验探索。Pro 按月或按年订阅；部分仪式与归档仍为预览或只读，开放范围以应用内说明为准。",
      priceNote:
        "价格因地区而异。付款前 App Store 会显示实时价格和是否有免费试用资格 —— 本页不编造数字。",
      monthly: {
        name: "Pro · 月度",
        price: "App Store 价格",
        pricePer: "每月",
        tagline: "完整 Pro，按月付费。",
        cta: "去 App Store 查看",
        features: [
          "问 AI —— 每天最多 30 次回答（60 次解释）",
          "当前开放的路线工具",
          "部分仪式与归档仍为预览",
          "购买前查看当前开放的权益",
          "跨设备同步（测试中）",
        ],
      },
      yearly: {
        badge: "更划算",
        name: "Pro · 年度",
        price: "App Store 价格",
        pricePer: "每年",
        tagline: "同一个 Pro，一年付一次。",
        cta: "去 App Store 查看",
        features: ["包含 Pro 月度全部内容", "一年付一次而不是十二次", "随时取消，无锁定"],
      },
      free: "或先玩网页地图 —— 免费，不用账号",
    },
    footer: {
      tagline: "地图、每个体验的依据，以及独自旅行时更清楚的下一步。",
      columns: [
        {
          heading: "产品",
          links: [
            {
              label: "功能",
              href: "/zh/#features",
            },
            {
              label: "价格",
              href: "/zh/pricing",
            },
            {
              label: "下载",
              href: "/download",
            },
          ],
        },
        {
          heading: "关于",
          links: [
            {
              label: "宣言",
              href: "/zh/manifesto",
            },
            {
              label: "联系",
              href: `mailto:${SUPPORT_EMAIL}`,
            },
          ],
        },
        {
          heading: "法律",
          links: [
            {
              label: "隐私",
              href: "/zh/privacy",
            },
            {
              label: "用户协议",
              href: "/terms",
            },
            { label: "支持", href: "/support" },
          ],
        },
      ],
      bottom: "© 2026 Roamorrow · 尊重每一位独自出发的人。",
    },
    langSwitch: "English",
  },
};

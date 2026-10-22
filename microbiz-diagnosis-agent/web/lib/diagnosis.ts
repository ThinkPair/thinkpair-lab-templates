export type Metric =
  | "customers"
  | "inquiries"
  | "orders"
  | "revenue"
  | "avgTicket"
  | "repeat";

export type Trend = "down" | "stable" | "up" | "unknown" | "";
export type EvidenceChoice = "yes" | "no" | "unknown" | "";

export interface DiagnosisAnswers {
  businessType: string;
  region: string;
  concern: string;
  metric: Metric | "";
  changeSince: string;
  comparisonPeriod: string;
  hasComparableData: EvidenceChoice;
  beforeValue: string;
  afterValue: string;
  sameConditions: EvidenceChoice;
  inquiryTrend: Trend;
  conversionTrend: Trend;
  repeatTrend: Trend;
  internalChanges: string[];
  externalSignals: string[];
  demoLabel: string;
}

export interface DiagnosisResult {
  outcome: "unconfirmed" | "external" | "internal" | "mixed";
  eyebrow: string;
  title: string;
  summary: string;
  confidence: "较低" | "中等" | "较高";
  facts: string[];
  unknowns: string[];
  externalEvidence: string[];
  internalEvidence: string[];
  alternatives: string[];
  priorityAction: {
    title: string;
    instruction: string;
    acceptance: string;
  };
}

export const metricLabels: Record<Metric, string> = {
  customers: "实际客户数",
  inquiries: "咨询／到店人数",
  orders: "成交订单数",
  revenue: "营业额",
  avgTicket: "平均客单价",
  repeat: "老客复购率",
};

export const metricUnits: Record<Metric, string> = {
  customers: "人",
  inquiries: "人",
  orders: "单",
  revenue: "元",
  avgTicket: "元",
  repeat: "%",
};

export const internalChangeLabels: Record<string, string> = {
  channel: "获客渠道或投放发生变化",
  hours: "营业时间或人员排班发生变化",
  offer: "产品、套餐或价格发生变化",
  response: "咨询回复与到店承接发生变化",
  service: "交付、服务或口碑出现波动",
};

export const externalSignalLabels: Record<string, string> = {
  footfall: "经营半径内客流／目标客群减少",
  competitors: "附近新增直接竞品或替代方案",
  seasonality: "季节、天气、假期带来需求变化",
  platform: "平台入口、流量规则或渠道环境变化",
  customerShift: "目标客群迁移或需求结构变化",
  none: "暂未掌握明确外部变化证据",
};

const trendLabels: Record<Exclude<Trend, "">, string> = {
  down: "下降",
  stable: "基本稳定",
  up: "上升",
  unknown: "未知",
};

export const emptyAnswers: DiagnosisAnswers = {
  businessType: "",
  region: "",
  concern: "",
  metric: "",
  changeSince: "",
  comparisonPeriod: "",
  hasComparableData: "",
  beforeValue: "",
  afterValue: "",
  sameConditions: "",
  inquiryTrend: "",
  conversionTrend: "",
  repeatTrend: "",
  internalChanges: [],
  externalSignals: [],
  demoLabel: "",
};

export const externalDemo: DiagnosisAnswers = {
  businessType: "社区少儿体能馆",
  region: "城市东部 3 公里经营半径",
  concern: "近两个月到店体验的家长明显减少，我担心是课程不够有吸引力。",
  metric: "inquiries",
  changeSince: "近两个月",
  comparisonPeriod: "与去年同期的完整八周比较",
  hasComparableData: "yes",
  beforeValue: "186",
  afterValue: "121",
  sameConditions: "yes",
  inquiryTrend: "down",
  conversionTrend: "stable",
  repeatTrend: "stable",
  internalChanges: [],
  externalSignals: ["footfall", "competitors", "customerShift"],
  demoLabel: "模拟样本 · 外部盘分支",
};

export function sanitizeSensitiveText(input: string) {
  let sanitized = input;
  sanitized = sanitized.replace(/\b1[3-9]\d{9}\b/g, (phone) => `${phone.slice(0, 3)}****${phone.slice(-4)}`);
  sanitized = sanitized.replace(/\bsk-[A-Za-z0-9_-]{6,}\b/gi, "[已遮蔽密钥]");
  sanitized = sanitized.replace(
    /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi,
    "[已遮蔽邮箱]",
  );
  sanitized = sanitized.replace(
    /[\u4e00-\u9fa5A-Za-z0-9]{2,}(?:路|街|巷|弄)\s*\d+\s*号?/g,
    "[已简化为城市级区域]",
  );
  return { value: sanitized, changed: sanitized !== input };
}

export const internalDemo: DiagnosisAnswers = {
  businessType: "社区摄影工作室",
  region: "城市南部 5 公里经营半径",
  concern: "咨询人数差不多，但最近总觉得成交客户越来越少。",
  metric: "orders",
  changeSince: "最近六周",
  comparisonPeriod: "与此前连续六周比较",
  hasComparableData: "yes",
  beforeValue: "54",
  afterValue: "31",
  sameConditions: "yes",
  inquiryTrend: "stable",
  conversionTrend: "down",
  repeatTrend: "stable",
  internalChanges: ["offer", "response"],
  externalSignals: ["none"],
  demoLabel: "模拟样本 · 内部盘分支",
};

function toNumber(value: string) {
  const parsed = Number(value.replace(/,/g, "").trim());
  return Number.isFinite(parsed) ? parsed : null;
}

export function getDelta(answers: DiagnosisAnswers) {
  const before = toNumber(answers.beforeValue);
  const after = toNumber(answers.afterValue);
  if (before === null || after === null || before <= 0 || after < 0) return null;
  return (after - before) / before;
}

export function shouldStopAfterEvidence(answers: DiagnosisAnswers) {
  const delta = getDelta(answers);
  return (
    answers.hasComparableData !== "yes" ||
    answers.sameConditions !== "yes" ||
    delta === null ||
    delta > -0.05 ||
    answers.metric === "revenue" ||
    answers.metric === "avgTicket"
  );
}

export function getLiveLedger(answers: DiagnosisAnswers) {
  const facts: string[] = [];
  const unknowns: string[] = [];
  const external: string[] = [];
  const internal: string[] = [];

  if (answers.businessType) facts.push(`生意类型：${answers.businessType}`);
  if (answers.region) facts.push(`经营范围：${answers.region}`);
  if (answers.metric) facts.push(`正在核对：${metricLabels[answers.metric]}`);
  if (answers.changeSince && answers.comparisonPeriod) {
    facts.push(`比较口径：${answers.changeSince}，${answers.comparisonPeriod}`);
  }

  const delta = getDelta(answers);
  if (answers.hasComparableData === "yes" && delta !== null && answers.metric) {
    facts.push(
      `${metricLabels[answers.metric]}从 ${answers.beforeValue}${metricUnits[answers.metric]}变为 ${answers.afterValue}${metricUnits[answers.metric]}（${Math.abs(
        delta * 100,
      ).toFixed(1)}% ${delta < 0 ? "下降" : "变化"}）`,
    );
  } else if (answers.hasComparableData === "no") {
    unknowns.push("缺少同口径前后数据，当前只能确认主观感受");
  }

  if (answers.sameConditions === "no") unknowns.push("两个周期的营业条件不同，暂不可直接比较");
  if (answers.sameConditions === "unknown") unknowns.push("尚未确认两个周期是否同口径");

  if (answers.inquiryTrend) {
    if (answers.inquiryTrend === "unknown") unknowns.push("咨询／到店趋势未知");
    else internal.push(`咨询／到店：${trendLabels[answers.inquiryTrend]}`);
  }
  if (answers.conversionTrend) {
    if (answers.conversionTrend === "unknown") unknowns.push("成交转化趋势未知");
    else internal.push(`成交转化：${trendLabels[answers.conversionTrend]}`);
  }
  if (answers.repeatTrend) {
    if (answers.repeatTrend === "unknown") unknowns.push("老客复购趋势未知");
    else internal.push(`老客复购：${trendLabels[answers.repeatTrend]}`);
  }

  answers.internalChanges.forEach((key) => {
    if (internalChangeLabels[key]) internal.push(internalChangeLabels[key]);
  });
  answers.externalSignals.forEach((key) => {
    if (key !== "none" && externalSignalLabels[key]) external.push(externalSignalLabels[key]);
  });
  if (external.length) unknowns.push("外部变化为手动录入，尚未用公共信息或同类样本独立核验");
  if (answers.externalSignals.includes("none")) unknowns.push("外部盘尚无明确证据");

  return { facts, unknowns, external, internal };
}

function makeUnconfirmed(
  answers: DiagnosisAnswers,
  title: string,
  summary: string,
): DiagnosisResult {
  const ledger = getLiveLedger(answers);
  const metric = answers.metric ? metricLabels[answers.metric] : "客户变化";
  return {
    outcome: "unconfirmed",
    eyebrow: "问题成立性｜尚未通过",
    title,
    summary,
    confidence: "较低",
    facts: ledger.facts,
    unknowns: ledger.unknowns.length ? ledger.unknowns : ["缺少足以支持归因的连续记录"],
    externalEvidence: ledger.external,
    internalEvidence: ledger.internal,
    alternatives: [
      "比较周期或营业条件不同造成的假下降",
      "营业额、客单变化被误认为客户人数变化",
    ],
    priorityAction: {
      title: `建立 7 天同口径「${metric}」记录`,
      instruction:
        "固定同一营业时段和统计定义，每天只记录咨询／到店、成交和营业条件；期间先不同时调整价格、渠道和套餐。",
      acceptance: "连续 7 天无缺口，并能与一个同口径周期直接比较，再进入外部盘／内部盘判断。",
    },
  };
}

export function diagnose(answers: DiagnosisAnswers): DiagnosisResult {
  const delta = getDelta(answers);
  if (answers.hasComparableData !== "yes" || delta === null) {
    return makeUnconfirmed(
      answers,
      "现在还不能确认客户真的减少",
      "你感受到变化，但当前缺少同口径前后数据。先补事实，比立即改经营动作更重要。",
    );
  }

  if (answers.sameConditions !== "yes") {
    return makeUnconfirmed(
      answers,
      "这两段数据暂时不能直接比较",
      "营业时长、渠道、价格或统计方式并不一致时，数字变化不能直接证明客户减少。",
    );
  }

  if (answers.metric === "revenue" || answers.metric === "avgTicket") {
    return makeUnconfirmed(
      answers,
      `目前只确认了${metricLabels[answers.metric]}下降`,
      "营业额或客单价下降不等于客户人数减少；还需要客户数、咨询数或订单数的同口径记录。",
    );
  }

  if (delta > -0.05) {
    return makeUnconfirmed(
      answers,
      "当前数据没有显示出明确下降",
      "前后变化不足 5%，更像正常波动。先延长观察窗口，不宜立刻归因。",
    );
  }

  const ledger = getLiveLedger(answers);
  const externalSignals = answers.externalSignals.filter((key) => key !== "none");
  const externalScore = externalSignals.length * 2 + (answers.inquiryTrend === "down" ? 1 : 0);
  const internalScore =
    (answers.conversionTrend === "down" ? 3 : 0) +
    (answers.repeatTrend === "down" ? 3 : 0) +
    answers.internalChanges.length +
    (answers.inquiryTrend === "down" && answers.internalChanges.includes("channel") ? 2 : 0);
  const confidence: DiagnosisResult["confidence"] =
    Math.abs(externalScore - internalScore) >= 4 && ledger.unknowns.length === 0
      ? "较高"
      : Math.abs(externalScore - internalScore) >= 2
        ? "中等"
        : "较低";

  if (externalScore >= 4 && externalScore >= internalScore + 2) {
    return {
      outcome: "external",
      eyebrow: "当前判断｜外部盘优先",
      title: "客户入口正在缩小，外部变化更像主要矛盾",
      summary:
        "同口径下降已经成立，内部转化与复购没有同步恶化，而经营半径、竞品或客群变化出现了更强信号。",
      confidence,
      facts: ledger.facts,
      unknowns: ledger.unknowns,
      externalEvidence: ledger.external,
      internalEvidence: ledger.internal,
      alternatives: [
        "原获客渠道的内部执行效率下降",
        "短期季节波动被误判为长期客群迁移",
      ],
      priorityAction: {
        title: "做一次 7 天替代入口验证",
        instruction:
          "只选择一个仍覆盖目标客群的新入口，用固定话术和固定预算连续测试 7 天；原入口保持不变，避免同时改价或改产品。",
        acceptance: "记录两个入口的有效咨询数与单条有效咨询成本，能够判断客群是否仍在、只是入口发生迁移。",
      },
    };
  }

  if (internalScore >= 3 && internalScore >= externalScore + 1) {
    const isConversion = answers.conversionTrend === "down";
    const isRepeat = !isConversion && answers.repeatTrend === "down";
    return {
      outcome: "internal",
      eyebrow: "当前判断｜内部盘优先",
      title: isConversion
        ? "客户没有先消失，更多流失在成交环节"
        : isRepeat
          ? "新客入口未明显恶化，老客复购断点更突出"
          : "内部获客与承接变化更像主要矛盾",
      summary:
        "客户减少已经成立，但当前证据更集中在内部转化、复购或经营动作变化，不支持先把原因归给市场。",
      confidence,
      facts: ledger.facts,
      unknowns: ledger.unknowns,
      externalEvidence: ledger.external,
      internalEvidence: ledger.internal,
      alternatives: [
        "外部竞争变化尚未被记录",
        "样本周期过短，内部波动可能被放大",
      ],
      priorityAction: isConversion
        ? {
            title: "复盘最近 20 条未成交咨询",
            instruction:
              "只按首次响应、需求澄清、报价、跟进和流失原因五项回看最近 20 条未成交记录，先找最高频的一个断点。",
            acceptance: "20 条记录全部归类，并能用同一口径说清最高频断点及其占比，再决定改哪一个承接动作。",
          }
        : isRepeat
          ? {
              title: "回访最近 20 名到期未复购老客",
              instruction:
                "使用同一组三个问题，记录未复购原因，不在回访中临时改价或承诺新权益。",
              acceptance: "完成 20 名有效回访并形成原因分布，能够判断是需求消失、体验问题还是触达断点。",
            }
          : {
              title: "连续 7 天补齐获客漏斗",
              instruction:
                "固定记录曝光、有效咨询、到店和成交四个节点；这 7 天只恢复一个已中断的获客动作。",
              acceptance: "能看出客户从哪一层开始减少，并确认恢复动作是否让该层数据回升。",
            },
    };
  }

  return {
    outcome: "mixed",
    eyebrow: "当前判断｜证据分叉",
    title: "外部盘和内部盘都有信号，暂时不能单归因",
    summary:
      "客户减少已经成立，但现有证据无法把主要责任稳定落在市场或经营动作中的一边。先补一轮对照证据。",
    confidence: "较低",
    facts: ledger.facts,
    unknowns: ledger.unknowns.length ? ledger.unknowns : ["外部变化与内部断点的先后顺序尚不清楚"],
    externalEvidence: ledger.external,
    internalEvidence: ledger.internal,
    alternatives: ["外部客流下降与内部转化下降同时发生", "单一周期内的偶然波动"],
    priorityAction: {
      title: "建立 7 天双列证据表",
      instruction:
        "每天只记录一个外部指标（经营半径客流或入口咨询）和一个内部指标（转化或复购），期间不同时更改多个经营变量。",
      acceptance: "连续 7 天后能判断哪一列先变、哪一列变化幅度更大，并据此选择下一轮单变量实验。",
    },
  };
}

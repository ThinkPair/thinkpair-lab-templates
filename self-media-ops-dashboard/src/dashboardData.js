export const PLATFORM_META = {
  douyin: { id: "douyin", label: "抖音", color: "#5662A8" },
  xhs: { id: "xhs", label: "小红书", color: "#DF7F7C" },
  bilibili: { id: "bilibili", label: "B站", color: "#5A9991" },
};

export const PLATFORM_IDS = Object.keys(PLATFORM_META);

const VALID_STATES = new Set(["confirmed", "estimated", "missing", "conflict", "unknown"]);

const STAGE_DEFINITIONS = [
  {
    id: "reach",
    label: "内容触达",
    unit: "次",
    unitType: "事件",
    definition:
      "所选周期内各平台后台记录的内容播放或曝光事件之和，同一人多次观看会重复计数。",
  },
  {
    id: "follow",
    label: "新增关注",
    unit: "条",
    unitType: "平台记录",
    definition:
      "所选周期内各平台新增关注记录之和，同一身份跨平台关注可能重复。",
  },
  {
    id: "lead",
    label: "有效线索",
    unit: "条",
    unitType: "平台记录",
    definition:
      "明确表达需求并进入可持续联系渠道的线索记录；跨平台身份是否去重以数据页标记为准。",
  },
  {
    id: "conversation",
    label: "深度沟通",
    unit: "条",
    unitType: "平台记录",
    definition:
      "已完成一次达到业务门槛的双向需求沟通，包括连麦、语音、面谈或采齐关键经营信息。",
  },
  {
    id: "paid",
    label: "首次付费",
    unit: "单",
    unitType: "订单",
    definition: "首次产生成功付款且未全额退款的确认订单。",
  },
  {
    id: "renewal",
    label: "升级续费",
    unit: "单",
    unitType: "订单",
    definition: "首次付费后再次付款、续费或升级的确认订单。",
  },
];

function numberOrNull(input) {
  if (input === null || input === undefined || input === "") return null;
  const value = Number(input);
  return Number.isFinite(value) && value >= 0 ? value : null;
}

function textOrFallback(input, fallback = "") {
  return typeof input === "string" && input.trim() ? input.trim() : fallback;
}

function normalizeCell(input) {
  const source = input && typeof input === "object" && !Array.isArray(input) ? input : {};
  const value = numberOrNull(Object.hasOwn(source, "value") ? source.value : input);
  const requestedState = textOrFallback(source.state, value === null ? "missing" : "confirmed");
  const state = VALID_STATES.has(requestedState) ? requestedState : value === null ? "missing" : "confirmed";
  return {
    value,
    state: value === null && state === "confirmed" ? "missing" : state,
    sourceRefs: Array.isArray(source.sourceRefs)
      ? source.sourceRefs.filter((item) => typeof item === "string" && item.trim())
      : [],
  };
}

function summarizeStageState(cells, requestedState) {
  if (VALID_STATES.has(requestedState)) return requestedState;
  const states = Object.values(cells).map((cell) => cell.state);
  if (states.includes("conflict")) return "conflict";
  if (states.includes("estimated")) return "estimated";
  if (states.every((state) => state === "missing" || state === "unknown")) return "missing";
  if (states.some((state) => state === "missing" || state === "unknown")) return "unknown";
  return "confirmed";
}

function normalizeTrendRow(row, index) {
  if (!row || typeof row !== "object") return null;
  const week = textOrFallback(row.week || row.label, `第${index + 1}周`);
  const rawValues = row.values && typeof row.values === "object" ? row.values : row;
  return {
    week,
    ...Object.fromEntries(PLATFORM_IDS.map((id) => [id, numberOrNull(rawValues[id])] )),
  };
}

function normalizeEpisodePlay(row, index) {
  if (!row || typeof row !== "object") return null;
  const episode = textOrFallback(row.episode || row.label, `第${index + 1}期`);
  const rawValues = row.values && typeof row.values === "object" ? row.values : row;
  return {
    episode,
    note: textOrFallback(row.note),
    ...Object.fromEntries(PLATFORM_IDS.map((id) => [id, numberOrNull(rawValues[id])])),
  };
}

function normalizeAttribution(row) {
  if (!row || typeof row !== "object") return null;
  return {
    title: textOrFallback(row.title, "未命名内容"),
    platformId: PLATFORM_META[row.platformId] ? row.platformId : null,
    platform: textOrFallback(row.platform),
    leads: numberOrNull(row.leads),
    conversations: numberOrNull(row.conversations),
    paid: numberOrNull(row.paid),
    sourceRefs: Array.isArray(row.sourceRefs) ? row.sourceRefs : [],
  };
}

function normalizeEvidence(row) {
  if (!row || typeof row !== "object") return null;
  const state = VALID_STATES.has(row.state) ? row.state : "unknown";
  return {
    time: textOrFallback(row.time, "—"),
    item: textOrFallback(row.item, "未命名数据项"),
    source: textOrFallback(row.source, "未标记"),
    value: textOrFallback(row.value, "—"),
    state,
    sourceRefs: Array.isArray(row.sourceRefs) ? row.sourceRefs : [],
  };
}

export function normalizeDashboardData(rawInput) {
  const raw = rawInput && typeof rawInput === "object" ? rawInput : {};
  const rawStages = Array.isArray(raw.stages) ? raw.stages : [];
  const rawStageMap = new Map(rawStages.map((stage) => [stage?.id, stage]));

  const stages = STAGE_DEFINITIONS.map((definition, index) => {
    const source = rawStageMap.get(definition.id) || {};
    const rawValues = source.values && typeof source.values === "object" ? source.values : {};
    const cells = Object.fromEntries(PLATFORM_IDS.map((id) => [id, normalizeCell(rawValues[id])]));
    const knownCells = Object.values(cells).filter((cell) => cell.value !== null);
    const knownTotal = knownCells.reduce((sum, cell) => sum + cell.value, 0);
    const complete = knownCells.length === PLATFORM_IDS.length;
    const sourceRefs = Array.isArray(source.sourceRefs)
      ? source.sourceRefs.filter((item) => typeof item === "string" && item.trim())
      : [];

    return {
      ...definition,
      label: textOrFallback(source.label, definition.label),
      unit: textOrFallback(source.unit, definition.unit),
      unitType: textOrFallback(source.unitType, definition.unitType),
      definition: textOrFallback(source.definition, definition.definition),
      values: Object.fromEntries(PLATFORM_IDS.map((id) => [id, cells[id].value])),
      cells,
      knownTotal,
      total: complete ? knownTotal : null,
      completeness: complete ? "complete" : knownCells.length ? "partial" : "empty",
      evidence: summarizeStageState(cells, source.evidence || source.evidenceState),
      sourceRefs,
      ratioAfter: null,
      width: 100 - index * 6,
    };
  });

  stages.forEach((stage, index) => {
    const next = stages[index + 1];
    if (!next || stage.total === null || next.total === null || stage.total <= 0) return;
    stage.ratioAfter = next.total / stage.total;
  });

  const leadTrendInput = Array.isArray(raw.leadTrend)
    ? raw.leadTrend
    : Array.isArray(raw.weeklySeries)
      ? raw.weeklySeries
      : Array.isArray(raw.weekly_leads)
        ? raw.weekly_leads
        : [];

  const leadTrend = leadTrendInput.map(normalizeTrendRow).filter(Boolean);
  const episodePlays = (Array.isArray(raw.episodePlays) ? raw.episodePlays : [])
    .map(normalizeEpisodePlay)
    .filter(Boolean);
  const attribution = (Array.isArray(raw.attribution) ? raw.attribution : [])
    .map(normalizeAttribution)
    .filter(Boolean);
  const evidence = (Array.isArray(raw.evidence) ? raw.evidence : [])
    .map(normalizeEvidence)
    .filter(Boolean);

  const cells = stages.flatMap((stage) => Object.values(stage.cells));
  const anyStageValue = cells.some((cell) => cell.value !== null);
  const hasConflict = cells.some((cell) => cell.state === "conflict") || evidence.some((row) => row.state === "conflict");
  const hasMissing = cells.some((cell) => cell.value === null);
  const isDemo = textOrFallback(raw?.meta?.status) === "demo";
  const mode = isDemo ? "demo" : hasConflict ? "conflict" : !anyStageValue ? "blank" : hasMissing ? "partial" : "actual";

  const meta = raw.meta && typeof raw.meta === "object" ? raw.meta : {};
  const platformOverrides = Array.isArray(raw.platforms) ? raw.platforms : [];
  const platforms = PLATFORM_IDS.map((id) => {
    const override = platformOverrides.find((item) => item?.id === id) || {};
    return { ...PLATFORM_META[id], label: textOrFallback(override.label, PLATFORM_META[id].label) };
  });

  return {
    schemaVersion: Number(raw.schemaVersion || raw.schema_version || 1),
    meta: {
      dashboardTitle: textOrFallback(meta.dashboardTitle, "降噪实验室"),
      periodLabel: textOrFallback(meta.periodLabel, "等待补录"),
      periodStart: textOrFallback(meta.periodStart),
      periodEnd: textOrFallback(meta.periodEnd),
      generatedAt: textOrFallback(meta.generatedAt),
      identityDeduplicated: meta.identityDeduplicated === true,
      status: textOrFallback(meta.status, mode),
    },
    platforms,
    stages,
    leadTrend,
    episodePlays,
    attribution,
    evidence,
    mode,
    isBlank: mode === "blank",
  };
}

export function getDashboardData() {
  const search = typeof globalThis.location?.search === "string" ? globalThis.location.search : "";
  const wantsDemo = new URLSearchParams(search).has("demo");
  if (wantsDemo && globalThis.DASHBOARD_DEMO_DATA && typeof globalThis.DASHBOARD_DEMO_DATA === "object") {
    return normalizeDashboardData(globalThis.DASHBOARD_DEMO_DATA);
  }
  return normalizeDashboardData(globalThis.DASHBOARD_DATA || {});
}


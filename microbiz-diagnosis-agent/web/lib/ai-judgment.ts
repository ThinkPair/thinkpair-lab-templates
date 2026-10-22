import type { AiDiagnosis } from "./ai-diagnosis";

export const dimensionIds = ["acquisition", "conversion", "ticket", "repeat", "delivery", "margin"] as const;
export type DimensionId = (typeof dimensionIds)[number];

export const dimensionLabels: Record<DimensionId, string> = {
  acquisition: "客流健康",
  conversion: "成交效率",
  ticket: "客单结构",
  repeat: "复购能力",
  delivery: "交付效率",
  margin: "利润质量",
};

export type JudgmentDimension = {
  id: DimensionId;
  score: number | null;
  status: "measured" | "derived" | "unscored";
  basis: "self_baseline" | "business_target" | "absolute" | "none";
  confidence: "low" | "medium" | "high";
  evidence: string[];
  summary: string;
};

export type AiJudgment = {
  headline: string;
  summary: string;
  primaryJudgment: {
    dimensionId: DimensionId;
    statement: string;
    status: "supported" | "provisional";
    confidence: "low" | "medium" | "high";
    evidence: string[];
    competingExplanation: string;
  };
  dimensions: JudgmentDimension[];
  unknowns: string[];
  priorityAction: {
    title: string;
    instruction: string;
    successMetric: string;
  };
  evidenceBoundary: string;
};

const dimensionSchema = {
  type: "object",
  properties: {
    id: { type: "string", enum: dimensionIds },
    score: { type: ["number", "null"], minimum: 0, maximum: 100 },
    status: { type: "string", enum: ["measured", "derived", "unscored"] },
    basis: { type: "string", enum: ["self_baseline", "business_target", "absolute", "none"] },
    confidence: { type: "string", enum: ["low", "medium", "high"] },
    evidence: { type: "array", items: { type: "string" }, maxItems: 4 },
    summary: { type: "string" },
  },
  required: ["id", "score", "status", "basis", "confidence", "evidence", "summary"],
  additionalProperties: false,
} as const;

export const aiJudgmentSchema = {
  type: "object",
  properties: {
    headline: { type: "string" },
    summary: { type: "string" },
    primaryJudgment: {
      type: "object",
      properties: {
        dimensionId: { type: "string", enum: dimensionIds },
        statement: { type: "string" },
        status: { type: "string", enum: ["supported", "provisional"] },
        confidence: { type: "string", enum: ["low", "medium", "high"] },
        evidence: { type: "array", items: { type: "string" }, maxItems: 5 },
        competingExplanation: { type: "string" },
      },
      required: ["dimensionId", "statement", "status", "confidence", "evidence", "competingExplanation"],
      additionalProperties: false,
    },
    dimensions: { type: "array", items: dimensionSchema, minItems: 6, maxItems: 6 },
    unknowns: { type: "array", items: { type: "string" }, maxItems: 6 },
    priorityAction: {
      type: "object",
      properties: {
        title: { type: "string" },
        instruction: { type: "string" },
        successMetric: { type: "string" },
      },
      required: ["title", "instruction", "successMetric"],
      additionalProperties: false,
    },
    evidenceBoundary: { type: "string" },
  },
  required: ["headline", "summary", "primaryJudgment", "dimensions", "unknowns", "priorityAction", "evidenceBoundary"],
  additionalProperties: false,
} as const;

export const aiJudgmentInstructions = `你是 ThinkPair 的经营判断引擎。输入包含已经确认的店铺事实和上一阶段诊断结果。你必须把“事实、推断、未知”严格分开。
规则：
1. 六个维度固定为 acquisition、conversion、ticket、repeat、delivery、margin，并各返回一次。
2. 分数越高表示越健康，只用 5 的整数倍。
3. 只有存在明确的本店历史对比、经营目标或可计算事实时才能评分。没有证据必须 score=null、status=unscored、basis=none，绝不能用 0 或 50 填空。
4. measured 表示用户直接提供了同口径数据；derived 表示由已给事实可计算或有充分支持；不得冒充行业基准。
5. 每个非空分数必须在 evidence 中引用输入里真实存在的事实。证据不足就不评分。
6. 只给一个核心判断和一个优先动作；核心判断保留一个竞争解释。
7. 如果上一阶段仍是 question 或 problemStatus=unconfirmed，以临时判断呈现，不能写成确定根因。
8. 中文表达直接、克制、面向经营者，不使用第三方旁观口吻。
9. 只输出要求的结构化结果。`;

export function buildJudgmentInput(args: {
  shop: Record<string, unknown>;
  pain: string;
  diagnosis: AiDiagnosis;
}) {
  return JSON.stringify(
    {
      shopProfile: args.shop,
      selectedPain: args.pain,
      diagnosis: args.diagnosis,
      scoringMeaning: "0 表示极不健康，100 表示健康；未知维度必须留空，不是 0。",
      outputGoal: "给出一个证据可追溯的核心判断、六维经营图和一个优先动作。",
    },
    null,
    2,
  );
}

function isStringArray(value: unknown, max: number): value is string[] {
  return Array.isArray(value) && value.length <= max && value.every((item) => typeof item === "string");
}

export function parseAiJudgment(text: string): AiJudgment {
  const value = JSON.parse(text) as Partial<AiJudgment>;
  if (
    typeof value.headline !== "string" ||
    typeof value.summary !== "string" ||
    typeof value.evidenceBoundary !== "string" ||
    !value.primaryJudgment ||
    !value.priorityAction ||
    !isStringArray(value.unknowns, 6) ||
    !Array.isArray(value.dimensions) ||
    value.dimensions.length !== 6
  ) {
    throw new Error("INVALID_JUDGMENT");
  }

  const ids = new Set(value.dimensions.map((item) => item.id));
  if (ids.size !== 6 || dimensionIds.some((id) => !ids.has(id))) throw new Error("INVALID_DIMENSIONS");

  for (const dimension of value.dimensions) {
    if (!dimensionIds.includes(dimension.id)) throw new Error("INVALID_DIMENSION_ID");
    if (!isStringArray(dimension.evidence, 4) || typeof dimension.summary !== "string") {
      throw new Error("INVALID_DIMENSION");
    }
    if (dimension.status === "unscored") {
      if (dimension.score !== null || dimension.basis !== "none") throw new Error("INVALID_UNSCORED_DIMENSION");
    } else {
      if (
        typeof dimension.score !== "number" ||
        dimension.score < 0 ||
        dimension.score > 100 ||
        dimension.score % 5 !== 0 ||
        dimension.basis === "none" ||
        dimension.evidence.length === 0
      ) {
        throw new Error("INVALID_SCORED_DIMENSION");
      }
    }
  }

  if (
    !dimensionIds.includes(value.primaryJudgment.dimensionId) ||
    !isStringArray(value.primaryJudgment.evidence, 5) ||
    typeof value.primaryJudgment.statement !== "string" ||
    typeof value.primaryJudgment.competingExplanation !== "string" ||
    typeof value.priorityAction.title !== "string" ||
    typeof value.priorityAction.instruction !== "string" ||
    typeof value.priorityAction.successMetric !== "string"
  ) {
    throw new Error("INVALID_PRIMARY_JUDGMENT");
  }

  return value as AiJudgment;
}

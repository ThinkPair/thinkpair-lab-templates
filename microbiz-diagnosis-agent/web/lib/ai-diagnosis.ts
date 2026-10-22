export const painIds = ["customers", "conversion", "repeat", "profit"] as const;

export type PainId = (typeof painIds)[number];
export type DiagnosisStage = "question" | "analysis";
export type DiagnosisConfidence = "low" | "medium" | "high";

export type DiagnosisTurn = {
  role: "user" | "assistant";
  content: string;
};

export type AiDiagnosis = {
  stage: DiagnosisStage;
  problemStatus: "unconfirmed" | "confirmed";
  headline: string;
  question: string;
  why: string;
  facts: string[];
  externalEvidence: string[];
  internalEvidence: string[];
  unknowns: string[];
  inferences: string[];
  alternatives: string[];
  action: {
    title: string;
    instruction: string;
    successMetric: string;
  };
  confidence: DiagnosisConfidence;
  evidenceBoundary: string;
};

export const painLabels: Record<PainId, string> = {
  customers: "客流下滑",
  conversion: "成交卡住",
  repeat: "复购走低",
  profit: "利润被吃掉",
};

const frameworkQuestions: Record<PainId, Pick<AiDiagnosis, "headline" | "question" | "why" | "unknowns">> = {
  customers: {
    headline: "先确认客流下降是否真实",
    question: "最近 30 天，进店人数和有效咨询分别变化了多少？请尽量给出同口径的前后数据。",
    why: "先排除统计口径和周期差异，才能判断问题在客流入口还是后续转化。",
    unknowns: ["同口径客流数据", "有效咨询的定义", "比较周期是否一致"],
  },
  conversion: {
    headline: "先找到成交停住的那一句",
    question: "最近 10 次未成交，客户最后停在哪一步？可以粘贴匿名聊天片段或概括。",
    why: "咨询量不低时，最有价值的证据是未成交记录中反复出现的断点。",
    unknowns: ["未成交对话的高频断点", "报价前是否建立价值", "首次响应与跟进间隔"],
  },
  repeat: {
    headline: "先区分需求消失与触达中断",
    question: "最近 20 名到期未复购客户，分别是没有需求、体验不满，还是没有被及时触达？",
    why: "复购下降可能来自产品体验，也可能只是回访链路断开；两者动作完全不同。",
    unknowns: ["未复购原因分布", "到期触达覆盖率", "首次购买后的体验反馈"],
  },
  profit: {
    headline: "先把忙碌拆成收入与成本",
    question: "最近一个月，新增工作量主要来自更多订单、返工、低价单，还是沟通与交付成本？",
    why: "忙但利润不变，往往不是努力不够，而是工作量落在了不创造毛利的环节。",
    unknowns: ["订单结构变化", "单笔交付时间", "返工与隐性沟通成本"],
  },
};

export function getFrameworkDraft(painId: PainId, problem = ""): AiDiagnosis {
  const draft = frameworkQuestions[painId];
  return {
    stage: "question",
    problemStatus: "unconfirmed",
    headline: draft.headline,
    question: draft.question,
    why: draft.why,
    facts: problem.trim() ? [`经营者描述：${problem.trim()}`] : [],
    externalEvidence: [],
    internalEvidence: [],
    unknowns: [...draft.unknowns],
    inferences: [],
    alternatives: [],
    action: { title: "", instruction: "", successMetric: "" },
    confidence: "low",
    evidenceBoundary: "当前只依据你提供的信息；未知不会被当成 0，也不会冒充外部市场核验。",
  };
}

export const aiDiagnosisSchema = {
  type: "object",
  properties: {
    stage: { type: "string", enum: ["question", "analysis"] },
    problemStatus: { type: "string", enum: ["unconfirmed", "confirmed"] },
    headline: { type: "string" },
    question: { type: "string" },
    why: { type: "string" },
    facts: { type: "array", items: { type: "string" }, maxItems: 6 },
    externalEvidence: { type: "array", items: { type: "string" }, maxItems: 5 },
    internalEvidence: { type: "array", items: { type: "string" }, maxItems: 5 },
    unknowns: { type: "array", items: { type: "string" }, maxItems: 6 },
    inferences: { type: "array", items: { type: "string" }, maxItems: 5 },
    alternatives: { type: "array", items: { type: "string" }, maxItems: 4 },
    action: {
      type: "object",
      properties: {
        title: { type: "string" },
        instruction: { type: "string" },
        successMetric: { type: "string" },
      },
      required: ["title", "instruction", "successMetric"],
      additionalProperties: false,
    },
    confidence: { type: "string", enum: ["low", "medium", "high"] },
    evidenceBoundary: { type: "string" },
  },
  required: [
    "stage",
    "problemStatus",
    "headline",
    "question",
    "why",
    "facts",
    "externalEvidence",
    "internalEvidence",
    "unknowns",
    "inferences",
    "alternatives",
    "action",
    "confidence",
    "evidenceBoundary",
  ],
  additionalProperties: false,
} as const;

export const aiDiagnosisInstructions = `你是 ThinkPair 的经营诊断协作引擎。你的任务不是快速给答案，而是把经营者的模糊感受变成可验证的事实、推断和一个优先动作。
必须遵守：
1. 用户选择的痛点只是入口假设，不是结论。
2. 没有同口径证据时 problemStatus 必须是 unconfirmed；只有问题被数据或连续记录支持时才是 confirmed。
3. 只能把用户明确提供的信息写入 facts；没有数据就写入 unknowns，未知绝不能按 0 处理。
4. externalEvidence 只放市场、客群、人口、竞品、季节或替代方案等外部盘证据；internalEvidence 只放获客、转化、客单、复购、产能、服务或成本等内部盘证据。不得凭空补全。
5. alternatives 至少保留一个能解释现象的替代解释，避免把相关性直接写成根因。
6. 不得声称已经联网搜索、核验行业数据或掌握用户没有提供的业务事实。
7. 证据不足时 stage=question，一次只问一个最高信息增益的问题；action 三个字段都返回空字符串。
8. 证据足够时 stage=analysis；inferences 必须是可被证伪的推断，不能伪装成事实。
9. 最终只给一个优先动作，写清执行方式和可验收标准。
10. 中文表达直接、克制、面向经营者；不使用“这是演示”“AI 建议用户”等旁观口吻。
11. 只输出要求的结构化结果。`;

export function buildDiagnosisInput(args: {
  painId: PainId;
  problem: string;
  evidence: string;
  history: DiagnosisTurn[];
  shop?: Record<string, unknown>;
}) {
  const history = args.history.slice(-6).map((turn) => ({
    role: turn.role,
    content: turn.content.slice(0, 1800),
  }));

  return JSON.stringify(
    {
      shopProfile: args.shop ?? {},
      selectedPain: painLabels[args.painId],
      initialProblem: args.problem.slice(0, 1200),
      newEvidence: args.evidence.slice(0, 4000),
      previousTurns: history,
      outputGoal: "先判断问题是否成立，再区分外部盘与内部盘证据；证据不足继续追问，足够时形成可证伪判断、替代解释和一个唯一动作。",
    },
    null,
    2,
  );
}

type RawResponse = {
  output?: Array<{
    type?: string;
    content?: Array<{ type?: string; text?: string; refusal?: string }>;
  }>;
};

export function extractResponseText(response: RawResponse): string {
  for (const item of response.output ?? []) {
    if (item.type !== "message") continue;
    for (const content of item.content ?? []) {
      if (content.type === "refusal" && content.refusal) throw new Error("MODEL_REFUSAL");
      if (content.type === "output_text" && content.text) return content.text;
    }
  }
  throw new Error("EMPTY_MODEL_OUTPUT");
}

function isStringArray(value: unknown, max: number): value is string[] {
  return Array.isArray(value) && value.length <= max && value.every((item) => typeof item === "string");
}

export function parseAiDiagnosis(text: string): AiDiagnosis {
  const value = JSON.parse(text) as Partial<AiDiagnosis>;
  if (value.stage !== "question" && value.stage !== "analysis") throw new Error("INVALID_STAGE");
  if (value.problemStatus !== "unconfirmed" && value.problemStatus !== "confirmed") {
    throw new Error("INVALID_PROBLEM_STATUS");
  }
  if (
    typeof value.headline !== "string" ||
    typeof value.question !== "string" ||
    typeof value.why !== "string" ||
    typeof value.evidenceBoundary !== "string" ||
    !isStringArray(value.facts, 6) ||
    !isStringArray(value.externalEvidence, 5) ||
    !isStringArray(value.internalEvidence, 5) ||
    !isStringArray(value.unknowns, 6) ||
    !isStringArray(value.inferences, 5) ||
    !isStringArray(value.alternatives, 4) ||
    !value.action ||
    typeof value.action.title !== "string" ||
    typeof value.action.instruction !== "string" ||
    typeof value.action.successMetric !== "string"
  ) {
    throw new Error("INVALID_DIAGNOSIS");
  }
  if (value.confidence !== "low" && value.confidence !== "medium" && value.confidence !== "high") {
    throw new Error("INVALID_CONFIDENCE");
  }
  return value as AiDiagnosis;
}

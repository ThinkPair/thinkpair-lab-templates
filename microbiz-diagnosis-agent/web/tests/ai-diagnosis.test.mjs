import assert from "node:assert/strict";
import test from "node:test";
import {
  aiDiagnosisInstructions,
  aiDiagnosisSchema,
  buildDiagnosisInput,
  extractResponseText,
  getFrameworkDraft,
  painIds,
  painLabels,
  parseAiDiagnosis,
} from "../lib/ai-diagnosis.ts";

test("exposes four pain entrances without turning them into conclusions", () => {
  assert.deepEqual(painIds, ["customers", "conversion", "repeat", "profit"]);
  assert.deepEqual(painIds.map((id) => painLabels[id]), ["客流下滑", "成交卡住", "复购走低", "利润被吃掉"]);
  for (const painId of painIds) {
    const draft = getFrameworkDraft(painId);
    assert.equal(draft.stage, "question");
    assert.equal(draft.problemStatus, "unconfirmed");
    assert.equal(draft.confidence, "low");
    assert.equal(draft.action.title, "");
    assert.match(draft.evidenceBoundary, /未知不会被当成 0/);
  }
});

test("buildDiagnosisInput includes the shop, caps text, and keeps six turns", () => {
  const input = JSON.parse(buildDiagnosisInput({
    painId: "conversion",
    problem: "p".repeat(1500),
    evidence: "e".repeat(4500),
    history: Array.from({ length: 8 }, (_, index) => ({ role: index % 2 ? "assistant" : "user", content: `turn-${index}` })),
    shop: { name: "木棉咖啡", areaSqm: 86 },
  }));
  assert.equal(input.shopProfile.name, "木棉咖啡");
  assert.equal(input.selectedPain, "成交卡住");
  assert.equal(input.initialProblem.length, 1200);
  assert.equal(input.newEvidence.length, 4000);
  assert.equal(input.previousTurns.length, 6);
  assert.equal(input.previousTurns[0].content, "turn-2");
});

test("extractResponseText rejects refusals and missing output", () => {
  assert.equal(extractResponseText({ output: [{ type: "message", content: [{ type: "output_text", text: "{}" }] }] }), "{}");
  assert.throws(() => extractResponseText({ output: [{ type: "message", content: [{ type: "refusal", refusal: "no" }] }] }), /MODEL_REFUSAL/);
  assert.throws(() => extractResponseText({ output: [] }), /EMPTY_MODEL_OUTPUT/);
});

test("parseAiDiagnosis accepts the evidence-first contract", () => {
  const diagnosis = {
    stage: "analysis",
    problemStatus: "confirmed",
    headline: "成交断点集中在报价后",
    question: "",
    why: "已有同口径记录。",
    facts: ["10 次咨询中有 7 次在报价后停止回复"],
    externalEvidence: [],
    internalEvidence: ["断点集中在报价后"],
    unknowns: ["客户预算是否变化"],
    inferences: ["报价前的价值说明可能不足"],
    alternatives: ["客户预算变化尚未排除"],
    action: { title: "回访未成交客户", instruction: "只问首要原因。", successMetric: "获得 6 条可归类回复。" },
    confidence: "medium",
    evidenceBoundary: "只依据匿名咨询记录。",
  };
  assert.deepEqual(parseAiDiagnosis(JSON.stringify(diagnosis)), diagnosis);
  assert.throws(() => parseAiDiagnosis(JSON.stringify({ ...diagnosis, facts: "bad" })), /INVALID_DIAGNOSIS/);
});

test("schema and instructions preserve the honesty boundary", () => {
  assert.equal(aiDiagnosisSchema.additionalProperties, false);
  assert.match(aiDiagnosisInstructions, /用户选择的痛点只是入口假设/);
  assert.match(aiDiagnosisInstructions, /未知绝不能按 0 处理/);
  assert.match(aiDiagnosisInstructions, /最终只给一个优先动作/);
});

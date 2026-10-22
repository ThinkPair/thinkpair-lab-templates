import assert from "node:assert/strict";
import test from "node:test";
import {
  aiJudgmentInstructions,
  dimensionIds,
  parseAiJudgment,
} from "../lib/ai-judgment.ts";

function validJudgment() {
  return {
    headline: "先修成交，不再盲目加流量",
    summary: "当前证据把主要断点指向报价后的价值说明。",
    primaryJudgment: {
      dimensionId: "conversion",
      statement: "成交效率是本轮最需要先处理的卡点。",
      status: "supported",
      confidence: "medium",
      evidence: ["10 次咨询中有 7 次在报价后停止回复"],
      competingExplanation: "客户预算变化尚未排除。",
    },
    dimensions: dimensionIds.map((id) => id === "conversion"
      ? { id, score: 35, status: "measured", basis: "self_baseline", confidence: "medium", evidence: ["报价后流失 7/10"], summary: "报价后流失集中。" }
      : { id, score: null, status: "unscored", basis: "none", confidence: "low", evidence: [], summary: "证据不足。" }),
    unknowns: ["客单与复购数据"],
    priorityAction: { title: "回访 10 名未成交客户", instruction: "只记录报价后停止的首要原因。", successMetric: "获得 6 条可归类回复。" },
    evidenceBoundary: "没有行业基准，未评分维度保持空白。",
  };
}

test("judgment accepts six fixed dimensions and preserves nulls", () => {
  const judgment = validJudgment();
  assert.deepEqual(parseAiJudgment(JSON.stringify(judgment)), judgment);
  assert.equal(judgment.dimensions.filter((item) => item.score === null).length, 5);
});

test("judgment rejects fake fallback scores and duplicate dimensions", () => {
  const unscoredWith50 = validJudgment();
  unscoredWith50.dimensions[0].score = 50;
  assert.throws(() => parseAiJudgment(JSON.stringify(unscoredWith50)), /INVALID_UNSCORED_DIMENSION/);

  const duplicate = validJudgment();
  duplicate.dimensions[2].id = "conversion";
  assert.throws(() => parseAiJudgment(JSON.stringify(duplicate)), /INVALID_DIMENSIONS/);
});

test("judgment instructions ban industry-benchmark theater", () => {
  assert.match(aiJudgmentInstructions, /没有证据必须 score=null/);
  assert.match(aiJudgmentInstructions, /不得冒充行业基准/);
  assert.match(aiJudgmentInstructions, /只给一个核心判断和一个优先动作/);
});

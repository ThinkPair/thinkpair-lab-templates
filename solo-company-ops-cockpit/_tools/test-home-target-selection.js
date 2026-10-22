"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const packageRoot = path.resolve(__dirname, "..");
const vaultRoot = path.join(packageRoot, "2_一人公司经营空间_首次选择这个文件夹");
const homePath = path.join(vaultRoot, "00_开始这里", "首页.md");
const enginePath = path.join(vaultRoot, "90_系统设置_不用先看", "创业算账引擎.js");
const homeSource = fs.readFileSync(homePath, "utf8");
const selectorMatch = homeSource.match(/\/\/ home-target-selector:start\s*([\s\S]*?)\s*\/\/ home-target-selector:end/);

assert.ok(selectorMatch, "首页缺少可测试的目标选择纯函数");
const targetPlanMatchesCalculation = new Function(selectorMatch[1] + "\nreturn targetPlanMatchesCalculation;")();
const engine = require(enginePath);

const plan = engine.calculateBusinessTargetPlan({
  calculationId: "calc-fixture",
  sourceInputHash: "source-fixture-hash",
  targetMonth: "2026-07",
  targetProfit: 5000,
  targetCashIncrease: 2000,
  fixedOperatingCost: 3500,
  ownerWage: 6000,
  contributionMarginRate: 75,
  unitRecognizedRevenue: 2000,
  unitDirectCost: 500,
  maxStableDeliveryUnits: 20,
  averageCashCollectedPerSale: 2000,
  deliveryUnit: "单",
  salesUnit: "单"
});

assert.equal(plan.savable, true, "fixture 目标应可保存");
const payload = { input: plan.deterministicInput, result: plan };
const frontmatter = {
  record_type: "business_target_plan",
  calculation_id: plan.calculationId,
  source_input_hash: plan.sourceInputHash,
  target_plan_id: plan.targetPlanId,
  target_input_hash: plan.targetInputHash
};

assert.equal(
  targetPlanMatchesCalculation(frontmatter, payload, plan.calculationId, plan.sourceInputHash),
  true,
  "刚保存且哈希匹配的完整目标 envelope 应被首页选中"
);
assert.equal(
  targetPlanMatchesCalculation(frontmatter, payload, plan.calculationId, "stale-source-hash"),
  false,
  "核算哈希变化后旧目标必须退出首页"
);
assert.equal(
  targetPlanMatchesCalculation(Object.assign({}, frontmatter, { target_input_hash: "stale-target-hash" }), payload, plan.calculationId, plan.sourceInputHash),
  false,
  "目标哈希不匹配时不得进入首页"
);
assert.equal(
  targetPlanMatchesCalculation(frontmatter, { input: plan.deterministicInput, result: plan.result }, plan.calculationId, plan.sourceInputHash),
  false,
  "缺少 planType 与哈希的 preview 不能伪装成完整目标 envelope"
);

process.stdout.write("Home target selection fixture: passed.\n");

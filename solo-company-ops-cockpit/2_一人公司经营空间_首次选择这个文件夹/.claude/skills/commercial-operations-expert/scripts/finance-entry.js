#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const VAULT_ROOT = path.resolve(__dirname, "../../../..");
const ENGINE_PATH = path.join(VAULT_ROOT, "90_系统设置_不用先看", "创业算账引擎.js");
const DRAFT_DIR_RELATIVE = "60_AI商业运营专家/核算草稿";
const DRAFT_DIR = path.join(VAULT_ROOT, ...DRAFT_DIR_RELATIVE.split("/"));

const TOP_FIELDS = new Set([
  "inputMode", "mode", "periodStart", "periodEnd", "periodEndInclusive",
  "currency", "offerName", "deliveryModel", "unitLabel", "quick"
]);
const QUICK_FIELDS = new Set([
  "recognizedRevenue", "cashIn", "cashOut", "directCost",
  "monthlyFixedCostExOwner", "monthlyOwnerWage", "availableCash",
  "remainingFulfillmentCost", "completedUnits", "next30RigidOutflow",
  "unitPrice", "unitDirectCost", "baseUnits", "capacityUnits",
  "cashAfterStartup", "startupInvestment"
]);
const FORBIDDEN_FIELD = /(result|output|path|record.?id|calculation.?id|input.?hash|payload.?hash|preview.?id|version)/i;

function parseArgs(argv) {
  const out = { mode: null };
  const valueArguments = new Set(["--input-base64"]);
  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    if (key === "--preview" || key === "--stage" || key === "--self-test") {
      if (out.mode) throw new Error("只能选择一个执行模式。");
      out.mode = key.slice(2);
      continue;
    }
    if (!valueArguments.has(key)) throw new Error("未知参数：" + key);
    const value = argv[++i];
    if (value === undefined || value.startsWith("--")) throw new Error(key + " 缺少值。");
    out[key.slice(2)] = value;
  }
  return out;
}

function decodeBase64Url(value) {
  if (!/^[A-Za-z0-9_-]+$/.test(String(value || ""))) throw new Error("input-base64 不合法。");
  return Buffer.from(String(value), "base64url").toString("utf8");
}

function assertPlainObject(value, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(label + " 必须是对象。");
}

function validateAndNormalizeInput(raw) {
  assertPlainObject(raw, "核算输入");
  for (const key of Object.keys(raw)) {
    if (FORBIDDEN_FIELD.test(key)) throw new Error("输入不得包含系统字段：" + key);
    if (!TOP_FIELDS.has(key)) throw new Error("未知字段：" + key);
  }
  assertPlainObject(raw.quick, "quick");
  for (const key of Object.keys(raw.quick)) {
    if (FORBIDDEN_FIELD.test(key)) throw new Error("输入不得包含系统字段：quick." + key);
    if (!QUICK_FIELDS.has(key)) throw new Error("未知字段：quick." + key);
    const value = raw.quick[key];
    if (value !== null && (typeof value !== "number" || !Number.isFinite(value))) {
      throw new Error("quick." + key + " 只能是有限数字或 null。");
    }
  }
  const input = {
    inputMode: "quick_v3",
    mode: raw.mode,
    periodStart: raw.periodStart,
    periodEnd: raw.periodEnd,
    periodEndInclusive: true,
    currency: raw.currency || "CNY",
    offerName: raw.offerName || "",
    deliveryModel: raw.deliveryModel || "instant",
    unitLabel: raw.unitLabel || "单",
    quick: {}
  };
  if (!/^(actual|forecast)$/.test(String(input.mode || ""))) throw new Error("mode 必须是 actual 或 forecast。");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(input.periodStart || "")) || !/^\d{4}-\d{2}-\d{2}$/.test(String(input.periodEnd || ""))) {
    throw new Error("periodStart 与 periodEnd 必须是 YYYY-MM-DD。");
  }
  if (raw.inputMode !== undefined && raw.inputMode !== "quick_v3") throw new Error("只接受 quick_v3 输入。");
  if (raw.periodEndInclusive !== undefined && raw.periodEndInclusive !== true) throw new Error("结束日期必须按包含当天处理。");
  for (const key of QUICK_FIELDS) if (Object.prototype.hasOwnProperty.call(raw.quick, key)) input.quick[key] = raw.quick[key];
  return input;
}

function loadEngine() {
  if (!fs.existsSync(ENGINE_PATH)) throw new Error("确定性核算引擎不存在。");
  delete require.cache[require.resolve(ENGINE_PATH)];
  return require(ENGINE_PATH);
}

function calculate(input) {
  const engine = loadEngine();
  const calculated = engine.calculate(input);
  if (!calculated || calculated.inputMode !== "quick_v3") throw new Error("当前引擎尚未返回 quick_v3 结果。");
  if (Array.isArray(calculated.errors) && calculated.errors.length) {
    throw new Error(calculated.errors.join("；"));
  }
  if (calculated.dataStatus !== "ready" || calculated.savable !== true || !calculated.result) {
    const missing = (calculated.missing || []).map((row) => row.label || row.field || String(row)).join("、");
    const errors = (calculated.errors || []).join("；");
    throw new Error(errors || (missing ? "还缺：" + missing : "核算输入尚未达到可计算状态。"));
  }
  return calculated;
}

function buildPreview(input, calculated) {
  return {
    schema: "calculation_draft_preview.v2",
    operation: "finance_stage",
    target_directory: DRAFT_DIR_RELATIVE,
    summary: "把已确认的用户输入暂存到计算页草稿；不创建正式核算，不保存公式结果。",
    ready: true,
    calculation_mode: calculated.mode,
    input_mode: calculated.inputMode,
    calculation_input_hash: calculated.inputHash,
    period: { start: input.periodStart, end: input.periodEnd, end_inclusive: true },
    deterministic_result_preview: calculated.result,
    warnings: calculated.warnings || [],
    next_step: "核对摘要后确认填入；计算页载入草稿后仍需用户点击确认保存。"
  };
}

function yamlString(value) {
  return JSON.stringify(String(value));
}

function createDraftId(calculated) {
  const inputHash = String(calculated.inputHash || "").toLowerCase();
  if (!/^[a-f0-9]{16}$/.test(inputHash)) throw new Error("确定性引擎没有返回合法的输入哈希。");
  const timestamp = new Date().toISOString().replace(/[-:TZ.]/g, "").slice(0, 14);
  return "draft-" + timestamp + "-" + inputHash.slice(0, 8) + "-" + crypto.randomBytes(3).toString("hex");
}

function draftMarkdown(input, draftId, calculated) {
  const now = new Date().toISOString();
  return [
    "---",
    "record_type: calculation_draft",
    "draft_status: ready",
    "input_mode: quick_v3",
    "draft_id: " + yamlString(draftId),
    "preview_hash: " + yamlString(calculated.inputHash),
    "created_at: " + yamlString(now),
    "updated_at: " + yamlString(now),
    "privacy: sensitive",
    "retrieval: excluded",
    "schema_version: \"calculation_draft.v1.1\"",
    "---",
    "",
    "# 待载入创业算账的输入草稿",
    "",
    "> 本文件只保存用户确认过的输入，不是正式核算，不包含公式结果。请在创业算账页核对并确认保存。",
    "",
    "<!-- finance-draft-json:start -->",
    "```json",
    JSON.stringify({ draftId, previewHash: calculated.inputHash, state: input }),
    "```",
    "<!-- finance-draft-json:end -->",
    ""
  ].join("\n");
}

function runSelfTest() {
  const rejected = [];
  for (const candidate of [
    { inputMode: "quick_v3", mode: "actual", periodStart: "2026-01-01", periodEnd: "2026-01-31", quick: {}, result: {} },
    { inputMode: "quick_v3", mode: "actual", periodStart: "2026-01-01", periodEnd: "2026-01-31", quick: { inputHash: "x" } },
    { inputMode: "quick_v3", mode: "actual", periodStart: "2026-01-01", periodEnd: "2026-01-31", quick: { unknown: 1 } }
  ]) {
    try { validateAndNormalizeInput(candidate); rejected.push(false); } catch { rejected.push(true); }
  }
  if (rejected.some((item) => !item)) throw new Error("非法字段自测失败。");
  const state = validateAndNormalizeInput({
    inputMode: "quick_v3", mode: "actual", periodStart: "2026-01-01", periodEnd: "2026-01-31",
    quick: { recognizedRevenue: 1, cashIn: 1, cashOut: 1, directCost: 0, monthlyFixedCostExOwner: 0, monthlyOwnerWage: 0, availableCash: 0, remainingFulfillmentCost: 0 }
  });
  const markdown = draftMarkdown(state, "draft-self-test", { inputHash: "0123456789abcdef" });
  for (const token of [
    "record_type: calculation_draft", "draft_status: ready", "input_mode: quick_v3", "schema_version: \"calculation_draft.v1.1\"",
    "draft_id: \"draft-self-test\"", "preview_hash: \"0123456789abcdef\"",
    "<!-- finance-draft-json:start -->", "<!-- finance-draft-json:end -->",
    '"previewHash":"0123456789abcdef"', '"state":'
  ]) if (!markdown.includes(token)) throw new Error("草稿契约自测失败：" + token);
  if (markdown.includes("operation_payload_hash") || markdown.includes("preview_id")) {
    throw new Error("正常核算草稿仍包含旧操作预览令牌。");
  }
  let legacyTokenRejected = false;
  try { parseArgs(["--stage", "--input-base64", "e30", "--preview-id", "opv-deprecated"]); } catch { legacyTokenRejected = true; }
  if (!legacyTokenRejected) throw new Error("旧操作预览令牌仍被正常流程接受。");
  const forecast = validateAndNormalizeInput({
    inputMode: "quick_v3", mode: "forecast", periodStart: "2026-08-01", periodEnd: "2026-08-31",
    quick: { unitPrice: 2000, unitDirectCost: 500, monthlyFixedCostExOwner: 3500, monthlyOwnerWage: 6000, baseUnits: 10, capacityUnits: 20 }
  });
  calculate(forecast);
  let missingActualRejected = false;
  let missingForecastRejected = false;
  let invalidOptionalRejected = false;
  try { calculate(validateAndNormalizeInput({ inputMode: "quick_v3", mode: "actual", periodStart: "2026-01-01", periodEnd: "2026-01-31", quick: {} })); } catch { missingActualRejected = true; }
  try { calculate(validateAndNormalizeInput({ inputMode: "quick_v3", mode: "forecast", periodStart: "2026-08-01", periodEnd: "2026-08-31", quick: { unitPrice: 2000, unitDirectCost: 500, monthlyFixedCostExOwner: 3500, monthlyOwnerWage: 6000, baseUnits: 10 } })); } catch { missingForecastRejected = true; }
  const invalidState = JSON.parse(JSON.stringify(state));
  invalidState.quick.completedUnits = -1;
  try { calculate(invalidState); } catch { invalidOptionalRejected = true; }
  if (!missingActualRejected || !missingForecastRejected || !invalidOptionalRejected) throw new Error("必填字段或 invalid/errors 拒绝自测失败。");
  process.stdout.write(JSON.stringify({
    ok: true,
    forbidden_fields_rejected: rejected.length,
    draft_contract: true,
    low_friction_stage: true,
    legacy_operation_tokens_rejected: true,
    actual_missing_rejected: true,
    forecast_missing_rejected: true,
    invalid_errors_rejected: true
  }, null, 2));
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.mode === "self-test") return runSelfTest();
  if (!/^(preview|stage)$/.test(String(args.mode || ""))) throw new Error("必须指定 --preview 或 --stage。");
  const raw = JSON.parse(decodeBase64Url(args["input-base64"]));
  const input = validateAndNormalizeInput(raw);
  const calculated = calculate(input);
  const preview = buildPreview(input, calculated);
  if (args.mode === "preview") {
    process.stdout.write(JSON.stringify(preview, null, 2));
    return;
  }
  fs.mkdirSync(DRAFT_DIR, { recursive: true });
  const draftId = createDraftId(calculated);
  const target = path.join(DRAFT_DIR, "calculation-draft-" + draftId + ".md");
  fs.writeFileSync(target, draftMarkdown(input, draftId, calculated), { encoding: "utf8", flag: "wx" });
  process.stdout.write(JSON.stringify({
    ok: true,
    staged: true,
    target: path.relative(VAULT_ROOT, target).replace(/\\/g, "/"),
    draft_id: draftId,
    input_hash: calculated.inputHash,
    formal_calculation_created: false
  }, null, 2));
}

try { main(); } catch (error) {
  process.stderr.write(JSON.stringify({ ok: false, error: error.message }));
  process.exitCode = 1;
}

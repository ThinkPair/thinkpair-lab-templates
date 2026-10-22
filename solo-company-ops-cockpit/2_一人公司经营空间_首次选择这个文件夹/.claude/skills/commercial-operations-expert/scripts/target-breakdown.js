#!/usr/bin/env node
"use strict";

// 只读 CLI：读取当前有效核算/目标，调用同一确定性引擎计算或复核行动计划。
// 本文件不得写文件、联网或引入行业默认转化率。

const fs = require("fs");
const path = require("path");

const DEFAULT_VAULT_ROOT = path.resolve(__dirname, "..", "..", "..", "..");
const TARGET_DIRECTORY = "20_经营数据/经营目标/目标方案";
const ACTION_DIRECTORY = "20_经营数据/经营目标/行动计划";
const CALCULATION_DIRECTORIES = [
  "20_经营数据/经营核算/实际核算",
  "20_经营数据/经营核算/创业预估"
];
const TARGET_PATTERN = /^20_经营数据\/经营目标\/目标方案\/btp-[a-f0-9]{16}\.md$/;
const ACTION_PATTERN = /^20_经营数据\/经营目标\/行动计划\/oap-[a-f0-9]{16}\.md$/;

function parseArguments(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (!key.startsWith("--")) throw new Error("不支持的位置参数：" + key);
    const next = argv[index + 1];
    if (next === undefined || next.startsWith("--")) result[key.slice(2)] = true;
    else {
      result[key.slice(2)] = next;
      index += 1;
    }
  }
  return result;
}

function normalizeRelative(value) {
  return String(value || "").replace(/\\/g, "/").replace(/^\.\//, "");
}

function resolveInside(vaultRoot, relative, pattern) {
  const clean = normalizeRelative(relative);
  if (!pattern.test(clean)) throw new Error("路径不符合经营目标只读契约：" + clean);
  const root = path.resolve(vaultRoot);
  const absolute = path.resolve(root, ...clean.split("/"));
  if (absolute !== root && !absolute.startsWith(root + path.sep)) throw new Error("路径越出当前经营空间。");
  return { relative: clean, absolute };
}

function scalar(value) {
  const text = String(value || "").trim();
  if (text === "" || text === "null" || text === "~") return null;
  if (text === "true") return true;
  if (text === "false") return false;
  if (/^-?(?:0|[1-9]\d*)(?:\.\d+)?$/.test(text)) return Number(text);
  if (text.startsWith('"') && text.endsWith('"')) {
    try { return JSON.parse(text); } catch (_) { return text.slice(1, -1); }
  }
  if (text.startsWith("'") && text.endsWith("'")) return text.slice(1, -1).replace(/''/g, "'");
  return text;
}

function parseFrontmatter(content) {
  const match = String(content || "").match(/^\uFEFF?---\s*\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/);
  if (!match) throw new Error("记录缺少 YAML frontmatter。");
  const result = {};
  match[1].split(/\r?\n/).forEach((line) => {
    const row = line.match(/^\s*([A-Za-z0-9_\u4e00-\u9fff-]+)\s*:\s*(.*?)\s*$/);
    if (row) result[row[1]] = scalar(row[2]);
  });
  return result;
}

function parseMachinePayload(content, kind) {
  const marker = kind === "target" ? "business-target-plan-json" : "operating-action-plan-json";
  const expression = new RegExp("<!--\\s*" + marker + ":start\\s*-->\\s*```json\\s*([\\s\\S]*?)\\s*```\\s*<!--\\s*" + marker + ":end\\s*-->");
  const match = String(content || "").match(expression);
  if (!match) throw new Error("记录缺少 " + marker + " 确定性数据块。");
  try { return JSON.parse(match[1]); }
  catch (error) { throw new Error(marker + " 数据块不是有效 JSON：" + error.message); }
}

function parseFinancePayload(content) {
  const match = String(content || "").match(/<!--\s*finance-json:start\s*-->\s*```json\s*([\s\S]*?)\s*```\s*<!--\s*finance-json:end\s*-->/);
  if (!match) throw new Error("来源核算缺少 finance-json 确定性数据块。");
  try { return JSON.parse(match[1]); }
  catch (error) { throw new Error("来源核算 finance-json 不是有效 JSON：" + error.message); }
}

function readMarkdownRecord(absolute, kind) {
  if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) throw new Error("记录不存在：" + absolute);
  const content = fs.readFileSync(absolute, "utf8");
  const frontmatter = parseFrontmatter(content);
  const payload = parseMachinePayload(content, kind);
  return { content, frontmatter, payload, record: Object.assign({}, frontmatter, payload) };
}

function recordTimestamp(record, absolute) {
  const candidate = record.frontmatter.updated_at || record.frontmatter.created_at;
  const parsed = candidate ? Date.parse(String(candidate)) : NaN;
  return Number.isFinite(parsed) ? parsed : fs.statSync(absolute).mtimeMs;
}

function listMarkdownFiles(absoluteDirectory) {
  if (!fs.existsSync(absoluteDirectory) || !fs.statSync(absoluteDirectory).isDirectory()) return [];
  return fs.readdirSync(absoluteDirectory, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(".md") && entry.name !== "README.md")
    .map((entry) => path.join(absoluteDirectory, entry.name));
}

function findCalculation(vaultRoot, calculationId) {
  const matches = [];
  CALCULATION_DIRECTORIES.forEach((relativeDirectory) => {
    const absolute = path.join(vaultRoot, ...relativeDirectory.split("/"), calculationId + ".md");
    if (fs.existsSync(absolute) && fs.statSync(absolute).isFile()) matches.push(absolute);
  });
  if (matches.length !== 1) throw new Error("calculation_id 没有唯一对应已保存核算。");
  const content = fs.readFileSync(matches[0], "utf8");
  const frontmatter = parseFrontmatter(content);
  if (frontmatter.record_type !== "business_calculation" || frontmatter.calculation_status !== "confirmed") {
    throw new Error("目标引用的核算不是 confirmed business_calculation。");
  }
  if (frontmatter.hash_algorithm !== "fnv1a64" || !/^[a-f0-9]{16}$/.test(String(frontmatter.input_hash || ""))) {
    throw new Error("目标引用的核算哈希无效。");
  }
  const payload = parseFinancePayload(content);
  const envelope = Object.assign({}, payload, {
    calculationId: frontmatter.calculation_id,
    calculationMode: frontmatter.calculation_mode,
    inputHash: frontmatter.input_hash,
    hashAlgorithm: frontmatter.hash_algorithm
  });
  return { absolute: matches[0], frontmatter, payload, envelope, timestamp: recordTimestamp({ frontmatter }, matches[0]) };
}

function latestCalculation(vaultRoot) {
  const rows = [];
  CALCULATION_DIRECTORIES.forEach((relativeDirectory) => {
    listMarkdownFiles(path.join(vaultRoot, ...relativeDirectory.split("/"))).forEach((absolute) => {
      try {
        const frontmatter = parseFrontmatter(fs.readFileSync(absolute, "utf8"));
        if (frontmatter.record_type === "business_calculation" && frontmatter.calculation_status === "confirmed") {
          rows.push({ absolute, frontmatter, timestamp: recordTimestamp({ frontmatter }, absolute) });
        }
      } catch (_) { /* 无效记录由包校验单独报告。 */ }
    });
  });
  rows.sort((left, right) => right.timestamp - left.timestamp || right.absolute.localeCompare(left.absolute));
  return rows[0] || null;
}

function validateTargetFile(engine, vaultRoot, relative, requireCurrentCalculation) {
  const resolved = resolveInside(vaultRoot, relative, TARGET_PATTERN);
  const parsed = readMarkdownRecord(resolved.absolute, "target");
  const fm = parsed.frontmatter;
  const errors = [];
  if (fm.record_type !== "business_target_plan") errors.push("record_type 必须为 business_target_plan。");
  if (fm.schema_version !== "business_target_plan.v1") errors.push("schema_version 必须为 business_target_plan.v1。");
  if (fm.hash_algorithm !== "fnv1a64") errors.push("hash_algorithm 必须为 fnv1a64。");
  if (fm.privacy !== "sensitive") errors.push("privacy 必须为 sensitive。");
  if (!fm.target_plan_id || path.basename(resolved.absolute, ".md") !== fm.target_plan_id) errors.push("文件名必须等于 target_plan_id。");
  const calculation = findCalculation(vaultRoot, String(fm.calculation_id || ""));
  if (String(fm.source_input_hash || "") !== String(calculation.frontmatter.input_hash || "")) errors.push("source_input_hash 与来源核算不一致。");
  if (requireCurrentCalculation) {
    const latest = latestCalculation(vaultRoot);
    if (!latest || latest.frontmatter.calculation_id !== fm.calculation_id || latest.frontmatter.input_hash !== fm.source_input_hash) {
      errors.push("目标方案未绑定当前最新有效核算。");
    }
  }
  const validation = engine.validateBusinessTargetPlanRecord(parsed.record, {
    expectedCalculationId: fm.calculation_id,
    expectedSourceInputHash: calculation.frontmatter.input_hash,
    expectedSourceCalculation: calculation.envelope
  });
  if (!validation.valid) errors.push(...validation.errors);
  const recalculated = validation.recalculated;
  if (recalculated && recalculated.result) {
    if (fm.target_plan_id !== recalculated.targetPlanId) errors.push("frontmatter target_plan_id 与复算结果不一致。");
    if (fm.target_input_hash !== recalculated.targetInputHash) errors.push("frontmatter target_input_hash 与复算结果不一致。");
    if (fm.target_month !== recalculated.result.targetMonth) errors.push("frontmatter target_month 与复算结果不一致。");
  }
  return { valid: errors.length === 0, errors: Array.from(new Set(errors)), resolved, parsed, recalculated, calculation };
}

function latestCurrentTarget(engine, vaultRoot) {
  const latest = latestCalculation(vaultRoot);
  if (!latest) throw new Error("没有已确认核算，不能拆解经营目标。");
  const directory = path.join(vaultRoot, ...TARGET_DIRECTORY.split("/"));
  const rows = [];
  listMarkdownFiles(directory).forEach((absolute) => {
    const relative = normalizeRelative(path.relative(vaultRoot, absolute));
    try {
      const validation = validateTargetFile(engine, vaultRoot, relative, true);
      if (validation.valid) rows.push(Object.assign(validation, { timestamp: recordTimestamp(validation.parsed, absolute) }));
    } catch (_) { /* 无效或历史目标不参与当前选择。 */ }
  });
  rows.sort((left, right) => right.timestamp - left.timestamp || right.resolved.relative.localeCompare(left.resolved.relative));
  if (!rows.length) throw new Error("没有与当前核算哈希匹配且可复算的目标方案。");
  return rows[0];
}

function decodeBase64Url(value) {
  if (!value || !/^[A-Za-z0-9_-]+$/.test(value)) throw new Error("--input-base64 必须是无填充 base64url。");
  const padding = "=".repeat((4 - (value.length % 4)) % 4);
  const text = Buffer.from(value.replace(/-/g, "+").replace(/_/g, "/") + padding, "base64").toString("utf8");
  const parsed = JSON.parse(text);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("拆解输入必须是 JSON object。");
  return parsed;
}

function requiredNumber(args, name, integer) {
  const value = args[name];
  if (value === undefined || !/^(?:0|[1-9]\d*)(?:\.\d+)?$/.test(String(value))) throw new Error("缺少或非法参数 --" + name + "。");
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || (integer && !Number.isInteger(parsed))) throw new Error("参数 --" + name + (integer ? " 必须是整数。" : " 必须是非负数。"));
  return parsed;
}

function optionalNumber(args, name, integer) {
  if (args[name] === undefined) return null;
  return requiredNumber(args, name, integer);
}

function parseShares(value, label, maximum) {
  if (value === undefined) return undefined;
  const rows = String(value).split(",").map((item) => {
    const match = item.match(/^([\p{L}\p{N}_-]{1,24}):((?:0|[1-9]\d*)(?:\.\d+)?)$/u);
    if (!match) throw new Error(label + "参数格式错误。");
    return { name: match[1], sharePercent: Number(match[2]) };
  });
  if (!rows.length || rows.length > maximum) throw new Error(label + "数量必须为 1—" + maximum + " 项。");
  return rows;
}

function safeInputFromArguments(args) {
  const allowed = new Set([
    "target", "actual-cash", "actual-deals", "actual-revenue", "actual-delivery", "remaining-days",
    "outreach-response", "response-discussion", "discussion-quote", "quote-sale", "basis",
    "actual-outreach", "actual-responses", "actual-discussions", "actual-quotes", "actual-funnel-deals",
    "channels", "weeks", "sprint-factor", "cash-risk"
  ]);
  Object.keys(args).forEach((name) => {
    if (!allowed.has(name)) throw new Error("日常目标拆解不支持参数 --" + name + "。");
  });
  const input = {
    progress: {
      actualCashReceived: requiredNumber(args, "actual-cash", false),
      actualDeals: requiredNumber(args, "actual-deals", true),
      actualRecognizedRevenue: requiredNumber(args, "actual-revenue", false),
      actualDeliveredUnits: requiredNumber(args, "actual-delivery", false)
    },
    remainingBusinessDays: requiredNumber(args, "remaining-days", true)
  };
  const rateNames = ["outreach-response", "response-discussion", "discussion-quote", "quote-sale"];
  const suppliedRates = rateNames.filter((name) => args[name] !== undefined);
  if (suppliedRates.length && suppliedRates.length !== rateNames.length) throw new Error("四段转化率必须同时提供；完全未知时全部省略并进入七天校准。");
  if (suppliedRates.length) {
    if (!/^(?:historical|user_estimate|mixed)$/.test(String(args.basis || ""))) throw new Error("已提供转化率时必须给出 --basis。");
    input.conversionRates = {
      outreachToResponse: requiredNumber(args, "outreach-response", false),
      responseToDiscussion: requiredNumber(args, "response-discussion", false),
      discussionToQuote: requiredNumber(args, "discussion-quote", false),
      quoteToSale: requiredNumber(args, "quote-sale", false)
    };
    input.conversionBasis = args.basis;
  } else if (args.basis !== undefined) throw new Error("没有四段转化率时不得单独提供 --basis。");

  const funnelNames = ["actual-outreach", "actual-responses", "actual-discussions", "actual-quotes", "actual-funnel-deals"];
  const suppliedFunnel = funnelNames.filter((name) => args[name] !== undefined);
  if (suppliedFunnel.length && suppliedFunnel.length !== funnelNames.length) throw new Error("五段漏斗实际数必须同时提供；未知时不要用 0 冒充。");
  if (suppliedFunnel.length) {
    input.funnelActuals = {
      outreach: requiredNumber(args, "actual-outreach", true),
      responses: requiredNumber(args, "actual-responses", true),
      discussions: requiredNumber(args, "actual-discussions", true),
      quotes: requiredNumber(args, "actual-quotes", true),
      deals: requiredNumber(args, "actual-funnel-deals", true)
    };
    if (input.funnelActuals.deals !== input.progress.actualDeals) {
      throw new Error("--actual-funnel-deals 必须与 --actual-deals 一致；成交进度不能维护两套数字。");
    }
  }
  const channels = parseShares(args.channels, "渠道", 3);
  const weeks = parseShares(args.weeks, "周权重", 5);
  if (channels) input.channels = channels;
  if (weeks) input.weekWeights = weeks;
  const sprintFactor = optionalNumber(args, "sprint-factor", false);
  if (sprintFactor !== null) input.sprintFactor = sprintFactor;
  if (args["cash-risk"] !== undefined) {
    if (!/^(?:true|false)$/.test(String(args["cash-risk"]))) throw new Error("--cash-risk 只能是 true 或 false。");
    input.cashRiskCritical = args["cash-risk"] === "true";
  }
  return input;
}

function computeBreakdown(engine, vaultRoot, targetRelative, encodedInput) {
  const current = latestCurrentTarget(engine, vaultRoot);
  const requested = normalizeRelative(targetRelative);
  if (requested !== current.resolved.relative) throw new Error("指定目标不是当前最新有效目标，请重新读取后再拆解。");
  const userInput = decodeBase64Url(encodedInput);
  ["targetPlan", "target_plan", "targetPlanId", "target_plan_id", "targetInputHash", "target_input_hash"].forEach((key) => {
    if (Object.prototype.hasOwnProperty.call(userInput, key)) throw new Error("拆解输入不得自行提供或覆盖目标绑定字段：" + key);
  });
  const calculation = engine.calculateOperatingBreakdown(Object.assign({}, userInput, { targetPlan: current.parsed.record }));
  if (!calculation || calculation.planType !== "operating_action_plan") throw new Error("确定性引擎没有返回 operating_action_plan。");
  return calculation;
}

function validateActionContent(engine, vaultRoot, relative, content, requireCurrentTarget) {
  const resolved = resolveInside(vaultRoot, relative, ACTION_PATTERN);
  const frontmatter = parseFrontmatter(content);
  const payload = parseMachinePayload(content, "action");
  const record = Object.assign({}, frontmatter, payload);
  const errors = [];
  if (frontmatter.record_type !== "operating_action_plan") errors.push("record_type 必须为 operating_action_plan。");
  if (frontmatter.schema_version !== "operating_action_plan.v1") errors.push("schema_version 必须为 operating_action_plan.v1。");
  if (frontmatter.hash_algorithm !== "fnv1a64") errors.push("hash_algorithm 必须为 fnv1a64。");
  if (frontmatter.privacy !== "sensitive") errors.push("privacy 必须为 sensitive。");
  if (frontmatter.record_status !== "active") errors.push("record_status 必须为 active。");
  if (!frontmatter.action_plan_id || path.basename(resolved.absolute, ".md") !== frontmatter.action_plan_id) errors.push("文件名必须等于 action_plan_id。");
  const current = requireCurrentTarget
    ? latestCurrentTarget(engine, vaultRoot)
    : validateTargetFile(
      engine,
      vaultRoot,
      TARGET_DIRECTORY + "/" + String(frontmatter.target_plan_id || "") + ".md",
      false
    );
  if (!current.valid) errors.push(...current.errors);
  if (frontmatter.target_plan_id !== current.recalculated.targetPlanId) errors.push(requireCurrentTarget ? "行动计划 target_plan_id 不是当前目标。" : "行动计划 target_plan_id 与引用目标不一致。");
  if (frontmatter.target_input_hash !== current.recalculated.targetInputHash) errors.push(requireCurrentTarget ? "行动计划 target_input_hash 不是当前目标哈希。" : "行动计划 target_input_hash 与引用目标不一致。");
  const validation = engine.validateOperatingActionPlanRecord(record, {
    expectedTargetPlanId: current.recalculated.targetPlanId,
    expectedTargetInputHash: current.recalculated.targetInputHash,
    expectedTargetPlan: current.parsed.record
  });
  if (!validation.valid) errors.push(...validation.errors);
  const recalculated = validation.recalculated;
  if (recalculated && recalculated.result) {
    if (frontmatter.action_plan_id !== recalculated.actionPlanId) errors.push("frontmatter action_plan_id 与复算结果不一致。");
    if (frontmatter.breakdown_input_hash !== recalculated.breakdownInputHash) errors.push("frontmatter breakdown_input_hash 与复算结果不一致。");
    if (frontmatter.target_month !== recalculated.result.targetMonth) errors.push("frontmatter target_month 与复算结果不一致。");
    const targetResult = current.recalculated.result;
    const actionInput = recalculated.deterministicInput || {};
    [
      "targetMonth", "targetProfit", "minimumCashReceivedTarget", "monthlySalesTarget",
      "executableProfitRevenue", "targetDeliveryUnits", "unitContribution", "capacityFeasible"
    ].forEach((field) => {
      const actionValue = Object.prototype.hasOwnProperty.call(actionInput, field) ? actionInput[field] : null;
      const targetValue = Object.prototype.hasOwnProperty.call(targetResult, field) ? targetResult[field] : null;
      if (JSON.stringify(actionValue) !== JSON.stringify(targetValue)) {
        errors.push("行动计划的目标快照与当前 business_target_plan 不一致：" + field + "。");
      }
    });
  }
  return { valid: errors.length === 0, errors: Array.from(new Set(errors)), recalculated };
}

function output(value, exitCode) {
  process.stdout.write(JSON.stringify(value, null, 2) + "\n");
  process.exitCode = exitCode;
}

async function main() {
  const args = parseArguments(process.argv.slice(2));
  const validationInvocation = Boolean(args["validate-action-stdin"] || args["validate-target-file"] || args["validate-action-file"]);
  if (args["vault-root"] !== undefined && !validationInvocation) {
    throw new Error("日常目标拆解不得传 --vault-root；请在当前经营空间使用守卫允许的固定命令。");
  }
  const vaultRoot = path.resolve(String(args["vault-root"] || DEFAULT_VAULT_ROOT));
  const enginePath = path.join(vaultRoot, "90_系统设置_不用先看", "创业算账引擎.js");
  if (!fs.existsSync(enginePath)) throw new Error("找不到确定性引擎。");
  const engine = require(enginePath);
  ["calculateBusinessTargetPlan", "validateBusinessTargetPlanRecord", "calculateOperatingBreakdown", "validateOperatingActionPlanRecord"].forEach((name) => {
    if (typeof engine[name] !== "function") throw new Error("确定性引擎缺少接口：" + name);
  });

  if (args["validate-action-stdin"]) {
    const chunks = [];
    for await (const chunk of process.stdin) chunks.push(chunk);
    const validation = validateActionContent(engine, vaultRoot, args.relative, Buffer.concat(chunks).toString("utf8"), true);
    output({ valid: validation.valid, errors: validation.errors }, validation.valid ? 0 : 1);
    return;
  }
  if (args["validate-target-file"]) {
    const validation = validateTargetFile(engine, vaultRoot, args.target, Boolean(args.current));
    output({ valid: validation.valid, errors: validation.errors }, validation.valid ? 0 : 1);
    return;
  }
  if (args["validate-action-file"]) {
    const resolved = resolveInside(vaultRoot, args.action, ACTION_PATTERN);
    const validation = validateActionContent(engine, vaultRoot, resolved.relative, fs.readFileSync(resolved.absolute, "utf8"), Boolean(args.current));
    output({ valid: validation.valid, errors: validation.errors }, validation.valid ? 0 : 1);
    return;
  }
  if (!args.target) throw new Error("需要 --target。");
  const encodedInput = args["input-base64"];
  if (encodedInput) {
    Object.keys(args).forEach((name) => {
      if (name !== "target" && name !== "input-base64") throw new Error("base64 兼容模式不支持额外参数 --" + name + "。");
    });
  }
  const calculation = encodedInput
    ? computeBreakdown(engine, vaultRoot, args.target, encodedInput)
    : (() => {
      const current = latestCurrentTarget(engine, vaultRoot);
      if (normalizeRelative(args.target) !== current.resolved.relative) throw new Error("指定目标不是当前最新有效目标，请重新读取后再拆解。");
      return engine.calculateOperatingBreakdown(Object.assign(safeInputFromArguments(args), { targetPlan: current.parsed.record }));
    })();
  output(calculation, calculation.savable ? 0 : 2);
}

main().catch((error) => output({ valid: false, errors: [error.message] }, 1));

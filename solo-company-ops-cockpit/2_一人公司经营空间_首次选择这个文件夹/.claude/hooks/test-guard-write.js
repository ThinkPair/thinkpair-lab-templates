#!/usr/bin/env node
"use strict";

const cp = require("child_process");
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");

const guard = path.join(__dirname, "guard-write.ps1");
const postAudit = path.join(__dirname, "post-write-audit.ps1");
const temp = fs.mkdtempSync(path.join(os.tmpdir(), "business-cockpit-guard-v014-"));
const root = path.join(temp, "vault");

function ensure(relative) { fs.mkdirSync(path.join(root, relative), { recursive: true }); }
function write(relative, content) {
  const target = path.join(root, ...relative.split("/"));
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, content, "utf8");
  return target;
}
function transcript(assistant, user) {
  const file = path.join(temp, crypto.randomUUID() + ".jsonl");
  const rows = [
    { type: "assistant", message: { role: "assistant", content: [{ type: "text", text: assistant }] } },
    { type: "user", message: { role: "user", content: [{ type: "text", text: user }] } }
  ];
  fs.writeFileSync(file, rows.map((row) => JSON.stringify(row)).join("\n"), "utf8");
  return file;
}
function runHook(script, input) {
  const run = cp.spawnSync("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script], {
    input: JSON.stringify(input), encoding: "utf8",
    env: { ...process.env, BUSINESS_COCKPIT_HOOK_DEBUG: "1" }
  });
  if (run.status !== 0) throw new Error(run.stderr || `${path.basename(script)} failed`);
  return run.stdout.trim();
}
function invoke(tool, toolInput, assistant = "", user = "") {
  const stdout = runHook(guard, {
    hook_event_name: "PreToolUse",
    tool_name: tool,
    tool_input: toolInput,
    tool_use_id: "test-" + crypto.randomUUID(),
    cwd: root,
    transcript_path: transcript(assistant, user)
  });
  const output = JSON.parse(stdout).hookSpecificOutput;
  return { decision: output.permissionDecision, reason: output.permissionDecisionReason };
}
function invokePost(tool, toolInput) {
  runHook(postAudit, {
    hook_event_name: "PostToolUse", tool_name: tool, tool_input: toolInput,
    tool_response: { success: true }, cwd: root
  });
}
function check(name, decision, code, actual, rows) {
  if (actual.decision !== decision) throw new Error(`${name}: expected ${decision}, got ${actual.decision}: ${actual.reason}`);
  if (!actual.reason.startsWith(code + " |")) throw new Error(`${name}: expected code ${code}, got ${actual.reason}`);
  rows.push({ test: name, decision: actual.decision, code, ok: true });
}
function projectContent(next = "联系客户确认时间") {
  return [
    "---", "record_type: project", "record_id: project-test", "record_status: active",
    "fact_gate_confirmed: true", "fact_gate_confirmed_at: 2026-07-13", "source_ability_id: null",
    "created_at: 2026-07-13", "updated_at: 2026-07-13", "客户: 测试客户", "项目: 测试项目",
    "报价: null", "回款: null", `下一步: ${next}`, "本周复盘: 尚未复盘",
    "privacy: sensitive", "schema_version: project.v1", "---", "", "# 测试项目", ""
  ].join("\n");
}
function calculationContent({ id, inputMode, start, end, inputHash, reviewRequired = false }) {
  return [
    "---", "record_type: business_calculation", `calculation_id: ${id}`, "calculation_mode: actual",
    `input_mode: ${inputMode}`, "calculation_status: confirmed", "record_status: saved",
    `period_start: ${start}`, `period_end: ${end}`, "period_end_inclusive: true",
    `period_review_required: ${reviewRequired}`, `input_hash: ${inputHash}`, "hash_algorithm: fnv1a64",
    "calculation_version: 1.3.0", "privacy: sensitive", "schema_version: finance.v2", "---", ""
  ].join("\n");
}
function insightContent(id, inputHash, recordId) {
  return [
    "---", "record_type: finance_ai_insight", `record_id: ${recordId}`, "record_status: active",
    `calculation_id: ${id}`, `input_hash: ${inputHash}`, "maximum_issue: 当前最大问题",
    "unique_action: 本周只做一项动作", "created_at: 2026-07-13", "updated_at: 2026-07-13",
    "privacy: sensitive", 'schema_version: "finance.v1"', "---", "", "# 经营结论", ""
  ].join("\n");
}

const rows = [];
try {
  [
    "20_经营数据/当前项目", "20_经营数据/经营核算/实际核算", "20_经营数据/经营核算/AI结论",
    "20_经营数据/经营目标/目标方案", "20_经营数据/经营目标/行动计划",
    "30_五维周复盘/历史周复盘", "40_能力商品化/验证记录", ".claude/hooks"
  ].forEach(ensure);

  check("vault read", "allow", "allow:vault_read", invoke("Read", { file_path: "20_经营数据/经营状态.md" }), rows);
  check("guard read protected", "deny", "deny:path_protected", invoke("Read", { file_path: ".claude/hooks/guard-write.ps1" }), rows);
  check("settings read protected", "deny", "deny:path_protected", invoke("Read", { file_path: ".claude/settings.json" }), rows);
  check("secret read", "deny", "deny:path_protected", invoke("Read", { file_path: ".claudian/claudian-settings.json" }), rows);
  check("guard search protected", "deny", "deny:path_protected", invoke("Grep", { pattern: "guard-write", path: ".claude/hooks" }), rows);
  check("explicit web task", "allow", "allow:operation_valid", invoke("WebSearch", { query: "market" }, "", "搜索公开市场资料"), rows);
  check("unrequested web task", "deny", "deny:operation_not_allowed", invoke("WebSearch", { query: "market" }, "", "继续分析本地数据"), rows);
  check("external read asks", "ask", "ask:user_confirmation_required", invoke("Read", { file_path: path.join(temp, "outside.txt") }, "", "读取这个外部文件"), rows);
  check("shell chaining denied", "deny", "deny:permanent_risk", invoke("Bash", { command: "git status; whoami" }), rows);
  check("permanent delete denied", "deny", "deny:permanent_risk", invoke("Bash", { command: "Remove-Item old.txt" }), rows);
  check("bounded shell asks", "ask", "ask:user_confirmation_required", invoke("Bash", { command: "git status" }), rows);
  check("finance draft direct instruction", "allow", "allow:direct_user_instruction", invoke("Bash", { command: "node .claude/skills/commercial-operations-expert/scripts/finance-entry.js --stage --input-base64 e30" }, "", "把这些数据填进去"), rows);
  check("finance draft ambiguous asks", "ask", "ask:user_confirmation_required", invoke("Bash", { command: "node .claude/skills/commercial-operations-expert/scripts/finance-entry.js --stage --input-base64 e30" }, "", "好"), rows);

  const relative = "20_经营数据/当前项目/test-direct.md";
  const content = projectContent();
  check("direct save succeeds first time", "allow", "allow:direct_user_instruction", invoke("Write", { file_path: relative, content }, "普通自然语言摘要，不含任何技术令牌。", "请直接保存这条项目记录"), rows);
  check("formatting does not affect authorization", "allow", "allow:direct_user_instruction", invoke("Write", { file_path: "20_经营数据/当前项目/test-format.md", content: content.replace("project-test", "project-format") }, "**表格**\r\n|字段|内容|\r\n|-|-|", "确认写入"), rows);
  check("plain confirm after preview succeeds", "allow", "allow:direct_user_instruction", invoke("Write", { file_path: "20_经营数据/当前项目/test-confirm.md", content: content.replace("project-test", "project-confirm") }, "这里是自然语言预览。", "确认"), rows);
  check("create is a direct instruction", "allow", "allow:direct_user_instruction", invoke("Write", { file_path: "20_经营数据/当前项目/test-create.md", content: content.replace("project-test", "project-create") }, "", "创建这条项目记录"), rows);
  check("record is a direct instruction", "allow", "allow:direct_user_instruction", invoke("Write", { file_path: "20_经营数据/当前项目/test-record.md", content: content.replace("project-test", "project-record") }, "", "把这件事记录下来"), rows);
  check("past save statement is not authorization", "ask", "ask:user_confirmation_required", invoke("Write", { file_path: "20_经营数据/当前项目/test-past-save.md", content: content.replace("project-test", "project-past-save") }, "", "我已经保存过这份记录了"), rows);
  check("record noun is not authorization", "ask", "ask:user_confirmation_required", invoke("Write", { file_path: "20_经营数据/当前项目/test-record-noun.md", content: content.replace("project-test", "project-record-noun") }, "", "我这里有一条项目记录"), rows);
  check("past update statement is not authorization", "ask", "ask:user_confirmation_required", invoke("Write", { file_path: "20_经营数据/当前项目/test-past-update.md", content: content.replace("project-test", "project-past-update") }, "", "我刚才更新了这个项目"), rows);
  check("bare okay asks once", "ask", "ask:user_confirmation_required", invoke("Write", { file_path: relative, content }, "已经整理好了。", "好"), rows);
  check("write failure question is not authorization", "ask", "ask:user_confirmation_required", invoke("Write", { file_path: relative, content }, "", "为什么你总是写入失败？"), rows);
  check("conditional revision asks once", "ask", "ask:user_confirmation_required", invoke("Write", { file_path: relative, content }, "", "可以保存，但把下一步改成周五联系"), rows);
  check("negative intent denies", "deny", "deny:user_declined", invoke("Write", { file_path: relative, content }, "", "先别写"), rows);
  check("missing schema denies", "deny", "deny:schema_invalid", invoke("Write", { file_path: "20_经营数据/当前项目/bad.md", content: "---\nrecord_type: project\n---\n" }, "", "保存"), rows);
  check("deterministic target protected", "deny", "deny:path_protected", invoke("Write", { file_path: "20_经营数据/经营目标/目标方案/btp-1111111111111111.md", content: "x" }, "", "保存"), rows);
  check("external write always asks", "ask", "ask:external_state_change", invoke("Write", { file_path: path.join(temp, "external.md"), content: "x" }, "", "直接保存"), rows);
  check("same direct instruction permits second bounded file", "allow", "allow:direct_user_instruction", invoke("Write", { file_path: "20_经营数据/当前项目/test-second.md", content: content.replace("project-test", "project-second") }, "", "保存这两条项目记录"), rows);

  const editRelative = "20_经营数据/当前项目/existing.md";
  const before = projectContent("旧的下一步").replace("project-test", "project-existing");
  const editTarget = write(editRelative, before);
  const editInput = { file_path: editRelative, old_string: "下一步: 旧的下一步", new_string: "下一步: 新的下一步", replace_all: false };
  check("direct edit creates undo snapshot", "allow", "allow:direct_user_instruction", invoke("Edit", editInput, "", "更新这个项目的下一步"), rows);
  const undoRoot = path.join(root, ".claude/runtime/undo");
  const undoFolders = fs.readdirSync(undoRoot);
  if (!undoFolders.length) throw new Error("undo snapshot was not created");
  const undoOriginal = fs.readFileSync(path.join(undoRoot, undoFolders[0], "original.md"), "utf8");
  if (undoOriginal !== before) throw new Error("undo snapshot does not preserve the original file");
  check("identity edit denied", "deny", "deny:schema_invalid", invoke("Edit", { file_path: editRelative, old_string: "record_id: project-existing", new_string: "record_id: changed", replace_all: false }, "", "更新记录"), rows);
  check("replace all denied", "deny", "deny:schema_invalid", invoke("Edit", { file_path: editRelative, old_string: "旧", new_string: "新", replace_all: true }, "", "更新记录"), rows);

  fs.writeFileSync(editTarget, before.replace("下一步: 旧的下一步", "下一步: 新的下一步"), "utf8");
  invokePost("Edit", editInput);
  const auditPath = path.join(root, ".claude/runtime/write-audit.jsonl");
  const auditText = fs.readFileSync(auditPath, "utf8");
  if (!auditText.includes(editRelative) || auditText.includes("新的下一步")) throw new Error("post-write audit is missing metadata or contains business body text");
  rows.push({ test: "successful edit audit contains metadata only", decision: "post", code: "audit:v1", ok: true });

  const validHash = "a1b2c3d4e5f60718";
  const validId = "calc-actual-20260713120000-abcde";
  write(`20_经营数据/经营核算/实际核算/${validId}.md`, calculationContent({ id: validId, inputMode: "quick_v3", start: "2026-06-01", end: "2026-06-30", inputHash: validHash }));
  check("valid quick v3 insight allowed", "allow", "allow:direct_user_instruction", invoke("Write", { file_path: "20_经营数据/经营核算/AI结论/insight-v3.md", content: insightContent(validId, validHash, "insight-v3") }, "", "保存这条结论"), rows);

  const monthId = "calc-actual-20260713120100-bcdef";
  write(`20_经营数据/经营核算/实际核算/${monthId}.md`, calculationContent({ id: monthId, inputMode: "quick_v2", start: "2025-02-01", end: "2025-02-28", inputHash: validHash }));
  check("complete-month quick v2 remains compatible", "allow", "allow:direct_user_instruction", invoke("Write", { file_path: "20_经营数据/经营核算/AI结论/insight-v2-month.md", content: insightContent(monthId, validHash, "insight-v2-month") }, "", "保存结论"), rows);

  const annualId = "calc-actual-20260713120200-cdefg";
  write(`20_经营数据/经营核算/实际核算/${annualId}.md`, calculationContent({ id: annualId, inputMode: "quick_v2", start: "2025-01-01", end: "2025-12-31", inputHash: validHash }));
  check("cross-period quick v2 is stale", "deny", "deny:stale_reference", invoke("Write", { file_path: "20_经营数据/经营核算/AI结论/insight-v2-annual.md", content: insightContent(annualId, validHash, "insight-v2-annual") }, "", "保存结论"), rows);

  const extraDayId = "calc-actual-20260713120230-efghi";
  write(`20_经营数据/经营核算/实际核算/${extraDayId}.md`, calculationContent({ id: extraDayId, inputMode: "quick_v2", start: "2025-01-01", end: "2026-01-01", inputHash: validHash }));
  check("annual quick v2 with one extra day is stale", "deny", "deny:stale_reference", invoke("Write", { file_path: "20_经营数据/经营核算/AI结论/insight-v2-extra-day.md", content: insightContent(extraDayId, validHash, "insight-v2-extra-day") }, "", "保存结论"), rows);

  const reviewId = "calc-actual-20260713120300-defgh";
  write(`20_经营数据/经营核算/实际核算/${reviewId}.md`, calculationContent({ id: reviewId, inputMode: "quick_v3", start: "2026-06-01", end: "2026-06-30", inputHash: validHash, reviewRequired: true }));
  check("review-required calculation is stale", "deny", "deny:stale_reference", invoke("Write", { file_path: "20_经营数据/经营核算/AI结论/insight-review.md", content: insightContent(reviewId, validHash, "insight-review") }, "", "保存结论"), rows);
  check("wrong source hash is stale", "deny", "deny:stale_reference", invoke("Write", { file_path: "20_经营数据/经营核算/AI结论/insight-wrong-hash.md", content: insightContent(validId, "0000000000000000", "insight-wrong-hash") }, "", "保存结论"), rows);

  const invalidAction = [
    "---", "record_type: operating_action_plan", "action_plan_id: oap-1111111111111111", "record_status: active",
    "target_plan_id: btp-1111111111111111", "target_input_hash: 1111111111111111", "breakdown_input_hash: 2222222222222222",
    "target_month: 2026-07", "hash_algorithm: fnv1a64", "created_at: 2026-07-13", "updated_at: 2026-07-13",
    "privacy: sensitive", 'schema_version: "operating_action_plan.v1"', "---", "<!-- operating-action-plan-json:start -->",
    "```json", "{}", "```", "<!-- operating-action-plan-json:end -->"
  ].join("\n");
  check("action formula boundary remains enforced", "deny", "deny:schema_invalid", invoke("Write", { file_path: "20_经营数据/经营目标/行动计划/oap-1111111111111111.md", content: invalidAction }, "", "保存行动计划"), rows);
  check("external send asks", "ask", "ask:user_confirmation_required", invoke("mcp__mail__send_message", { to: "x@example.com", body: "test" }, "", "发送这封邮件"), rows);
  check("payment denied", "deny", "deny:permanent_risk", invoke("mcp__pay__payment", { amount: 1 }, "", "付款"), rows);

  process.stdout.write(JSON.stringify({ ok: true, count: rows.length, results: rows }, null, 2));
} finally {
  if (path.resolve(temp).startsWith(path.resolve(os.tmpdir()) + path.sep)) fs.rmSync(temp, { recursive: true, force: true });
}

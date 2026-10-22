#!/usr/bin/env node
"use strict";

const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");

const VAULT_ROOT = path.resolve(__dirname, "../../../..");
const META_DIR = path.join(VAULT_ROOT, ".claudian", "sessions");
const ARCHIVE_RELATIVE = "60_AI商业运营专家/对话归档";
const ARCHIVE_DIR = path.join(VAULT_ROOT, ...ARCHIVE_RELATIVE.split("/"));

function parseArgs(argv) {
  const out = { mode: null };
  const valueArguments = new Set(["--conversation"]);
  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    if (["--preview", "--export", "--self-test"].includes(key)) {
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

function sha256(text) {
  return crypto.createHash("sha256").update(text).digest("hex");
}

function readMeta(conversationId) {
  if (!/^conv-[a-z0-9-]{8,80}$/i.test(String(conversationId || ""))) throw new Error("conversation id 不合法。");
  const metaPath = path.join(META_DIR, conversationId + ".meta.json");
  if (!fs.existsSync(metaPath)) throw new Error("找不到对应的 Claudian 会话元数据。");
  const meta = JSON.parse(fs.readFileSync(metaPath, "utf8"));
  const sessionId = String(meta.sessionId || (meta.providerState && meta.providerState.providerSessionId) || "");
  if (!/^[a-f0-9-]{36}$/i.test(sessionId)) throw new Error("会话元数据没有有效的 Claude session id。");
  return { meta, metaPath, sessionId };
}

function findTranscript(sessionId) {
  const root = path.join(os.homedir(), ".claude", "projects");
  if (!fs.existsSync(root)) throw new Error("找不到本机 Claude 会话目录。");
  const wanted = sessionId + ".jsonl";
  const stack = [root];
  let visited = 0;
  while (stack.length) {
    const current = stack.pop();
    visited += 1;
    if (visited > 100000) throw new Error("会话目录过大，已停止查找。");
    let rows;
    try { rows = fs.readdirSync(current, { withFileTypes: true }); } catch { continue; }
    for (const row of rows) {
      const full = path.join(current, row.name);
      if (row.isDirectory()) stack.push(full);
      else if (row.isFile() && row.name === wanted) return full;
    }
  }
  throw new Error("未找到 Claudian 对应的原始 Claude transcript。");
}

function messageText(content) {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content.filter((block) => block && block.type === "text" && typeof block.text === "string").map((block) => block.text).join("\n");
}

function extractMessages(raw) {
  const messages = [];
  for (const line of raw.split(/\r?\n/)) {
    if (!line.trim()) continue;
    let row;
    try { row = JSON.parse(line); } catch { continue; }
    if (!/^(user|assistant)$/.test(String(row.type || ""))) continue;
    const role = String((row.message && row.message.role) || row.type);
    if (!/^(user|assistant)$/.test(role)) continue;
    const text = messageText(row.message ? row.message.content : row.content).trim();
    if (!text) continue;
    messages.push({ role, timestamp: String(row.timestamp || row.created_at || ""), text });
  }
  return messages;
}

function redact(text) {
  let count = 0;
  let clean = String(text);
  const replacements = [
    [/\b((?:ANTHROPIC|OPENAI|DEEPSEEK|GOOGLE|AZURE|AWS)?_?(?:API_?KEY|AUTH_?TOKEN|ACCESS_?TOKEN|SECRET|PASSWORD|PRIVATE_?KEY))\s*[=:]\s*([^\s"']+)/gi, (_, key) => { count += 1; return key + "=[REDACTED]"; }],
    [/\bBearer\s+[A-Za-z0-9._~+\/-]{16,}/gi, () => { count += 1; return "Bearer [REDACTED]"; }],
    [/\bsk-[A-Za-z0-9_-]{16,}/g, () => { count += 1; return "sk-[REDACTED]"; }],
    [/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/g, () => { count += 1; return "[PRIVATE KEY REDACTED]"; }]
  ];
  for (const [pattern, replacer] of replacements) clean = clean.replace(pattern, replacer);
  return { text: clean, count };
}

function prepare(conversationId) {
  const { meta, sessionId } = readMeta(conversationId);
  const transcriptPath = findTranscript(sessionId);
  const raw = fs.readFileSync(transcriptPath, "utf8");
  const messages = extractMessages(raw);
  if (!messages.length) throw new Error("原始 transcript 中没有可导出的用户或助手文本。");
  const transcriptHash = sha256(raw);
  const target = ARCHIVE_RELATIVE + "/session-" + sessionId + "-" + transcriptHash.slice(0, 16) + ".md";
  const payload = {
    conversation_id: conversationId,
    session_id: sessionId,
    transcript_sha256: transcriptHash,
    source_message_count: messages.length,
    title: String(meta.title || "未命名会话"),
    updated_at: meta.updatedAt || null
  };
  const summary = {
    schema: "session_export_preview.v2",
    operation: "session_export",
    target,
    summary: "从本机会话源导出用户与助手原文，自动遮蔽疑似密钥；归档默认不参与 AI 检索。",
    ready: true
  };
  return { meta, sessionId, transcriptPath, raw, messages, target, payload, summary };
}

function yamlString(value) {
  return JSON.stringify(String(value));
}

function archiveMarkdown(prepared) {
  let redactionCount = 0;
  const sections = prepared.messages.map((message) => {
    const cleaned = redact(message.text);
    redactionCount += cleaned.count;
    const who = message.role === "user" ? "用户" : "商业运营专家";
    const stamp = message.timestamp ? " · " + message.timestamp : "";
    return "## " + who + stamp + "\n\n" + cleaned.text;
  });
  const created = new Date().toISOString();
  return [
    "---",
    "record_type: chat_transcript",
    "source: claudian_claude_transcript",
    "source_conversation_id: " + yamlString(prepared.payload.conversation_id),
    "source_session_id: " + yamlString(prepared.sessionId),
    "source_transcript_sha256: " + yamlString(prepared.payload.transcript_sha256),
    "session_date: " + yamlString(new Date(prepared.meta.createdAt || Date.now()).toISOString().slice(0, 10)),
    "created_at: " + yamlString(created),
    "privacy: sensitive",
    "retrieval: excluded",
    "completeness: source_messages_text",
    "source_message_count: " + prepared.messages.length,
    "redactions_applied: " + redactionCount,
    "schema_version: \"chat_transcript.v1.1\"",
    "---",
    "",
    "# " + String(prepared.meta.title || "AI 对话记录").replace(/[\r\n]+/g, " ").trim(),
    "",
    "> 本记录直接导出自 Claudian 关联的 Claude transcript，不是 AI 凭上下文回忆的拟写稿。工具调用的结构化参数与结果未纳入正文；疑似密钥已遮蔽。",
    "",
    sections.join("\n\n---\n\n"),
    ""
  ].join("\n");
}

function selfTest() {
  const keyName = ["ANTHROPIC", "API", "KEY"].join("_");
  const fakeSecret = ["secret", "value"].join("-");
  const fakeBearer = ["Bearer", "abcdefghijklmnopqrstuvwxyz"].join(" ");
  const fakeSk = ["sk", "1234567890abcdefghijkl"].join("-");
  const sample = keyName + "=" + fakeSecret + "\nAuthorization: " + fakeBearer + "\n" + fakeSk;
  const cleaned = redact(sample);
  if (cleaned.count !== 3 || cleaned.text.includes("secret-value") || cleaned.text.includes("abcdefghijklmnopqrstuvwxyz")) {
    throw new Error("密钥遮蔽自测失败。");
  }
  const raw = [
    JSON.stringify({ type: "user", timestamp: "2026-07-12T00:00:00Z", message: { role: "user", content: "hello " + keyName + "=" + fakeSecret } }),
    JSON.stringify({ type: "assistant", timestamp: "2026-07-12T00:00:01Z", message: { role: "assistant", content: [{ type: "text", text: "world" }, { type: "tool_use", name: "Read" }] } })
  ].join("\n");
  const messages = extractMessages(raw);
  const markdown = archiveMarkdown({
    meta: { title: "test\nconversation", createdAt: Date.now() },
    sessionId: "00000000-0000-0000-0000-000000000000",
    messages,
    payload: { conversation_id: "conv-test-session", transcript_sha256: sha256(raw) }
  });
  for (const token of ["record_type: chat_transcript", "privacy: sensitive", "retrieval: excluded", "completeness: source_messages_text", "[REDACTED]", "source_transcript_sha256:"]) {
    if (!markdown.includes(token)) throw new Error("会话归档契约自测失败：" + token);
  }
  if (markdown.includes("operation_preview_id") || markdown.includes("operation_payload_hash")) {
    throw new Error("正常会话归档仍包含旧操作预览令牌。");
  }
  let legacyTokenRejected = false;
  try { parseArgs(["--export", "--conversation", "conv-test-session", "--preview-id", "opv-deprecated"]); } catch { legacyTokenRejected = true; }
  if (!legacyTokenRejected) throw new Error("旧操作预览令牌仍被正常流程接受。");
  if (markdown.includes(fakeSecret) || messages.length !== 2) throw new Error("会话提取或遮蔽自测失败。");
  process.stdout.write(JSON.stringify({
    ok: true,
    redactions: cleaned.count,
    source_messages: messages.length,
    archive_contract: true,
    low_friction_export: true,
    legacy_operation_tokens_rejected: true
  }, null, 2));
}

function existingArchiveMatches(targetPath, prepared) {
  if (!fs.existsSync(targetPath)) return false;
  const content = fs.readFileSync(targetPath, "utf8");
  const sessionLine = "source_session_id: " + yamlString(prepared.sessionId);
  const hashLine = "source_transcript_sha256: " + yamlString(prepared.payload.transcript_sha256);
  const legacyHashInName = path.basename(targetPath).includes(prepared.payload.transcript_sha256.slice(0, 16));
  return content.includes(sessionLine) && (content.includes(hashLine) || legacyHashInName);
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.mode === "self-test") return selfTest();
  if (!/^(preview|export)$/.test(String(args.mode || ""))) throw new Error("必须指定 --preview 或 --export。");
  const prepared = prepare(args.conversation);
  if (args.mode === "preview") {
    process.stdout.write(JSON.stringify(Object.assign({}, prepared.summary, {
      title: prepared.payload.title,
      source_message_count: prepared.messages.length,
      completeness: "source_messages_text",
      secrets_will_be_redacted: true
    }), null, 2));
    return;
  }
  fs.mkdirSync(ARCHIVE_DIR, { recursive: true });
  const targetPath = path.join(VAULT_ROOT, ...prepared.target.split("/"));
  if (fs.existsSync(targetPath)) {
    if (!existingArchiveMatches(targetPath, prepared)) throw new Error("受控归档路径已存在不匹配文件，已停止覆盖。");
    process.stdout.write(JSON.stringify({
      ok: true,
      exported: true,
      already_exported: true,
      target: prepared.target
    }, null, 2));
    return;
  }
  fs.writeFileSync(targetPath, archiveMarkdown(prepared), { encoding: "utf8", flag: "wx" });
  process.stdout.write(JSON.stringify({
    ok: true,
    exported: true,
    target: prepared.target,
    already_exported: false
  }, null, 2));
}

try { main(); } catch (error) {
  process.stderr.write(JSON.stringify({ ok: false, error: error.message }));
  process.exitCode = 1;
}

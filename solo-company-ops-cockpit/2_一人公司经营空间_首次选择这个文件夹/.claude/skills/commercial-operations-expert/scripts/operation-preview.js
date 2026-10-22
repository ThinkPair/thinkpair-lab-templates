#!/usr/bin/env node
"use strict";

const crypto = require("crypto");

const SCHEMA = "operation-preview.v1";
const LEGACY_NOTICE = "仅供 v0.1.3 旧记录与旧流程兼容；v0.1.4 正常写回不再使用操作预览令牌。";

function stableStringify(value) {
  if (value === null || typeof value !== "object") return JSON.stringify(value);
  if (Array.isArray(value)) return "[" + value.map(stableStringify).join(",") + "]";
  return "{" + Object.keys(value).sort().map((key) => JSON.stringify(key) + ":" + stableStringify(value[key])).join(",") + "}";
}

function normalizeTarget(target) {
  return String(target || "").trim().replace(/\\/g, "/").replace(/\/+/g, "/");
}

function payloadText(payload) {
  return typeof payload === "string" ? payload : stableStringify(payload);
}

function canonicalEnvelope(operation, target, payload) {
  const body = Buffer.from(payloadText(payload), "utf8").toString("base64url");
  return [SCHEMA, String(operation || "").trim(), normalizeTarget(target), body].join("\n");
}

function createPreview({ operation, target, payload, summary = "" }) {
  if (!/^[a-z][a-z0-9_]{2,40}$/.test(String(operation || ""))) throw new Error("operation 不合法。");
  const normalizedTarget = normalizeTarget(target);
  if (!normalizedTarget) throw new Error("target 不能为空。");
  const hex = crypto.createHash("sha256").update(canonicalEnvelope(operation, normalizedTarget, payload), "utf8").digest("hex");
  return Object.freeze({
    schema: SCHEMA,
    legacy_compatibility: true,
    legacy_notice: LEGACY_NOTICE,
    operation: String(operation),
    target: normalizedTarget,
    summary: String(summary || "").trim(),
    preview_id: "opv-" + hex.slice(0, 16),
    payload_hash: "sha256:" + hex
  });
}

function decodeBase64Url(text) {
  if (!/^[A-Za-z0-9_-]+$/.test(String(text || ""))) throw new Error("input-base64 不合法。");
  return Buffer.from(String(text), "base64url").toString("utf8");
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    if (!key.startsWith("--")) throw new Error("参数格式不合法。");
    if (key === "--self-test") { out.selfTest = true; continue; }
    const value = argv[++i];
    if (value === undefined || value.startsWith("--")) throw new Error(key + " 缺少值。");
    out[key.slice(2)] = value;
  }
  return out;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.selfTest) {
    const a = createPreview({ operation: "write", target: "x\\y.md", payload: "内容", summary: "测试" });
    const b = createPreview({ operation: "write", target: "x/y.md", payload: "内容", summary: "不同摘要" });
    const c = createPreview({ operation: "write", target: "x/y.md", payload: "新内容" });
    if (a.payload_hash !== b.payload_hash || a.payload_hash === c.payload_hash) throw new Error("preview hash self-test failed");
    if (a.legacy_compatibility !== true || !a.legacy_notice.includes("v0.1.4")) throw new Error("legacy compatibility marker missing");
    process.stdout.write(JSON.stringify({ ok: true, legacy_compatibility: true, preview: a }, null, 2));
    return;
  }
  const raw = decodeBase64Url(args["input-base64"]);
  const input = JSON.parse(raw);
  const allowed = new Set(["operation", "target", "payload", "summary"]);
  const unknown = Object.keys(input).filter((key) => !allowed.has(key));
  if (unknown.length) throw new Error("未知字段：" + unknown.join(", "));
  process.stdout.write(JSON.stringify(createPreview(input), null, 2));
}

if (require.main === module) {
  try { main(); } catch (error) {
    process.stderr.write(JSON.stringify({ ok: false, error: error.message }));
    process.exitCode = 1;
  }
}

module.exports = Object.freeze({ SCHEMA, LEGACY_NOTICE, stableStringify, normalizeTarget, canonicalEnvelope, createPreview });

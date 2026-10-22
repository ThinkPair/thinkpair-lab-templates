import test from "node:test";
import assert from "node:assert/strict";
import {
  diagnose,
  emptyAnswers,
  externalDemo,
  getLiveLedger,
  internalDemo,
  sanitizeSensitiveText,
} from "../lib/diagnosis.ts";

test("external evidence routes to the external branch", () => {
  const result = diagnose({ ...externalDemo });
  assert.equal(result.outcome, "external");
  assert.match(result.title, /外部/);
  assert.equal(result.externalEvidence.length, 3);
  assert.notEqual(result.confidence, "较高");
  assert.ok(result.unknowns.some((item) => item.includes("独立核验")));
  assert.match(result.priorityAction.title, /7 天/);
});

test("conversion loss routes to the internal branch without inventing external stability", () => {
  const result = diagnose({ ...internalDemo });
  assert.equal(result.outcome, "internal");
  assert.match(result.title, /成交/);
  assert.equal(result.externalEvidence.length, 0);
  assert.ok(result.unknowns.some((item) => item.includes("外部")));
  assert.match(result.priorityAction.title, /20 条未成交咨询/);
});

test("subjective concern without comparable records stops at an evidence action", () => {
  const answers = {
    ...emptyAnswers,
    businessType: "社区美甲店",
    region: "城市级区域",
    concern: "感觉最近人少了",
    metric: "customers",
    changeSince: "最近两个月",
    comparisonPeriod: "说不清",
    hasComparableData: "no",
  };
  const result = diagnose(answers);
  assert.equal(result.outcome, "unconfirmed");
  assert.match(result.title, /不能确认/);
  assert.match(result.priorityAction.title, /同口径/);
  assert.ok(result.unknowns.every((item) => !item.includes("0")));
});

test("revenue decline never masquerades as customer decline", () => {
  const answers = {
    ...internalDemo,
    metric: "revenue",
    beforeValue: "24000",
    afterValue: "18000",
  };
  const result = diagnose(answers);
  assert.equal(result.outcome, "unconfirmed");
  assert.match(result.title, /营业额下降/);
  assert.match(result.summary, /不等于客户人数减少/);
});

test("unknown values remain visible as unknown rather than zero", () => {
  const answers = {
    ...internalDemo,
    inquiryTrend: "unknown",
    repeatTrend: "unknown",
    externalSignals: ["none"],
  };
  const ledger = getLiveLedger(answers);
  assert.ok(ledger.unknowns.some((item) => item.includes("咨询")));
  assert.ok(ledger.unknowns.some((item) => item.includes("复购")));
  assert.ok(ledger.unknowns.some((item) => item.includes("外部")));
});

test("sensitive strings are masked before entering the report", () => {
  const input = "手机号13800138000，邮箱demo@example.com，Key sk-demo-not-a-real-key，星河路88号";
  const sanitized = sanitizeSensitiveText(input);
  assert.equal(sanitized.changed, true);
  assert.doesNotMatch(sanitized.value, /13800138000/);
  assert.doesNotMatch(sanitized.value, /demo@example\.com/);
  assert.doesNotMatch(sanitized.value, /sk-demo-not-a-real-key/);
  assert.doesNotMatch(sanitized.value, /星河路88号/);
});

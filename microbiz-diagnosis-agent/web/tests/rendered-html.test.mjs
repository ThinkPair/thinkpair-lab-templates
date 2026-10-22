import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);
  return worker.fetch(
    new Request("http://localhost/", { headers: { accept: "text/html" } }),
    { ASSETS: { fetch: async () => new Response("Not found", { status: 404 }) } },
    { waitUntil() {}, passThroughOnException() {} },
  );
}

test("server-renders the first act of the ThinkPair shop journey", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<html lang="zh-CN">/i);
  assert.match(html, /<title>ThinkPair｜把小店建起来，再把问题看清<\/title>/i);
  assert.match(html, /先把小店/);
  assert.match(html, /建起来/);
  assert.match(html, /店铺名字/);
  assert.match(html, /六项事实，拼出你的经营现场/);
  assert.match(html, /01[\s\S]*建店[\s\S]*02[\s\S]*诊断[\s\S]*03[\s\S]*判断/);
  assert.match(html, /shop-stage-0-plot\.webp/);
  assert.doesNotMatch(html, /运营闭环|这是演示|模拟样本|样例站点|AI 建议用户|根据知识库/);
});

test("keeps actual AI routes, honest offline boundaries, and all seven scene frames", async () => {
  const [page, diagnosisRoute, judgmentRoute, diagnosisHelper, judgmentHelper] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/api/diagnose/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/api/judge/route.ts", import.meta.url), "utf8"),
    readFile(new URL("../lib/ai-diagnosis.ts", import.meta.url), "utf8"),
    readFile(new URL("../lib/ai-judgment.ts", import.meta.url), "utf8"),
  ]);

  assert.match(page, /fetch\("\/api\/diagnose"/);
  assert.match(page, /fetch\("\/api\/judge"/);
  assert.match(diagnosisRoute, /store: false/);
  assert.match(judgmentRoute, /store: false/);
  assert.match(diagnosisRoute, /AI 尚未连接/);
  assert.match(judgmentRoute, /不能生成经营判断/);
  assert.match(diagnosisHelper, /未知绝不能按 0 处理/);
  assert.match(judgmentHelper, /score=null/);
  assert.match(judgmentHelper, /只给一个核心判断和一个优先动作/);

  const names = ["plot", "foundation", "structure", "facade", "interior", "owner", "complete"];
  for (const [index, name] of names.entries()) {
    await access(new URL(`../public/assets/thinkpair-pixel-v5/shop-stage-${index}-${name}.webp`, import.meta.url));
  }
});

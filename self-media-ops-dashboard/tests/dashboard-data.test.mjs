import assert from "node:assert/strict";
import test from "node:test";
import { getDashboardData, normalizeDashboardData } from "../src/dashboardData.js";

const completeStage = (id, values) => ({
  id,
  values: Object.fromEntries(
    Object.entries(values).map(([platform, value]) => [
      platform,
      { value, state: "confirmed", sourceRefs: [`source/${id}/${platform}`] },
    ]),
  ),
});

test("all-null input stays blank and never becomes zero", () => {
  const dashboard = normalizeDashboardData({
    stages: [
      completeStage("reach", { douyin: null, xhs: null, bilibili: null }),
      completeStage("follow", { douyin: null, xhs: null, bilibili: null }),
    ],
  });

  assert.equal(dashboard.mode, "blank");
  assert.equal(dashboard.stages[0].total, null);
  assert.equal(dashboard.stages[0].knownTotal, 0);
  assert.equal(dashboard.stages[0].ratioAfter, null);
});

test("partial platform data exposes known total but withholds complete total and ratio", () => {
  const dashboard = normalizeDashboardData({
    stages: [
      completeStage("reach", { douyin: 120, xhs: 80, bilibili: null }),
      completeStage("follow", { douyin: 12, xhs: 8, bilibili: 4 }),
    ],
  });

  assert.equal(dashboard.mode, "partial");
  assert.equal(dashboard.stages[0].knownTotal, 200);
  assert.equal(dashboard.stages[0].total, null);
  assert.equal(dashboard.stages[0].ratioAfter, null);
});

test("complete adjacent stages derive totals and stage-volume ratio", () => {
  const dashboard = normalizeDashboardData({
    stages: [
      completeStage("reach", { douyin: 100, xhs: 60, bilibili: 40 }),
      completeStage("follow", { douyin: 10, xhs: 6, bilibili: 4 }),
      completeStage("lead", { douyin: 5, xhs: 3, bilibili: 2 }),
      completeStage("conversation", { douyin: 2, xhs: 1, bilibili: 1 }),
      completeStage("paid", { douyin: 1, xhs: 0, bilibili: 0 }),
      completeStage("renewal", { douyin: 0, xhs: 0, bilibili: 0 }),
    ],
  });

  assert.equal(dashboard.mode, "actual");
  assert.equal(dashboard.stages[0].total, 200);
  assert.equal(dashboard.stages[1].total, 20);
  assert.equal(dashboard.stages[0].ratioAfter, 0.1);
  assert.equal(dashboard.stages[5].total, 0);
});

test("conflict state is preserved and reported at dashboard level", () => {
  const dashboard = normalizeDashboardData({
    stages: [
      {
        id: "reach",
        values: {
          douyin: { value: 100, state: "conflict", sourceRefs: ["A", "B"] },
          xhs: { value: 50, state: "confirmed", sourceRefs: ["C"] },
          bilibili: { value: 25, state: "confirmed", sourceRefs: ["D"] },
        },
      },
    ],
  });

  assert.equal(dashboard.mode, "conflict");
  assert.equal(dashboard.stages[0].evidence, "conflict");
});

test("missing trend points remain null instead of being interpolated to zero", () => {
  const dashboard = normalizeDashboardData({
    leadTrend: [
      { week: "W1", values: { douyin: 2, xhs: null, bilibili: 1 } },
      { week: "W2", values: { douyin: 4, xhs: 2, bilibili: null } },
    ],
  });

  assert.equal(dashboard.leadTrend[0].xhs, null);
  assert.equal(dashboard.leadTrend[1].bilibili, null);
});

test("episode plays keep per-episode nulls and notes", () => {
  const dashboard = normalizeDashboardData({
    episodePlays: [
      { episode: "第01期", douyin: 3699, xhs: null, bilibili: null, note: "07-29主页快照约213h" },
      { episode: "第03期", douyin: 347, xhs: 227, bilibili: null, note: "08-01后台" },
    ],
  });

  assert.equal(dashboard.episodePlays.length, 2);
  assert.equal(dashboard.episodePlays[0].douyin, 3699);
  assert.equal(dashboard.episodePlays[0].xhs, null);
  assert.equal(dashboard.episodePlays[1].xhs, 227);
  assert.equal(dashboard.episodePlays[0].note, "07-29主页快照约213h");
});

test("demo status forces demo mode instead of actual", () => {
  const dashboard = normalizeDashboardData({
    meta: { status: "demo" },
    stages: [
      completeStage("reach", { douyin: 100, xhs: 60, bilibili: 40 }),
      completeStage("follow", { douyin: 10, xhs: 6, bilibili: 4 }),
    ],
  });

  assert.equal(dashboard.mode, "demo");
});

test("demo query switch keeps real data untouched without ?demo=1", () => {
  const real = { meta: { status: "blank" }, stages: [] };
  const demo = { meta: { status: "demo" }, stages: [completeStage("reach", { douyin: 5, xhs: 3, bilibili: 2 })] };

  globalThis.DASHBOARD_DATA = real;
  globalThis.DASHBOARD_DEMO_DATA = demo;
  delete globalThis.location;

  assert.equal(getDashboardData().mode, "blank");

  globalThis.location = { search: "?demo=1" };
  const demoDashboard = getDashboardData();
  assert.equal(demoDashboard.mode, "demo");
  assert.equal(demoDashboard.stages[0].total, 10);

  delete globalThis.location;
  assert.equal(getDashboardData().mode, "blank");

  delete globalThis.DASHBOARD_DATA;
  delete globalThis.DASHBOARD_DEMO_DATA;
});


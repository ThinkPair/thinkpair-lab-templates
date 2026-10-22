import assert from "node:assert/strict";
import test from "node:test";
import {
  answeredFieldCount,
  experienceReducer,
  initialExperienceState,
  isShopComplete,
  nextShopField,
  parseShopAnswer,
} from "../lib/experience-machine.ts";

test("shop answers advance one deterministic build stage at a time", () => {
  let state = initialExperienceState;
  const answers = [
    ["name", "木棉咖啡"],
    ["location", "杭州 · 城西"],
    ["category", "社区咖啡"],
    ["areaSqm", 86],
    ["yearsOpen", 3.5],
    ["staffCount", 4],
  ];
  for (const [index, [field, value]] of answers.entries()) {
    state = experienceReducer(state, { type: "answer", field, value });
    assert.equal(answeredFieldCount(state.shop), index + 1);
  }
  assert.equal(isShopComplete(state.shop), true);
  assert.equal(nextShopField(state.shop), undefined);
});

test("diagnosis is gated until the shop is complete and confirmed", () => {
  const early = experienceReducer(initialExperienceState, { type: "confirmShop" });
  assert.equal(early.phase, "build");
  const complete = { name: "店", location: "杭州", category: "咖啡", areaSqm: 50, yearsOpen: 2, staffCount: 3 };
  const confirmed = experienceReducer({ ...initialExperienceState, shop: complete }, { type: "confirmShop" });
  assert.equal(confirmed.phase, "diagnose");
  assert.equal(confirmed.confirmed, true);
});

test("numeric answers reject impossible values and keep unknowns absent", () => {
  assert.equal(parseShopAnswer("areaSqm", "86㎡"), 86);
  assert.equal(parseShopAnswer("yearsOpen", "3.5年"), 3.5);
  assert.equal(parseShopAnswer("staffCount", "4人"), 4);
  assert.throws(() => parseShopAnswer("areaSqm", "0"), /面积/);
  assert.throws(() => parseShopAnswer("staffCount", "0"), /团队人数/);
});

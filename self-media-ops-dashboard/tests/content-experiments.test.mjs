import assert from "node:assert/strict";
import test from "node:test";
import {
  CONTENT_EXPERIMENTS,
  EXPERIMENT_BASELINE,
  NEXT_BLIND_EXPERIMENT,
  visibleActionRate,
} from "../src/contentExperiments.js";

test("keeps all three published items labeled as retrospective backfills", () => {
  assert.equal(CONTENT_EXPERIMENTS.length, 3);
  assert.equal(EXPERIMENT_BASELINE.historicalSamples, 3);
  assert.equal(EXPERIMENT_BASELINE.prospectiveSamples, 0);

  for (const experiment of CONTENT_EXPERIMENTS) {
    assert.equal(experiment.recordMode, "retrospective");
    assert.equal(experiment.scoreMode, "retrospective_blinded_score");
    assert.equal(experiment.lockState, "not_pre_registered");
    assert.equal("accuracy" in experiment, false);
  }
});

test("preserves unknown platform fields instead of treating them as zero", () => {
  const episode01 = CONTENT_EXPERIMENTS.find((experiment) => experiment.id === "ep01");
  const episode03 = CONTENT_EXPERIMENTS.find((experiment) => experiment.id === "ep03");

  assert.equal(episode01.actual.avgWatchSeconds, null);
  assert.equal(episode01.actual.finishRate, null);
  assert.equal(episode01.actual.followerDelta, null);
  assert.equal(episode03.actual.likes, null);
  assert.equal(episode03.actual.finishRate, null);
  assert.equal(visibleActionRate(episode03.actual), null);
});

test("retains the episode-three script provenance caveat", () => {
  const episode03 = CONTENT_EXPERIMENTS.find((experiment) => experiment.id === "ep03");

  assert.equal(episode03.publishedAt, null);
  assert.equal(episode03.publishedAtPrecision, "unknown");
  assert.equal(episode03.scriptBasis, "current_production_text_not_independently_locked");
});

test("uses the fourth item as the first prospective blind experiment", () => {
  assert.equal(NEXT_BLIND_EXPERIMENT.episode, "04");
  assert.equal(NEXT_BLIND_EXPERIMENT.state, "waiting_for_final_script");
  assert.ok(NEXT_BLIND_EXPERIMENT.checklist.some((item) => item.includes("SHA-256")));
});

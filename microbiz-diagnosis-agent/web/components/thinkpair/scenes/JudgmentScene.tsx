"use client";

/* eslint-disable @next/next/no-img-element -- generated local scene frame is a product asset. */

import { ArrowCounterClockwise, Target } from "@phosphor-icons/react";
import type { AiJudgment } from "../../../lib/ai-judgment";
import type { ShopProfile } from "../../../lib/experience-machine";
import { OperatingRadar } from "../OperatingRadar";

export function JudgmentScene({ shop, judgment, onReset }: { shop: ShopProfile; judgment: AiJudgment; onReset: () => void }) {
  return (
    <div className="judgment-scene" data-scene="judgment">
      <img className="judgment-backdrop" src="/assets/thinkpair-pixel-v5/shop-stage-6-complete.webp" alt="已经建成并完成诊断的小店" />
      <span className="judgment-scrim" aria-hidden="true" />

      <section className="judgment-copy">
        <div className="scene-kicker"><span>03</span> SEE THE REAL PROBLEM</div>
        <p className="shop-signature">{shop.name} · 本轮经营判断</p>
        <h1>{judgment.headline}</h1>
        <p className="judgment-summary">{judgment.summary}</p>

        <article className="primary-finding">
          <small>核心判断 · {judgment.primaryJudgment.confidence === "high" ? "高" : judgment.primaryJudgment.confidence === "medium" ? "中" : "低"}置信</small>
          <h2>{judgment.primaryJudgment.statement}</h2>
          <p>仍需排除：{judgment.primaryJudgment.competingExplanation}</p>
        </article>

        <article className="priority-action">
          <span><Target weight="fill" /></span>
          <div>
            <small>先做这一件</small>
            <h3>{judgment.priorityAction.title}</h3>
            <p>{judgment.priorityAction.instruction}</p>
            <strong>验收：{judgment.priorityAction.successMetric}</strong>
          </div>
        </article>

        <p className="judgment-boundary">{judgment.evidenceBoundary}</p>
        <button className="restart-link" type="button" onClick={onReset}><ArrowCounterClockwise /> 重新建一家店</button>
      </section>

      <section className="radar-panel">
        <div className="radar-heading"><small>OPERATING MAP</small><strong>六维经营图</strong></div>
        <OperatingRadar dimensions={judgment.dimensions} />
        <p className="radar-note">没有证据的维度保持空白，不用 0 填补。</p>
      </section>
    </div>
  );
}

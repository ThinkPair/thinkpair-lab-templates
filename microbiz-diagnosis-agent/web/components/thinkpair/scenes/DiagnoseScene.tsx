"use client";

import { ArrowRight, LockKey, SpinnerGap, Sparkle } from "@phosphor-icons/react";
import type { FormEvent } from "react";
import { painLabels, type AiDiagnosis, type PainId } from "../../../lib/ai-diagnosis";
import type { ShopProfile } from "../../../lib/experience-machine";
import type { AiConnection } from "../ExperienceHeader";
import { PixelShopStage } from "../PixelShopStage";

export function DiagnoseScene({
  shop,
  connection,
  selectedPain,
  diagnosis,
  evidence,
  loading,
  error,
  onSelectPain,
  onEvidenceChange,
  onSubmit,
  onJudge,
}: {
  shop: ShopProfile;
  connection: AiConnection;
  selectedPain: PainId | null;
  diagnosis: AiDiagnosis | null;
  evidence: string;
  loading: boolean;
  error: string;
  onSelectPain: (pain: PainId) => void;
  onEvidenceChange: (value: string) => void;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onJudge: () => void;
}) {
  const connected = connection === "connected";
  const canJudge = connected && diagnosis?.stage === "analysis" && diagnosis.problemStatus === "confirmed";

  return (
    <div className="scene-layout diagnose-scene" data-scene="diagnose">
      <section className="conversation-panel">
        <div className="scene-kicker"><span>02</span> FIND THE BOTTLENECK</div>
        <h1>这家店，<br />哪里开始不对劲？</h1>
        <p className="shop-signature">{shop.name} · {shop.category} · {shop.location}</p>

        {!selectedPain ? (
          <div className="empty-diagnosis">
            <span>选择右侧最困扰你的变化</span>
            <p>它只是入口，不会直接成为结论。</p>
          </div>
        ) : (
          <>
            <div className="guide-message diagnosis-message">
              <span className="guide-avatar"><Sparkle weight="fill" /></span>
              <div>
                <small>{connected ? "AI 正在核对" : "本地诊断框架"}</small>
                <strong>{diagnosis?.headline}</strong>
                <p>{diagnosis?.question || diagnosis?.why}</p>
              </div>
            </div>

            {diagnosis?.stage === "analysis" ? (
              <div className="analysis-card">
                <small>当前核心判断</small>
                <h2>{diagnosis.headline}</h2>
                <p>{diagnosis.inferences[0] || diagnosis.why}</p>
                <div><span>{diagnosis.facts.length + diagnosis.internalEvidence.length} 条事实</span><span>{diagnosis.unknowns.length} 项待核实</span></div>
              </div>
            ) : null}

            <form className="evidence-composer" onSubmit={onSubmit}>
              <label htmlFor="evidence-input">补一条真实信息</label>
              <textarea
                id="evidence-input"
                value={evidence}
                onChange={(event) => onEvidenceChange(event.target.value)}
                placeholder={`例如：与「${painLabels[selectedPain]}」有关的同口径数据、记录或匿名反馈`}
                rows={3}
              />
              <button className="primary-action" type="submit" disabled={!connected || loading || !evidence.trim()}>
                {loading ? <SpinnerGap className="spin" /> : connected ? <Sparkle weight="fill" /> : <LockKey weight="fill" />}
                {loading ? "AI 核对中" : connected ? "交给 AI 核对" : "连接 AI 后核对"}
              </button>
            </form>

            {error ? <p className="field-error" role="alert">{error}</p> : null}
            {!connected ? <p className="offline-boundary">资料已留在当前页面。AI 未连接，所以不会生成判断或六维分数。</p> : null}

            <button className="judge-action" type="button" disabled={!canJudge || loading} onClick={onJudge}>
              {canJudge ? "生成经营判断" : "事实成立后解锁判断"} <ArrowRight weight="bold" />
            </button>
          </>
        )}
      </section>

      <PixelShopStage stage={6} mode="diagnose" selectedPain={selectedPain} onSelectPain={onSelectPain} />
    </div>
  );
}

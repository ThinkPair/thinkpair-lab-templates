"use client";

import { ArrowRight, Check, Sparkle } from "@phosphor-icons/react";
import type { FormEvent } from "react";
import {
  answeredFieldCount,
  formatShopValue,
  isShopComplete,
  nextShopField,
  shopFieldDefinitions,
  type ShopProfile,
} from "../../../lib/experience-machine";
import type { AiConnection } from "../ExperienceHeader";
import { PixelShopStage } from "../PixelShopStage";

export function BuildScene({
  shop,
  answer,
  error,
  connection,
  onAnswerChange,
  onSubmit,
  onConfirm,
}: {
  shop: ShopProfile;
  answer: string;
  error: string;
  connection: AiConnection;
  onAnswerChange: (value: string) => void;
  onSubmit: (event: FormEvent<HTMLFormElement>) => void;
  onConfirm: () => void;
}) {
  const current = nextShopField(shop);
  const count = answeredFieldCount(shop);
  const complete = isShopComplete(shop);

  return (
    <div className="scene-layout build-scene" data-scene="build">
      <section className="conversation-panel">
        <div className="scene-kicker"><span>01</span> BUILD YOUR SHOP</div>
        <h1>先把小店<br />建起来。</h1>
        <p className="scene-lead">六项事实，拼出你的经营现场。</p>

        <div className="guide-message">
          <span className="guide-avatar"><Sparkle weight="fill" /></span>
          <div>
            <small>建店向导</small>
            <p>{current ? current.prompt : "小店已经成形。确认资料后，我们再开始诊断。"}</p>
          </div>
        </div>

        <div className="profile-ledger" aria-label="店铺资料">
          {shopFieldDefinitions.map((field, index) => {
            const value = shop[field.id];
            const done = typeof value === "number" ? Number.isFinite(value) : Boolean(value);
            return (
              <div key={field.id} className={done ? "is-done" : index === count ? "is-current" : ""}>
                <span>{done ? <Check weight="bold" /> : String(index + 1).padStart(2, "0")}</span>
                <small>{field.shortLabel}</small>
                <strong>{formatShopValue(field.id, value)}</strong>
              </div>
            );
          })}
        </div>

        {complete ? (
          <button className="primary-action confirm-shop" type="button" onClick={onConfirm}>
            确认这家店 <ArrowRight weight="bold" />
          </button>
        ) : (
          <form className="answer-composer" onSubmit={onSubmit}>
            <label htmlFor="shop-answer">{current?.label}</label>
            <div>
              <input
                id="shop-answer"
                value={answer}
                onChange={(event) => onAnswerChange(event.target.value)}
                placeholder={current?.placeholder}
                inputMode={current && "inputMode" in current ? current.inputMode : "text"}
                autoComplete="off"
              />
              <button type="submit" aria-label="提交这一项"><ArrowRight weight="bold" /></button>
            </div>
            {error ? <p className="field-error" role="alert">{error}</p> : null}
          </form>
        )}

        <p className="privacy-note">
          {connection === "connected"
            ? "资料先保存在当前页面；进入诊断后由你确认提交。"
            : "当前为本地建店；AI 未连接，不会产生经营判断。"}
        </p>
      </section>

      <PixelShopStage stage={count} mode="build" />
    </div>
  );
}

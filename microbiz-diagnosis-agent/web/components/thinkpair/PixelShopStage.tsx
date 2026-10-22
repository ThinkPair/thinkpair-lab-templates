"use client";

/* eslint-disable @next/next/no-img-element -- generated local scene frames need exact browser rendering. */

import { ChartLineDown, Coins, Funnel, Repeat } from "@phosphor-icons/react";
import { useEffect } from "react";
import type { PainId } from "../../lib/ai-diagnosis";

const sceneFrames = Array.from({ length: 7 }, (_, index) =>
  `/assets/thinkpair-pixel-v5/shop-stage-${index}-${["plot", "foundation", "structure", "facade", "interior", "owner", "complete"][index]}.webp`,
);

const stageLabels = ["等待地块", "地基落位", "结构成形", "外立面完成", "店内布置", "店主入场", "小店开门"];

const painCards: Array<{ id: PainId; title: string; note: string; icon: typeof Funnel }> = [
  { id: "customers", title: "客流下滑", note: "入口在哪变窄", icon: ChartLineDown },
  { id: "conversion", title: "成交卡住", note: "客户停在哪一步", icon: Funnel },
  { id: "repeat", title: "复购走低", note: "体验还是触达", icon: Repeat },
  { id: "profit", title: "利润被吃掉", note: "钱耗在哪一层", icon: Coins },
];

export function PixelShopStage({
  stage,
  mode,
  selectedPain,
  onSelectPain,
}: {
  stage: number;
  mode: "build" | "diagnose";
  selectedPain?: PainId | null;
  onSelectPain?: (pain: PainId) => void;
}) {
  const safeStage = Math.min(6, Math.max(0, stage));

  useEffect(() => {
    sceneFrames.forEach((src) => {
      const image = new Image();
      image.src = src;
    });
  }, []);

  return (
    <section className={`pixel-stage mode-${mode}`} aria-label={mode === "build" ? "小店搭建场景" : "小店经营诊断场景"}>
      <img key={sceneFrames[safeStage]} className="scene-frame" src={sceneFrames[safeStage]} alt="像素城市中逐步建成的小店" />
      <span className="scene-vignette" aria-hidden="true" />
      <span className="pixel-grain" aria-hidden="true" />

      {mode === "build" ? (
        <div className="build-hud">
          <div>
            <small>SHOP BUILD</small>
            <strong>{String(safeStage).padStart(2, "0")} / 06</strong>
          </div>
          <span>{stageLabels[safeStage]}</span>
          <div className="build-meter" aria-label={`搭建进度 ${Math.round((safeStage / 6) * 100)}%`}>
            <i style={{ width: `${(safeStage / 6) * 100}%` }} />
          </div>
        </div>
      ) : (
        <div className="pain-cloud" aria-label="选择最困扰你的经营变化">
          {painCards.map((pain) => {
            const Icon = pain.icon;
            return (
              <button
                key={pain.id}
                className={`pain-orbit pain-${pain.id} ${selectedPain === pain.id ? "is-selected" : ""}`}
                type="button"
                aria-pressed={selectedPain === pain.id}
                onClick={() => onSelectPain?.(pain.id)}
              >
                <Icon weight="bold" />
                <span><strong>{pain.title}</strong><small>{pain.note}</small></span>
              </button>
            );
          })}
        </div>
      )}
    </section>
  );
}

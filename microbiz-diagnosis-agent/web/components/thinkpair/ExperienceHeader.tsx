"use client";

import { ArrowCounterClockwise, CirclesFour, CloudCheck, CloudSlash } from "@phosphor-icons/react";
import type { ExperiencePhase } from "../../lib/experience-machine";

export type AiConnection = "checking" | "connected" | "offline" | "error";

const phaseIndex: Record<ExperiencePhase, number> = { build: 0, diagnose: 1, judgment: 2 };
const phases = [
  { id: "build", number: "01", label: "建店" },
  { id: "diagnose", number: "02", label: "诊断" },
  { id: "judgment", number: "03", label: "判断" },
] as const;

function connectionText(connection: AiConnection) {
  if (connection === "connected") return "AI 已连接";
  if (connection === "checking") return "检测 AI";
  if (connection === "error") return "AI 暂不可用";
  return "AI 未连接";
}

export function ExperienceHeader({
  phase,
  connection,
  onReset,
}: {
  phase: ExperiencePhase;
  connection: AiConnection;
  onReset: () => void;
}) {
  const active = phaseIndex[phase];
  const ConnectedIcon = connection === "connected" ? CloudCheck : CloudSlash;

  return (
    <header className="experience-header">
      <a className="brand" href="#top" aria-label="ThinkPair 首页">
        <span className="brand-mark" aria-hidden="true"><CirclesFour weight="fill" /></span>
        <span>ThinkPair</span>
      </a>

      <ol className="phase-nav" aria-label="诊断进度">
        {phases.map((item, index) => (
          <li key={item.id} className={index === active ? "is-active" : index < active ? "is-done" : ""}>
            <span>{item.number}</span>
            <strong>{item.label}</strong>
          </li>
        ))}
      </ol>

      <div className="header-actions">
        <span className={`connection-pill ${connection}`} role="status">
          <ConnectedIcon weight="fill" />
          {connectionText(connection)}
        </span>
        <button className="icon-button" type="button" onClick={onReset} aria-label="重新开始">
          <ArrowCounterClockwise />
        </button>
      </div>
    </header>
  );
}

"use client";

import { gsap } from "gsap";
import { useEffect, useLayoutEffect, useReducer, useRef, useState, type FormEvent } from "react";
import { ExperienceHeader, type AiConnection } from "../components/thinkpair/ExperienceHeader";
import { BuildScene } from "../components/thinkpair/scenes/BuildScene";
import { DiagnoseScene } from "../components/thinkpair/scenes/DiagnoseScene";
import { JudgmentScene } from "../components/thinkpair/scenes/JudgmentScene";
import {
  getFrameworkDraft,
  painLabels,
  type AiDiagnosis,
  type DiagnosisTurn,
  type PainId,
} from "../lib/ai-diagnosis";
import type { AiJudgment } from "../lib/ai-judgment";
import {
  experienceReducer,
  initialExperienceState,
  nextShopField,
  parseShopAnswer,
} from "../lib/experience-machine";

type ErrorPayload = { message?: string };

export default function Home() {
  const [experience, dispatch] = useReducer(experienceReducer, initialExperienceState);
  const [connection, setConnection] = useState<AiConnection>("checking");
  const [answer, setAnswer] = useState("");
  const [buildError, setBuildError] = useState("");
  const [selectedPain, setSelectedPain] = useState<PainId | null>(null);
  const [diagnosis, setDiagnosis] = useState<AiDiagnosis | null>(null);
  const [diagnosisHistory, setDiagnosisHistory] = useState<DiagnosisTurn[]>([]);
  const [evidence, setEvidence] = useState("");
  const [requestError, setRequestError] = useState("");
  const [loading, setLoading] = useState(false);
  const [judgment, setJudgment] = useState<AiJudgment | null>(null);
  const sceneRef = useRef<HTMLDivElement>(null);
  const requestId = useRef(0);

  useEffect(() => {
    let alive = true;
    fetch("/api/diagnose", { cache: "no-store" })
      .then(async (response) => {
        if (!response.ok) throw new Error("STATUS_CHECK_FAILED");
        const payload = (await response.json()) as { configured?: boolean };
        if (alive) setConnection(payload.configured ? "connected" : "offline");
      })
      .catch(() => alive && setConnection("error"));
    return () => { alive = false; };
  }, []);

  useLayoutEffect(() => {
    const root = sceneRef.current;
    if (!root) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const context = gsap.context(() => {
      gsap.fromTo("[data-scene]", { autoAlpha: 0, y: 18, scale: 0.992 }, { autoAlpha: 1, y: 0, scale: 1, duration: 0.72, ease: "power3.out" });
    }, root);
    return () => context.revert();
  }, [experience.phase]);

  function resetExperience() {
    requestId.current += 1;
    dispatch({ type: "reset" });
    setAnswer("");
    setBuildError("");
    setSelectedPain(null);
    setDiagnosis(null);
    setDiagnosisHistory([]);
    setEvidence("");
    setRequestError("");
    setJudgment(null);
    setLoading(false);
  }

  function submitBuildAnswer(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const field = nextShopField(experience.shop);
    if (!field) return;
    try {
      const value = parseShopAnswer(field.id, answer);
      dispatch({ type: "answer", field: field.id, value });
      setAnswer("");
      setBuildError("");
    } catch (error) {
      setBuildError(error instanceof Error ? error.message : "请重新填写这一项。");
    }
  }

  function confirmShop() {
    dispatch({ type: "confirmShop" });
    setRequestError("");
  }

  function choosePain(pain: PainId) {
    setSelectedPain(pain);
    setDiagnosis(getFrameworkDraft(pain, painLabels[pain]));
    setDiagnosisHistory([]);
    setEvidence("");
    setRequestError("");
  }

  async function submitEvidence(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (connection !== "connected" || !selectedPain || !evidence.trim() || loading) return;

    const currentRequest = ++requestId.current;
    const userTurn: DiagnosisTurn = { role: "user", content: evidence.trim() };
    setLoading(true);
    setRequestError("");

    try {
      const response = await fetch("/api/diagnose", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          painId: selectedPain,
          problem: painLabels[selectedPain],
          evidence: evidence.trim(),
          history: [...diagnosisHistory, userTurn],
          shop: experience.shop,
        }),
      });
      const payload = (await response.json()) as { diagnosis?: AiDiagnosis } & ErrorPayload;
      if (currentRequest !== requestId.current) return;
      if (!response.ok || !payload.diagnosis) throw new Error(payload.message || "AI 核对没有完成，请再试一次。");

      const assistantTurn: DiagnosisTurn = {
        role: "assistant",
        content: payload.diagnosis.stage === "question" ? payload.diagnosis.question : payload.diagnosis.headline,
      };
      setDiagnosis(payload.diagnosis);
      setDiagnosisHistory((turns) => [...turns, userTurn, assistantTurn].slice(-6));
      setEvidence("");
    } catch (error) {
      if (currentRequest === requestId.current) setRequestError(error instanceof Error ? error.message : "AI 暂时不可用。");
    } finally {
      if (currentRequest === requestId.current) setLoading(false);
    }
  }

  async function generateJudgment() {
    if (connection !== "connected" || !selectedPain || diagnosis?.stage !== "analysis" || loading) return;
    const currentRequest = ++requestId.current;
    setLoading(true);
    setRequestError("");

    try {
      const response = await fetch("/api/judge", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ shop: experience.shop, pain: painLabels[selectedPain], diagnosis }),
      });
      const payload = (await response.json()) as { judgment?: AiJudgment } & ErrorPayload;
      if (currentRequest !== requestId.current) return;
      if (!response.ok || !payload.judgment) throw new Error(payload.message || "经营判断没有生成，请再试一次。");
      setJudgment(payload.judgment);
      dispatch({ type: "showJudgment" });
    } catch (error) {
      if (currentRequest === requestId.current) setRequestError(error instanceof Error ? error.message : "AI 暂时不可用。");
    } finally {
      if (currentRequest === requestId.current) setLoading(false);
    }
  }

  return (
    <main className={`experience phase-${experience.phase}`} id="top">
      <ExperienceHeader phase={experience.phase} connection={connection} onReset={resetExperience} />
      <div className="scene-viewport" ref={sceneRef}>
        {experience.phase === "build" ? (
          <BuildScene
            shop={experience.shop}
            answer={answer}
            error={buildError}
            connection={connection}
            onAnswerChange={setAnswer}
            onSubmit={submitBuildAnswer}
            onConfirm={confirmShop}
          />
        ) : null}

        {experience.phase === "diagnose" ? (
          <DiagnoseScene
            shop={experience.shop}
            connection={connection}
            selectedPain={selectedPain}
            diagnosis={diagnosis}
            evidence={evidence}
            loading={loading}
            error={requestError}
            onSelectPain={choosePain}
            onEvidenceChange={setEvidence}
            onSubmit={submitEvidence}
            onJudge={generateJudgment}
          />
        ) : null}

        {experience.phase === "judgment" && judgment ? (
          <JudgmentScene shop={experience.shop} judgment={judgment} onReset={resetExperience} />
        ) : null}
      </div>
    </main>
  );
}

import { useEffect, useMemo, useRef, useState } from "react";
import {
  ArrowDown,
  ArrowRight,
  ArrowUp,
  Check,
  GripVertical,
  Info,
  PencilLine,
  RotateCcw,
  Sparkles,
  X,
} from "lucide-react";

const DEFAULT_DIMENSIONS = [
  { id: "extraction", name: "萃取稳定性", criterion: "至少 3 次对照，TDS 波动 ≤ 0.10%", value: 4.1 },
  { id: "flavor", name: "风味识别", criterion: "至少 2 次描述，风味词一致", value: 3.0 },
  { id: "repeat", name: "冲煮复现", criterion: "至少 3 次复现，每杯偏差 ≤ 1.5%", value: 3.0 },
  { id: "control", name: "变量控制", criterion: "仅单变量调整且记录完整", value: 2.9 },
  { id: "record", name: "记录完整度", criterion: "记录 100%，含关键参数与过程", value: 2.1 },
  { id: "feedback", name: "外部反馈", criterion: "至少 1 条有效反馈或建议", value: 2.0 },
];

const STATUS_LABELS = ["未证明", "已观察", "可重复", "外部验证", "可移交"];

function RadarChart({ dimensions }) {
  const canvasRef = useRef(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return undefined;

    const draw = () => {
      const rect = canvas.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      canvas.width = Math.max(1, Math.round(rect.width * dpr));
      canvas.height = Math.max(1, Math.round(rect.height * dpr));
      const ctx = canvas.getContext("2d");
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, rect.width, rect.height);

      const centerX = rect.width / 2;
      const centerY = rect.height / 2 + 5;
      const radius = Math.min(rect.width, rect.height) * 0.355;
      const angleFor = (index) => -Math.PI / 2 + (Math.PI * 2 * index) / 6;
      const pointAt = (index, scale) => ({
        x: centerX + Math.cos(angleFor(index)) * radius * scale,
        y: centerY + Math.sin(angleFor(index)) * radius * scale,
      });

      ctx.lineWidth = 1;
      for (let level = 1; level <= 5; level += 1) {
        ctx.beginPath();
        dimensions.forEach((_, index) => {
          const point = pointAt(index, level / 5);
          if (index === 0) ctx.moveTo(point.x, point.y);
          else ctx.lineTo(point.x, point.y);
        });
        ctx.closePath();
        ctx.strokeStyle = level === 5 ? "rgba(95,91,85,.38)" : "rgba(95,91,85,.22)";
        ctx.stroke();
      }

      dimensions.forEach((_, index) => {
        const point = pointAt(index, 1);
        ctx.beginPath();
        ctx.moveTo(centerX, centerY);
        ctx.lineTo(point.x, point.y);
        ctx.strokeStyle = "rgba(95,91,85,.24)";
        ctx.stroke();
      });

      const valuePoints = dimensions.map((item, index) => pointAt(index, item.value / 5));
      ctx.beginPath();
      valuePoints.forEach((point, index) => {
        if (index === 0) ctx.moveTo(point.x, point.y);
        else ctx.lineTo(point.x, point.y);
      });
      ctx.closePath();
      ctx.fillStyle = "rgba(93,126,167,.23)";
      ctx.fill();
      ctx.lineWidth = 3;
      ctx.strokeStyle = "#2e69a5";
      ctx.stroke();

      valuePoints.forEach((point) => {
        ctx.beginPath();
        ctx.arc(point.x, point.y, 4.5, 0, Math.PI * 2);
        ctx.fillStyle = "#f2ece2";
        ctx.fill();
        ctx.lineWidth = 2.5;
        ctx.strokeStyle = "#2e69a5";
        ctx.stroke();
      });

      ctx.fillStyle = "#3f3d39";
      ctx.font = '14px "Microsoft YaHei UI", "Microsoft YaHei", sans-serif';
      ctx.textBaseline = "middle";
      dimensions.forEach((item, index) => {
        const point = pointAt(index, 1.19);
        const horizontal = Math.cos(angleFor(index));
        ctx.textAlign = horizontal > 0.2 ? "left" : horizontal < -0.2 ? "right" : "center";
        const maxWidth = Math.max(58, rect.width * 0.24);
        ctx.fillText(item.name, point.x, point.y, maxWidth);
      });
    };

    draw();
    const observer = new ResizeObserver(draw);
    observer.observe(canvas);
    return () => observer.disconnect();
  }, [dimensions]);

  return (
    <div className="radar-accessible-wrap">
      <canvas
        ref={canvasRef}
        className="radar-canvas"
        aria-label="六维能力证据雷达图"
        aria-describedby="radar-status-list"
      />
      <ul id="radar-status-list" className="visually-hidden">
        {dimensions.map((item) => (
          <li key={item.id}>{item.name}：{STATUS_LABELS[Math.max(0, Math.round(item.value) - 1)]}，达标证据为{item.criterion}</li>
        ))}
      </ul>
    </div>
  );
}

function SectionTitle({ children, meta }) {
  return (
    <div className="section-title-row">
      <h2>{children}</h2>
      {meta ? <span>{meta}</span> : null}
    </div>
  );
}

function DimensionEditor({ dimensions, onChange, onClose, onSave, onReset, isModal }) {
  const [draggedId, setDraggedId] = useState(null);
  const drawerRef = useRef(null);
  const closeButtonRef = useRef(null);

  useEffect(() => {
    if (isModal) closeButtonRef.current?.focus();
  }, [isModal]);

  const keepFocusInside = (event) => {
    if (!isModal || event.key !== "Tab") return;
    const focusable = drawerRef.current?.querySelectorAll(
      'button:not(:disabled), input:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex="-1"])',
    );
    if (!focusable?.length) return;
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  };

  const move = (index, direction) => {
    const nextIndex = index + direction;
    if (nextIndex < 0 || nextIndex >= dimensions.length) return;
    const next = [...dimensions];
    [next[index], next[nextIndex]] = [next[nextIndex], next[index]];
    onChange(next);
  };

  const update = (id, key, value) => {
    onChange(dimensions.map((item) => (item.id === id ? { ...item, [key]: value } : item)));
  };

  const dropAt = (targetId) => {
    if (!draggedId || draggedId === targetId) return;
    const from = dimensions.findIndex((item) => item.id === draggedId);
    const to = dimensions.findIndex((item) => item.id === targetId);
    const next = [...dimensions];
    const [moved] = next.splice(from, 1);
    next.splice(to, 0, moved);
    onChange(next);
    setDraggedId(null);
  };

  return (
    <aside
      ref={drawerRef}
      className="editor-drawer"
      role="dialog"
      aria-modal={isModal}
      aria-labelledby="editor-title"
      onKeyDown={keepFocusInside}
    >
      <div className="drawer-header">
        <div>
          <span className="eyebrow">我的六边形模板</span>
          <h2 id="editor-title">编辑六维模板</h2>
        </div>
        <button ref={closeButtonRef} className="icon-button" type="button" onClick={onClose} aria-label="关闭模板编辑器">
          <X size={20} />
        </button>
      </div>

      <div className="guard-note"><Info size={15} />维度可改；证据状态不可手动拔高</div>
      <p className="drawer-help">固定六个位置。可拖拽排序，也可使用上下键；名称与证据标准会同步到六边形。</p>

      <div className="dimension-list">
        {dimensions.map((item, index) => (
          <article
            className="dimension-card"
            key={item.id}
            draggable
            onDragStart={() => setDraggedId(item.id)}
            onDragOver={(event) => event.preventDefault()}
            onDrop={() => dropAt(item.id)}
          >
            <div className="dimension-order" aria-hidden="true"><GripVertical size={17} />{index + 1}</div>
            <div className="dimension-fields">
              <label>
                <span>维度名称</span>
                <input
                  value={item.name}
                  maxLength={10}
                  onChange={(event) => update(item.id, "name", event.target.value)}
                />
              </label>
              <label>
                <span>达标证据</span>
                <textarea
                  value={item.criterion}
                  maxLength={70}
                  rows={2}
                  onChange={(event) => update(item.id, "criterion", event.target.value)}
                />
              </label>
              <div className="dimension-status">
                <span>当前证据：{STATUS_LABELS[Math.max(0, Math.round(item.value) - 1)]}</span>
                <span aria-label="此状态只读" className="readonly-pill">只读</span>
              </div>
            </div>
            <div className="reorder-buttons">
              <button type="button" onClick={() => move(index, -1)} disabled={index === 0} aria-label={`上移${item.name}`}><ArrowUp size={15} /></button>
              <button type="button" onClick={() => move(index, 1)} disabled={index === dimensions.length - 1} aria-label={`下移${item.name}`}><ArrowDown size={15} /></button>
            </div>
          </article>
        ))}
      </div>

      <div className="drawer-actions">
        <button className="ai-button" type="button" onClick={() => onChange(DEFAULT_DIMENSIONS.map((item) => ({ ...item })))}>
          <Sparkles size={17} />AI 推荐六维
        </button>
        <div className="drawer-action-row">
          <button className="secondary-button" type="button" onClick={onSave}><Check size={17} />保存我的模板</button>
          <button className="ghost-button" type="button" onClick={onReset}><RotateCcw size={16} />恢复默认</button>
        </div>
      </div>
    </aside>
  );
}

export function App() {
  const [dimensions, setDimensions] = useState(() => {
    try {
      const saved = window.localStorage.getItem("ability-six-dimensions");
      return saved ? JSON.parse(saved) : DEFAULT_DIMENSIONS.map((item) => ({ ...item }));
    } catch {
      return DEFAULT_DIMENSIONS.map((item) => ({ ...item }));
    }
  });
  const [editorOpen, setEditorOpen] = useState(true);
  const [toast, setToast] = useState("");
  const [isNarrow, setIsNarrow] = useState(() => window.matchMedia("(max-width: 1179px)").matches);
  const lastEditorTrigger = useRef(null);
  const lastTriggerWasFloating = useRef(false);
  const floatingEditorButton = useRef(null);

  const weakest = useMemo(
    () => dimensions.reduce((current, item) => (item.value < current.value ? item : current), dimensions[0]),
    [dimensions],
  );

  useEffect(() => {
    if (!toast) return undefined;
    const timer = window.setTimeout(() => setToast(""), 2800);
    return () => window.clearTimeout(timer);
  }, [toast]);

  useEffect(() => {
    const query = window.matchMedia("(max-width: 1179px)");
    const update = () => setIsNarrow(query.matches);
    query.addEventListener("change", update);
    return () => query.removeEventListener("change", update);
  }, []);

  const openEditor = (event) => {
    lastEditorTrigger.current = event?.currentTarget ?? null;
    lastTriggerWasFloating.current = Boolean(event?.currentTarget?.classList.contains("floating-editor-button"));
    setEditorOpen(true);
  };

  const closeEditor = () => {
    setEditorOpen(false);
    window.requestAnimationFrame(() => {
      if (lastTriggerWasFloating.current) floatingEditorButton.current?.focus();
      else if (lastEditorTrigger.current) lastEditorTrigger.current.focus();
      else floatingEditorButton.current?.focus();
    });
  };

  useEffect(() => {
    const onKeyDown = (event) => {
      if (event.key === "Escape" && editorOpen) closeEditor();
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [editorOpen]);

  const saveDimensions = () => {
    window.localStorage.setItem("ability-six-dimensions", JSON.stringify(dimensions));
    setToast("六维模板已保存；证据状态保持不变");
  };

  const resetDimensions = () => {
    setDimensions(DEFAULT_DIMENSIONS.map((item) => ({ ...item })));
    setToast("已恢复咖啡师演示模板，尚未保存");
  };

  return (
    <main className="cockpit-shell">
      <img className="binder-decoration" src="/assets/binder-rings.png" alt="" aria-hidden="true" />
      <img className="clip-decoration" src="/assets/brass-clips.png" alt="" aria-hidden="true" />
      <header className="brand-bar">
        <div className="brand-lockup">
          <img src="/assets/crystal-logo.png" alt="降噪实验室晶体标识" />
          <strong>降噪实验室</strong>
          <span className="brand-divider" aria-hidden="true" />
          <span>个人能力复利驾驶舱</span>
        </div>
        <span className="edition-mark">证据手账 <Sparkles size={15} /></span>
      </header>

      <nav className="folder-tabs" aria-label="当前技能与证据视图">
        <button className="folder-tab active" type="button">手冲咖啡 <span aria-hidden="true" /></button>
        <button className="folder-tab" type="button">能力版本 v1</button>
        <button className="folder-tab wide-tab" type="button">当前最弱证据：{weakest.name}</button>
      </nav>

      <div className={`workspace ${editorOpen ? "has-editor" : ""} ${editorOpen && isNarrow ? "is-modal" : ""}`}>
        <section
          className="notebook"
          aria-label="个人能力证据手账"
          aria-hidden={editorOpen && isNarrow ? true : undefined}
          inert={editorOpen && isNarrow ? true : undefined}
        >
          <article className="paper-page left-page">
            <SectionTitle meta="2026-07-12　周日（今天）">练习档案</SectionTitle>

            <section className="practice-block">
              <h3>本周唯一练习</h3>
              <div className="practice-note">固定研磨度，完成 3 次对照萃取</div>
            </section>

            <section className="evidence-block">
              <SectionTitle meta="2026-07-12　记录">作品证据</SectionTitle>
              <img className="evidence-photo" src="/assets/coffee-evidence.png" alt="手冲咖啡萃取、电子秤与手写参数记录" />
            </section>

            <section className="feedback-block">
              <SectionTitle meta="2026-07-12　来自：同杯小林">外部反馈</SectionTitle>
              <blockquote>
                <span className="quote-mark">“</span>
                第二杯的前中段更干净，甜感更清晰；第三杯尾段有点涩，建议延长二注后段时间，或微调水温。
                <span className="quote-mark closing">”</span>
              </blockquote>
            </section>

            <section className="practice-footnote">
              <div className="record-stamp"><strong>已记录</strong><span>2026-07-12</span></div>
              <div><span>本次练习备注</span><p>第二杯表现最好。下次尝试把二注后段延长 10 秒，观察尾段变化。</p></div>
            </section>
          </article>

          <article className="paper-page right-page">
            <section className="radar-block">
              <div className="section-title-row radar-title">
                <h2>能力证据地图</h2>
                <button className="edit-template-button" type="button" onClick={openEditor}>
                  <PencilLine size={14} />编辑六维模板
                </button>
                <span>2026-07-12　更新</span>
              </div>
              <RadarChart dimensions={dimensions} />
              <div className="radar-legend" aria-label="证据图例">
                <span><i className="legend-dot solid" />已有证据</span>
                <span><i className="legend-dot" />证据不足</span>
                <span><i className="legend-line" />无证据</span>
              </div>
              <p className="radar-guard"><Info size={14} />维度可改，证据状态不可手动拔高</p>
            </section>

            <section className="adjustment-block">
              <SectionTitle meta="2026-07-11　计划">下一次调整</SectionTitle>
              <div className="ruled-note">
                <p><strong>假设：</strong>二注后段流速过快，导致尾段涩感。</p>
                <p><strong>调整：</strong>延长二注后段 10 秒，或将水温下调 1°C。</p>
                <p><strong>验证：</strong>观察尾段涩感与甜感变化。</p>
              </div>
            </section>

            <section className="transfer-block">
              <SectionTitle meta="2026-07-11　评估">移交准备度</SectionTitle>
              <div className="progress-row"><div className="progress-track"><span style={{ width: "42%" }} /></div><strong>42%</strong></div>
              <p>证据链仍需加强，继续积累对照与外部反馈。</p>
            </section>

            <button
              className="primary-cta"
              type="button"
              onClick={() => setToast("本周唯一练习已打开：先记录第 1 次对照萃取")}
            >
              开始本周练习 <ArrowRight size={31} />
            </button>
          </article>
        </section>

        {editorOpen ? (
          <DimensionEditor
            dimensions={dimensions}
            onChange={setDimensions}
            onClose={closeEditor}
            onSave={saveDimensions}
            onReset={resetDimensions}
            isModal={isNarrow}
          />
        ) : (
          <button ref={floatingEditorButton} className="floating-editor-button" type="button" onClick={openEditor}>
            <PencilLine size={17} />编辑我的六边形
          </button>
        )}
      </div>

      <div className="edge-tabs" aria-hidden="true"><span>手冲咖啡</span><span className="active">证据手账 ★</span><span>降噪实验室</span></div>
      {toast ? <div className="toast" role="status"><Check size={17} />{toast}</div> : null}
    </main>
  );
}

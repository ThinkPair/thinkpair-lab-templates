import { useEffect, useMemo, useState } from "react";
import {
  ArrowClockwise,
  ArrowRight,
  CalendarBlank,
  FileText,
  Info,
  Waveform,
  X,
} from "@phosphor-icons/react";
import {
  CartesianGrid,
  Cell,
  LabelList,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { getDashboardData, PLATFORM_IDS, PLATFORM_META } from "./dashboardData";

const EVIDENCE_LABELS = {
  confirmed: "已确认",
  estimated: "估算待核",
  missing: "缺失",
  unknown: "待确认",
  conflict: "来源冲突",
};

const STATUS_LABELS = {
  blank: "空白模板",
  partial: "部分数据",
  actual: "实际数据",
  conflict: "数据有冲突",
  demo: "演示数据",
};

function formatNumber(value) {
  return value === null || value === undefined ? "—" : new Intl.NumberFormat("zh-CN").format(value);
}

function formatPercent(value) {
  return value === null || value === undefined ? null : `${(value * 100).toFixed(2)}%`;
}

function displayStageTotal(stage) {
  if (stage.total !== null) return formatNumber(stage.total);
  if (stage.completeness === "partial") return `≥${formatNumber(stage.knownTotal)}`;
  return "—";
}

function EvidenceMark({ type = "confirmed" }) {
  return <span className={`evidence-mark evidence-mark--${type}`} aria-hidden="true" />;
}

function Header({ dashboard, activeTab, setActiveTab, onRefresh }) {
  const tabs = [
    ["path", "经营链路"],
    ["attribution", "内容归因"],
    ["data", "数据明细"],
  ];

  return (
    <header className="topbar">
      <button className="brand" onClick={() => setActiveTab("path")} aria-label="返回经营链路">
        <span className="brand-mark" aria-hidden="true">
          <Waveform size={29} weight="bold" />
        </span>
        <span>{dashboard.meta.dashboardTitle}</span>
      </button>

      <nav className="main-tabs" aria-label="主导航">
        {tabs.map(([id, label]) => (
          <button
            key={id}
            className={`main-tab ${activeTab === id ? "is-active" : ""}`}
            onClick={() => setActiveTab(id)}
          >
            {label}
          </button>
        ))}
      </nav>

      <div className="topbar-actions">
        <span className={`data-mode data-mode--${dashboard.mode}`}>
          <EvidenceMark type={dashboard.mode === "actual" ? "confirmed" : dashboard.mode === "partial" || dashboard.mode === "demo" ? "estimated" : dashboard.mode === "conflict" ? "conflict" : "missing"} />
          {STATUS_LABELS[dashboard.mode]}
        </span>
        <span className="topbar-divider" aria-hidden="true" />
        <span className="quiet-control" aria-label="时间范围">
          <CalendarBlank size={18} />
          {dashboard.meta.periodLabel}
        </span>
        <button className="primary-button" onClick={onRefresh}>
          <ArrowClockwise size={17} weight="bold" />
          刷新数据
        </button>
      </div>
    </header>
  );
}

function MetricStrip({ stages }) {
  const metricIds = ["reach", "lead", "paid", "renewal"];
  const metrics = metricIds.map((id) => stages.find((stage) => stage.id === id)).filter(Boolean);

  return (
    <div className="metric-strip" aria-label="核心经营结果">
      {metrics.map((metric) => (
        <div className={`metric metric--${metric.completeness}`} key={metric.id}>
          <span>{metric.label}</span>
          <strong>
            {displayStageTotal(metric)}
            <small>{metric.unit}</small>
          </strong>
        </div>
      ))}
    </div>
  );
}

function PlatformLegend({ selected, onSelect, disabled }) {
  return (
    <div className="platform-legend" aria-label="平台筛选">
      {PLATFORM_IDS.map((id) => (
        <button
          key={id}
          className={selected === id ? "is-active" : ""}
          onClick={() => onSelect(selected === id ? "all" : id)}
          aria-pressed={selected === id}
          disabled={disabled}
        >
          <i style={{ backgroundColor: PLATFORM_META[id].color }} />
          {PLATFORM_META[id].label}
        </button>
      ))}
      {selected !== "all" && (
        <button className="legend-reset" onClick={() => onSelect("all")}>
          显示全部
        </button>
      )}
    </div>
  );
}

function StageRail({ stage, selectedPlatform }) {
  if (stage.completeness === "empty") {
    return (
      <div className="stage-rail-shell is-empty" style={{ width: `${stage.width}%` }}>
        <span className="stage-empty-label">待补录</span>
      </div>
    );
  }

  const visualTotal = Math.max(stage.knownTotal, 1);
  return (
    <div className={`stage-rail-shell is-${stage.completeness}`} style={{ width: `${stage.width}%` }}>
      {PLATFORM_IDS.map((id) => {
        const value = stage.values[id];
        const missing = value === null;
        const share = missing ? 0 : value / visualTotal;
        const dimmed = selectedPlatform !== "all" && selectedPlatform !== id;
        return (
          <span
            key={id}
            className={`stage-segment stage-segment--${id} ${dimmed ? "is-dimmed" : ""} ${
              missing ? "is-missing" : value === 0 ? "is-zero" : ""
            }`}
            style={{
              flexGrow: missing ? 0.12 : value === 0 ? 0.035 : Math.max(share, 0.08),
              backgroundColor: missing ? undefined : PLATFORM_META[id].color,
            }}
            title={
              missing
                ? `${PLATFORM_META[id].label}未补录`
                : `${PLATFORM_META[id].label} ${formatNumber(value)} ${stage.unit}`
            }
          >
            <b>{missing ? "—" : formatNumber(value)}</b>
          </span>
        );
      })}
    </div>
  );
}

function OperatingPathCard({ dashboard, selectedPlatform, setSelectedPlatform, selectedStage, setSelectedStage }) {
  return (
    <section className="surface path-card">
      <div className="path-card-head">
        <div>
          <p className="eyebrow">OPERATING PATH · {dashboard.meta.periodLabel}</p>
          <h2>从内容到付费</h2>
        </div>
        <PlatformLegend selected={selectedPlatform} onSelect={setSelectedPlatform} disabled={dashboard.isBlank} />
      </div>

      <div className="stage-stack">
        <span className="stage-flow-spine" aria-hidden="true" />
        {dashboard.stages.map((stage, index) => {
          const ratio = formatPercent(stage.ratioAfter);
          return (
            <div className="stage-block" key={stage.id}>
              <button
                className={`stage-row ${selectedStage === stage.id ? "is-selected" : ""} ${
                  stage.id === "lead" ? "is-focus-stage" : ""
                }`}
                onClick={() => setSelectedStage(stage.id)}
                aria-label={`${stage.label}，${displayStageTotal(stage)}${stage.unit}`}
              >
                <div className="stage-identity">
                  <span className="stage-index">{index + 1}</span>
                  <span className="stage-copy">
                    <b>{stage.label}</b>
                    <small>{stage.unitType}</small>
                  </span>
                </div>

                <div className="stage-rail-area">
                  <StageRail stage={stage} selectedPlatform={selectedPlatform} />
                </div>

                <div className="stage-total">
                  <strong>{displayStageTotal(stage)}</strong>
                  <span>{stage.unit}</span>
                </div>
              </button>

              {index < dashboard.stages.length - 1 && (
                <div className={`conversion-gap ${ratio ? "" : "is-empty"}`} aria-label={ratio ? `相邻阶段量比 ${ratio}` : "相邻阶段量比待计算"}>
                  <span />
                  <span className="conversion-gap-center">
                    <i aria-hidden="true" />
                    <b>{ratio || "待计算"}</b>
                  </span>
                  <span />
                </div>
              )}
            </div>
          );
        })}
      </div>

      <div className="path-footnote">
        <Info size={15} />
        <span>
          触达为事件；关注、线索及沟通按平台记录统计；付费按订单统计。缺失不作 0，阶段量比不代表用户级转化率。
        </span>
        <button onClick={() => setSelectedStage("lead")}>
          查看口径
          <ArrowRight size={14} />
        </button>
      </div>
    </section>
  );
}

function DonutTooltip({ active, payload }) {
  if (!active || !payload?.[0]) return null;
  const item = payload[0].payload;
  return (
    <div className="chart-tooltip">
      <strong>{item.name}</strong>
      <span>{formatNumber(item.value)} {item.unit} · {item.percent}</span>
    </div>
  );
}

function LeadSourceCard({ dashboard, selectedPlatform, setSelectedPlatform }) {
  const lead = dashboard.stages.find((stage) => stage.id === "lead");
  const reach = dashboard.stages.find((stage) => stage.id === "reach");
  const leadHasValues = (lead?.knownTotal || 0) > 0;
  const metricStage = leadHasValues ? lead : reach;
  const metricMode = leadHasValues ? "lead" : "reach";
  const metricMeta = metricMode === "lead"
    ? { eyebrow: "SOURCE MIX", title: "有效线索来源", unit: "条", emptyLabel: "线索来源待补录" }
    : { eyebrow: "REACH MIX", title: "内容触达平台构成", unit: "次", emptyLabel: "触达数据待补录" };
  const knownTotal = metricStage?.knownTotal || 0;
  const hasKnownValues = metricStage?.completeness !== "empty";
  const canCalculateShare = metricStage?.total !== null && metricStage?.total > 0;
  const data = PLATFORM_IDS.map((id) => {
    const value = metricStage?.values[id] ?? null;
    return {
      id,
      name: PLATFORM_META[id].label,
      value,
      chartValue: value || 0,
      unit: metricMeta.unit,
      percent: canCalculateShare && value !== null ? `${((value / metricStage.total) * 100).toFixed(1)}%` : "待完整",
      color: PLATFORM_META[id].color,
    };
  });
  const chartData = data.filter((item) => item.value !== null && item.value > 0);

  return (
    <section className="surface source-card">
      <div className="card-heading">
        <div>
          <p className="eyebrow">{metricMeta.eyebrow}</p>
          <h2>{metricMeta.title}</h2>
        </div>
        <span>{dashboard.meta.periodLabel}</span>
      </div>

      <div className="source-layout">
        <div className="donut-chart">
          {chartData.length ? (
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={chartData}
                  dataKey="chartValue"
                  nameKey="name"
                  cx="50%"
                  cy="50%"
                  innerRadius="59%"
                  outerRadius="94%"
                  paddingAngle={0.45}
                  cornerRadius={1}
                  stroke="#DCE7DF"
                  strokeWidth={1.5}
                  onClick={(entry) => setSelectedPlatform(selectedPlatform === entry.id ? "all" : entry.id)}
                >
                  {chartData.map((entry) => (
                    <Cell
                      key={entry.id}
                      fill={entry.color}
                      fillOpacity={selectedPlatform === "all" || selectedPlatform === entry.id ? 1 : 0.2}
                    />
                  ))}
                </Pie>
                <Tooltip content={<DonutTooltip />} />
              </PieChart>
            </ResponsiveContainer>
          ) : (
            <div className="donut-empty-ring" aria-label={hasKnownValues ? "本期暂无记录" : metricMeta.emptyLabel} />
          )}
          <div className="donut-center">
            <strong>{metricStage?.total !== null ? formatNumber(metricStage.total) : knownTotal > 0 ? `≥${formatNumber(knownTotal)}` : "—"}</strong>
            <span>{hasKnownValues ? metricMeta.unit : "待补录"}</span>
          </div>
        </div>

        <div className="source-list">
          {data.map((item) => (
            <button
              key={item.id}
              className={selectedPlatform === item.id ? "is-active" : ""}
              onClick={() => setSelectedPlatform(selectedPlatform === item.id ? "all" : item.id)}
              disabled={item.value === null}
            >
              <i style={{ backgroundColor: item.color }} />
              <span>{item.name}</span>
              <strong>{formatNumber(item.value)}</strong>
              <small>{item.value === null ? "未补录" : item.percent}</small>
            </button>
          ))}
        </div>
      </div>

      {metricMode === "reach" ? (
        <div className="path-footnote">
          <Info size={15} />
          <span>有效线索尚未补录，当前展示触达构成；各平台统计窗口不一致，口径见数据明细。</span>
        </div>
      ) : null}
    </section>
  );
}

function TrendTooltip({ active, payload, label, unit = "条" }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="chart-tooltip trend-tooltip">
      <small>{label}</small>
      {payload.filter((item) => item.value !== null).map((item) => (
        <span key={item.dataKey}>
          <i style={{ backgroundColor: item.stroke }} />
          {PLATFORM_META[item.dataKey].label}
          <b>{formatNumber(item.value)} {unit}</b>
        </span>
      ))}
    </div>
  );
}

function TrendEndLabel({ x, y, index, value, platform, lastIndex }) {
  if (index !== lastIndex || x == null || y == null || value === null) return null;
  const meta = PLATFORM_META[platform];
  return <text x={x + 10} y={y + 4} fill={meta.color} fontSize={10} fontWeight={600}>{meta.label} {value}</text>;
}

function TrendCard({ dashboard, selectedPlatform, range, setRange }) {
  const allData = dashboard.leadTrend;
  const leadData = range === "4w" ? allData.slice(-4) : allData.slice(-12);
  const shownPlatforms = selectedPlatform === "all" ? PLATFORM_IDS : [selectedPlatform];
  const hasLeadTrend = leadData.some((row) => shownPlatforms.some((id) => row[id] !== null));
  const episodeRows = (dashboard.episodePlays || []).map((row) => ({ ...row, week: row.episode }));
  const hasEpisodeData = !hasLeadTrend && episodeRows.some((row) => shownPlatforms.some((id) => row[id] !== null));
  const episodeMode = !hasLeadTrend && hasEpisodeData;
  const data = hasLeadTrend ? leadData : episodeRows;
  const xKey = "week";
  const hasTrendData = hasLeadTrend || hasEpisodeData;
  const lastIndexes = Object.fromEntries(
    PLATFORM_IDS.map((id) => {
      let lastIndex = -1;
      data.forEach((row, index) => { if (row[id] !== null) lastIndex = index; });
      return [id, lastIndex];
    }),
  );

  const head = episodeMode
    ? { eyebrow: "EPISODE PLAYS", title: "三期作品播放走势", unit: "播放事件", aria: "三期作品播放走势（分平台）", tooltipUnit: "次" }
    : { eyebrow: "LEAD MOMENTUM", title: `近${range === "4w" ? "4" : "12"}周累计有效线索`, unit: "平台记录", aria: `近${range === "4w" ? "4" : "12"}周累计有效线索趋势`, tooltipUnit: "条" };

  return (
    <section className="surface trend-card">
      <div className="card-heading">
        <div>
          <p className="eyebrow">{head.eyebrow}</p>
          <h2>{head.title}</h2>
          <span className="chart-unit">{head.unit}</span>
        </div>
        {!episodeMode ? (
          <div className="range-switch" role="group" aria-label="趋势时间范围">
            <button className={range === "4w" ? "is-active" : ""} onClick={() => setRange("4w")}>4周</button>
            <button className={range === "12w" ? "is-active" : ""} onClick={() => setRange("12w")}>12周</button>
          </div>
        ) : null}
      </div>

      <div className="trend-chart" aria-label={head.aria}>
        {hasTrendData ? (
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={data} margin={{ top: 30, right: 72, bottom: 0, left: 0 }}>
              <CartesianGrid vertical={false} stroke="rgba(23,26,24,.09)" strokeDasharray="3 5" />
              <XAxis dataKey={xKey} tickLine={false} axisLine={false} interval={0} minTickGap={18} tick={{ fill: "#666C66", fontSize: episodeMode ? 10 : range === "4w" ? 10 : 8 }} />
              <YAxis domain={[0, "dataMax + 2"]} allowDecimals={false} tickLine={false} axisLine={false} width={36} tick={{ fill: "#737873", fontSize: 10 }} />
              <Tooltip content={<TrendTooltip unit={head.tooltipUnit} />} />
              {shownPlatforms.map((id, index) => (
                <Line
                  key={id}
                  type="monotone"
                  dataKey={id}
                  connectNulls={false}
                  stroke={PLATFORM_META[id].color}
                  strokeWidth={id === "douyin" || selectedPlatform === id ? 2.6 : 1.8}
                  strokeOpacity={index === 0 ? 1 : 0.78}
                  dot={{ r: id === "douyin" || selectedPlatform === id ? 4.2 : 3.4, strokeWidth: 2 }}
                  activeDot={{ r: 5.8, strokeWidth: 2 }}
                  animationDuration={450}
                >
                  <LabelList dataKey={id} position="top" offset={7} fill={PLATFORM_META[id].color} fontSize={10} />
                  <LabelList dataKey={id} content={(props) => <TrendEndLabel {...props} platform={id} lastIndex={lastIndexes[id]} />} />
                </Line>
              ))}
            </LineChart>
          </ResponsiveContainer>
        ) : (
          <div className="chart-empty-state">
            <span className="empty-chart-line" aria-hidden="true" />
            <strong>还没有趋势数据</strong>
            <small>在数据页填入至少两个完整周期后，这里才会连线。</small>
          </div>
        )}
      </div>

      {episodeMode ? (
        <div className="path-footnote">
          <Info size={15} />
          <span>各期为不同发布时长的快照值，非同窗口对比，仅描述事实，不作归因。</span>
        </div>
      ) : null}
    </section>
  );
}

function PathDashboard({ dashboard, selectedPlatform, setSelectedPlatform, selectedStage, setSelectedStage, range, setRange }) {
  return (
    <main className="dashboard-main">
      <section className="dashboard-intro">
        <div>
          <p className="eyebrow">OPERATING REVIEW · {dashboard.meta.periodLabel}</p>
          <h1>{dashboard.isBlank ? "经营链路等待第一份数据" : `${dashboard.meta.periodLabel}经营链路`}</h1>
          <p>阶段经营体量 · {dashboard.meta.identityDeduplicated ? "已按当前规则去重" : "跨平台身份未去重"}</p>
        </div>
        <MetricStrip stages={dashboard.stages} />
      </section>

      <div className="dashboard-grid">
        <OperatingPathCard dashboard={dashboard} selectedPlatform={selectedPlatform} setSelectedPlatform={setSelectedPlatform} selectedStage={selectedStage} setSelectedStage={setSelectedStage} />
        <div className="right-column">
          <LeadSourceCard dashboard={dashboard} selectedPlatform={selectedPlatform} setSelectedPlatform={setSelectedPlatform} />
          <TrendCard dashboard={dashboard} selectedPlatform={selectedPlatform} range={range} setRange={setRange} />
        </div>
      </div>
    </main>
  );
}

function StageDrawer({ dashboard, stageId, onClose }) {
  const stage = dashboard.stages.find((item) => item.id === stageId);
  if (!stage) return null;

  return (
    <>
      <button className="overlay" onClick={onClose} aria-label="关闭阶段明细" />
      <aside className="drawer" aria-label={`${stage.label}阶段明细`}>
        <div className="drawer-head">
          <div><p className="eyebrow">STAGE DETAIL</p><h2>{stage.label}</h2></div>
          <button className="icon-button" onClick={onClose} aria-label="关闭"><X size={18} /></button>
        </div>
        <div className="drawer-metrics">
          <div><span>当前体量</span><strong>{displayStageTotal(stage)} <small>{stage.unit}</small></strong></div>
          <div><span>证据状态</span><strong className="drawer-evidence"><EvidenceMark type={stage.evidence} />{EVIDENCE_LABELS[stage.evidence] || "待确认"}</strong></div>
        </div>
        <section className="drawer-section">
          <h3>平台构成</h3>
          {PLATFORM_IDS.map((id) => (
            <div className="drawer-row" key={id}>
              <span><i style={{ backgroundColor: PLATFORM_META[id].color }} />{PLATFORM_META[id].label}</span>
              <strong>{stage.values[id] === null ? "未补录" : `${formatNumber(stage.values[id])} ${stage.unit}`}</strong>
            </div>
          ))}
        </section>
        <section className="drawer-section drawer-definition"><Info size={18} /><p>{stage.definition}</p></section>
        {stage.sourceRefs.length ? (
          <section className="drawer-section source-ref-list"><h3>数据来源</h3>{stage.sourceRefs.map((ref) => <code key={ref}>{ref}</code>)}</section>
        ) : null}
        <p className="drawer-boundary">缺失平台不参与完整总量与阶段量比计算。</p>
      </aside>
    </>
  );
}

function RefreshModal({ dashboard, onClose }) {
  return (
    <div className="modal-layer" role="presentation">
      <button className="overlay" onClick={onClose} aria-label="关闭刷新说明" />
      <section className="import-modal" role="dialog" aria-modal="true" aria-labelledby="refresh-title">
        <div className="drawer-head">
          <div><p className="eyebrow">LOCAL DATA</p><h2 id="refresh-title">更新本地看板</h2></div>
          <button className="icon-button" onClick={onClose} aria-label="关闭"><X size={18} /></button>
        </div>
        <p className="modal-intro">看板不会自动补数。先在 Obsidian 中让 DeepSeek 更新包内的《01_看板数据.md》，人工确认后再重新双击“打开经营看板”。</p>
        <div className="refresh-steps">
          <div><span>01</span><FileText size={23} /><strong>更新数据笔记</strong><small>缺失填 null，每个数带来源</small></div>
          <div><span>02</span><Info size={23} /><strong>人工核对</strong><small>确认口径、周期和证据状态</small></div>
          <div><span>03</span><ArrowClockwise size={23} /><strong>重新打开</strong><small>启动器只读取通过校验的数据</small></div>
        </div>
        <p className="review-warning">当前状态：{STATUS_LABELS[dashboard.mode]}。JSON 格式错误时会保留上一次合法数据。</p>
        <div className="modal-actions">
          <button className="secondary-button" onClick={onClose}>关闭</button>
          <button className="primary-button" onClick={() => window.location.reload()}><ArrowClockwise size={17} />重新读取</button>
        </div>
      </section>
    </div>
  );
}

function AttributionView({ dashboard, onBack }) {
  return (
    <main className="secondary-page">
      <section className="surface secondary-surface">
        <div className="secondary-head">
          <div><p className="eyebrow">CONTENT ATTRIBUTION</p><h1>内容归因</h1><p>查看哪些内容带来了有效线索、深度沟通与首次付费。</p></div>
          <button className="secondary-button" onClick={onBack}>返回经营链路</button>
        </div>
        {dashboard.attribution.length ? (
          <div className="attribution-table">
            <div className="table-head"><span>内容</span><span>平台</span><span>有效线索</span><span>深度沟通</span><span>首次付费</span></div>
            {dashboard.attribution.map((row, index) => (
              <div className="table-row" key={`${row.title}-${index}`}>
                <span className="content-cell"><b>{String(index + 1).padStart(2, "0")}</b><span>{row.title}</span></span>
                <span>{row.platform || PLATFORM_META[row.platformId]?.label || "—"}</span>
                <strong>{formatNumber(row.leads)} 条</strong><strong>{formatNumber(row.conversations)} 条</strong><strong>{formatNumber(row.paid)} 单</strong>
              </div>
            ))}
          </div>
        ) : (
          <div className="page-empty-state"><FileText size={30} /><h2>还没有内容归因记录</h2><p>只有当内容与线索或订单存在可追溯关系时，才在这里展示。</p></div>
        )}
      </section>
    </main>
  );
}

function DataView({ dashboard, onBack }) {
  return (
    <main className="secondary-page">
      <section className="surface secondary-surface">
        <div className="secondary-head">
          <div><p className="eyebrow">DATA EVIDENCE</p><h1>数据明细</h1><p>每个经营数字都保留时间、来源、口径与证据状态。</p></div>
          <button className="secondary-button" onClick={onBack}>返回经营链路</button>
        </div>
        {dashboard.evidence.length ? (
          <div className="evidence-ledger">
            <div className="ledger-head"><span>更新时间</span><span>数据项</span><span>来源</span><span>当前值</span><span>状态</span></div>
            {dashboard.evidence.map((row, index) => (
              <div className="ledger-row" key={`${row.time}-${row.item}-${index}`}>
                <span>{row.time}</span><strong>{row.item}</strong><span>{row.source}</span><strong>{row.value}</strong>
                <span className="ledger-state"><EvidenceMark type={row.state} />{EVIDENCE_LABELS[row.state] || "待确认"}</span>
              </div>
            ))}
          </div>
        ) : (
          <div className="page-empty-state"><Info size={30} /><h2>还没有证据记录</h2><p>DeepSeek 整理数据时必须同时写入来源，不得只填看板数字。</p></div>
        )}
      </section>
    </main>
  );
}

export function App() {
  const [dashboard] = useState(() => getDashboardData());
  const [activeTab, setActiveTab] = useState("path");
  const [selectedPlatform, setSelectedPlatform] = useState("all");
  const [selectedStage, setSelectedStage] = useState(null);
  const [range, setRange] = useState("4w");
  const [refreshOpen, setRefreshOpen] = useState(false);

  useEffect(() => {
    const closeOnEscape = (event) => {
      if (event.key !== "Escape") return;
      setSelectedStage(null);
      setRefreshOpen(false);
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, []);

  const page = useMemo(() => {
    if (activeTab === "attribution") return <AttributionView dashboard={dashboard} onBack={() => setActiveTab("path")} />;
    if (activeTab === "data") return <DataView dashboard={dashboard} onBack={() => setActiveTab("path")} />;
    return <PathDashboard dashboard={dashboard} selectedPlatform={selectedPlatform} setSelectedPlatform={setSelectedPlatform} selectedStage={selectedStage} setSelectedStage={setSelectedStage} range={range} setRange={setRange} />;
  }, [activeTab, dashboard, selectedPlatform, selectedStage, range]);

  return (
    <div className="app">
      <Header dashboard={dashboard} activeTab={activeTab} setActiveTab={setActiveTab} onRefresh={() => setRefreshOpen(true)} />
      {page}
      {selectedStage && <StageDrawer dashboard={dashboard} stageId={selectedStage} onClose={() => setSelectedStage(null)} />}
      {refreshOpen && <RefreshModal dashboard={dashboard} onClose={() => setRefreshOpen(false)} />}
      <p className="demo-disclaimer">
        {dashboard.mode === "demo"
          ? "演示样本 · 触达为真实后台数据 · 其余环节按直播展示需要填补 · 不得说成真实经营成绩"
          : dashboard.mode === "blank" ? "空白数据模板" : STATUS_LABELS[dashboard.mode]} · 缺失不作 0 · 阶段量比不代表用户级转化率
      </p>
    </div>
  );
}


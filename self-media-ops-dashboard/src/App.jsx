import { useEffect, useMemo, useState } from "react";
import {
  ArrowRight,
  CalendarBlank,
  CaretDown,
  Check,
  FileCsv,
  ImageSquare,
  Info,
  Keyboard,
  Plus,
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
import {
  CONTENT_EXPERIMENTS,
  EXPERIMENT_BASELINE,
  NEXT_BLIND_EXPERIMENT,
  RUBRIC_DIMENSIONS,
  visibleActionRate,
} from "./contentExperiments";

const PLATFORM_META = {
  douyin: { label: "抖音", color: "#5662A8" },
  xhs: { label: "小红书", color: "#DF7F7C" },
  bilibili: { label: "B站", color: "#5A9991" },
};

const PLATFORM_IDS = Object.keys(PLATFORM_META);

const STAGES = [
  {
    id: "reach",
    label: "内容触达",
    unit: "次",
    unitType: "事件",
    total: 8960,
    values: { douyin: 4480, xhs: 2880, bilibili: 1600 },
    ratioAfter: "1.58%",
    width: 100,
    evidence: "confirmed",
    definition: "所选周期内三个平台后台记录的内容播放或曝光事件之和，同一人多次观看会重复计数。",
  },
  {
    id: "follow",
    label: "新增关注",
    unit: "条",
    unitType: "平台记录",
    total: 142,
    values: { douyin: 71, xhs: 45, bilibili: 26 },
    ratioAfter: "18.31%",
    width: 94,
    evidence: "confirmed",
    definition: "所选周期内三个平台新增关注记录之和，同一身份跨平台关注可能重复。",
  },
  {
    id: "lead",
    label: "有效线索",
    unit: "条",
    unitType: "平台记录",
    total: 26,
    values: { douyin: 14, xhs: 8, bilibili: 4 },
    ratioAfter: "42.31%",
    width: 88,
    evidence: "confirmed",
    definition: "明确表达经营诊断或看板需求，并进入可持续联系渠道的线索记录；演示数据尚未跨平台去重。",
  },
  {
    id: "conversation",
    label: "深度沟通",
    unit: "条",
    unitType: "平台记录",
    total: 11,
    values: { douyin: 6, xhs: 3, bilibili: 2 },
    ratioAfter: "36.36%",
    width: 82,
    evidence: "estimated",
    definition: "已经完成一次达到业务门槛的双向需求沟通，包括连麦、语音、面谈或采齐关键经营信息。",
  },
  {
    id: "paid",
    label: "首次付费",
    unit: "单",
    unitType: "订单",
    total: 4,
    values: { douyin: 2, xhs: 1, bilibili: 1 },
    ratioAfter: "25.00%",
    width: 76,
    evidence: "confirmed",
    definition: "首次产生成功付款且未全额退款的确认订单。",
  },
  {
    id: "renewal",
    label: "升级续费",
    unit: "单",
    unitType: "订单",
    total: 1,
    values: { douyin: 1, xhs: 0, bilibili: 0 },
    width: 70,
    evidence: "confirmed",
    definition: "首次付费后再次付款、续费或升级的确认订单。",
  },
];

const WEEK_DATA = [
  { week: "6/29—7/5", douyin: 8, xhs: 5, bilibili: 2 },
  { week: "7/6—7/12", douyin: 11, xhs: 6, bilibili: 3 },
  { week: "7/13—7/19", douyin: 12, xhs: 7, bilibili: 3 },
  { week: "7/20—7/26", douyin: 14, xhs: 8, bilibili: 4 },
];

const LONG_WEEK_DATA = [
  { week: "5/11", douyin: 3, xhs: 1, bilibili: 0 },
  { week: "5/18", douyin: 4, xhs: 2, bilibili: 0 },
  { week: "5/25", douyin: 5, xhs: 2, bilibili: 1 },
  { week: "6/1", douyin: 5, xhs: 3, bilibili: 1 },
  { week: "6/8", douyin: 6, xhs: 3, bilibili: 1 },
  { week: "6/15", douyin: 7, xhs: 4, bilibili: 2 },
  { week: "6/22", douyin: 7, xhs: 4, bilibili: 2 },
  { week: "6/29", douyin: 8, xhs: 5, bilibili: 2 },
  ...WEEK_DATA.slice(1),
];

const ATTRIBUTION_ROWS = [
  { title: "做内容最难的不是灵感，是判断", platform: "抖音", leads: 8, conversations: 4, paid: 2 },
  { title: "老板真正需要的不是另一张报表", platform: "小红书", leads: 6, conversations: 3, paid: 1 },
  { title: "知识库为什么越积累越容易失真", platform: "B站", leads: 4, conversations: 2, paid: 1 },
];

const EVIDENCE_ROWS = [
  { time: "07-30 14:20", item: "抖音有效线索", source: "平台截图", value: "14 条", state: "confirmed" },
  { time: "07-30 13:40", item: "深度沟通记录", source: "手动补录", value: "11 条", state: "estimated" },
  { time: "07-29 21:10", item: "首次付费订单", source: "支付记录", value: "4 单", state: "confirmed" },
  { time: "07-29 18:30", item: "升级续费订单", source: "支付记录", value: "1 单", state: "confirmed" },
];

function formatNumber(value) {
  return new Intl.NumberFormat("zh-CN").format(value);
}

function EvidenceMark({ type = "confirmed" }) {
  return <span className={`evidence-mark evidence-mark--${type}`} aria-hidden="true" />;
}

function Header({ activeTab, setActiveTab, onImport }) {
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
        <span>降噪实验室</span>
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
        <button className="quiet-control" aria-label="数据状态">
          演示数据
          <CaretDown size={13} />
        </button>
        <span className="topbar-divider" aria-hidden="true" />
        <button className="quiet-control" aria-label="时间范围">
          <CalendarBlank size={18} />
          近4完整周
          <CaretDown size={13} />
        </button>
        <button className="primary-button" onClick={onImport}>
          <Plus size={17} weight="bold" />
          补数据
        </button>
      </div>
    </header>
  );
}

function MetricStrip() {
  const metrics = [
    { label: "内容触达", value: "8,960", unit: "次" },
    { label: "有效线索", value: "26", unit: "条" },
    { label: "首次付费", value: "4", unit: "单" },
    { label: "升级续费", value: "1", unit: "单" },
  ];

  return (
    <div className="metric-strip" aria-label="核心经营结果">
      {metrics.map((metric) => (
        <div className="metric" key={metric.label}>
          <span>{metric.label}</span>
          <strong>
            {metric.value}
            <small>{metric.unit}</small>
          </strong>
        </div>
      ))}
    </div>
  );
}

function PlatformLegend({ selected, onSelect }) {
  return (
    <div className="platform-legend" aria-label="平台筛选">
      {PLATFORM_IDS.map((id) => (
        <button
          key={id}
          className={selected === id ? "is-active" : ""}
          onClick={() => onSelect(selected === id ? "all" : id)}
          aria-pressed={selected === id}
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
  const rawTotal = Object.values(stage.values).reduce((sum, value) => sum + value, 0);

  return (
    <div className="stage-rail-shell" style={{ width: `${stage.width}%` }}>
      {PLATFORM_IDS.map((id) => {
        const value = stage.values[id];
        const share = rawTotal > 0 ? value / rawTotal : 0;
        const dimmed = selectedPlatform !== "all" && selectedPlatform !== id;
        return (
          <span
            key={id}
            className={`stage-segment stage-segment--${id} ${dimmed ? "is-dimmed" : ""} ${
              value === 0 ? "is-zero" : ""
            }`}
            style={{
              flexGrow: value === 0 ? 0.035 : Math.max(share, 0.08),
              backgroundColor: PLATFORM_META[id].color,
            }}
            title={`${PLATFORM_META[id].label} ${formatNumber(value)} ${stage.unit}`}
          >
            <b>{formatNumber(value)}</b>
          </span>
        );
      })}
    </div>
  );
}

function OperatingPathCard({ selectedPlatform, setSelectedPlatform, selectedStage, setSelectedStage }) {
  return (
    <section className="surface path-card">
      <div className="path-card-head">
        <div>
          <p className="eyebrow">OPERATING PATH · 近4周</p>
          <h2>从内容到付费</h2>
        </div>
        <PlatformLegend selected={selectedPlatform} onSelect={setSelectedPlatform} />
      </div>

      <div className="stage-stack">
        <span className="stage-flow-spine" aria-hidden="true" />
        {STAGES.map((stage, index) => (
          <div className="stage-block" key={stage.id}>
            <button
              className={`stage-row ${selectedStage === stage.id ? "is-selected" : ""} ${
                stage.id === "lead" ? "is-focus-stage" : ""
              }`}
              onClick={() => setSelectedStage(stage.id)}
              aria-label={`${stage.label}，${formatNumber(stage.total)}${stage.unit}`}
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
                <strong>{formatNumber(stage.total)}</strong>
                <span>{stage.unit}</span>
              </div>
            </button>

            {stage.ratioAfter && (
              <div className="conversion-gap" aria-label={`相邻阶段比 ${stage.ratioAfter}`}>
                <span />
                <span className="conversion-gap-center">
                  <i aria-hidden="true" />
                  <b>{stage.ratioAfter}</b>
                </span>
                <span />
              </div>
            )}
          </div>
        ))}
      </div>

      <div className="path-footnote">
        <Info size={15} />
        <span>
          触达为事件；关注、线索及沟通按平台记录统计；付费按订单统计。层宽经压缩，阶段比不代表用户级转化率。
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
      <span>
        {item.value} 条 · {item.percent}
      </span>
    </div>
  );
}

function LeadSourceCard({ selectedPlatform, setSelectedPlatform }) {
  const data = [
    { id: "douyin", name: "抖音", value: 14, percent: "53.8%", color: PLATFORM_META.douyin.color },
    { id: "xhs", name: "小红书", value: 8, percent: "30.8%", color: PLATFORM_META.xhs.color },
    { id: "bilibili", name: "B站", value: 4, percent: "15.4%", color: PLATFORM_META.bilibili.color },
  ];

  return (
    <section className="surface source-card">
      <div className="card-heading">
        <div>
          <p className="eyebrow">SOURCE MIX</p>
          <h2>有效线索来源</h2>
        </div>
        <span>近4周</span>
      </div>

      <div className="source-layout">
        <div className="donut-chart">
          <ResponsiveContainer width="100%" height="100%">
            <PieChart>
              <Pie
                data={data}
                dataKey="value"
                nameKey="name"
                cx="50%"
                cy="50%"
                innerRadius="59%"
                outerRadius="94%"
                paddingAngle={0.45}
                cornerRadius={1}
                stroke="#DCE7DF"
                strokeWidth={1.5}
                onClick={(entry) =>
                  setSelectedPlatform(selectedPlatform === entry.id ? "all" : entry.id)
                }
              >
                {data.map((entry) => (
                  <Cell
                    key={entry.id}
                    fill={entry.color}
                    fillOpacity={
                      selectedPlatform === "all" || selectedPlatform === entry.id ? 1 : 0.2
                    }
                  />
                ))}
              </Pie>
              <Tooltip content={<DonutTooltip />} />
            </PieChart>
          </ResponsiveContainer>
          <div className="donut-center">
            <strong>26</strong>
            <span>条</span>
          </div>
        </div>

        <div className="source-list">
          {data.map((item) => (
            <button
              key={item.id}
              className={selectedPlatform === item.id ? "is-active" : ""}
              onClick={() =>
                setSelectedPlatform(selectedPlatform === item.id ? "all" : item.id)
              }
            >
              <i style={{ backgroundColor: item.color }} />
              <span>{item.name}</span>
              <strong>{item.value}</strong>
              <small>{item.percent}</small>
            </button>
          ))}
        </div>
      </div>
    </section>
  );
}

function TrendTooltip({ active, payload, label }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="chart-tooltip trend-tooltip">
      <small>{label}</small>
      {payload.map((item) => (
        <span key={item.dataKey}>
          <i style={{ backgroundColor: item.stroke }} />
          {PLATFORM_META[item.dataKey].label}
          <b>{item.value} 条</b>
        </span>
      ))}
    </div>
  );
}

function TrendEndLabel({ x, y, index, value, platform, lastIndex }) {
  if (index !== lastIndex || x == null || y == null) return null;
  const meta = PLATFORM_META[platform];
  return (
    <text
      x={x + 10}
      y={y + 4}
      fill={meta.color}
      fontSize={10}
      fontWeight={600}
      textAnchor="start"
    >
      {meta.label} {value}
    </text>
  );
}

function TrendCard({ selectedPlatform, range, setRange }) {
  const data = range === "4w" ? WEEK_DATA : LONG_WEEK_DATA;
  const shownPlatforms = selectedPlatform === "all" ? PLATFORM_IDS : [selectedPlatform];

  return (
    <section className="surface trend-card">
      <div className="card-heading">
        <div>
          <p className="eyebrow">LEAD MOMENTUM</p>
          <h2>近{range === "4w" ? "4" : "12"}周累计有效线索</h2>
          <span className="chart-unit">平台记录</span>
        </div>
        <div className="range-switch" role="group" aria-label="趋势时间范围">
          <button className={range === "4w" ? "is-active" : ""} onClick={() => setRange("4w")}>
            4周
          </button>
          <button className={range === "12w" ? "is-active" : ""} onClick={() => setRange("12w")}>
            12周
          </button>
        </div>
      </div>

      <div className="trend-chart" aria-label={`近${range === "4w" ? "4" : "12"}周累计有效线索趋势`}>
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data} margin={{ top: 30, right: 72, bottom: 0, left: 0 }}>
            <CartesianGrid vertical={false} stroke="rgba(23,26,24,.09)" strokeDasharray="3 5" />
            <XAxis
              dataKey="week"
              tickLine={false}
              axisLine={false}
              interval={0}
              minTickGap={18}
              tick={{ fill: "#666C66", fontSize: range === "4w" ? 10 : 8 }}
            />
            <YAxis
              domain={[0, "dataMax + 2"]}
              allowDecimals={false}
              tickLine={false}
              axisLine={false}
              width={36}
              tick={{ fill: "#737873", fontSize: 10 }}
            />
            <Tooltip content={<TrendTooltip />} />
            {shownPlatforms.map((id, index) => (
              <Line
                key={id}
                type="monotone"
                dataKey={id}
                stroke={PLATFORM_META[id].color}
                strokeWidth={id === "douyin" || selectedPlatform === id ? 2.6 : 1.8}
                strokeOpacity={index === 0 ? 1 : 0.78}
                dot={{ r: id === "douyin" || selectedPlatform === id ? 4.2 : 3.4, strokeWidth: 2 }}
                activeDot={{ r: 5.8, strokeWidth: 2 }}
                animationDuration={450}
              >
                {range === "4w" ? (
                  <LabelList
                    dataKey={id}
                    position="top"
                    offset={7}
                    fill={PLATFORM_META[id].color}
                    fontSize={10}
                  />
                ) : null}
                <LabelList
                  dataKey={id}
                  content={(props) => (
                    <TrendEndLabel
                      {...props}
                      platform={id}
                      lastIndex={data.length - 1}
                    />
                  )}
                />
              </Line>
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>

      <div className="trend-endpoints sr-only" aria-label="最新累计值">
        {shownPlatforms.map((id) => (
          <span key={id} style={{ color: PLATFORM_META[id].color }}>
            <i style={{ backgroundColor: PLATFORM_META[id].color }} />
            {PLATFORM_META[id].label} {data.at(-1)[id]}
          </span>
        ))}
      </div>
    </section>
  );
}

function PathDashboard({
  selectedPlatform,
  setSelectedPlatform,
  selectedStage,
  setSelectedStage,
  range,
  setRange,
}) {
  return (
    <main className="dashboard-main">
      <section className="dashboard-intro">
        <div>
          <p className="eyebrow">OPERATING REVIEW · 近4完整周</p>
          <h1>近4周经营链路</h1>
          <p>阶段经营体量 · 跨平台身份未去重</p>
        </div>
        <MetricStrip />
      </section>

      <div className="dashboard-grid">
        <OperatingPathCard
          selectedPlatform={selectedPlatform}
          setSelectedPlatform={setSelectedPlatform}
          selectedStage={selectedStage}
          setSelectedStage={setSelectedStage}
        />
        <div className="right-column">
          <LeadSourceCard
            selectedPlatform={selectedPlatform}
            setSelectedPlatform={setSelectedPlatform}
          />
          <TrendCard selectedPlatform={selectedPlatform} range={range} setRange={setRange} />
        </div>
      </div>
    </main>
  );
}

function StageDrawer({ stageId, onClose }) {
  const stage = STAGES.find((item) => item.id === stageId);
  if (!stage) return null;

  const evidenceLabels = {
    confirmed: "已确认",
    estimated: "估算待核",
    missing: "缺失",
    conflict: "冲突",
  };

  return (
    <>
      <button className="overlay" onClick={onClose} aria-label="关闭阶段明细" />
      <aside className="drawer" aria-label={`${stage.label}阶段明细`}>
        <div className="drawer-head">
          <div>
            <p className="eyebrow">STAGE DETAIL</p>
            <h2>{stage.label}</h2>
          </div>
          <button className="icon-button" onClick={onClose} aria-label="关闭">
            <X size={18} />
          </button>
        </div>

        <div className="drawer-metrics">
          <div>
            <span>当前体量</span>
            <strong>
              {formatNumber(stage.total)} <small>{stage.unit}</small>
            </strong>
          </div>
          <div>
            <span>证据状态</span>
            <strong className="drawer-evidence">
              <EvidenceMark type={stage.evidence} />
              {evidenceLabels[stage.evidence]}
            </strong>
          </div>
        </div>

        <section className="drawer-section">
          <h3>平台构成</h3>
          {PLATFORM_IDS.map((id) => (
            <div className="drawer-row" key={id}>
              <span>
                <i style={{ backgroundColor: PLATFORM_META[id].color }} />
                {PLATFORM_META[id].label}
              </span>
              <strong>
                {formatNumber(stage.values[id])} {stage.unit}
              </strong>
            </div>
          ))}
        </section>

        <section className="drawer-section drawer-definition">
          <Info size={18} />
          <p>{stage.definition}</p>
        </section>

        <p className="drawer-boundary">
          全链路暂未跨平台身份去重；首页百分比只表示相邻阶段体量比。
        </p>
      </aside>
    </>
  );
}

function ImportModal({ onClose }) {
  const [choice, setChoice] = useState(null);

  const options = [
    { id: "image", title: "上传后台截图", copy: "适合抖音、小红书与B站后台数据", icon: ImageSquare },
    { id: "csv", title: "导入 CSV", copy: "适合已有表格或平台导出记录", icon: FileCsv },
    { id: "manual", title: "手动补录", copy: "只填写本周新增或修正的数据", icon: Keyboard },
  ];

  return (
    <div className="modal-layer" role="presentation">
      <button className="overlay" onClick={onClose} aria-label="关闭补录弹窗" />
      <section className="import-modal" role="dialog" aria-modal="true" aria-labelledby="import-title">
        <div className="drawer-head">
          <div>
            <p className="eyebrow">DATA INTAKE</p>
            <h2 id="import-title">补数据</h2>
          </div>
          <button className="icon-button" onClick={onClose} aria-label="关闭">
            <X size={18} />
          </button>
        </div>

        {!choice ? (
          <>
            <p className="modal-intro">选择最顺手的方式。演示原型只展示核对流程，不会上传真实文件。</p>
            <div className="import-options">
              {options.map((option) => {
                const Icon = option.icon;
                return (
                  <button key={option.id} onClick={() => setChoice(option.id)}>
                    <Icon size={25} />
                    <strong>{option.title}</strong>
                    <span>{option.copy}</span>
                    <ArrowRight size={17} />
                  </button>
                );
              })}
            </div>
          </>
        ) : (
          <div className="import-review">
            <div className="review-success">
              <Check size={21} weight="bold" />
              <div>
                <strong>演示数据已读取</strong>
                <span>请先确认口径和证据状态，再写入看板。</span>
              </div>
            </div>
            <div className="review-grid">
              <div>
                <span>识别记录</span>
                <strong>12 项</strong>
              </div>
              <div>
                <span>待核数据</span>
                <strong>2 项</strong>
              </div>
              <div>
                <span>缺失字段</span>
                <strong>1 项</strong>
              </div>
            </div>
            <p className="review-warning">
              当前原型不会保存文件，也不会把“缺失”自动当作 0。
            </p>
            <div className="modal-actions">
              <button className="secondary-button" onClick={() => setChoice(null)}>
                返回
              </button>
              <button className="primary-button" onClick={onClose}>
                确认演示数据
              </button>
            </div>
          </div>
        )}
      </section>
    </div>
  );
}

function ExperimentStatusStrip() {
  const items = [
    { label: "历史回填", value: EXPERIMENT_BASELINE.historicalSamples, unit: "条" },
    { label: "真正盲测", value: EXPERIMENT_BASELINE.prospectiveSamples, unit: "条" },
    { label: "已有实绩", value: EXPERIMENT_BASELINE.reconciledSamples, unit: "条" },
    { label: "规则版本", value: EXPERIMENT_BASELINE.rubricVersion, unit: "" },
  ];

  return (
    <div className="experiment-status-strip" aria-label="内容实验状态">
      {items.map((item) => (
        <div className="experiment-status-item" key={item.label}>
          <span>{item.label}</span>
          <strong>
            {item.value}
            {item.unit ? <small>{item.unit}</small> : null}
          </strong>
        </div>
      ))}
    </div>
  );
}

function ExperimentRow({ experiment, selected, onSelect }) {
  const scoreReady = experiment.composite != null;
  const reachIndex = Math.max(
    6,
    Math.round((experiment.actual.reach / EXPERIMENT_BASELINE.maxReach) * 100),
  );

  return (
    <button
      className={`experiment-row ${selected ? "is-selected" : ""}`}
      onClick={onSelect}
      aria-pressed={selected}
    >
      <span className="experiment-episode">{experiment.episode}</span>
      <span className="experiment-title-cell">
        <strong>{experiment.title}</strong>
        <small>
          {experiment.snapshotWindow} · 历史回测
        </small>
      </span>
      <span className="experiment-score-cell">
        <small>盲化评分</small>
        <strong>
          {scoreReady ? experiment.composite.toFixed(1) : "待评分"}
          {scoreReady ? <em>/10</em> : null}
        </strong>
      </span>
      <span className="experiment-result-cell">
        <small>近似同窗播放</small>
        <strong>{formatNumber(experiment.actual.reach)}</strong>
        <span className="experiment-result-bar" aria-hidden="true">
          <i style={{ width: `${reachIndex}%` }} />
        </span>
      </span>
      <span className="experiment-row-arrow" aria-hidden="true">
        <ArrowRight size={15} />
      </span>
    </button>
  );
}

function MetricValue({ label, value, suffix = "", precision = 0 }) {
  const known = value != null;
  const rendered =
    known && typeof value === "number"
      ? precision > 0
        ? value.toFixed(precision)
        : formatNumber(value)
      : value;

  return (
    <div className={`experiment-actual-metric ${known ? "" : "is-missing"}`}>
      <span>{label}</span>
      <strong>
        {known ? rendered : "未知"}
        {known && suffix ? <small>{suffix}</small> : null}
      </strong>
    </div>
  );
}

function ExperimentInspector({ experiment }) {
  const actionRate = visibleActionRate(experiment.actual);

  return (
    <aside className="experiment-inspector">
      <div className="experiment-inspector-head">
        <div>
          <p className="eyebrow">RETROSPECTIVE CHECK</p>
          <h3>第{experiment.episode}期实验底稿</h3>
        </div>
        <span className="hypothesis-badge">历史回填</span>
      </div>

      <dl className="experiment-meta">
        <div>
          <dt>记录类型</dt>
          <dd>盲化回测评分</dd>
        </div>
        <div>
          <dt>锁定状态</dt>
          <dd>发布前未预登记</dd>
        </div>
        <div>
          <dt>规则版本</dt>
          <dd>{experiment.rubricVersion}</dd>
        </div>
        <div>
          <dt>实绩窗口</dt>
          <dd>{experiment.snapshotWindow}</dd>
        </div>
      </dl>

      {experiment.scriptBasis === "current_production_text_not_independently_locked" ? (
        <div className="experiment-script-basis">
          <Info size={15} />
          <span>第03期依据当前制作文字评分，尚无独立锁稿证据。</span>
        </div>
      ) : null}

      <section className="experiment-inspector-section">
        <div className="experiment-section-title">
          <h4>稿件维度</h4>
          <span>{experiment.composite == null ? "评分待写入" : `${experiment.composite.toFixed(1)}/10`}</span>
        </div>
        <div className="rubric-list">
          {RUBRIC_DIMENSIONS.map((dimension) => {
            const item = experiment.dimensions[dimension.id];
            const score = item?.score ?? 0;
            return (
              <div className={`rubric-row ${item ? "" : "is-pending"}`} key={dimension.id}>
                <div>
                  <span>{dimension.id}</span>
                  <strong>{dimension.label}</strong>
                  <small>{item?.reason ?? "待盲化评分"}</small>
                </div>
                <div
                  className="rubric-meter"
                  role="meter"
                  aria-label={`${dimension.label} ${item?.score ?? "待评分"}`}
                  aria-valuemin="0"
                  aria-valuemax="5"
                  aria-valuenow={item?.score}
                >
                  <i style={{ width: `${(score / 5) * 100}%` }} />
                </div>
                <b>{item?.score ?? "—"}</b>
              </div>
            );
          })}
        </div>
      </section>

      <section className="experiment-inspector-section">
        <div className="experiment-section-title">
          <h4>发布后实绩</h4>
          <span className="ledger-state">
            <EvidenceMark type={experiment.evidenceState} />
            {experiment.evidenceLabel}
          </span>
        </div>
        <div className="experiment-actual-grid">
          <MetricValue label="播放" value={experiment.actual.reach} />
          <MetricValue label="可见互动率" value={actionRate == null ? null : actionRate * 100} suffix="%" precision={2} />
          <MetricValue label="平均观看" value={experiment.actual.avgWatchSeconds} suffix="秒" />
          <MetricValue
            label="完播率"
            value={experiment.actual.finishRate == null ? null : experiment.actual.finishRate * 100}
            suffix="%"
            precision={2}
          />
        </div>
      </section>

      <div className="experiment-boundary-note">
        <Info size={17} />
        <p>
          这是一条发布后的盲化回测，不是当时锁定的预测。它可以初始化评分规则，不能计入预测命中率。
        </p>
      </div>

      {experiment.missingFields.length > 0 ? (
        <p className="experiment-missing">
          待补字段：{experiment.missingFields.join("、")}
        </p>
      ) : null}
    </aside>
  );
}

function ExperimentRules() {
  return (
    <section className="experiment-rules">
      <div>
        <p className="eyebrow">CALIBRATION BOUNDARY</p>
        <h3>判读边界</h3>
      </div>
      <ul>
        <li>三期均为历史回填，不显示准确率。</li>
        <li>约19—24小时只是近似同窗口。</li>
        <li>播放差异不直接归因于选题或脚本。</li>
        <li>有效线索与付费仍是经营结果，流量只是中间变量。</li>
      </ul>
      <div className="next-blind-block">
        <span>下一条真盲测</span>
        <strong>第{NEXT_BLIND_EXPERIMENT.episode}期</strong>
        <p>终稿出现后先冻结以下四项，再发布。</p>
        <ol>
          {NEXT_BLIND_EXPERIMENT.checklist.map((item) => (
            <li key={item}>{item}</li>
          ))}
        </ol>
      </div>
    </section>
  );
}

function HistoricalExperimentsView() {
  const [selectedId, setSelectedId] = useState(CONTENT_EXPERIMENTS[0].id);
  const selected =
    CONTENT_EXPERIMENTS.find((experiment) => experiment.id === selectedId) ??
    CONTENT_EXPERIMENTS[0];

  return (
    <div className="historical-experiments">
      <ExperimentStatusStrip />

      <div className="experiment-scope">
        <div>
          <span>比较范围</span>
          <strong>
            {EXPERIMENT_BASELINE.platform} · {EXPERIMENT_BASELINE.comparisonWindow}
          </strong>
        </div>
        <div className="experiment-scope-fact">
          <span>三期分发跨度</span>
          <strong>{EXPERIMENT_BASELINE.reachSpread}</strong>
          <small>仅描述事实，不作归因</small>
        </div>
      </div>

      <div className="experiment-workspace">
        <section className="experiment-comparison">
          <div className="experiment-comparison-head">
            <div>
              <p className="eyebrow">HISTORICAL BACKTEST</p>
              <h2>三期历史回测</h2>
              <p>同一套rubric盲化评稿，实绩只从现有证据台账读取。</p>
            </div>
            <span className="experiment-mode-badge">0条发布前盲测</span>
          </div>

          <div className="experiment-list">
            {CONTENT_EXPERIMENTS.map((experiment) => (
              <ExperimentRow
                key={experiment.id}
                experiment={experiment}
                selected={selectedId === experiment.id}
                onSelect={() => setSelectedId(experiment.id)}
              />
            ))}
          </div>

          <div className="experiment-comparison-foot">
            <Info size={15} />
            <span>
              第01期3184、第02期2399、第03期303，窗口约T+19—24小时；第三期分发明显更低，但后台字段尚不完整。
            </span>
          </div>
        </section>

        <div className="experiment-side">
          <ExperimentInspector experiment={selected} />
          <ExperimentRules />
        </div>
      </div>
    </div>
  );
}

function AttributionView({ onBack }) {
  const [viewMode, setViewMode] = useState("results");
  const experimentMode = viewMode === "experiments";

  return (
    <main className="secondary-page">
      <section className="surface secondary-surface">
        <div className="secondary-head">
          <div>
            <p className="eyebrow">
              {experimentMode ? "CONTENT EXPERIMENTS" : "CONTENT ATTRIBUTION"}
            </p>
            <h1>{experimentMode ? "发布前假设与历史回测" : "内容归因"}</h1>
            <p>
              {experimentMode
                ? "只区分历史回填与真正盲测，不输出爆款概率或选题结论。"
                : "查看哪些内容带来了有效线索、深度沟通与首次付费。"}
            </p>
          </div>
          <div className="secondary-head-actions">
            <div className="secondary-view-switch" role="group" aria-label="内容归因视图">
              <button
                className={viewMode === "results" ? "is-active" : ""}
                onClick={() => setViewMode("results")}
                aria-pressed={viewMode === "results"}
              >
                归因结果
              </button>
              <button
                className={experimentMode ? "is-active" : ""}
                onClick={() => setViewMode("experiments")}
                aria-pressed={experimentMode}
              >
                历史回测
              </button>
            </div>
            <button className="secondary-button" onClick={onBack}>
              返回经营链路
            </button>
          </div>
        </div>

        {experimentMode ? (
          <HistoricalExperimentsView />
        ) : (
          <div className="attribution-table">
            <div className="table-head">
              <span>内容</span>
              <span>平台</span>
              <span>有效线索</span>
              <span>深度沟通</span>
              <span>首次付费</span>
            </div>
            {ATTRIBUTION_ROWS.map((row, index) => (
              <button className="table-row" key={row.title}>
                <span className="content-cell">
                  <b>{String(index + 1).padStart(2, "0")}</b>
                  <span>{row.title}</span>
                </span>
                <span>{row.platform}</span>
                <strong>{row.leads} 条</strong>
                <strong>{row.conversations} 条</strong>
                <strong>{row.paid} 单</strong>
              </button>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}

function DataView({ onBack }) {
  return (
    <main className="secondary-page">
      <section className="surface secondary-surface">
        <div className="secondary-head">
          <div>
            <p className="eyebrow">DATA EVIDENCE</p>
            <h1>数据明细</h1>
            <p>每个经营数字都保留时间、来源、口径与证据状态。</p>
          </div>
          <button className="secondary-button" onClick={onBack}>
            返回经营链路
          </button>
        </div>

        <div className="evidence-ledger">
          <div className="ledger-head">
            <span>更新时间</span>
            <span>数据项</span>
            <span>来源</span>
            <span>当前值</span>
            <span>状态</span>
          </div>
          {EVIDENCE_ROWS.map((row) => (
            <div className="ledger-row" key={`${row.time}-${row.item}`}>
              <span>{row.time}</span>
              <strong>{row.item}</strong>
              <span>{row.source}</span>
              <strong>{row.value}</strong>
              <span className="ledger-state">
                <EvidenceMark type={row.state} />
                {row.state === "confirmed" ? "已确认" : "估算待核"}
              </span>
            </div>
          ))}
        </div>
      </section>
    </main>
  );
}

export function App() {
  const [activeTab, setActiveTab] = useState("path");
  const [selectedPlatform, setSelectedPlatform] = useState("all");
  const [selectedStage, setSelectedStage] = useState(null);
  const [range, setRange] = useState("4w");
  const [importOpen, setImportOpen] = useState(false);

  useEffect(() => {
    const closeOnEscape = (event) => {
      if (event.key !== "Escape") return;
      setSelectedStage(null);
      setImportOpen(false);
    };
    window.addEventListener("keydown", closeOnEscape);
    return () => window.removeEventListener("keydown", closeOnEscape);
  }, []);

  const page = useMemo(() => {
    if (activeTab === "attribution") {
      return <AttributionView onBack={() => setActiveTab("path")} />;
    }
    if (activeTab === "data") {
      return <DataView onBack={() => setActiveTab("path")} />;
    }
    return (
      <PathDashboard
        selectedPlatform={selectedPlatform}
        setSelectedPlatform={setSelectedPlatform}
        selectedStage={selectedStage}
        setSelectedStage={setSelectedStage}
        range={range}
        setRange={setRange}
      />
    );
  }, [activeTab, selectedPlatform, selectedStage, range]);

  return (
    <div className="app">
      <Header activeTab={activeTab} setActiveTab={setActiveTab} onImport={() => setImportOpen(true)} />
      {page}

      {selectedStage && (
        <StageDrawer stageId={selectedStage} onClose={() => setSelectedStage(null)} />
      )}
      {importOpen && <ImportModal onClose={() => setImportOpen(false)} />}

      <p className="demo-disclaimer">
        演示数据 · 全链路暂未跨平台身份去重 · 相邻阶段比不代表用户级转化率
      </p>
    </div>
  );
}

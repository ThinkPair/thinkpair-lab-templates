import type { JudgmentDimension } from "../../lib/ai-judgment";
import { dimensionIds, dimensionLabels } from "../../lib/ai-judgment";

const center = 190;
const radius = 118;

function point(index: number, value = 100) {
  const angle = (Math.PI * 2 * index) / 6 - Math.PI / 2;
  const length = radius * (value / 100);
  return [center + Math.cos(angle) * length, center + Math.sin(angle) * length] as const;
}

function polygonPoints(value: number) {
  return dimensionIds.map((_, index) => point(index, value).join(",")).join(" ");
}

export function OperatingRadar({ dimensions }: { dimensions: JudgmentDimension[] }) {
  const map = new Map(dimensions.map((item) => [item.id, item]));
  const scored = dimensionIds.filter((id) => map.get(id)?.score !== null);
  const areaPoints = dimensionIds
    .map((id, index) => point(index, map.get(id)?.score ?? 0).join(","))
    .join(" ");

  return (
    <div className="radar-shell">
      <svg className="operating-radar" viewBox="0 0 380 380" role="img" aria-labelledby="radar-title radar-desc">
        <title id="radar-title">六维经营判断图</title>
        <desc id="radar-desc">只绘制有证据的维度；空心点表示当前证据不足。</desc>
        {[25, 50, 75, 100].map((value) => (
          <polygon key={value} points={polygonPoints(value)} className="radar-grid" />
        ))}
        {dimensionIds.map((id, index) => {
          const [x, y] = point(index);
          return <line key={id} x1={center} y1={center} x2={x} y2={y} className="radar-axis" />;
        })}
        {scored.length >= 3 ? <polygon points={areaPoints} className="radar-area" /> : null}
        {dimensionIds.map((id, index) => {
          const dimension = map.get(id);
          const value = dimension?.score;
          const [x, y] = point(index, value ?? 100);
          return (
            <g key={id}>
              <circle cx={x} cy={y} r="6" className={value === null || value === undefined ? "radar-dot is-empty" : "radar-dot"} />
              <text
                x={point(index, 132)[0]}
                y={point(index, 132)[1]}
                textAnchor={index === 1 || index === 2 ? "start" : index === 4 || index === 5 ? "end" : "middle"}
                dominantBaseline="middle"
                className="radar-label"
              >
                {dimensionLabels[id]}
              </text>
              <text
                x={point(index, 112)[0]}
                y={point(index, 112)[1]}
                textAnchor="middle"
                dominantBaseline="middle"
                className="radar-value"
              >
                {value ?? "—"}
              </text>
            </g>
          );
        })}
      </svg>
      <p><span /> 有证据评分 <i /> 待核实</p>
    </div>
  );
}

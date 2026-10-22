import {
  aiDiagnosisInstructions,
  aiDiagnosisSchema,
  buildDiagnosisInput,
  extractResponseText,
  painIds,
  parseAiDiagnosis,
  type DiagnosisTurn,
  type PainId,
} from "../../../lib/ai-diagnosis";
import { sanitizeSensitiveText } from "../../../lib/diagnosis";

export const dynamic = "force-dynamic";

const DEFAULT_MODEL = "gpt-5.6-terra";

type DiagnosisRequest = {
  painId?: unknown;
  problem?: unknown;
  evidence?: unknown;
  history?: unknown;
  shop?: unknown;
};

function json(body: unknown, status = 200) {
  return Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
}

function cleanText(value: unknown, max: number) {
  if (typeof value !== "string") return "";
  return sanitizeSensitiveText(value.slice(0, max)).value.trim();
}

function cleanHistory(value: unknown): DiagnosisTurn[] {
  if (!Array.isArray(value)) return [];
  return value.slice(-6).flatMap((turn) => {
    if (!turn || typeof turn !== "object") return [];
    const role = "role" in turn ? turn.role : null;
    const content = "content" in turn ? cleanText(turn.content, 1800) : "";
    if ((role !== "user" && role !== "assistant") || !content) return [];
    return [{ role, content } satisfies DiagnosisTurn];
  });
}

function cleanShop(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>)
      .slice(0, 12)
      .map(([key, item]) => [key, typeof item === "number" ? item : cleanText(item, 120)]),
  );
}

function isPainId(value: unknown): value is PainId {
  return typeof value === "string" && painIds.includes(value as PainId);
}

export async function GET() {
  return json({ configured: Boolean(process.env.OPENAI_API_KEY), model: process.env.OPENAI_MODEL || DEFAULT_MODEL });
}

export async function POST(request: Request) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    return json({ code: "AI_NOT_CONFIGURED", message: "AI 尚未连接。配置 OPENAI_API_KEY 并重启服务后再开始真实诊断。" }, 503);
  }

  let body: DiagnosisRequest;
  try {
    body = (await request.json()) as DiagnosisRequest;
  } catch {
    return json({ code: "INVALID_JSON", message: "提交内容无法读取，请重试。" }, 400);
  }

  if (!isPainId(body.painId)) return json({ code: "INVALID_PAIN", message: "请先选择一个经营痛点。" }, 400);

  const problem = cleanText(body.problem, 1200);
  const evidence = cleanText(body.evidence, 4000);
  if (!problem && !evidence) return json({ code: "EMPTY_INPUT", message: "请先补充一条真实经营信息。" }, 400);

  const model = process.env.OPENAI_MODEL || DEFAULT_MODEL;
  let upstream: Response;
  try {
    upstream = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model,
        store: false,
        reasoning: { effort: "low", context: "current_turn" },
        instructions: aiDiagnosisInstructions,
        input: buildDiagnosisInput({
          painId: body.painId,
          problem,
          evidence,
          history: cleanHistory(body.history),
          shop: cleanShop(body.shop),
        }),
        max_output_tokens: 1400,
        text: { verbosity: "low", format: { type: "json_schema", name: "thinkpair_diagnosis", strict: true, schema: aiDiagnosisSchema } },
      }),
      signal: AbortSignal.timeout(45_000),
    });
  } catch {
    return json({ code: "AI_UNREACHABLE", message: "AI 暂时没有响应，请稍后再试。" }, 502);
  }

  if (!upstream.ok) {
    return json({ code: "AI_REQUEST_FAILED", message: upstream.status === 401 ? "AI 凭据无效，请重新配置。" : "AI 请求没有完成，请稍后再试。" }, 502);
  }

  try {
    const payload = (await upstream.json()) as Parameters<typeof extractResponseText>[0] & { model?: string };
    return json({ diagnosis: parseAiDiagnosis(extractResponseText(payload)), configured: true, model: payload.model || model });
  } catch {
    return json({ code: "AI_OUTPUT_INVALID", message: "AI 返回的诊断结构不完整，请再试一次。" }, 502);
  }
}

import { extractResponseText, type AiDiagnosis } from "../../../lib/ai-diagnosis";
import {
  aiJudgmentInstructions,
  aiJudgmentSchema,
  buildJudgmentInput,
  parseAiJudgment,
} from "../../../lib/ai-judgment";
import { sanitizeSensitiveText } from "../../../lib/diagnosis";

export const dynamic = "force-dynamic";
const DEFAULT_MODEL = "gpt-5.6-terra";

function json(body: unknown, status = 200) {
  return Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
}

function cleanText(value: unknown, max: number) {
  if (typeof value !== "string") return "";
  return sanitizeSensitiveText(value.slice(0, max)).value.trim();
}

function cleanShop(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>)
      .slice(0, 12)
      .map(([key, item]) => [key, typeof item === "number" ? item : cleanText(item, 120)]),
  );
}

export async function POST(request: Request) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return json({ code: "AI_NOT_CONFIGURED", message: "AI 尚未连接，不能生成经营判断。" }, 503);

  let body: { shop?: unknown; pain?: unknown; diagnosis?: unknown };
  try {
    body = (await request.json()) as typeof body;
  } catch {
    return json({ code: "INVALID_JSON", message: "提交内容无法读取，请重试。" }, 400);
  }

  if (!body.diagnosis || typeof body.diagnosis !== "object") {
    return json({ code: "DIAGNOSIS_REQUIRED", message: "请先完成 AI 诊断。" }, 400);
  }

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
        instructions: aiJudgmentInstructions,
        input: buildJudgmentInput({
          shop: cleanShop(body.shop),
          pain: cleanText(body.pain, 120),
          diagnosis: body.diagnosis as AiDiagnosis,
        }),
        max_output_tokens: 1800,
        text: { verbosity: "low", format: { type: "json_schema", name: "thinkpair_judgment", strict: true, schema: aiJudgmentSchema } },
      }),
      signal: AbortSignal.timeout(45_000),
    });
  } catch {
    return json({ code: "AI_UNREACHABLE", message: "AI 暂时没有响应，请稍后再试。" }, 502);
  }

  if (!upstream.ok) return json({ code: "AI_REQUEST_FAILED", message: "AI 判断没有完成，请稍后再试。" }, 502);

  try {
    const payload = (await upstream.json()) as Parameters<typeof extractResponseText>[0] & { model?: string };
    return json({ judgment: parseAiJudgment(extractResponseText(payload)), configured: true, model: payload.model || model });
  } catch {
    return json({ code: "AI_OUTPUT_INVALID", message: "AI 返回的判断结构不完整，请再试一次。" }, 502);
  }
}

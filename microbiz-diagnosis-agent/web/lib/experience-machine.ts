export const shopFieldDefinitions = [
  {
    id: "name",
    label: "店铺名字",
    shortLabel: "名字",
    prompt: "先给这家小店一个名字。",
    placeholder: "例如：木棉咖啡",
    buildCue: "点亮地块",
  },
  {
    id: "location",
    label: "所在位置",
    shortLabel: "位置",
    prompt: "它在哪个城市或商圈？不用写详细地址。",
    placeholder: "例如：杭州 · 城西银泰附近",
    buildCue: "落下地基",
  },
  {
    id: "category",
    label: "经营类型",
    shortLabel: "行业",
    prompt: "这家店主要做什么？",
    placeholder: "例如：社区咖啡与烘焙",
    buildCue: "搭起结构",
  },
  {
    id: "areaSqm",
    label: "店铺面积",
    shortLabel: "面积",
    prompt: "店铺大约多少平方米？",
    placeholder: "例如：86",
    suffix: "㎡",
    inputMode: "decimal",
    buildCue: "完成外立面",
  },
  {
    id: "yearsOpen",
    label: "经营年限",
    shortLabel: "店龄",
    prompt: "这家店开了多少年？",
    placeholder: "例如：3.5",
    suffix: "年",
    inputMode: "decimal",
    buildCue: "布置店内",
  },
  {
    id: "staffCount",
    label: "团队人数",
    shortLabel: "人员",
    prompt: "算上你，现在一共有几个人？",
    placeholder: "例如：4",
    suffix: "人",
    inputMode: "numeric",
    buildCue: "店主入场",
  },
] as const;

export type ShopFieldId = (typeof shopFieldDefinitions)[number]["id"];

export type ShopProfile = {
  name?: string;
  location?: string;
  category?: string;
  areaSqm?: number;
  yearsOpen?: number;
  staffCount?: number;
};

export type ExperiencePhase = "build" | "diagnose" | "judgment";

export type ExperienceState = {
  phase: ExperiencePhase;
  shop: ShopProfile;
  confirmed: boolean;
};

export type ExperienceAction =
  | { type: "answer"; field: ShopFieldId; value: string | number }
  | { type: "confirmShop" }
  | { type: "showJudgment" }
  | { type: "reset" };

export const initialExperienceState: ExperienceState = {
  phase: "build",
  shop: {},
  confirmed: false,
};

export function answeredFieldCount(shop: ShopProfile) {
  return shopFieldDefinitions.filter(({ id }) => {
    const value = shop[id];
    return typeof value === "number" ? Number.isFinite(value) : Boolean(value?.trim());
  }).length;
}

export function isShopComplete(shop: ShopProfile) {
  return answeredFieldCount(shop) === shopFieldDefinitions.length;
}

export function nextShopField(shop: ShopProfile) {
  return shopFieldDefinitions.find(({ id }) => {
    const value = shop[id];
    return typeof value === "number" ? !Number.isFinite(value) : !value?.trim();
  });
}

export function parseShopAnswer(field: ShopFieldId, raw: string): string | number {
  const value = raw.trim();
  if (!value) throw new Error("请先回答这一项。");

  if (field === "areaSqm") {
    const number = Number(value.replace(/[^\d.]/g, ""));
    if (!Number.isFinite(number) || number < 3 || number > 20_000) {
      throw new Error("请输入 3–20,000 之间的面积。");
    }
    return Math.round(number * 10) / 10;
  }

  if (field === "yearsOpen") {
    const number = Number(value.replace(/[^\d.]/g, ""));
    if (!Number.isFinite(number) || number < 0 || number > 100) {
      throw new Error("请输入 0–100 之间的经营年限。");
    }
    return Math.round(number * 10) / 10;
  }

  if (field === "staffCount") {
    const number = Number(value.replace(/[^\d]/g, ""));
    if (!Number.isInteger(number) || number < 1 || number > 1_000) {
      throw new Error("请输入 1–1,000 之间的团队人数。");
    }
    return number;
  }

  if (value.length > 60) throw new Error("这一项请控制在 60 个字以内。");
  return value;
}

export function formatShopValue(field: ShopFieldId, value: string | number | undefined) {
  if (value === undefined || value === "") return "待补充";
  const definition = shopFieldDefinitions.find((item) => item.id === field);
  return `${value}${definition && "suffix" in definition ? definition.suffix ?? "" : ""}`;
}

export function experienceReducer(state: ExperienceState, action: ExperienceAction): ExperienceState {
  if (action.type === "reset") return initialExperienceState;

  if (action.type === "answer") {
    if (state.phase !== "build") return state;
    return {
      ...state,
      shop: { ...state.shop, [action.field]: action.value },
      confirmed: false,
    };
  }

  if (action.type === "confirmShop") {
    if (!isShopComplete(state.shop)) return state;
    return { ...state, phase: "diagnose", confirmed: true };
  }

  if (action.type === "showJudgment") {
    if (state.phase !== "diagnose" || !state.confirmed) return state;
    return { ...state, phase: "judgment" };
  }

  return state;
}

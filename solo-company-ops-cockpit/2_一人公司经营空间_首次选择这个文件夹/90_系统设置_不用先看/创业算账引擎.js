/*
 * 降噪实验室 · 创业算账确定性引擎
 * 纯函数、无网络、无文件写入。首页、计算页和测试必须共用本文件。
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.BusinessFinanceEngine = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const VERSION = "1.3.0";
  const HASH_ALGORITHM = "fnv1a64";
  const QUICK_V3_SCHEMA_VERSION = "finance.v2";
  const BUSINESS_TARGET_SCHEMA_VERSION = "business_target_plan.v1";
  const OPERATING_ACTION_SCHEMA_VERSION = "operating_action_plan.v1";
  const MODES = Object.freeze(["actual", "forecast"]);
  const DELIVERY_MODELS = Object.freeze(["instant", "milestone", "subscription", "stored_value"]);
  const SCENARIOS = Object.freeze(["low", "base", "high"]);
  const INPUT_MODES = Object.freeze(["finance.v1", "quick_v2", "quick_v3"]);
  const CONVERSION_BASES = Object.freeze(["historical", "user_estimate", "mixed"]);

  const TARGET_FIELD_LABELS = Object.freeze({
    calculationId: "核算记录 ID",
    sourceInputHash: "核算输入哈希",
    targetMonth: "目标月份",
    targetProfit: "目标利润",
    targetCashIncrease: "目标现金增加",
    fixedOperatingCost: "固定经营成本",
    ownerWage: "创业者合理工资",
    contributionMarginRate: "贡献毛利率",
    unitRecognizedRevenue: "每个交付单位可确认收入",
    unitDirectCost: "每个交付单位直接成本",
    maxStableDeliveryUnits: "每月最大稳定交付量",
    averageCashCollectedPerSale: "平均每单本月实收",
    futureRigidCashOutflow: "未来刚性现金支出"
  });

  const BREAKDOWN_FIELD_LABELS = Object.freeze({
    targetPlanId: "目标方案 ID",
    targetInputHash: "目标输入哈希",
    targetMonth: "目标月份",
    actualCashReceived: "当前已完成实收",
    actualDeals: "当前已完成成交单数",
    actualRecognizedRevenue: "当前已确认收入",
    actualDeliveredUnits: "当前已完成交付量",
    remainingBusinessDays: "剩余有效经营日",
    outreachToResponse: "触达到回应转化率",
    responseToDiscussion: "回应到讨论转化率",
    discussionToQuote: "讨论到报价转化率",
    quoteToSale: "报价到成交转化率",
    conversionBasis: "转化率依据",
    sprintFactor: "冲刺系数"
  });

  const QUICK_FIELD_LABELS = Object.freeze({
    recognizedRevenue: "最近30天已完成交付的价值",
    cashIn: "最近30天实际经营现金流入",
    cashOut: "最近30天实际经营现金流出",
    directCost: "本期直接交付成本",
    fixedCostExOwner: "本期固定经营成本（不含老板工资）",
    ownerWage: "老板合理工资",
    monthlyFixedCostExOwner: "平均每月固定经营成本（不含自己的合理工资）",
    monthlyOwnerWage: "自己每月合理工资",
    availableCash: "当前可动用现金",
    remainingFulfillmentCost: "完成已收款未交付承诺还需的成本",
    completedUnits: "本期已完成交付数量",
    next30RigidOutflow: "未来30天刚性现金支出",
    unitPrice: "单位售价",
    unitDirectCost: "单位直接成本",
    baseUnits: "基准月销量",
    capacityUnits: "每月最大稳定交付能力",
    cashAfterStartup: "启动投入后剩余经营现金",
    startupInvestment: "一次性启动投入"
  });

  const FIELD_LABELS = Object.freeze({
    periodStart: "核算开始日期",
    periodEnd: "核算结束日期",
    sharedFixedCost: "公司共同固定成本",
    ownerWage: "老板合理工资",
    taxCost: "本期税费",
    cashOperatingOutflow: "本期实际经营现金支出",
    ownerCashDraw: "老板实际取款",
    availableCash: "当前可动用现金",
    payableReserve: "应付款、待退款与应缴税费准备",
    nearTermRigidOutflow: "未来30天刚性现金支出",
    startupInvestment: "一次性启动投入",
    taxRate: "预计综合税费率",
    recognizedRevenue: "已交付确认收入",
    cashReceived: "实际经营到账",
    revenueRefund: "冲减收入的退款",
    cashRefund: "实际现金退款",
    unitsDelivered: "已完成交付量",
    directCost: "直接交付成本",
    productFixedCost: "产品专属固定成本",
    platformFees: "平台及支付费用",
    unfulfilledCost: "未履约承诺剩余成本",
    capacityUnits: "本周期最大交付能力",
    unitPrice: "单位售价",
    unitVariableCost: "单位变动成本",
    feeRate: "平台及支付费率",
    refundRate: "预计退款率",
    collectionRate: "本周期收款比例",
    commitmentRate: "期末未完成交付比例",
    unitsLow: "保守销量",
    unitsBase: "基准销量",
    unitsHigh: "乐观销量"
  });

  const MODEL_LABELS = Object.freeze({
    instant: "即时交付",
    milestone: "项目／里程碑交付",
    subscription: "周期订阅",
    stored_value: "储值计次"
  });

  function isBlank(value) {
    return value === null || value === undefined || (typeof value === "string" && value.trim() === "");
  }

  function asNumber(value) {
    if (isBlank(value)) return null;
    const parsed = typeof value === "number" ? value : Number(String(value).trim());
    return Number.isFinite(parsed) ? parsed : null;
  }

  function cents(value) {
    const number = asNumber(value);
    return number === null ? null : Math.round((number + Number.EPSILON) * 100);
  }

  function money(centsValue) {
    return centsValue === null || centsValue === undefined ? null : Number((centsValue / 100).toFixed(2));
  }

  function quantityHundredths(value) {
    const number = asNumber(value);
    return number === null ? null : Math.round((number + Number.EPSILON) * 100);
  }

  function multiplyMoneyByQuantity(moneyCents, quantity) {
    const quantity100 = quantityHundredths(quantity);
    if (moneyCents === null || quantity100 === null) return null;
    return Math.round((moneyCents * quantity100) / 100);
  }

  function percentToBasisPoints(value) {
    const number = asNumber(value);
    return number === null ? null : Math.round(number * 100);
  }

  function applyRate(centsValue, basisPoints) {
    if (centsValue === null || basisPoints === null) return null;
    return Math.round((centsValue * basisPoints) / 10000);
  }

  function sumCents(values) {
    return values.reduce((total, value) => total + (value || 0), 0);
  }

  function stableStringify(value) {
    if (value === null || typeof value !== "object") return JSON.stringify(value);
    if (Array.isArray(value)) return "[" + value.map(stableStringify).join(",") + "]";
    return "{" + Object.keys(value).sort().map((key) => JSON.stringify(key) + ":" + stableStringify(value[key])).join(",") + "}";
  }

  function hashInput(value) {
    const text = stableStringify(value);
    let hash = 0xcbf29ce484222325n;
    for (let index = 0; index < text.length; index += 1) {
      hash ^= BigInt(text.charCodeAt(index));
      hash = BigInt.asUintN(64, hash * 0x100000001b3n);
    }
    return hash.toString(16).padStart(16, "0");
  }

  function clone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  const DAY_MS = 24 * 60 * 60 * 1000;

  function daysInCalendarMonth(year, month) {
    if (month === 2) {
      const leap = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
      return leap ? 29 : 28;
    }
    return [4, 6, 9, 11].includes(month) ? 30 : 31;
  }

  function parseIsoDate(value) {
    const text = String(value || "").trim();
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
    if (!match) return null;
    const year = Number(match[1]);
    const month = Number(match[2]);
    const day = Number(match[3]);
    if (year < 1000 || month < 1 || month > 12) return null;
    const daysInMonth = daysInCalendarMonth(year, month);
    if (day < 1 || day > daysInMonth) return null;
    return { text, year, month, day, daysInMonth, utc: Date.UTC(year, month - 1, day) };
  }

  function isoDate(year, month, day) {
    return String(year).padStart(4, "0") + "-" + String(month).padStart(2, "0") + "-" + String(day).padStart(2, "0");
  }

  function periodArguments(inputOrStart, periodEnd, inputMode) {
    if (inputOrStart && typeof inputOrStart === "object") {
      const source = inputOrStart.state && typeof inputOrStart.state === "object" ? inputOrStart.state : inputOrStart;
      return {
        periodStart: String(source.periodStart || source.period_start || ""),
        periodEnd: String(source.periodEnd || source.period_end || ""),
        inputMode: String(source.inputMode || source.input_mode || inputMode || "")
      };
    }
    return {
      periodStart: String(inputOrStart || ""),
      periodEnd: String(periodEnd || ""),
      inputMode: String(inputMode || "")
    };
  }

  function getPeriodProfile(inputOrStart, periodEnd, inputMode) {
    const args = periodArguments(inputOrStart, periodEnd, inputMode);
    const start = parseIsoDate(args.periodStart);
    const end = parseIsoDate(args.periodEnd);
    const errors = [];
    const warnings = [];
    if (!start) errors.push("核算开始日期无效，必须使用真实的 YYYY-MM-DD 日期。");
    if (!end) errors.push("核算结束日期无效，必须使用真实的 YYYY-MM-DD 日期。");
    if (start && end && end.utc < start.utc) errors.push("核算结束日期不能早于开始日期。");
    if (errors.length) {
      return {
        valid: false,
        errors,
        warnings,
        periodStart: args.periodStart,
        periodEnd: args.periodEnd,
        periodEndInclusive: true,
        totalDays: null,
        monthFactor: null,
        isFullCalendarMonth: false,
        isLegacyPeriodAmbiguous: args.inputMode === "quick_v2",
        monthSegments: []
      };
    }

    const monthSegments = [];
    let cursorYear = start.year;
    let cursorMonth = start.month;
    let factor = 0;
    while (cursorYear < end.year || (cursorYear === end.year && cursorMonth <= end.month)) {
      const daysInMonth = daysInCalendarMonth(cursorYear, cursorMonth);
      const segmentStartDay = cursorYear === start.year && cursorMonth === start.month ? start.day : 1;
      const segmentEndDay = cursorYear === end.year && cursorMonth === end.month ? end.day : daysInMonth;
      const coveredDays = segmentEndDay - segmentStartDay + 1;
      const segmentFactor = coveredDays / daysInMonth;
      factor += segmentFactor;
      monthSegments.push({
        month: String(cursorYear).padStart(4, "0") + "-" + String(cursorMonth).padStart(2, "0"),
        start: isoDate(cursorYear, cursorMonth, segmentStartDay),
        end: isoDate(cursorYear, cursorMonth, segmentEndDay),
        coveredDays,
        daysInMonth,
        factor: Number(segmentFactor.toFixed(10))
      });
      cursorMonth += 1;
      if (cursorMonth > 12) {
        cursorMonth = 1;
        cursorYear += 1;
      }
    }

    const totalDays = Math.round((end.utc - start.utc) / DAY_MS) + 1;
    const isFullCalendarMonth = start.year === end.year
      && start.month === end.month
      && start.day === 1
      && end.day === end.daysInMonth;
    const isWholeCalendarMonths = start.day === 1 && end.day === end.daysInMonth;
    if (!isWholeCalendarMonths) warnings.push("核算区间包含部分自然月，月度成本将按每个月实际覆盖天数占比逐月折算。");
    if (start.month === 1 && start.day === 1 && end.year === start.year + 1 && end.month === 1 && end.day === 1) {
      warnings.push("该区间比一个完整自然年多包含下一年第一天；如核算上一整年，请把结束日期改为上一年的 12 月 31 日。");
    }
    const isLegacyPeriodAmbiguous = args.inputMode === "quick_v2" && !isFullCalendarMonth;
    if (isLegacyPeriodAmbiguous) warnings.push("旧版 quick_v2 只有完整单月记录可直接解释；当前跨月或部分月成本口径需要人工复核。");
    return {
      valid: true,
      errors,
      warnings,
      periodStart: start.text,
      periodEnd: end.text,
      periodEndInclusive: true,
      totalDays,
      monthFactor: Number(factor.toFixed(10)),
      isFullCalendarMonth,
      isLegacyPeriodAmbiguous,
      monthSegments
    };
  }

  function classifyLegacyQuickPeriod(input) {
    const profile = getPeriodProfile(input);
    const source = input && input.state && typeof input.state === "object" ? input.state : (input || {});
    const mode = String(source.inputMode || source.input_mode || "");
    if (mode !== "quick_v2") return Object.assign({}, profile, { isLegacyPeriodAmbiguous: false });
    return Object.assign({}, profile, {
      isLegacyPeriodAmbiguous: !profile.valid || !profile.isFullCalendarMonth
    });
  }

  function prorateMonthlyCents(monthlyCents, profile) {
    if (monthlyCents === null || !profile || !profile.valid) return null;
    return profile.monthSegments.reduce((total, segment) => {
      return total + Math.round((monthlyCents * segment.coveredDays) / segment.daysInMonth);
    }, 0);
  }

  function hasOwn(source, key) {
    return Boolean(source && Object.prototype.hasOwnProperty.call(source, key));
  }

  function firstOwn(source, keys) {
    for (let index = 0; index < keys.length; index += 1) {
      if (hasOwn(source, keys[index])) return source[keys[index]];
    }
    return undefined;
  }

  function firstValue(sources, keys) {
    for (let index = 0; index < sources.length; index += 1) {
      const value = firstOwn(sources[index], keys);
      if (value !== undefined) return { found: true, value };
    }
    return { found: false, value: undefined };
  }

  function firstNumber(sources, keys) {
    for (let index = 0; index < sources.length; index += 1) {
      const value = firstOwn(sources[index], keys);
      if (value !== undefined && !isBlank(value)) return asNumber(value);
    }
    return null;
  }

  function firstText(sources, keys, fallback) {
    for (let index = 0; index < sources.length; index += 1) {
      const value = firstOwn(sources[index], keys);
      if (value !== undefined && value !== null && String(value).trim()) return String(value).trim();
    }
    return fallback === undefined ? "" : fallback;
  }

  function firstBoolean(sources, keys, fallback) {
    for (let index = 0; index < sources.length; index += 1) {
      const value = firstOwn(sources[index], keys);
      if (value === true || value === false) return value;
      if (value === 1 || value === "1" || value === "true") return true;
      if (value === 0 || value === "0" || value === "false") return false;
    }
    return Boolean(fallback);
  }

  function firstNullableBoolean(sources, keys) {
    const found = firstValue(sources, keys);
    if (!found.found || found.value === null || found.value === undefined || found.value === "") return null;
    if (found.value === true || found.value === 1 || found.value === "1" || found.value === "true") return true;
    if (found.value === false || found.value === 0 || found.value === "0" || found.value === "false") return false;
    return null;
  }

  function readiness(status, missingFields, errors) {
    return {
      status,
      missingFields: missingFields || [],
      errors: errors || []
    };
  }

  function deepEqual(left, right) {
    return stableStringify(left) === stableStringify(right);
  }

  function cleanState(input) {
    const source = input && typeof input === "object" ? input : {};
    return {
      mode: MODES.includes(source.mode) ? source.mode : "actual",
      periodStart: String(source.periodStart || ""),
      periodEnd: String(source.periodEnd || ""),
      currency: String(source.currency || "CNY"),
      company: Object.assign({
        sharedFixedCost: null,
        ownerWage: null,
        taxCost: null,
        cashOperatingOutflow: null,
        ownerCashDraw: null,
        availableCash: null,
        payableReserve: null,
        nearTermRigidOutflow: null,
        startupInvestment: null,
        taxRate: null
      }, source.company || {}),
      products: Array.isArray(source.products) ? source.products.map((product, index) => Object.assign({
        id: "product-" + (index + 1),
        name: "",
        model: "instant",
        salesUnit: "单",
        deliveryUnit: "次",
        recognizedRevenue: null,
        cashReceived: null,
        revenueRefund: null,
        cashRefund: null,
        unitsDelivered: null,
        directCost: null,
        productFixedCost: null,
        platformFees: null,
        unfulfilledCost: null,
        capacityUnits: null,
        acceptedReceivable: null,
        unitPrice: null,
        unitVariableCost: null,
        feeRate: null,
        refundRate: null,
        collectionRate: null,
        commitmentRate: null,
        unitsLow: null,
        unitsBase: null,
        unitsHigh: null
      }, product || {})) : []
    };
  }

  function validDate(value) {
    return /^\d{4}-\d{2}-\d{2}$/.test(String(value || "")) && !Number.isNaN(new Date(value + "T00:00:00").getTime());
  }

  function pushMissing(list, scope, field) {
    list.push({ scope, field, label: FIELD_LABELS[field] || field });
  }

  function validate(input) {
    const state = cleanState(input);
    const missing = [];
    const errors = [];
    const warnings = [];

    if (!validDate(state.periodStart)) pushMissing(missing, "company", "periodStart");
    if (!validDate(state.periodEnd)) pushMissing(missing, "company", "periodEnd");
    if (validDate(state.periodStart) && validDate(state.periodEnd) && state.periodStart > state.periodEnd) {
      errors.push("核算开始日期不能晚于结束日期。");
    }
    if (!state.products.length) errors.push("至少需要一个产品或收费方案。");

    const companyFields = state.mode === "actual"
      ? ["sharedFixedCost", "ownerWage", "taxCost", "cashOperatingOutflow", "ownerCashDraw", "availableCash", "payableReserve", "nearTermRigidOutflow"]
      : ["sharedFixedCost", "ownerWage", "taxRate", "availableCash", "payableReserve", "nearTermRigidOutflow", "startupInvestment"];

    companyFields.forEach((field) => {
      const value = asNumber(state.company[field]);
      if (value === null) pushMissing(missing, "company", field);
      else if (field !== "availableCash" && value < 0) errors.push((FIELD_LABELS[field] || field) + "不能为负数。");
    });
    if (asNumber(state.company.taxRate) !== null && (asNumber(state.company.taxRate) < 0 || asNumber(state.company.taxRate) > 100)) {
      errors.push("预计综合税费率必须在 0% 到 100% 之间。");
    }

    state.products.forEach((product, index) => {
      const scope = String(product.name || "").trim() || "产品" + (index + 1);
      if (!String(product.name || "").trim()) errors.push("第 " + (index + 1) + " 个产品缺少名称。");
      if (!DELIVERY_MODELS.includes(product.model)) errors.push(scope + " 的交付模型无效。");
      const required = state.mode === "actual"
        ? ["recognizedRevenue", "cashReceived", "revenueRefund", "cashRefund", "unitsDelivered", "directCost", "productFixedCost", "platformFees", "unfulfilledCost", "capacityUnits"]
        : ["unitPrice", "unitVariableCost", "productFixedCost", "feeRate", "refundRate", "collectionRate", "commitmentRate", "unitsLow", "unitsBase", "unitsHigh", "capacityUnits"];
      required.forEach((field) => {
        const value = asNumber(product[field]);
        if (value === null) pushMissing(missing, scope, field);
        else if (value < 0) errors.push(scope + "的“" + (FIELD_LABELS[field] || field) + "”不能为负数。");
      });
      ["feeRate", "refundRate", "collectionRate", "commitmentRate"].forEach((field) => {
        const value = asNumber(product[field]);
        if (value !== null && (value < 0 || value > 100)) errors.push(scope + "的“" + FIELD_LABELS[field] + "”必须在 0% 到 100% 之间。");
      });
      if (state.mode === "forecast") {
        const low = asNumber(product.unitsLow);
        const base = asNumber(product.unitsBase);
        const high = asNumber(product.unitsHigh);
        if (low !== null && base !== null && high !== null && !(low <= base && base <= high)) {
          errors.push(scope + "的三档销量必须满足：保守 ≤ 基准 ≤ 乐观。");
        }
      }
    });

    return {
      state,
      missing,
      errors,
      warnings,
      ready: missing.length === 0 && errors.length === 0
    };
  }

  function statusFrom(profitCents, cashCents) {
    if (profitCents > 0 && cashCents > 0) return { code: "profit_cash_positive", text: "业务赚钱，现金也在增加" };
    if (profitCents > 0 && cashCents < 0) return { code: "profit_positive_cash_negative", text: "业务赚钱，但现金节奏承压" };
    if (profitCents < 0 && cashCents > 0) return { code: "profit_negative_cash_positive", text: "现金流入掩盖了经营亏损" };
    if (profitCents < 0 && cashCents < 0) return { code: "profit_cash_negative", text: "业务亏损，现金也在流出" };
    if (profitCents === 0 && cashCents === 0) return { code: "on_break_even", text: "利润和现金都处在临界线" };
    if (profitCents === 0) return { code: "profit_break_even", text: cashCents >= 0 ? "业务刚好保本，现金为正" : "业务刚好保本，现金为负" };
    return { code: "cash_break_even", text: profitCents >= 0 ? "业务盈利，现金持平" : "业务亏损，现金持平" };
  }

  function calculateActual(state, validation) {
    const company = state.company;
    const sharedFixed = cents(company.sharedFixedCost);
    const ownerWage = cents(company.ownerWage);
    const taxCost = cents(company.taxCost);
    const productResults = state.products.map((product) => {
      const revenue = cents(product.recognizedRevenue);
      const revenueRefund = cents(product.revenueRefund);
      const direct = cents(product.directCost);
      const fixed = cents(product.productFixedCost);
      const fees = cents(product.platformFees);
      const units = asNumber(product.unitsDelivered);
      const netRevenue = revenue - revenueRefund;
      const contribution = netRevenue - direct - fees;
      const unitContribution = units > 0 ? Math.round(contribution / units) : null;
      const contributionRate = netRevenue > 0 ? Number(((contribution / netRevenue) * 100).toFixed(2)) : null;
      return {
        id: product.id,
        name: product.name,
        model: product.model,
        modelLabel: MODEL_LABELS[product.model],
        salesUnit: product.salesUnit,
        deliveryUnit: product.deliveryUnit,
        netRevenue: money(netRevenue),
        contribution: money(contribution),
        unitContribution: money(unitContribution),
        contributionRate,
        unitsDelivered: units,
        capacityUnits: asNumber(product.capacityUnits),
        unfulfilledCost: money(cents(product.unfulfilledCost)),
        acceptedReceivable: money(cents(product.acceptedReceivable))
      };
    });

    const totalRevenue = sumCents(state.products.map((product) => cents(product.recognizedRevenue) - cents(product.revenueRefund)));
    const totalDirect = sumCents(state.products.map((product) => cents(product.directCost)));
    const totalProductFixed = sumCents(state.products.map((product) => cents(product.productFixedCost)));
    const totalFees = sumCents(state.products.map((product) => cents(product.platformFees)));
    const sustainableProfit = totalRevenue - totalDirect - totalProductFixed - totalFees - sharedFixed - ownerWage - taxCost;
    const cashIn = sumCents(state.products.map((product) => cents(product.cashReceived)));
    const cashRefund = sumCents(state.products.map((product) => cents(product.cashRefund)));
    const cashNet = cashIn - cashRefund - cents(company.cashOperatingOutflow) - cents(company.ownerCashDraw);
    const commitmentReserve = sumCents(state.products.map((product) => cents(product.unfulfilledCost))) + cents(company.payableReserve);
    const safety = cents(company.availableCash) - commitmentReserve - cents(company.nearTermRigidOutflow);
    const warnings = validation.warnings.slice();
    let breakEvenUnits = null;
    let breakEvenLabel = "多产品请看公司保本差额";
    let unitContribution = null;
    if (productResults.length === 1) {
      unitContribution = cents(productResults[0].unitContribution);
      if (unitContribution > 0) {
        const fixedNeed = cents(state.products[0].productFixedCost) + sharedFixed + ownerWage + taxCost;
        breakEvenUnits = Math.ceil(fixedNeed / unitContribution);
        breakEvenLabel = "保本需要 " + breakEvenUnits + " " + (state.products[0].salesUnit || "单");
        if (asNumber(state.products[0].capacityUnits) < breakEvenUnits) warnings.push("保本量超过当前交付能力，数学上保本但现实产能不足。");
      } else {
        breakEvenLabel = "单位贡献不为正，卖得越多亏得越多";
        warnings.push(breakEvenLabel + "。");
      }
    }
    const profitGap = sustainableProfit < 0 ? -sustainableProfit : 0;
    if (safety < 0) warnings.push("当前现金不足以覆盖未履约承诺和未来30天刚性支出。");
    const status = statusFrom(sustainableProfit, cashNet);

    return {
      calculationVersion: VERSION,
      mode: "actual",
      status,
      sustainableProfit: money(sustainableProfit),
      cashNetChange: money(cashNet),
      safetyValue: money(safety),
      safetyLabel: "交付安全余额",
      totalRecognizedRevenue: money(totalRevenue),
      totalCashReceived: money(cashIn),
      totalCommitmentReserve: money(commitmentReserve),
      profitGap: money(profitGap),
      breakEvenUnits,
      breakEvenLabel,
      unitContribution: money(unitContribution),
      products: productResults,
      warnings
    };
  }

  function forecastScenario(state, scenario) {
    const company = state.company;
    const sharedFixed = cents(company.sharedFixedCost);
    const ownerWage = cents(company.ownerWage);
    const taxRate = percentToBasisPoints(company.taxRate);
    const productRows = state.products.map((product) => {
      const units = asNumber(product["units" + scenario.charAt(0).toUpperCase() + scenario.slice(1)]);
      const unitPrice = cents(product.unitPrice);
      const unitCost = cents(product.unitVariableCost);
      const grossRevenue = multiplyMoneyByQuantity(unitPrice, units);
      const refunds = applyRate(grossRevenue, percentToBasisPoints(product.refundRate));
      const netRevenue = grossRevenue - refunds;
      const fees = applyRate(grossRevenue, percentToBasisPoints(product.feeRate));
      const variableCost = multiplyMoneyByQuantity(unitCost, units);
      const contribution = netRevenue - variableCost - fees;
      const cashCollected = applyRate(netRevenue, percentToBasisPoints(product.collectionRate));
      const commitmentUnits = units * (asNumber(product.commitmentRate) / 100);
      const commitmentCost = multiplyMoneyByQuantity(unitCost, commitmentUnits);
      const unitContribution = units > 0 ? Math.round(contribution / units) : (unitPrice - unitCost - applyRate(unitPrice, percentToBasisPoints(product.feeRate)) - applyRate(unitPrice, percentToBasisPoints(product.refundRate)));
      return {
        id: product.id,
        name: product.name,
        model: product.model,
        modelLabel: MODEL_LABELS[product.model],
        units,
        capacityUnits: asNumber(product.capacityUnits),
        netRevenueCents: netRevenue,
        contributionCents: contribution,
        cashCollectedCents: cashCollected,
        variableCostCents: variableCost,
        feeCents: fees,
        fixedCents: cents(product.productFixedCost),
        commitmentCostCents: commitmentCost,
        unitContributionCents: unitContribution
      };
    });
    const netRevenue = sumCents(productRows.map((row) => row.netRevenueCents));
    const directCost = sumCents(productRows.map((row) => row.variableCostCents));
    const fees = sumCents(productRows.map((row) => row.feeCents));
    const productFixed = sumCents(productRows.map((row) => row.fixedCents));
    const tax = applyRate(netRevenue, taxRate);
    const profit = netRevenue - directCost - fees - productFixed - sharedFixed - ownerWage - tax;
    const cashCollected = sumCents(productRows.map((row) => row.cashCollectedCents));
    const cashNet = cashCollected - directCost - fees - productFixed - sharedFixed - ownerWage - tax;
    const commitmentReserve = sumCents(productRows.map((row) => row.commitmentCostCents)) + cents(company.payableReserve);
    const cashAfterStartup = cents(company.availableCash) - cents(company.startupInvestment) + cashNet - cents(company.nearTermRigidOutflow) - commitmentReserve;
    const fundingGap = cashAfterStartup < 0 ? -cashAfterStartup : 0;
    const capacityWarnings = productRows.filter((row) => row.units > row.capacityUnits).map((row) => row.name + "的预计销量超过交付能力");
    return {
      scenario,
      netRevenue: money(netRevenue),
      sustainableProfit: money(profit),
      cashNetChange: money(cashNet),
      cashAfterStartup: money(cashAfterStartup),
      fundingGap: money(fundingGap),
      commitmentReserve: money(commitmentReserve),
      capacityFeasible: capacityWarnings.length === 0,
      capacityWarnings,
      products: productRows.map((row) => ({
        id: row.id,
        name: row.name,
        units: row.units,
        netRevenue: money(row.netRevenueCents),
        contribution: money(row.contributionCents),
        unitContribution: money(row.unitContributionCents),
        capacityUnits: row.capacityUnits
      }))
    };
  }

  function calculateForecast(state, validation) {
    const scenarios = SCENARIOS.map((scenario) => forecastScenario(state, scenario));
    const base = scenarios.find((item) => item.scenario === "base");
    const warnings = validation.warnings.slice();
    scenarios.forEach((scenario) => warnings.push.apply(warnings, scenario.capacityWarnings.map((item) => ({ low: "保守", base: "基准", high: "乐观" }[scenario.scenario] + "情景：" + item + "。"))));
    const nonPositive = base.products.filter((product) => product.unitContribution !== null && product.unitContribution <= 0);
    nonPositive.forEach((product) => warnings.push(product.name + "单位贡献不为正，扩大销量会扩大亏损。"));
    const status = statusFrom(cents(base.sustainableProfit), cents(base.cashNetChange));
    return {
      calculationVersion: VERSION,
      mode: "forecast",
      status: { code: "forecast_" + status.code, text: "基准预估：" + status.text },
      sustainableProfit: base.sustainableProfit,
      cashNetChange: base.cashNetChange,
      safetyValue: base.fundingGap,
      safetyLabel: base.fundingGap > 0 ? "启动资金缺口" : "启动资金缺口",
      breakEvenUnits: null,
      breakEvenLabel: "按三档销量与产能判断",
      unitContribution: base.products.length === 1 ? base.products[0].unitContribution : null,
      scenarios,
      warnings
    };
  }

  const QUICK_NUMERIC_FIELDS = Object.freeze([
    "recognizedRevenue",
    "cashIn",
    "cashOut",
    "directCost",
    "fixedCostExOwner",
    "ownerWage",
    "availableCash",
    "remainingFulfillmentCost",
    "completedUnits",
    "next30RigidOutflow",
    "unitPrice",
    "unitDirectCost",
    "baseUnits",
    "capacityUnits",
    "cashAfterStartup",
    "startupInvestment"
  ]);

  const QUICK_ACTUAL_CORE_FIELDS = Object.freeze([
    "recognizedRevenue",
    "cashIn",
    "cashOut",
    "directCost",
    "fixedCostExOwner",
    "ownerWage",
    "availableCash",
    "remainingFulfillmentCost"
  ]);

  const QUICK_FORECAST_CORE_FIELDS = Object.freeze([
    "unitPrice",
    "unitDirectCost",
    "fixedCostExOwner",
    "ownerWage",
    "baseUnits",
    "capacityUnits"
  ]);

  const DEFAULT_UNIT_LABELS = Object.freeze({
    instant: "单",
    milestone: "阶段",
    subscription: "客户·月",
    stored_value: "次"
  });

  function cleanQuickV2State(input) {
    const source = input && typeof input === "object" ? input : {};
    const quickSource = source.quick && typeof source.quick === "object" ? source.quick : {};
    const deliveryModel = DELIVERY_MODELS.includes(source.deliveryModel) ? source.deliveryModel : "instant";
    const quick = {};
    QUICK_NUMERIC_FIELDS.forEach((field) => {
      quick[field] = asNumber(quickSource[field]);
    });
    return {
      inputMode: "quick_v2",
      mode: MODES.includes(source.mode) ? source.mode : "actual",
      periodStart: String(source.periodStart || ""),
      periodEnd: String(source.periodEnd || ""),
      currency: String(source.currency || "CNY"),
      offerName: String(source.offerName || "").trim(),
      deliveryModel,
      unitLabel: String(source.unitLabel || DEFAULT_UNIT_LABELS[deliveryModel]).trim() || DEFAULT_UNIT_LABELS[deliveryModel],
      quick
    };
  }

  const QUICK_V3_NUMERIC_FIELDS = Object.freeze(QUICK_NUMERIC_FIELDS
    .filter((field) => field !== "fixedCostExOwner" && field !== "ownerWage")
    .concat(["monthlyFixedCostExOwner", "monthlyOwnerWage"]));

  function cleanQuickV3State(input) {
    const source = input && typeof input === "object" ? input : {};
    const quickSource = source.quick && typeof source.quick === "object" ? source.quick : {};
    const deliveryModel = DELIVERY_MODELS.includes(source.deliveryModel) ? source.deliveryModel : "instant";
    const quick = {};
    QUICK_V3_NUMERIC_FIELDS.forEach((field) => {
      quick[field] = asNumber(firstOwn(quickSource, [field]));
    });
    const monthlyFixed = firstValue([quickSource, source], [
      "monthlyFixedCostExOwner",
      "monthly_fixed_cost_ex_owner"
    ]);
    const monthlyWage = firstValue([quickSource, source], [
      "monthlyOwnerWage",
      "monthly_owner_wage"
    ]);
    quick.monthlyFixedCostExOwner = monthlyFixed.found ? asNumber(monthlyFixed.value) : null;
    quick.monthlyOwnerWage = monthlyWage.found ? asNumber(monthlyWage.value) : null;
    return {
      inputMode: "quick_v3",
      schemaVersion: QUICK_V3_SCHEMA_VERSION,
      mode: MODES.includes(source.mode) ? source.mode : "actual",
      periodStart: String(source.periodStart || source.period_start || ""),
      periodEnd: String(source.periodEnd || source.period_end || ""),
      periodEndInclusive: true,
      currency: String(source.currency || "CNY"),
      offerName: String(source.offerName || "").trim(),
      deliveryModel,
      unitLabel: String(source.unitLabel || DEFAULT_UNIT_LABELS[deliveryModel]).trim() || DEFAULT_UNIT_LABELS[deliveryModel],
      quick
    };
  }

  function cleanQuickState(input) {
    return input && input.inputMode === "quick_v3" ? cleanQuickV3State(input) : cleanQuickV2State(input);
  }

  function quickFieldError(state, field) {
    const value = state.quick[field];
    if (value === null) return null;
    if (field === "availableCash" || field === "cashAfterStartup") return null;
    if (value < 0) return (QUICK_FIELD_LABELS[field] || field) + "不能为负数。";
    return null;
  }

  function explicitFalse(value) {
    return value === false
      || value === 0
      || (typeof value === "string" && ["0", "false"].includes(value.trim().toLowerCase()));
  }

  function quickV3SchemaErrors(input, state, periodProfile) {
    const source = input && typeof input === "object" ? input : {};
    const quickSource = source.quick && typeof source.quick === "object" ? source.quick : {};
    const errors = [];
    const add = (message) => {
      if (!errors.includes(message)) errors.push(message);
    };

    if (hasOwn(source, "periodEndInclusive") && explicitFalse(source.periodEndInclusive)) {
      add("quick_v3 的核算结束日期必须包含当天，periodEndInclusive 不能为 false。");
    }
    if (hasOwn(source, "period_end_inclusive") && explicitFalse(source.period_end_inclusive)) {
      add("quick_v3 的核算结束日期必须包含当天，period_end_inclusive 不能为 false。");
    }
    [quickSource, source].forEach((candidate) => {
      if (hasOwn(candidate, "fixedCostExOwner") || hasOwn(candidate, "fixed_cost_ex_owner")) {
        add("quick_v3 不接受旧字段 fixedCostExOwner；请明确填写 monthlyFixedCostExOwner。");
      }
      if (hasOwn(candidate, "ownerWage") || hasOwn(candidate, "owner_wage")) {
        add("quick_v3 不接受旧字段 ownerWage；请明确填写 monthlyOwnerWage。");
      }
    });
    QUICK_V3_NUMERIC_FIELDS.forEach((field) => {
      const keys = field === "monthlyFixedCostExOwner"
        ? [field, "monthly_fixed_cost_ex_owner"]
        : (field === "monthlyOwnerWage" ? [field, "monthly_owner_wage"] : [field]);
      const raw = firstValue([quickSource, source], keys);
      if (raw.found && !isBlank(raw.value) && asNumber(raw.value) === null) {
        add((QUICK_FIELD_LABELS[field] || field) + "必须是有效数字；未知时请留空。");
      }
    });
    QUICK_V3_NUMERIC_FIELDS.forEach((field) => {
      const error = quickFieldError(state, field);
      if (error) add(error);
    });
    if (state.mode === "actual" && state.quick.completedUnits !== null && state.quick.completedUnits <= 0) {
      add("已填写完成交付数量时必须大于 0；未知时请留空。");
    }
    if (state.mode === "forecast") {
      if (state.quick.unitPrice !== null && state.quick.unitPrice <= 0) add("单位售价必须大于 0；未知时请留空。");
      if (state.quick.capacityUnits !== null && state.quick.capacityUnits <= 0) add("每月最大稳定交付能力必须大于 0；未知时请留空。");
    }
    periodProfile.errors.forEach(add);
    if (state.mode === "forecast" && periodProfile.valid && !periodProfile.isFullCalendarMonth) {
      add("创业预估是月度模型，quick_v3 forecast 只能选择一个完整自然月。");
    }
    return errors;
  }

  function quickReadiness(state, fields) {
    const missingFields = fields.filter((field) => state.quick[field] === null);
    const errors = fields.map((field) => quickFieldError(state, field)).filter(Boolean);
    return {
      status: errors.length ? "invalid" : (missingFields.length ? "missing" : "ready"),
      missingFields,
      errors
    };
  }

  function invalidReadiness(message) {
    return { status: "invalid", missingFields: [], errors: [message] };
  }

  function copyReadiness(readiness) {
    return {
      status: readiness.status,
      missingFields: readiness.missingFields.slice(),
      errors: readiness.errors.slice()
    };
  }

  function quickMissingRows(fields) {
    return fields.map((field) => ({ scope: "quick", field, label: QUICK_FIELD_LABELS[field] || field }));
  }

  function roundedQuantity(value) {
    return Number(Number(value).toFixed(2));
  }

  function quickScenario(name, units, unitContributionCents, fixedNeedCents, unitPriceCents, capacityUnits) {
    const profitCents = multiplyMoneyByQuantity(unitContributionCents, units) - fixedNeedCents;
    const revenueCents = multiplyMoneyByQuantity(unitPriceCents, units);
    return {
      scenario: name,
      units,
      sustainableProfit: money(profitCents),
      revenue: money(revenueCents),
      capacityFeasible: units <= capacityUnits
    };
  }

  function calculateQuickActual(state) {
    const q = state.quick;
    const metricReadiness = {
      profit: quickReadiness(state, ["recognizedRevenue", "directCost", "fixedCostExOwner", "ownerWage"]),
      cash: quickReadiness(state, ["cashIn", "cashOut"]),
      safety: null,
      breakEvenRevenue: null,
      unitEconomics: null,
      breakEvenUnits: null,
      diagnosis: null
    };

    const safetyFields = ["availableCash", "remainingFulfillmentCost"];
    if (q.next30RigidOutflow === null) safetyFields.push("fixedCostExOwner", "ownerWage");
    metricReadiness.safety = quickReadiness(state, safetyFields);
    metricReadiness.breakEvenRevenue = copyReadiness(metricReadiness.profit);
    metricReadiness.unitEconomics = quickReadiness(state, ["recognizedRevenue", "directCost", "completedUnits"]);
    metricReadiness.breakEvenUnits = quickReadiness(state, ["recognizedRevenue", "directCost", "fixedCostExOwner", "ownerWage", "completedUnits"]);

    const warnings = [];
    let sustainableProfit = null;
    let contribution = null;
    let contributionRate = null;
    let cashNetChange = null;
    let safetyValue = null;
    let safetyStatus = null;
    let breakEvenRevenue = null;
    let breakEvenUnits = null;
    let breakEvenLabel = "还缺少保本测算所需数据";
    let unitContribution = null;
    let unitPrice = null;
    let unitDirectCost = null;
    let status = { code: "insufficient_data", text: "还需要补充利润和现金数据" };

    if (metricReadiness.profit.status === "ready") {
      const revenueCents = cents(q.recognizedRevenue);
      const directCents = cents(q.directCost);
      const fixedCents = cents(q.fixedCostExOwner);
      const wageCents = cents(q.ownerWage);
      const contributionCents = revenueCents - directCents;
      const profitCents = contributionCents - fixedCents - wageCents;
      sustainableProfit = money(profitCents);
      contribution = money(contributionCents);
      contributionRate = revenueCents > 0 ? Number(((contributionCents / revenueCents) * 100).toFixed(2)) : null;
      if (revenueCents <= 0) {
        metricReadiness.breakEvenRevenue = invalidReadiness("确认收入必须大于 0，才能反推保本营业额。");
      } else if (contributionCents <= 0) {
        metricReadiness.breakEvenRevenue = invalidReadiness("贡献毛利不为正，无法生成保本营业额。");
        warnings.push("贡献毛利不为正，每增加一份交付都不会帮助覆盖固定成本。");
      } else {
        const fixedNeedCents = fixedCents + wageCents;
        const breakEvenRevenueCents = Math.ceil((fixedNeedCents * revenueCents) / contributionCents);
        breakEvenRevenue = money(breakEvenRevenueCents);
        breakEvenLabel = "每月需要完成约 ¥" + breakEvenRevenue.toFixed(2) + " 的交付额才能保本";
      }
    }

    if (metricReadiness.cash.status === "ready") {
      cashNetChange = money(cents(q.cashIn) - cents(q.cashOut));
    }

    let safetyNext30RigidOutflow = null;
    let safetyAssumption = null;
    if (metricReadiness.safety.status === "ready") {
      if (q.next30RigidOutflow === null) {
        safetyNext30RigidOutflow = money(cents(q.fixedCostExOwner) + cents(q.ownerWage));
        safetyAssumption = "fixed_plus_owner_wage";
      } else {
        safetyNext30RigidOutflow = money(cents(q.next30RigidOutflow));
        safetyAssumption = "provided_next30_rigid_outflow";
      }
      const safetyCents = cents(q.availableCash) - cents(q.remainingFulfillmentCost) - cents(safetyNext30RigidOutflow);
      safetyValue = money(safetyCents);
      if (safetyCents < 0) safetyStatus = { code: "high_risk", text: "现有现金不足以覆盖未交付承诺与未来30天刚性支出" };
      else if (safetyCents < cents(safetyNext30RigidOutflow)) safetyStatus = { code: "warning", text: "交付后剩余安全垫不足一个月" };
      else safetyStatus = { code: "safe", text: "当前交付安全垫充足" };
    }

    if (metricReadiness.unitEconomics.status === "ready") {
      if (q.completedUnits <= 0) {
        metricReadiness.unitEconomics = invalidReadiness("完成交付数量必须大于 0，才能计算单位贡献。");
        metricReadiness.breakEvenUnits = invalidReadiness("完成交付数量必须大于 0，才能计算保本数量。");
      } else {
        const revenueCents = cents(q.recognizedRevenue);
        const directCents = cents(q.directCost);
        const unitPriceCents = Math.round(revenueCents / q.completedUnits);
        const unitDirectCostCents = Math.round(directCents / q.completedUnits);
        const unitContributionCents = unitPriceCents - unitDirectCostCents;
        unitPrice = money(unitPriceCents);
        unitDirectCost = money(unitDirectCostCents);
        unitContribution = money(unitContributionCents);
        if (unitContributionCents <= 0) {
          metricReadiness.breakEvenUnits = invalidReadiness("单位贡献不为正，无法生成保本数量。");
          breakEvenLabel = "单位贡献不为正，做得越多亏得越多";
        } else if (metricReadiness.breakEvenUnits.status === "ready") {
          const fixedNeedCents = cents(q.fixedCostExOwner) + cents(q.ownerWage);
          breakEvenUnits = Math.ceil(fixedNeedCents / unitContributionCents);
          breakEvenLabel = "每月需要完成 " + breakEvenUnits + " " + state.unitLabel + "才能保本";
        }
      }
    }

    if (metricReadiness.profit.status === "ready" && metricReadiness.cash.status === "ready") {
      metricReadiness.diagnosis = { status: "ready", missingFields: [], errors: [] };
      status = statusFrom(cents(sustainableProfit), cents(cashNetChange));
    } else {
      const missing = [];
      if (metricReadiness.profit.status !== "ready") missing.push.apply(missing, metricReadiness.profit.missingFields);
      if (metricReadiness.cash.status !== "ready") missing.push.apply(missing, metricReadiness.cash.missingFields);
      metricReadiness.diagnosis = {
        status: metricReadiness.profit.status === "invalid" || metricReadiness.cash.status === "invalid" ? "invalid" : "missing",
        missingFields: Array.from(new Set(missing)),
        errors: metricReadiness.profit.errors.concat(metricReadiness.cash.errors)
      };
    }

    const preview = {
      mode: "actual",
      status,
      sustainableProfit,
      cashNetChange,
      safetyValue,
      safetyLabel: "交付安全余额",
      safetyStatus,
      safetyAssumption,
      safetyNext30RigidOutflow,
      totalRecognizedRevenue: q.recognizedRevenue,
      totalCashReceived: q.cashIn,
      contribution,
      contributionRate,
      breakEvenRevenue,
      breakEvenUnits,
      breakEvenLabel,
      unitPrice,
      unitDirectCost,
      unitContribution,
      completedUnits: q.completedUnits,
      warnings,
      readiness: metricReadiness
    };

    const coreReadiness = quickReadiness(state, QUICK_ACTUAL_CORE_FIELDS);
    const savable = [metricReadiness.profit, metricReadiness.cash, metricReadiness.safety].some((item) => item.status === "ready");
    return { preview, metricReadiness, coreReadiness, savable };
  }

  function calculateQuickV3Actual(state, periodProfile) {
    const q = state.quick;
    const periodReadiness = periodProfile.valid
      ? { status: "ready", missingFields: [], errors: [] }
      : { status: "invalid", missingFields: [], errors: periodProfile.errors.slice() };
    const profitInputs = quickReadiness(state, ["recognizedRevenue", "directCost", "monthlyFixedCostExOwner", "monthlyOwnerWage"]);
    const metricReadiness = {
      period: periodReadiness,
      profit: periodProfile.valid
        ? profitInputs
        : {
          status: "invalid",
          missingFields: profitInputs.missingFields.slice(),
          errors: profitInputs.errors.concat(periodProfile.errors)
        },
      cash: quickReadiness(state, ["cashIn", "cashOut"]),
      safety: null,
      breakEvenRevenue: quickReadiness(state, ["recognizedRevenue", "directCost", "monthlyFixedCostExOwner", "monthlyOwnerWage"]),
      unitEconomics: null,
      breakEvenUnits: null,
      diagnosis: null
    };

    const safetyFields = ["availableCash", "remainingFulfillmentCost"];
    if (q.next30RigidOutflow === null) safetyFields.push("monthlyFixedCostExOwner", "monthlyOwnerWage");
    metricReadiness.safety = quickReadiness(state, safetyFields);
    metricReadiness.unitEconomics = quickReadiness(state, ["recognizedRevenue", "directCost", "completedUnits"]);
    metricReadiness.breakEvenUnits = quickReadiness(state, ["recognizedRevenue", "directCost", "monthlyFixedCostExOwner", "monthlyOwnerWage", "completedUnits"]);

    const warnings = periodProfile.warnings.slice();
    const monthlyFixedCents = q.monthlyFixedCostExOwner === null ? null : cents(q.monthlyFixedCostExOwner);
    const monthlyWageCents = q.monthlyOwnerWage === null ? null : cents(q.monthlyOwnerWage);
    const periodFixedCents = prorateMonthlyCents(monthlyFixedCents, periodProfile);
    const periodWageCents = prorateMonthlyCents(monthlyWageCents, periodProfile);
    let sustainableProfit = null;
    let contribution = null;
    let contributionRate = null;
    let cashNetChange = null;
    let safetyValue = null;
    let safetyStatus = null;
    let monthlyBreakEvenRevenue = null;
    let breakEvenUnits = null;
    let breakEvenLabel = "还缺少保本测算所需数据";
    let unitContribution = null;
    let unitPrice = null;
    let unitDirectCost = null;
    let status = { code: "insufficient_data", text: "还需要补充利润和现金数据" };

    if (metricReadiness.profit.status === "ready") {
      const revenueCents = cents(q.recognizedRevenue);
      const directCents = cents(q.directCost);
      const contributionCents = revenueCents - directCents;
      const profitCents = contributionCents - periodFixedCents - periodWageCents;
      sustainableProfit = money(profitCents);
      contribution = money(contributionCents);
      contributionRate = revenueCents > 0 ? Number(((contributionCents / revenueCents) * 100).toFixed(2)) : null;
      if (revenueCents <= 0) {
        metricReadiness.breakEvenRevenue = invalidReadiness("确认收入必须大于 0，才能反推月保本营业额。");
      } else if (contributionCents <= 0) {
        metricReadiness.breakEvenRevenue = invalidReadiness("贡献毛利不为正，无法生成月保本营业额。");
        warnings.push("贡献毛利不为正，每增加一份交付都不会帮助覆盖固定成本。");
      } else {
        const monthlyFixedNeedCents = monthlyFixedCents + monthlyWageCents;
        monthlyBreakEvenRevenue = money(Math.ceil((monthlyFixedNeedCents * revenueCents) / contributionCents));
        breakEvenLabel = "每月需要完成约 ¥" + monthlyBreakEvenRevenue.toFixed(2) + " 的交付额才能保本";
      }
    }

    if (metricReadiness.cash.status === "ready") cashNetChange = money(cents(q.cashIn) - cents(q.cashOut));

    let safetyNext30RigidOutflow = null;
    let safetyAssumption = null;
    if (metricReadiness.safety.status === "ready") {
      if (q.next30RigidOutflow === null) {
        safetyNext30RigidOutflow = money(monthlyFixedCents + monthlyWageCents);
        safetyAssumption = "monthly_fixed_plus_owner_wage";
      } else {
        safetyNext30RigidOutflow = money(cents(q.next30RigidOutflow));
        safetyAssumption = "provided_next30_rigid_outflow";
      }
      const safetyCents = cents(q.availableCash) - cents(q.remainingFulfillmentCost) - cents(safetyNext30RigidOutflow);
      safetyValue = money(safetyCents);
      if (safetyCents < 0) safetyStatus = { code: "high_risk", text: "现有现金不足以覆盖未交付承诺与未来30天刚性支出" };
      else if (safetyCents < cents(safetyNext30RigidOutflow)) safetyStatus = { code: "warning", text: "履约后剩余现金不足再覆盖一个月刚性支出" };
      else safetyStatus = { code: "safe", text: "未来30天经营安全余额充足" };
    }

    if (metricReadiness.unitEconomics.status === "ready") {
      if (q.completedUnits <= 0) {
        metricReadiness.unitEconomics = invalidReadiness("完成交付数量必须大于 0，才能计算单位贡献。");
        metricReadiness.breakEvenUnits = invalidReadiness("完成交付数量必须大于 0，才能计算月保本数量。");
      } else {
        const revenueCents = cents(q.recognizedRevenue);
        const directCents = cents(q.directCost);
        const unitPriceCents = Math.round(revenueCents / q.completedUnits);
        const unitDirectCostCents = Math.round(directCents / q.completedUnits);
        const unitContributionCents = unitPriceCents - unitDirectCostCents;
        unitPrice = money(unitPriceCents);
        unitDirectCost = money(unitDirectCostCents);
        unitContribution = money(unitContributionCents);
        if (unitContributionCents <= 0) {
          metricReadiness.breakEvenUnits = invalidReadiness("单位贡献不为正，无法生成月保本数量。");
          breakEvenLabel = "单位贡献不为正，做得越多亏得越多";
        } else if (metricReadiness.breakEvenUnits.status === "ready") {
          const monthlyFixedNeedCents = monthlyFixedCents + monthlyWageCents;
          breakEvenUnits = Math.ceil(monthlyFixedNeedCents / unitContributionCents);
          breakEvenLabel = "每月需要完成 " + breakEvenUnits + " " + state.unitLabel + "才能保本";
        }
      }
    }

    if (metricReadiness.profit.status === "ready" && metricReadiness.cash.status === "ready") {
      metricReadiness.diagnosis = { status: "ready", missingFields: [], errors: [] };
      status = statusFrom(cents(sustainableProfit), cents(cashNetChange));
    } else {
      const missing = [];
      if (metricReadiness.profit.status !== "ready") missing.push.apply(missing, metricReadiness.profit.missingFields);
      if (metricReadiness.cash.status !== "ready") missing.push.apply(missing, metricReadiness.cash.missingFields);
      metricReadiness.diagnosis = {
        status: metricReadiness.profit.status === "invalid" || metricReadiness.cash.status === "invalid" ? "invalid" : "missing",
        missingFields: Array.from(new Set(missing)),
        errors: metricReadiness.profit.errors.concat(metricReadiness.cash.errors)
      };
    }

    const preview = {
      mode: "actual",
      status,
      periodMonthFactor: periodProfile.monthFactor,
      totalDays: periodProfile.totalDays,
      monthlyFixedCostExOwner: q.monthlyFixedCostExOwner,
      monthlyOwnerWage: q.monthlyOwnerWage,
      periodFixedCostExOwner: money(periodFixedCents),
      periodOwnerWage: money(periodWageCents),
      sustainableProfit,
      cashNetChange,
      safetyValue,
      safetyLabel: "未来30天经营安全余额",
      safetyStatus,
      safetyAssumption,
      safetyNext30RigidOutflow,
      totalRecognizedRevenue: q.recognizedRevenue,
      totalCashReceived: q.cashIn,
      contribution,
      contributionRate,
      monthlyBreakEvenRevenue,
      breakEvenRevenue: monthlyBreakEvenRevenue,
      breakEvenUnits,
      breakEvenLabel,
      unitPrice,
      unitDirectCost,
      unitContribution,
      completedUnits: q.completedUnits,
      warnings,
      readiness: metricReadiness
    };

    const coreInputs = quickReadiness(state, [
      "recognizedRevenue",
      "cashIn",
      "cashOut",
      "directCost",
      "monthlyFixedCostExOwner",
      "monthlyOwnerWage",
      "availableCash",
      "remainingFulfillmentCost"
    ]);
    const coreReadiness = periodProfile.valid
      ? coreInputs
      : { status: "invalid", missingFields: coreInputs.missingFields.slice(), errors: coreInputs.errors.concat(periodProfile.errors) };
    const savable = periodProfile.valid
      && [metricReadiness.profit, metricReadiness.cash, metricReadiness.safety].some((item) => item.status === "ready");
    return { preview, metricReadiness, coreReadiness, savable };
  }

  function quickForecastStatus(unitContributionCents, capacityRate) {
    if (unitContributionCents <= 0) return { code: "forecast_non_positive_contribution", text: "定价倒挂，卖得越多亏得越多，先不要扩大" };
    if (capacityRate === null) return { code: "forecast_needs_capacity", text: "单位模型可计算，还需要产能数据判断可行性" };
    if (capacityRate <= 60) return { code: "forecast_healthy", text: "达到六成以内产能即可保本，模型相对扎实" };
    if (capacityRate <= 80) return { code: "forecast_achievable", text: "需要持续获客，但保本目标仍可达到" };
    if (capacityRate <= 100) return { code: "forecast_high_pressure", text: "接近满负荷才能保本，经营压力较大" };
    return { code: "forecast_not_feasible", text: "保本量超过最大交付能力，当前模型不成立" };
  }

  function calculateQuickForecast(state) {
    const q = state.quick;
    const metricReadiness = {
      unitEconomics: quickReadiness(state, ["unitPrice", "unitDirectCost"]),
      breakEven: quickReadiness(state, ["unitPrice", "unitDirectCost", "fixedCostExOwner", "ownerWage"]),
      baseProfit: quickReadiness(state, ["unitPrice", "unitDirectCost", "fixedCostExOwner", "ownerWage", "baseUnits"]),
      capacityFeasibility: quickReadiness(state, ["unitPrice", "unitDirectCost", "fixedCostExOwner", "ownerWage", "capacityUnits"]),
      scenarios: quickReadiness(state, ["unitPrice", "unitDirectCost", "fixedCostExOwner", "ownerWage", "baseUnits", "capacityUnits"]),
      cashBuffer: quickReadiness(state, ["fixedCostExOwner", "ownerWage", "cashAfterStartup"]),
      payback: quickReadiness(state, ["unitPrice", "unitDirectCost", "fixedCostExOwner", "ownerWage", "baseUnits", "startupInvestment"])
    };

    const warnings = [];
    let unitContribution = null;
    let contributionRate = null;
    let sustainableProfit = null;
    let breakEvenUnits = null;
    let breakEvenRevenue = null;
    let capacityRate = null;
    let status = { code: "forecast_incomplete", text: "还需要补充定价、成本与产能数据" };
    let scenarios = [];
    let startupRunwayMonths = null;
    let paybackMonths = null;
    let baseRevenue = null;

    let unitPriceCents = null;
    let unitDirectCostCents = null;
    let unitContributionCents = null;
    let fixedNeedCents = null;

    if (metricReadiness.unitEconomics.status === "ready") {
      unitPriceCents = cents(q.unitPrice);
      unitDirectCostCents = cents(q.unitDirectCost);
      unitContributionCents = unitPriceCents - unitDirectCostCents;
      unitContribution = money(unitContributionCents);
      contributionRate = unitPriceCents > 0 ? Number(((unitContributionCents / unitPriceCents) * 100).toFixed(2)) : null;
      if (unitPriceCents <= 0) warnings.push("单位售价必须大于 0，才能判断经营模型。");
      if (unitContributionCents <= 0) warnings.push("单位贡献不为正，扩大销量会扩大亏损。");
    }

    if (q.fixedCostExOwner !== null && q.ownerWage !== null && !quickFieldError(state, "fixedCostExOwner") && !quickFieldError(state, "ownerWage")) {
      fixedNeedCents = cents(q.fixedCostExOwner) + cents(q.ownerWage);
    }

    if (metricReadiness.breakEven.status === "ready") {
      if (unitPriceCents <= 0 || unitContributionCents <= 0) {
        metricReadiness.breakEven = invalidReadiness("单位贡献不为正，无法生成保本量。");
      } else {
        breakEvenUnits = Math.ceil(fixedNeedCents / unitContributionCents);
        breakEvenRevenue = money(Math.ceil((fixedNeedCents * unitPriceCents) / unitContributionCents));
      }
    }

    if (metricReadiness.baseProfit.status === "ready") {
      sustainableProfit = money(multiplyMoneyByQuantity(unitContributionCents, q.baseUnits) - fixedNeedCents);
      baseRevenue = money(multiplyMoneyByQuantity(unitPriceCents, q.baseUnits));
    }

    if (metricReadiness.capacityFeasibility.status === "ready") {
      if (q.capacityUnits <= 0) {
        metricReadiness.capacityFeasibility = invalidReadiness("最大稳定交付能力必须大于 0。");
      } else if (unitContributionCents <= 0) {
        metricReadiness.capacityFeasibility = invalidReadiness("单位贡献不为正，无法判断保本产能占用率。");
      } else {
        capacityRate = Number(((breakEvenUnits / q.capacityUnits) * 100).toFixed(2));
      }
    }

    if (metricReadiness.scenarios.status === "ready") {
      if (q.capacityUnits <= 0) {
        metricReadiness.scenarios = invalidReadiness("最大稳定交付能力必须大于 0。");
      } else {
        const lowUnits = roundedQuantity(q.baseUnits * 0.7);
        const baseUnits = roundedQuantity(q.baseUnits);
        const highUnits = roundedQuantity(Math.min(q.baseUnits * 1.3, q.capacityUnits));
        scenarios = [
          quickScenario("low", lowUnits, unitContributionCents, fixedNeedCents, unitPriceCents, q.capacityUnits),
          quickScenario("base", baseUnits, unitContributionCents, fixedNeedCents, unitPriceCents, q.capacityUnits),
          quickScenario("high", highUnits, unitContributionCents, fixedNeedCents, unitPriceCents, q.capacityUnits)
        ];
      }
    }

    if (metricReadiness.cashBuffer.status === "ready") {
      if (fixedNeedCents > 0) startupRunwayMonths = Number((cents(q.cashAfterStartup) / fixedNeedCents).toFixed(2));
      else metricReadiness.cashBuffer = invalidReadiness("月固定成本为 0 时不生成启动安全月数。");
    }

    if (metricReadiness.payback.status === "ready") {
      if (sustainableProfit > 0) paybackMonths = Number((cents(q.startupInvestment) / cents(sustainableProfit)).toFixed(2));
      else metricReadiness.payback = invalidReadiness("基准利润不为正时不生成投资回收期。");
    }

    status = quickForecastStatus(unitContributionCents === null ? 0 : unitContributionCents, capacityRate);
    if (metricReadiness.unitEconomics.status !== "ready") status = { code: "forecast_incomplete", text: "还需要补充单位售价和单位直接成本" };

    const preview = {
      mode: "forecast",
      status,
      sustainableProfit,
      cashNetChange: null,
      safetyValue: q.cashAfterStartup,
      safetyLabel: q.cashAfterStartup === null ? "启动现金未填写" : "启动投入后剩余经营现金",
      totalRecognizedRevenue: baseRevenue,
      totalCashReceived: null,
      contributionRate,
      breakEvenRevenue,
      breakEvenUnits,
      breakEvenLabel: breakEvenUnits === null
        ? (unitContribution !== null && unitContribution <= 0 ? "单位贡献不为正，卖得越多亏得越多" : "还缺少保本测算所需数据")
        : "每月需要完成 " + breakEvenUnits + " " + state.unitLabel + "才能保本",
      unitContribution,
      capacityRate,
      baseUnits: q.baseUnits,
      capacityUnits: q.capacityUnits,
      scenarios,
      cashAfterStartup: q.cashAfterStartup,
      startupInvestment: q.startupInvestment,
      startupRunwayMonths,
      paybackMonths,
      warnings,
      readiness: metricReadiness
    };

    const coreReadiness = quickReadiness(state, QUICK_FORECAST_CORE_FIELDS);
    const savable = [metricReadiness.unitEconomics, metricReadiness.breakEven, metricReadiness.baseProfit, metricReadiness.capacityFeasibility]
      .some((item) => item.status === "ready");
    return { preview, metricReadiness, coreReadiness, savable };
  }

  function calculateQuick(input) {
    const state = cleanQuickState(input);
    const calculated = state.mode === "actual" ? calculateQuickActual(state) : calculateQuickForecast(state);
    const allErrors = [];
    Object.values(calculated.metricReadiness).forEach((readiness) => {
      readiness.errors.forEach((error) => {
        if (!allErrors.includes(error)) allErrors.push(error);
      });
    });
    const inputHash = hashInput(state);
    const dataStatus = calculated.coreReadiness.status === "ready"
      ? "ready"
      : (calculated.savable ? "partial" : "incomplete");
    return {
      calculationVersion: VERSION,
      inputMode: "quick_v2",
      hashAlgorithm: HASH_ALGORITHM,
      inputHash,
      dataStatus,
      savable: calculated.savable,
      mode: state.mode,
      state,
      missing: quickMissingRows(calculated.coreReadiness.missingFields),
      errors: allErrors,
      warnings: calculated.preview.warnings || [],
      metricReadiness: calculated.metricReadiness,
      preview: calculated.preview,
      result: calculated.savable ? calculated.preview : null
    };
  }

  function mapV3ReadinessFields(metricReadiness) {
    const mapField = (field) => field === "fixedCostExOwner"
      ? "monthlyFixedCostExOwner"
      : (field === "ownerWage" ? "monthlyOwnerWage" : field);
    const mapped = {};
    Object.keys(metricReadiness).forEach((key) => {
      const row = metricReadiness[key];
      mapped[key] = {
        status: row.status,
        missingFields: row.missingFields.map(mapField),
        errors: row.errors.slice()
      };
    });
    return mapped;
  }

  function calculateQuickV3Forecast(state, periodProfile) {
    const legacyState = clone(state);
    legacyState.inputMode = "quick_v2";
    delete legacyState.schemaVersion;
    delete legacyState.periodEndInclusive;
    legacyState.quick.fixedCostExOwner = state.quick.monthlyFixedCostExOwner;
    legacyState.quick.ownerWage = state.quick.monthlyOwnerWage;
    delete legacyState.quick.monthlyFixedCostExOwner;
    delete legacyState.quick.monthlyOwnerWage;
    const calculated = calculateQuickForecast(legacyState);
    const metricReadiness = mapV3ReadinessFields(calculated.metricReadiness);
    metricReadiness.period = periodProfile.valid
      ? { status: "ready", missingFields: [], errors: [] }
      : { status: "invalid", missingFields: [], errors: periodProfile.errors.slice() };
    const mappedCoreReadiness = {
      status: calculated.coreReadiness.status,
      missingFields: calculated.coreReadiness.missingFields.map((field) => field === "fixedCostExOwner"
        ? "monthlyFixedCostExOwner"
        : (field === "ownerWage" ? "monthlyOwnerWage" : field)),
      errors: calculated.coreReadiness.errors.slice()
    };
    const coreReadiness = periodProfile.valid
      ? mappedCoreReadiness
      : {
        status: "invalid",
        missingFields: mappedCoreReadiness.missingFields.slice(),
        errors: mappedCoreReadiness.errors.concat(periodProfile.errors)
      };
    const preview = Object.assign({}, calculated.preview, {
      periodMonthFactor: 1,
      totalDays: periodProfile.valid ? periodProfile.totalDays : null,
      monthlyFixedCostExOwner: state.quick.monthlyFixedCostExOwner,
      monthlyOwnerWage: state.quick.monthlyOwnerWage,
      periodFixedCostExOwner: state.quick.monthlyFixedCostExOwner,
      periodOwnerWage: state.quick.monthlyOwnerWage,
      monthlyBreakEvenRevenue: calculated.preview.breakEvenRevenue,
      warnings: calculated.preview.warnings.concat(periodProfile.warnings),
      readiness: metricReadiness
    });
    return { preview, metricReadiness, coreReadiness, savable: calculated.savable && periodProfile.valid };
  }

  function calculateQuickV3(input) {
    const state = cleanQuickV3State(input);
    const periodProfile = getPeriodProfile(state);
    const schemaErrors = quickV3SchemaErrors(input, state, periodProfile);
    const calculated = state.mode === "actual"
      ? calculateQuickV3Actual(state, periodProfile)
      : calculateQuickV3Forecast(state, periodProfile);
    calculated.metricReadiness.schema = schemaErrors.length
      ? { status: "invalid", missingFields: [], errors: schemaErrors.slice() }
      : { status: "ready", missingFields: [], errors: [] };
    calculated.preview.readiness = calculated.metricReadiness;
    const allErrors = schemaErrors.slice();
    Object.values(calculated.metricReadiness).forEach((readinessRow) => {
      readinessRow.errors.forEach((error) => {
        if (!allErrors.includes(error)) allErrors.push(error);
      });
    });
    const inputHash = hashInput(state);
    const savable = calculated.savable && schemaErrors.length === 0;
    let dataStatus = calculated.coreReadiness.status === "ready"
      ? "ready"
      : (savable ? "partial" : "incomplete");
    if (schemaErrors.length) dataStatus = "invalid";
    return {
      calculationVersion: VERSION,
      schemaVersion: QUICK_V3_SCHEMA_VERSION,
      inputMode: "quick_v3",
      hashAlgorithm: HASH_ALGORITHM,
      inputHash,
      dataStatus,
      savable,
      mode: state.mode,
      periodProfile,
      state,
      missing: quickMissingRows(calculated.coreReadiness.missingFields),
      errors: allErrors,
      warnings: calculated.preview.warnings || [],
      metricReadiness: calculated.metricReadiness,
      preview: calculated.preview,
      result: savable ? calculated.preview : null
    };
  }

  function cleanBusinessTargetState(input) {
    const rootSource = input && typeof input === "object" ? input : {};
    const nestedInput = rootSource.deterministicInput || rootSource.deterministic_input || rootSource.input;
    const source = nestedInput && typeof nestedInput === "object" ? nestedInput : rootSource;
    const sourceCalculation = source.sourceCalculation || source.source_calculation || rootSource.sourceCalculation || {};
    const calculationState = sourceCalculation.state && typeof sourceCalculation.state === "object" ? sourceCalculation.state : {};
    const quick = calculationState.quick && typeof calculationState.quick === "object"
      ? calculationState.quick
      : (source.quick && typeof source.quick === "object" ? source.quick : {});
    const preview = sourceCalculation.preview || sourceCalculation.result || source.calculationResult || source.calculation_result || {};
    const goal = source.goal && typeof source.goal === "object" ? source.goal : {};
    const sources = [source, goal, quick, preview, sourceCalculation];
    const sourceCalculationInputMode = firstText(
      [sourceCalculation, calculationState, source],
      ["inputMode", "input_mode", "sourceCalculationInputMode", "source_calculation_input_mode"],
      ""
    );
    const v3CalculationSources = [quick, preview, calculationState, sourceCalculation];
    const cashIncrease = firstValue(sources, ["targetCashIncrease", "target_cash_increase"]);
    return {
      targetPlanId: firstText([source, rootSource], ["targetPlanId", "target_plan_id"], ""),
      calculationId: firstText(sources, ["calculationId", "calculation_id"], ""),
      sourceInputHash: firstText(sources, ["sourceInputHash", "source_input_hash", "inputHash", "input_hash"], ""),
      targetMonth: firstText(sources, ["targetMonth", "target_month"], ""),
      targetProfit: firstNumber(sources, ["targetProfit", "target_profit"]),
      targetCashIncrease: cashIncrease.found && !isBlank(cashIncrease.value) ? asNumber(cashIncrease.value) : 0,
      fixedOperatingCost: sourceCalculationInputMode === "quick_v3"
        ? (firstNumber(v3CalculationSources, ["monthlyFixedCostExOwner", "monthly_fixed_cost_ex_owner"])
          ?? firstNumber(sources, ["fixedOperatingCost", "fixed_operating_cost", "fixedCostExOwner", "fixed_cost_ex_owner", "sharedFixedCost", "shared_fixed_cost"]))
        : firstNumber(sources, ["fixedOperatingCost", "fixed_operating_cost", "fixedCostExOwner", "fixed_cost_ex_owner", "sharedFixedCost", "shared_fixed_cost"]),
      ownerWage: sourceCalculationInputMode === "quick_v3"
        ? (firstNumber(v3CalculationSources, ["monthlyOwnerWage", "monthly_owner_wage"])
          ?? firstNumber(sources, ["ownerWage", "owner_wage"]))
        : firstNumber(sources, ["ownerWage", "owner_wage"]),
      contributionMarginRate: firstNumber(sources, ["contributionMarginRate", "contribution_margin_rate", "contributionRate", "contribution_rate"]),
      unitRecognizedRevenue: firstNumber(sources, ["unitRecognizedRevenue", "unit_recognized_revenue", "deliveryUnitRevenue", "delivery_unit_revenue", "unitPrice", "unit_price"]),
      unitDirectCost: firstNumber(sources, ["unitDirectCost", "unit_direct_cost", "unitVariableCost", "unit_variable_cost"]),
      maxStableDeliveryUnits: firstNumber(sources, ["maxStableDeliveryUnits", "max_stable_delivery_units", "capacityUnits", "capacity_units"]),
      averageCashCollectedPerSale: firstNumber(sources, ["averageCashCollectedPerSale", "average_cash_collected_per_sale", "averageCashPerSale", "average_cash_per_sale"]),
      futureRigidCashOutflow: firstNumber(sources, ["futureRigidCashOutflow", "future_rigid_cash_outflow", "next30RigidOutflow", "next30_rigid_outflow", "nearTermRigidOutflow", "near_term_rigid_outflow"]),
      currency: firstText(sources, ["currency"], "CNY"),
      salesUnit: firstText(sources, ["salesUnit", "sales_unit"], "单"),
      deliveryUnit: firstText(sources, ["deliveryUnit", "delivery_unit", "unitLabel", "unit_label"], "个交付单位")
    };
  }

  function inspectBusinessTargetSource(input) {
    const rootSource = input && typeof input === "object" ? input : {};
    const nestedInput = rootSource.deterministicInput || rootSource.deterministic_input || rootSource.input;
    const source = nestedInput && typeof nestedInput === "object" ? nestedInput : rootSource;
    const sourceCalculation = source.sourceCalculation || source.source_calculation || rootSource.sourceCalculation || {};
    if (!sourceCalculation || typeof sourceCalculation !== "object" || !Object.keys(sourceCalculation).length) {
      return { inputMode: "", status: "unknown", warnings: [], errors: [] };
    }
    const calculationState = sourceCalculation.state && typeof sourceCalculation.state === "object" ? sourceCalculation.state : {};
    const inputMode = firstText([sourceCalculation, calculationState], ["inputMode", "input_mode"], "");
    if (inputMode === "quick_v2") {
      const profile = classifyLegacyQuickPeriod(calculationState);
      return {
        inputMode,
        status: profile.isLegacyPeriodAmbiguous ? "legacy_period_ambiguous" : "eligible_monthly_source",
        warnings: profile.warnings.slice(),
        errors: profile.errors.slice()
      };
    }
    if (inputMode === "quick_v3") {
      const profile = getPeriodProfile(calculationState);
      return {
        inputMode,
        status: profile.valid ? "eligible_normalized_monthly_source" : "invalid_period_source",
        warnings: profile.warnings.slice(),
        errors: profile.errors.slice()
      };
    }
    return { inputMode, status: "unknown", warnings: [], errors: [] };
  }

  function targetMissingRow(field, optional) {
    return {
      scope: "business_target_plan",
      field,
      label: TARGET_FIELD_LABELS[field] || field,
      optional: Boolean(optional)
    };
  }

  function targetFieldsReadiness(state, fields, fieldErrors) {
    const missingFields = fields.filter((field) => {
      if (field === "calculationId" || field === "sourceInputHash" || field === "targetMonth") return !state[field];
      return state[field] === null;
    });
    const errors = [];
    fields.forEach((field) => {
      (fieldErrors[field] || []).forEach((error) => {
        if (!errors.includes(error)) errors.push(error);
      });
    });
    return readiness(errors.length ? "invalid" : (missingFields.length ? "missing" : "ready"), missingFields, errors);
  }

  function validateBusinessTargetPlan(input) {
    const state = cleanBusinessTargetState(input);
    const sourceDiagnostics = inspectBusinessTargetSource(input);
    const errors = [];
    const warnings = [];
    const blockers = [];
    const fieldErrors = {};
    const addFieldError = (field, message) => {
      if (!fieldErrors[field]) fieldErrors[field] = [];
      fieldErrors[field].push(message);
      if (!errors.includes(message)) errors.push(message);
    };

    if (sourceDiagnostics.status === "legacy_period_ambiguous") {
      const message = "旧版 quick_v2 跨月或部分月记录的成本口径不明确，不能直接生成完整月经营目标；请先按月均或本期总额确认并另存为 quick_v3。";
      addFieldError("calculationId", message);
      blockers.push({ code: "blocked_legacy_period", message });
    } else if (sourceDiagnostics.status === "invalid_period_source") {
      const message = "来源核算的日期无效，不能生成经营目标。";
      addFieldError("calculationId", message);
      blockers.push({ code: "blocked_invalid_period", message });
    }
    if (state.targetMonth && !/^\d{4}-(0[1-9]|1[0-2])$/.test(state.targetMonth)) {
      addFieldError("targetMonth", "目标月份必须使用 YYYY-MM 格式。");
    }
    ["targetProfit", "targetCashIncrease", "fixedOperatingCost", "ownerWage", "unitRecognizedRevenue", "unitDirectCost", "maxStableDeliveryUnits", "averageCashCollectedPerSale", "futureRigidCashOutflow"].forEach((field) => {
      if (state[field] !== null && state[field] < 0) addFieldError(field, (TARGET_FIELD_LABELS[field] || field) + "不能为负数。");
    });
    const unitInputsPresent = state.unitRecognizedRevenue !== null && state.unitDirectCost !== null;
    const unitContributionCents = unitInputsPresent ? cents(state.unitRecognizedRevenue) - cents(state.unitDirectCost) : null;
    const blockedUnitEconomics = unitContributionCents !== null && unitContributionCents <= 0;
    if (state.contributionMarginRate !== null && state.contributionMarginRate > 100) {
      addFieldError("contributionMarginRate", "贡献毛利率不能超过 100%。");
    } else if (state.contributionMarginRate !== null && state.contributionMarginRate <= 0 && !blockedUnitEconomics) {
      addFieldError("contributionMarginRate", "贡献毛利率必须大于 0%，才能倒推盈利营业额。");
    }
    if (state.maxStableDeliveryUnits !== null && state.maxStableDeliveryUnits <= 0) {
      addFieldError("maxStableDeliveryUnits", "每月最大稳定交付量必须大于 0。");
    }
    if (state.averageCashCollectedPerSale !== null && state.averageCashCollectedPerSale <= 0) {
      addFieldError("averageCashCollectedPerSale", "平均每单本月实收必须大于 0；未知时请留空。");
    }
    if (state.futureRigidCashOutflow !== null && state.ownerWage !== null && cents(state.futureRigidCashOutflow) < cents(state.ownerWage)) {
      addFieldError("futureRigidCashOutflow", "已填未来刚性现金支出必须包含创业者合理工资，不能低于创业者合理工资。");
    }
    if (unitInputsPresent) {
      if (blockedUnitEconomics) {
        blockers.push({
          code: "blocked_unit_economics",
          message: "单位贡献不为正，不能生成盈利营业额、交付量或成交量伪目标。"
        });
        warnings.push("单位贡献不为正：目标事实可以保存，但必须先处理定价或直接成本，不能继续扩大获客。");
      } else if (state.contributionMarginRate !== null && cents(state.unitRecognizedRevenue) > 0) {
        const unitRate = (unitContributionCents / cents(state.unitRecognizedRevenue)) * 100;
        if (Math.abs(unitRate - state.contributionMarginRate) >= 0.1) {
          warnings.push("贡献毛利率与单位收入、单位直接成本推导的比例不一致；理论营业额与整数交付营业额将分别按各自口径展示。");
        }
      }
    }

    const linkageFields = ["calculationId", "sourceInputHash"];
    const goalFields = ["targetMonth", "targetProfit", "targetCashIncrease"];
    const profitFields = goalFields.concat(["fixedOperatingCost", "ownerWage", "contributionMarginRate"]);
    const deliveryFields = profitFields.concat(["unitRecognizedRevenue", "unitDirectCost"]);
    const capacityFields = deliveryFields.concat(["maxStableDeliveryUnits"]);
    const cashFields = deliveryFields.concat(["targetCashIncrease"]);
    const salesFields = cashFields.concat(["averageCashCollectedPerSale"]);
    const metricReadiness = {
      linkage: targetFieldsReadiness(state, linkageFields, fieldErrors),
      goal: targetFieldsReadiness(state, goalFields, fieldErrors),
      profitLine: targetFieldsReadiness(state, profitFields, fieldErrors),
      deliveryLine: targetFieldsReadiness(state, deliveryFields, fieldErrors),
      capacity: targetFieldsReadiness(state, capacityFields, fieldErrors),
      cashLine: targetFieldsReadiness(state, cashFields, fieldErrors),
      salesCount: targetFieldsReadiness(state, salesFields, fieldErrors)
    };
    if (fieldErrors.futureRigidCashOutflow && fieldErrors.futureRigidCashOutflow.length) {
      metricReadiness.cashLine = readiness("invalid", metricReadiness.cashLine.missingFields, metricReadiness.cashLine.errors.concat(fieldErrors.futureRigidCashOutflow));
      metricReadiness.salesCount = readiness("invalid", metricReadiness.salesCount.missingFields, metricReadiness.salesCount.errors.concat(fieldErrors.futureRigidCashOutflow));
    }
    const blockedFactFields = linkageFields.concat(goalFields, ["fixedOperatingCost", "ownerWage", "unitRecognizedRevenue", "unitDirectCost"]);
    const requiredFields = Array.from(new Set(blockedUnitEconomics ? blockedFactFields : linkageFields.concat(capacityFields)));
    const missingFields = requiredFields.filter((field) => {
      if (field === "calculationId" || field === "sourceInputHash" || field === "targetMonth") return !state[field];
      return state[field] === null;
    });
    const optionalMissingFields = [];
    if (state.averageCashCollectedPerSale === null) optionalMissingFields.push("averageCashCollectedPerSale");
    if (blockedUnitEconomics && state.contributionMarginRate === null) optionalMissingFields.push("contributionMarginRate");
    if (blockedUnitEconomics && state.maxStableDeliveryUnits === null) optionalMissingFields.push("maxStableDeliveryUnits");
    const readyForSave = missingFields.length === 0 && errors.length === 0;
    return {
      state,
      sourceDiagnostics,
      missing: missingFields.map((field) => targetMissingRow(field, false)),
      optionalMissing: optionalMissingFields.map((field) => targetMissingRow(field, true)),
      errors,
      warnings,
      metricReadiness,
      blockers,
      blockedUnitEconomics,
      ready: readyForSave,
      savable: readyForSave
    };
  }

  function targetCapacityStatus(capacityUtilizationRate) {
    if (capacityUtilizationRate === null) return { code: "unknown", text: "还缺少稳定产能数据" };
    if (capacityUtilizationRate > 100) return { code: "not_feasible", text: "盈利交付目标超过最大稳定交付量" };
    if (capacityUtilizationRate > 80) return { code: "high_pressure", text: "盈利交付目标接近稳定产能上限" };
    return { code: "feasible", text: "盈利交付目标在稳定产能内" };
  }

  function calculateBusinessTargetPlan(input) {
    const validation = validateBusinessTargetPlan(input);
    const state = validation.state;
    const hashPayload = clone(state);
    delete hashPayload.targetPlanId;
    const targetInputHash = hashInput(hashPayload);
    const targetPlanId = state.targetPlanId || "btp-" + targetInputHash;
    const profitReady = validation.metricReadiness.profitLine.status === "ready";
    const capacityReady = validation.metricReadiness.capacity.status === "ready";
    const salesReady = validation.metricReadiness.salesCount.status === "ready";

    let fixedOperatingNeed = null;
    let breakEvenRevenue = null;
    let theoreticalProfitRevenue = null;
    let unitContribution = null;
    let breakEvenDeliveryUnits = null;
    let executableBreakEvenRevenue = null;
    let targetDeliveryUnits = null;
    let executableProfitRevenue = null;
    let capacityUtilizationRate = null;
    let capacityFeasible = null;
    let estimatedVariableCashCost = null;
    let rigidCashNeed = null;
    let rigidCashNeedSource = null;
    let minimumCashReceivedTarget = null;
    let monthlySalesTarget = null;

    if (state.fixedOperatingCost !== null && state.ownerWage !== null) {
      const fixedNeedCents = cents(state.fixedOperatingCost) + cents(state.ownerWage);
      fixedOperatingNeed = money(fixedNeedCents);
    }

    if (profitReady && !validation.blockedUnitEconomics && state.contributionMarginRate > 0) {
      const fixedNeedCents = cents(state.fixedOperatingCost) + cents(state.ownerWage);
      const profitNeedCents = fixedNeedCents + cents(state.targetProfit);
      const contributionBasisPoints = percentToBasisPoints(state.contributionMarginRate);
      breakEvenRevenue = money(Math.ceil((fixedNeedCents * 10000) / contributionBasisPoints));
      theoreticalProfitRevenue = money(Math.ceil((profitNeedCents * 10000) / contributionBasisPoints));
    }

    const unitInputsPresent = state.unitRecognizedRevenue !== null && state.unitDirectCost !== null;
    if (unitInputsPresent) {
      const unitContributionCents = cents(state.unitRecognizedRevenue) - cents(state.unitDirectCost);
      unitContribution = money(unitContributionCents);
      if (profitReady && !validation.blockedUnitEconomics && unitContributionCents > 0) {
        const fixedNeedCents = cents(state.fixedOperatingCost) + cents(state.ownerWage);
        const deliveryNeedCents = cents(state.fixedOperatingCost) + cents(state.ownerWage) + cents(state.targetProfit);
        breakEvenDeliveryUnits = Math.ceil(fixedNeedCents / unitContributionCents);
        executableBreakEvenRevenue = money(multiplyMoneyByQuantity(cents(state.unitRecognizedRevenue), breakEvenDeliveryUnits));
        targetDeliveryUnits = Math.ceil(deliveryNeedCents / unitContributionCents);
        executableProfitRevenue = money(multiplyMoneyByQuantity(cents(state.unitRecognizedRevenue), targetDeliveryUnits));
        estimatedVariableCashCost = money(multiplyMoneyByQuantity(cents(state.unitDirectCost), targetDeliveryUnits));
        if (state.futureRigidCashOutflow === null) {
          rigidCashNeed = money(cents(state.fixedOperatingCost) + cents(state.ownerWage));
          rigidCashNeedSource = "fixed_cost_plus_owner_wage";
        } else if (cents(state.futureRigidCashOutflow) >= cents(state.ownerWage)) {
          rigidCashNeed = money(cents(state.futureRigidCashOutflow));
          rigidCashNeedSource = "provided_future_rigid_outflow";
        }
        if (rigidCashNeed !== null) {
          minimumCashReceivedTarget = money(cents(rigidCashNeed) + cents(estimatedVariableCashCost) + cents(state.targetCashIncrease));
          if (salesReady) monthlySalesTarget = Math.ceil(cents(minimumCashReceivedTarget) / cents(state.averageCashCollectedPerSale));
        }
      }
    }

    if (capacityReady && targetDeliveryUnits !== null) {
      capacityUtilizationRate = Number(((targetDeliveryUnits / state.maxStableDeliveryUnits) * 100).toFixed(2));
      capacityFeasible = targetDeliveryUnits <= state.maxStableDeliveryUnits;
      if (!capacityFeasible) validation.warnings.push("盈利交付目标超过最大稳定交付量，不能继续用扩大获客来解决，应先调整价格、成本、交付方式或产能。");
    }
    const capacityStatus = targetCapacityStatus(capacityUtilizationRate);
    const planStatus = validation.blockedUnitEconomics
      ? { code: "blocked_unit_economics", text: "单位贡献不为正，先处理定价或直接成本" }
      : (capacityFeasible === false
        ? { code: "blocked_capacity", text: "盈利交付目标超过稳定产能" }
        : { code: "active", text: "目标可进入经营拆解" });
    if (state.averageCashCollectedPerSale === null && minimumCashReceivedTarget !== null) {
      validation.warnings.push("平均每单本月实收未知：只生成实收金额目标，不伪造成交单数。");
    }

    const preview = {
      targetPlanId,
      calculationId: state.calculationId,
      sourceInputHash: state.sourceInputHash,
      targetInputHash,
      targetMonth: state.targetMonth,
      planStatus,
      blockers: validation.blockers.slice(),
      currency: state.currency,
      salesUnit: state.salesUnit,
      deliveryUnit: state.deliveryUnit,
      targetProfit: state.targetProfit,
      targetCashIncrease: state.targetCashIncrease,
      fixedOperatingCost: state.fixedOperatingCost,
      ownerWage: state.ownerWage,
      fixedOperatingNeed,
      contributionMarginRate: state.contributionMarginRate,
      breakEvenRevenue,
      breakEvenDeliveryUnits,
      executableBreakEvenRevenue,
      theoreticalProfitRevenue,
      targetDeliveryUnits,
      executableProfitRevenue,
      unitRecognizedRevenue: state.unitRecognizedRevenue,
      unitDirectCost: state.unitDirectCost,
      unitContribution,
      maxStableDeliveryUnits: state.maxStableDeliveryUnits,
      capacityUtilizationRate,
      capacityFeasible,
      capacityStatus,
      estimatedVariableCashCost,
      rigidCashNeed,
      rigidCashNeedSource,
      minimumCashReceivedTarget,
      averageCashCollectedPerSale: state.averageCashCollectedPerSale,
      monthlySalesTarget,
      warnings: validation.warnings.slice(),
      readiness: validation.metricReadiness
    };
    let dataStatus = "incomplete";
    if (validation.errors.length) dataStatus = "invalid";
    else if (validation.savable) dataStatus = "ready";
    else if (fixedOperatingNeed !== null || theoreticalProfitRevenue !== null) dataStatus = "partial";
    const deterministicInput = Object.assign({}, state, { targetPlanId });
    return {
      calculationVersion: VERSION,
      schemaVersion: BUSINESS_TARGET_SCHEMA_VERSION,
      planType: "business_target_plan",
      hashAlgorithm: HASH_ALGORITHM,
      calculationId: state.calculationId,
      sourceInputHash: state.sourceInputHash,
      targetPlanId,
      targetInputHash,
      inputHash: targetInputHash,
      dataStatus,
      savable: validation.savable,
      deterministicInput,
      state: deterministicInput,
      missing: validation.missing,
      optionalMissing: validation.optionalMissing,
      errors: validation.errors,
      blockers: validation.blockers,
      warnings: validation.warnings,
      sourceDiagnostics: validation.sourceDiagnostics,
      metricReadiness: validation.metricReadiness,
      preview,
      result: validation.savable ? preview : null
    };
  }

  function recordEnvelope(record, planType) {
    if (!record || typeof record !== "object") return null;
    if (record.planType === planType || record.plan_type === planType) return record;
    if (record.result && typeof record.result === "object" && (record.result.planType === planType || record.result.plan_type === planType)) return record.result;
    if (record.deterministicResult && typeof record.deterministicResult === "object") return record.deterministicResult;
    if (record.deterministic_result && typeof record.deterministic_result === "object") return record.deterministic_result;
    return null;
  }

  function recordInput(record, envelope) {
    if (record && record.input && typeof record.input === "object") return record.input;
    if (record && record.deterministicInput && typeof record.deterministicInput === "object") return record.deterministicInput;
    if (record && record.deterministic_input && typeof record.deterministic_input === "object") return record.deterministic_input;
    if (envelope && envelope.deterministicInput && typeof envelope.deterministicInput === "object") return envelope.deterministicInput;
    if (envelope && envelope.deterministic_input && typeof envelope.deterministic_input === "object") return envelope.deterministic_input;
    return null;
  }

  function validationOptions(expected, hashField) {
    if (typeof expected === "string") {
      const options = {};
      options[hashField] = expected;
      return options;
    }
    return expected && typeof expected === "object" ? expected : {};
  }

  function validateBusinessTargetPlanRecord(record, expected) {
    const errors = [];
    const envelope = recordEnvelope(record, "business_target_plan");
    if (!envelope) return { valid: false, errors: ["记录不包含完整的 business_target_plan 确定性结果。"], recalculated: null };
    const input = recordInput(record, envelope);
    if (!input) return { valid: false, errors: ["目标方案缺少 deterministic input，无法重新运行公式。"], recalculated: null };
    const recalculated = calculateBusinessTargetPlan(input);
    const options = validationOptions(expected, "expectedSourceInputHash");
    if (envelope.planType !== "business_target_plan") errors.push("目标方案 record type 不匹配。");
    if (envelope.schemaVersion !== BUSINESS_TARGET_SCHEMA_VERSION) errors.push("目标方案 schema version 不匹配。");
    if (!recalculated.savable || !recalculated.result) errors.push("目标方案输入无法重新生成完整确定性结果。");
    if (envelope.calculationId !== recalculated.calculationId) errors.push("目标方案 calculation_id 与确定性输入不一致。");
    if (envelope.sourceInputHash !== recalculated.sourceInputHash) errors.push("目标方案 source_input_hash 与确定性输入不一致。");
    if (envelope.targetPlanId !== recalculated.targetPlanId) errors.push("目标方案 target_plan_id 与确定性输入不一致。");
    if (envelope.targetInputHash !== recalculated.targetInputHash) errors.push("目标方案 target_input_hash 已过期或被修改。");
    if (envelope.inputHash !== undefined && envelope.inputHash !== recalculated.targetInputHash) errors.push("目标方案 inputHash 与 target_input_hash 不一致。");
    if (!deepEqual(envelope.result, recalculated.result)) errors.push("目标方案中的确定性数字与公式复算结果不一致。");
    if (envelope.deterministicInput && !deepEqual(envelope.deterministicInput, input)) errors.push("目标方案内外 deterministic input 不一致。");
    if (options.expectedSourceInputHash && recalculated.sourceInputHash !== options.expectedSourceInputHash) errors.push("目标方案绑定的核算哈希不是当前最新有效哈希。");
    if (options.expectedCalculationId && recalculated.calculationId !== options.expectedCalculationId) errors.push("目标方案绑定的核算记录不是当前最新有效记录。");
    const expectedCalculation = options.expectedSourceCalculation || options.sourceCalculation;
    if (expectedCalculation && typeof expectedCalculation === "object") {
      if (expectedCalculation.inputHash && recalculated.sourceInputHash !== expectedCalculation.inputHash) {
        errors.push("目标方案绑定哈希与传入的最新核算结果不一致。");
      }
      const expectedSourceState = cleanBusinessTargetState({ sourceCalculation: expectedCalculation });
      ["fixedOperatingCost", "ownerWage", "contributionMarginRate", "unitRecognizedRevenue", "unitDirectCost", "maxStableDeliveryUnits", "futureRigidCashOutflow"].forEach((field) => {
        if (expectedSourceState[field] !== null && !deepEqual(recalculated.deterministicInput[field], expectedSourceState[field])) {
          errors.push("目标方案修改了最新核算已提供的“" + (TARGET_FIELD_LABELS[field] || field) + "”。");
        }
      });
    }
    if (options.expectedSourceValues && typeof options.expectedSourceValues === "object") {
      const expectedSourceState = cleanBusinessTargetState(options.expectedSourceValues);
      ["fixedOperatingCost", "ownerWage", "contributionMarginRate", "unitRecognizedRevenue", "unitDirectCost", "maxStableDeliveryUnits", "futureRigidCashOutflow"].forEach((field) => {
        if (expectedSourceState[field] !== null && !deepEqual(recalculated.deterministicInput[field], expectedSourceState[field])) {
          errors.push("目标方案修改了守卫提供的来源字段“" + (TARGET_FIELD_LABELS[field] || field) + "”。");
        }
      });
    }

    const recordSources = [record || {}, envelope];
    const recordTargetHash = firstText(recordSources, ["target_input_hash"], "");
    const recordSourceHash = firstText(recordSources, ["source_input_hash"], "");
    const recordTargetId = firstText(recordSources, ["target_plan_id"], "");
    if (recordTargetHash && recordTargetHash !== recalculated.targetInputHash) errors.push("目标方案 frontmatter 的 target_input_hash 不匹配。");
    if (recordSourceHash && recordSourceHash !== recalculated.sourceInputHash) errors.push("目标方案 frontmatter 的 source_input_hash 不匹配。");
    if (recordTargetId && recordTargetId !== recalculated.targetPlanId) errors.push("目标方案 frontmatter 的 target_plan_id 不匹配。");
    return { valid: errors.length === 0, errors, recalculated };
  }

  function operatingSource(input) {
    const rootSource = input && typeof input === "object" ? input : {};
    const nestedInput = rootSource.deterministicInput || rootSource.deterministic_input || rootSource.input;
    return {
      rootSource,
      source: nestedInput && typeof nestedInput === "object" ? nestedInput : rootSource
    };
  }

  function businessTargetCandidate(input) {
    const resolved = operatingSource(input);
    return resolved.source.targetPlan || resolved.source.target_plan || resolved.rootSource.targetPlan || resolved.rootSource.target_plan || null;
  }

  function businessTargetParts(candidate) {
    if (!candidate || typeof candidate !== "object") return { envelope: null, result: {} };
    const envelope = recordEnvelope(candidate, "business_target_plan");
    if (envelope) return { envelope, result: envelope.result || envelope.preview || {} };
    if (candidate.result && typeof candidate.result === "object") return { envelope: null, result: candidate.result };
    return { envelope: null, result: candidate };
  }

  function rateFromSources(sources, keys) {
    const found = firstValue(sources, keys);
    if (!found.found) return null;
    if (found.value && typeof found.value === "object") {
      return asNumber(firstOwn(found.value, ["value", "rate", "percent", "percentage"]));
    }
    return asNumber(found.value);
  }

  function normalizeShareRows(value, prefix) {
    if (!Array.isArray(value)) return [];
    return value.map((row, index) => {
      if (typeof row === "number" || typeof row === "string") {
        return { name: prefix + (index + 1), sharePercent: asNumber(row) };
      }
      const source = row && typeof row === "object" ? row : {};
      return {
        name: firstText([source], ["name", "label", "channel", "week"], prefix + (index + 1)),
        sharePercent: firstNumber([source], ["sharePercent", "share_percent", "share", "weightPercent", "weight_percent", "weight"])
      };
    });
  }

  function cleanOperatingBreakdownState(input) {
    const resolved = operatingSource(input);
    const source = resolved.source;
    const candidate = businessTargetCandidate(input);
    const targetParts = businessTargetParts(candidate);
    const directTarget = source.target && typeof source.target === "object" ? source.target : {};
    const targetSources = [source, directTarget, targetParts.envelope || {}, targetParts.result || {}];
    const progress = source.progress && typeof source.progress === "object" ? source.progress : {};
    const progressSources = [source, progress];
    const conversionRatesSource = source.conversionRates || source.conversion_rates || {};
    const conversionSources = [conversionRatesSource, source];
    const rates = {
      outreachToResponse: rateFromSources(conversionSources, ["outreachToResponse", "outreach_to_response", "touchToResponse", "touch_to_response"]),
      responseToDiscussion: rateFromSources(conversionSources, ["responseToDiscussion", "response_to_discussion"]),
      discussionToQuote: rateFromSources(conversionSources, ["discussionToQuote", "discussion_to_quote"]),
      quoteToSale: rateFromSources(conversionSources, ["quoteToSale", "quote_to_sale", "quoteToDeal", "quote_to_deal"])
    };
    let conversionBasis = firstText([source], ["conversionBasis", "conversion_basis"], "");
    if (!conversionBasis) {
      const rateBases = [];
      Object.keys(conversionRatesSource).forEach((key) => {
        const row = conversionRatesSource[key];
        if (row && typeof row === "object") {
          const basis = firstText([row], ["basis", "source", "dataBasis", "data_basis"], "");
          if (basis && !rateBases.includes(basis)) rateBases.push(basis);
        }
      });
      if (rateBases.length === 1) conversionBasis = rateBases[0];
      else if (rateBases.length > 1) conversionBasis = "mixed";
    }
    const rawChannels = firstOwn(source, ["channels", "channelShares", "channel_shares"]);
    const rawWeekWeights = firstOwn(source, ["weekWeights", "week_weights", "weeklyWeights", "weekly_weights"]);
    const funnelSource = source.funnelActuals || source.funnel_actuals || source.funnelProgress || source.funnel_progress || {};
    const sprintValue = firstValue([source], ["sprintFactor", "sprint_factor"]);
    const actualDeals = firstNumber(progressSources, ["actualDeals", "actual_deals", "deals", "closedDeals", "closed_deals"]);
    return {
      actionPlanId: firstText([source, resolved.rootSource], ["actionPlanId", "action_plan_id"], ""),
      targetPlanId: firstText(targetSources, ["targetPlanId", "target_plan_id"], ""),
      targetInputHash: firstText(targetSources, ["targetInputHash", "target_input_hash", "inputHash", "input_hash"], ""),
      targetMonth: firstText(targetSources, ["targetMonth", "target_month"], ""),
      targetProfit: firstNumber(targetSources, ["targetProfit", "target_profit"]),
      minimumCashReceivedTarget: firstNumber(targetSources, ["minimumCashReceivedTarget", "minimum_cash_received_target"]),
      monthlySalesTarget: firstNumber(targetSources, ["monthlySalesTarget", "monthly_sales_target"]),
      executableProfitRevenue: firstNumber(targetSources, ["executableProfitRevenue", "executable_profit_revenue", "profitRevenueTarget", "profit_revenue_target"]),
      targetDeliveryUnits: firstNumber(targetSources, ["targetDeliveryUnits", "target_delivery_units"]),
      unitContribution: firstNumber(targetSources, ["unitContribution", "unit_contribution"]),
      capacityFeasible: firstNullableBoolean(targetSources, ["capacityFeasible", "capacity_feasible"]),
      actualCashReceived: firstNumber(progressSources, ["actualCashReceived", "actual_cash_received", "cashReceived", "cash_received"]),
      actualDeals,
      actualRecognizedRevenue: firstNumber(progressSources, ["actualRecognizedRevenue", "actual_recognized_revenue", "recognizedRevenue", "recognized_revenue"]),
      actualDeliveredUnits: firstNumber(progressSources, ["actualDeliveredUnits", "actual_delivered_units", "deliveredUnits", "delivered_units"]),
      remainingBusinessDays: firstNumber([source], ["remainingBusinessDays", "remaining_business_days"]),
      conversionRates: rates,
      conversionBasis,
      channels: normalizeShareRows(rawChannels, "渠道"),
      weekWeights: normalizeShareRows(rawWeekWeights, "第"),
      sprintFactor: sprintValue.found && !isBlank(sprintValue.value) ? asNumber(sprintValue.value) : 1,
      funnelActuals: {
        outreach: firstNumber([funnelSource], ["outreach", "outreaches", "touches", "contacts"]),
        responses: firstNumber([funnelSource], ["responses", "response"]),
        discussions: firstNumber([funnelSource], ["discussions", "discussion"]),
        quotes: firstNumber([funnelSource], ["quotes", "quote"]),
        deals: firstNumber([funnelSource], ["deals", "sales", "closedDeals", "closed_deals"])
      },
      cashRiskCritical: firstBoolean([source], ["cashRiskCritical", "cash_risk_critical"], false)
    };
  }

  function breakdownMissingRow(field, optional) {
    return {
      scope: "operating_action_plan",
      field,
      label: BREAKDOWN_FIELD_LABELS[field] || field,
      optional: Boolean(optional)
    };
  }

  function shareRowsErrors(rows, label, minimum, maximum) {
    const errors = [];
    if (!rows.length) return errors;
    if (minimum !== null && rows.length < minimum) errors.push(label + "至少需要 " + minimum + " 项。");
    if (maximum !== null && rows.length > maximum) errors.push(label + "最多只能设置 " + maximum + " 项。");
    const names = [];
    rows.forEach((row) => {
      if (!row.name) errors.push(label + "名称不能为空。");
      if (names.includes(row.name)) errors.push(label + "名称不能重复：" + row.name + "。");
      names.push(row.name);
      if (row.sharePercent === null || row.sharePercent <= 0 || row.sharePercent > 100) errors.push(label + "占比必须大于 0% 且不超过 100%。");
    });
    if (rows.every((row) => row.sharePercent !== null)) {
      const totalHundredths = rows.reduce((sum, row) => sum + Math.round(row.sharePercent * 100), 0);
      if (totalHundredths !== 10000) errors.push(label + "占比必须合计 100%。");
    }
    return errors;
  }

  function inspectTargetCandidate(input) {
    const candidate = businessTargetCandidate(input);
    if (!candidate) return { checked: false, valid: null, errors: [] };
    const envelope = recordEnvelope(candidate, "business_target_plan");
    if (!envelope) return { checked: false, valid: null, errors: [] };
    const validation = validateBusinessTargetPlanRecord(candidate);
    return { checked: true, valid: validation.valid, errors: validation.errors };
  }

  function validateOperatingBreakdown(input) {
    const state = cleanOperatingBreakdownState(input);
    if (state.funnelActuals.deals === null) state.funnelActuals.deals = state.actualDeals;
    const errors = [];
    const warnings = [];
    const missingFields = [];
    const correctiveUnitMode = state.unitContribution !== null && state.unitContribution <= 0;
    const coreTextFields = ["targetPlanId", "targetInputHash", "targetMonth"];
    coreTextFields.forEach((field) => {
      if (!state[field]) missingFields.push(field);
    });
    const progressFields = correctiveUnitMode ? [] : ["actualCashReceived", "actualDeals", "actualRecognizedRevenue", "actualDeliveredUnits", "remainingBusinessDays"];
    progressFields.forEach((field) => {
      if (state[field] === null) missingFields.push(field);
    });
    const targetFields = correctiveUnitMode
      ? ["unitContribution"]
      : ["minimumCashReceivedTarget", "executableProfitRevenue", "targetDeliveryUnits", "unitContribution", "capacityFeasible"];
    targetFields.forEach((field) => {
      if (state[field] === null) missingFields.push(field);
    });
    ["actualCashReceived", "actualDeals", "actualRecognizedRevenue", "actualDeliveredUnits"].forEach((field) => {
      if (state[field] !== null && state[field] < 0) errors.push((BREAKDOWN_FIELD_LABELS[field] || field) + "不能为负数。");
    });
    if (state.actualDeals !== null && !Number.isInteger(state.actualDeals)) errors.push("当前已完成成交单数必须是整数。");
    if (state.remainingBusinessDays !== null && (!Number.isInteger(state.remainingBusinessDays) || state.remainingBusinessDays <= 0)) {
      errors.push("剩余有效经营日必须是大于 0 的整数。");
    }
    ["minimumCashReceivedTarget", "executableProfitRevenue", "targetDeliveryUnits"].forEach((field) => {
      if (state[field] !== null && state[field] < 0) errors.push(field + "不能为负数。");
    });
    if (state.monthlySalesTarget !== null && (!Number.isInteger(state.monthlySalesTarget) || state.monthlySalesTarget < 0)) {
      errors.push("月成交目标必须是非负整数；未知时保持为空。");
    }
    Object.keys(state.conversionRates).forEach((field) => {
      const value = state.conversionRates[field];
      if (value !== null && (value < 0 || value > 100)) errors.push((BREAKDOWN_FIELD_LABELS[field] || field) + "必须在 0% 到 100% 之间。");
    });
    const providedRateCount = Object.values(state.conversionRates).filter((value) => value !== null).length;
    const positiveRateCount = Object.values(state.conversionRates).filter((value) => value > 0).length;
    if (providedRateCount > 0 && !CONVERSION_BASES.includes(state.conversionBasis)) missingFields.push("conversionBasis");
    if (state.conversionBasis && !CONVERSION_BASES.includes(state.conversionBasis)) errors.push("转化率依据必须标记为 historical、user_estimate 或 mixed。");
    if (positiveRateCount < 4 && !correctiveUnitMode && state.capacityFeasible !== false) warnings.push("转化率不足以生成精确漏斗目标：进入七天校准模式，不使用行业默认数据。");
    const channelErrors = shareRowsErrors(state.channels, "渠道", 1, 3);
    const weekErrors = shareRowsErrors(state.weekWeights, "周权重", 1, null);
    channelErrors.concat(weekErrors).forEach((error) => errors.push(error));
    if (state.sprintFactor === null || state.sprintFactor < 1) errors.push("冲刺系数必须大于等于 1.00。");
    Object.keys(state.funnelActuals).forEach((field) => {
      const value = state.funnelActuals[field];
      if (value !== null && (!Number.isInteger(value) || value < 0)) errors.push("漏斗实际数量必须是非负整数：" + field + "。");
    });
    if (state.actualDeals !== null && state.funnelActuals.deals !== null && state.actualDeals !== state.funnelActuals.deals) {
      errors.push("漏斗中的成交数必须与当前已完成成交单数一致。");
    }
    const targetInspection = inspectTargetCandidate(input);
    if (targetInspection.checked && !targetInspection.valid) {
      errors.push("绑定的目标方案未通过确定性复算：" + targetInspection.errors.join("；"));
    }
    const uniqueMissing = Array.from(new Set(missingFields));
    const conversionReady = positiveRateCount === 4 && CONVERSION_BASES.includes(state.conversionBasis);
    const calibrationMode = !conversionReady && !correctiveUnitMode && state.capacityFeasible !== false;
    const metricReadiness = {
      linkage: readiness(coreTextFields.some((field) => !state[field]) ? "missing" : "ready", coreTextFields.filter((field) => !state[field]), []),
      progress: correctiveUnitMode
        ? readiness("not_required", [], [])
        : readiness(progressFields.some((field) => state[field] === null) ? "missing" : "ready", progressFields.filter((field) => state[field] === null), []),
      targetSnapshot: readiness(targetFields.some((field) => state[field] === null) ? "missing" : "ready", targetFields.filter((field) => state[field] === null), []),
      funnel: readiness(conversionReady ? "ready" : "calibration", Object.keys(state.conversionRates).filter((field) => !(state.conversionRates[field] > 0)), []),
      channels: readiness(channelErrors.length ? "invalid" : (state.channels.length ? "ready" : "not_used"), [], channelErrors),
      weekWeights: readiness(weekErrors.length ? "invalid" : (state.weekWeights.length ? "ready" : "not_used"), [], weekErrors)
    };
    const savable = uniqueMissing.length === 0 && errors.length === 0;
    return {
      state,
      missing: uniqueMissing.map((field) => breakdownMissingRow(field, false)),
      errors,
      warnings,
      metricReadiness,
      conversionReady,
      calibrationMode,
      correctiveUnitMode,
      ready: savable,
      savable
    };
  }

  function nonNegativeGap(target, actual) {
    if (target === null || actual === null) return null;
    return Number(Math.max(0, target - actual).toFixed(2));
  }

  function normalizedGap(target, remaining) {
    if (target === null || remaining === null) return null;
    if (target <= 0) return remaining > 0 ? 1 : 0;
    return Number((remaining / target).toFixed(4));
  }

  function gapRow(target, actual) {
    const remaining = nonNegativeGap(target, actual);
    return { target, actual, remaining, normalizedGap: normalizedGap(target, remaining) };
  }

  function divideCountByPercent(count, percent) {
    if (!(percent > 0)) return null;
    return Math.ceil((count * 10000) / Math.round(percent * 100));
  }

  function buildFunnelTarget(deals, rates) {
    if (deals === null) return null;
    const quotes = divideCountByPercent(deals, rates.quoteToSale);
    const discussions = divideCountByPercent(quotes, rates.discussionToQuote);
    const responses = divideCountByPercent(discussions, rates.responseToDiscussion);
    const outreach = divideCountByPercent(responses, rates.outreachToResponse);
    return { outreach, responses, discussions, quotes, deals };
  }

  function remainingFunnelFromActuals(target, actuals, warnings) {
    if (!target) return null;
    const actualByStage = {
      outreach: actuals.outreach,
      responses: actuals.responses,
      discussions: actuals.discussions,
      quotes: actuals.quotes,
      deals: actuals.deals
    };
    const missingStages = Object.keys(actualByStage).filter((stage) => actualByStage[stage] === null);
    if (missingStages.length) {
      warnings.push("以下漏斗环节未提供本月已完成数量，剩余任务按已完成 0 的保守口径计算：" + missingStages.join("、") + "。");
    }
    const remaining = {};
    Object.keys(target).forEach((stage) => {
      const actual = actualByStage[stage] === null ? 0 : actualByStage[stage];
      remaining[stage] = Math.max(0, target[stage] - actual);
    });
    return remaining;
  }

  function multiplyFunnelCounts(funnel, factor) {
    if (!funnel) return null;
    const output = {};
    Object.keys(funnel).forEach((field) => {
      output[field] = Math.ceil((funnel[field] * factor) - Number.EPSILON);
    });
    return output;
  }

  function dailyFunnelCounts(funnel, days) {
    if (!funnel || !(days > 0)) return null;
    const output = {};
    Object.keys(funnel).forEach((field) => {
      output[field] = Math.ceil(funnel[field] / days);
    });
    return output;
  }

  function allocateInteger(total, rows) {
    if (!Number.isInteger(total) || total < 0 || !rows.length) return [];
    const allocations = rows.map((row, index) => {
      const exact = (total * Math.round(row.sharePercent * 100)) / 10000;
      const base = Math.floor(exact);
      return { name: row.name, sharePercent: row.sharePercent, count: base, remainder: exact - base, index };
    });
    let remaining = total - allocations.reduce((sum, row) => sum + row.count, 0);
    const order = allocations.slice().sort((left, right) => right.remainder - left.remainder || left.index - right.index);
    let cursor = 0;
    while (remaining > 0 && order.length) {
      order[cursor % order.length].count += 1;
      remaining -= 1;
      cursor += 1;
    }
    return allocations.map((row) => ({ name: row.name, sharePercent: row.sharePercent, count: row.count }));
  }

  function allocateFunnelByRows(funnel, rows) {
    if (!funnel || !rows.length) return [];
    const byStage = {};
    Object.keys(funnel).forEach((field) => {
      byStage[field] = allocateInteger(funnel[field], rows);
    });
    return rows.map((row, index) => {
      const tasks = {};
      Object.keys(funnel).forEach((field) => {
        tasks[field] = byStage[field][index].count;
      });
      return { name: row.name, sharePercent: row.sharePercent, tasks };
    });
  }

  const FUNNEL_ACTIONS = Object.freeze({
    quotes: { code: "advance_quotes_to_sale", text: "本周先推进已报价对象完成成交。" },
    discussions: { code: "turn_discussions_into_quotes", text: "本周先把有效讨论推进到正式报价。" },
    responses: { code: "turn_responses_into_discussions", text: "本周先把有效回应推进到具体业务讨论。" },
    outreach: { code: "increase_qualified_outreach", text: "本周先完成足量且精准的有效触达。" }
  });

  function largestFunnelGap(target, remaining) {
    if (!target || !remaining) return null;
    const stageOrder = ["quotes", "discussions", "responses", "outreach"];
    let selected = null;
    stageOrder.forEach((stage) => {
      const value = normalizedGap(target[stage], remaining[stage]);
      if (value === null) return;
      if (!selected || value > selected.normalizedGap) selected = { stage, normalizedGap: value, target: target[stage], remaining: remaining[stage] };
    });
    return selected;
  }

  function chooseUniqueAction(state, gaps, funnelTarget, remainingFunnel, calibrationMode) {
    if (state.unitContribution !== null && state.unitContribution <= 0) {
      return {
        code: "fix_unit_economics",
        text: "本周先修正定价或直接成本，让单位贡献先转正。",
        reason: "单位贡献不为正，扩大销量只会扩大亏损。",
        bottleneckStage: "unit_economics"
      };
    }
    if (state.capacityFeasible === false) {
      return {
        code: "fix_capacity_model",
        text: "本周先调整价格、成本、交付方式或产能，让盈利交付目标回到稳定产能内。",
        reason: "盈利交付目标超过最大稳定交付量，不能继续扩大获客。",
        bottleneckStage: "capacity"
      };
    }
    if (state.cashRiskCritical && gaps.cashReceived.remaining > 0) {
      return {
        code: "collect_cash_first",
        text: "本周先追回最紧迫的实收缺口，优先保证经营现金不断裂。",
        reason: "现金缺口已危及经营，收款优先于扩大漏斗。",
        bottleneckStage: "cash_collection"
      };
    }
    const businessGapRows = [gaps.cashReceived, gaps.deals, gaps.recognizedRevenue, gaps.delivery].filter((row) => row.remaining !== null);
    if (businessGapRows.length && businessGapRows.every((row) => row.remaining <= 0)) {
      return {
        code: "review_and_recalibrate",
        text: "本周先复盘已完成结果并重新校准下一周期。",
        reason: "当前已没有未完成目标差额。",
        bottleneckStage: "review"
      };
    }
    if (state.monthlySalesTarget === null) {
      return {
        code: "confirm_average_cash_per_sale",
        text: "本周先确认平均每单本月实际能收到的钱，再生成成交与漏斗目标。",
        reason: "当前只有实收金额目标，缺少平均每单本月实收，不能伪造成交单数。",
        bottleneckStage: "sales_cash_baseline"
      };
    }
    if (calibrationMode || !funnelTarget || !remainingFunnel) {
      return {
        code: "calibrate_funnel_7_days",
        text: "本周先做七天漏斗校准，逐日记录触达、回应、讨论、报价和成交的真实分子分母。",
        reason: "历史转化率不足，不能使用行业默认值生成伪精确任务。",
        bottleneckStage: "funnel_calibration"
      };
    }
    const bottleneck = largestFunnelGap(funnelTarget, remainingFunnel);
    const action = bottleneck ? FUNNEL_ACTIONS[bottleneck.stage] : FUNNEL_ACTIONS.quotes;
    return {
      code: action.code,
      text: action.text,
      reason: "该漏斗环节的归一化剩余差额最大。",
      bottleneckStage: bottleneck ? bottleneck.stage : "quotes",
      normalizedGap: bottleneck ? bottleneck.normalizedGap : null
    };
  }

  function calculateOperatingBreakdown(input) {
    const validation = validateOperatingBreakdown(input);
    const state = validation.state;
    const hashPayload = clone(state);
    delete hashPayload.actionPlanId;
    const breakdownInputHash = hashInput(hashPayload);
    const actionPlanId = state.actionPlanId || "oap-" + breakdownInputHash;
    const gaps = {
      cashReceived: gapRow(state.minimumCashReceivedTarget, state.actualCashReceived),
      deals: gapRow(state.monthlySalesTarget, state.actualDeals),
      recognizedRevenue: gapRow(state.executableProfitRevenue, state.actualRecognizedRevenue),
      delivery: gapRow(state.targetDeliveryUnits, state.actualDeliveredUnits)
    };
    const acquisitionSuppressed = (state.unitContribution !== null && state.unitContribution <= 0) || state.capacityFeasible === false;
    let funnelTarget = null;
    let remainingFunnel = null;
    let sprintFunnelTarget = null;
    let sprintRemainingFunnel = null;
    let dailyTasks = { base: null, sprint: null };
    if (validation.conversionReady && state.monthlySalesTarget !== null && !acquisitionSuppressed) {
      funnelTarget = buildFunnelTarget(state.monthlySalesTarget, state.conversionRates);
      remainingFunnel = remainingFunnelFromActuals(funnelTarget, state.funnelActuals, validation.warnings);
      if (state.sprintFactor > 1) {
        sprintFunnelTarget = multiplyFunnelCounts(funnelTarget, state.sprintFactor);
        sprintRemainingFunnel = multiplyFunnelCounts(remainingFunnel, state.sprintFactor);
      }
      dailyTasks = {
        base: dailyFunnelCounts(remainingFunnel, state.remainingBusinessDays),
        sprint: sprintRemainingFunnel ? dailyFunnelCounts(sprintRemainingFunnel, state.remainingBusinessDays) : null
      };
    }
    const uniqueAction = chooseUniqueAction(state, gaps, funnelTarget, remainingFunnel, validation.calibrationMode);
    const calibration = validation.calibrationMode ? {
      mode: "seven_day_calibration",
      days: 7,
      generatesPreciseTargets: false,
      counters: [
        { stage: "outreach_to_response", numerator: "responses", denominator: "outreach" },
        { stage: "response_to_discussion", numerator: "discussions", denominator: "responses" },
        { stage: "discussion_to_quote", numerator: "quotes", denominator: "discussions" },
        { stage: "quote_to_sale", numerator: "deals", denominator: "quotes" }
      ]
    } : null;
    const channelAllocation = {
      base: remainingFunnel && state.channels.length ? allocateInteger(remainingFunnel.outreach, state.channels) : [],
      sprint: sprintRemainingFunnel && state.channels.length ? allocateInteger(sprintRemainingFunnel.outreach, state.channels) : []
    };
    const weeklyTasks = {
      base: allocateFunnelByRows(remainingFunnel, state.weekWeights),
      sprint: allocateFunnelByRows(sprintRemainingFunnel, state.weekWeights)
    };
    const preview = {
      actionPlanId,
      targetPlanId: state.targetPlanId,
      targetInputHash: state.targetInputHash,
      breakdownInputHash,
      targetMonth: state.targetMonth,
      progress: {
        actualCashReceived: state.actualCashReceived,
        actualDeals: state.actualDeals,
        actualRecognizedRevenue: state.actualRecognizedRevenue,
        actualDeliveredUnits: state.actualDeliveredUnits
      },
      gaps,
      remainingBusinessDays: state.remainingBusinessDays,
      conversionRates: clone(state.conversionRates),
      conversionBasis: state.conversionBasis || null,
      calibrationMode: validation.calibrationMode,
      calibration,
      funnelTargets: acquisitionSuppressed ? null : { base: funnelTarget, sprint: sprintFunnelTarget },
      remainingFunnelTasks: acquisitionSuppressed ? null : { base: remainingFunnel, sprint: sprintRemainingFunnel },
      dailyTasks: acquisitionSuppressed ? { base: null, sprint: null } : dailyTasks,
      channels: clone(state.channels),
      channelAllocation,
      weekWeights: clone(state.weekWeights),
      weeklyTasks,
      sprintFactor: state.sprintFactor,
      sprintApplied: state.sprintFactor > 1,
      acquisitionSuppressed,
      suppressedFunnelReason: acquisitionSuppressed
        ? (state.unitContribution <= 0 ? "non_positive_unit_contribution" : "capacity_not_feasible")
        : null,
      cashRiskCritical: state.cashRiskCritical,
      uniqueAction,
      targetTree: {
        profitRevenueTarget: state.executableProfitRevenue,
        cashReceivedTarget: state.minimumCashReceivedTarget,
        salesTarget: state.monthlySalesTarget,
        deliveryTarget: state.targetDeliveryUnits,
        funnelTarget,
        sprintFunnelTarget
      },
      warnings: validation.warnings.slice(),
      readiness: validation.metricReadiness
    };
    let dataStatus = "incomplete";
    if (validation.errors.length) dataStatus = "invalid";
    else if (validation.savable) dataStatus = "ready";
    const deterministicInput = Object.assign({}, state, { actionPlanId });
    return {
      calculationVersion: VERSION,
      schemaVersion: OPERATING_ACTION_SCHEMA_VERSION,
      planType: "operating_action_plan",
      hashAlgorithm: HASH_ALGORITHM,
      actionPlanId,
      targetPlanId: state.targetPlanId,
      targetInputHash: state.targetInputHash,
      breakdownInputHash,
      inputHash: breakdownInputHash,
      dataStatus,
      savable: validation.savable,
      deterministicInput,
      state: deterministicInput,
      missing: validation.missing,
      errors: validation.errors,
      warnings: validation.warnings,
      metricReadiness: validation.metricReadiness,
      preview,
      result: validation.savable ? preview : null
    };
  }

  function validateOperatingActionPlanRecord(record, expected) {
    const errors = [];
    const envelope = recordEnvelope(record, "operating_action_plan");
    if (!envelope) return { valid: false, errors: ["记录不包含完整的 operating_action_plan 确定性结果。"], recalculated: null };
    const input = recordInput(record, envelope);
    if (!input) return { valid: false, errors: ["行动计划缺少 deterministic input，无法重新运行公式。"], recalculated: null };
    const recalculated = calculateOperatingBreakdown(input);
    const options = validationOptions(expected, "expectedTargetInputHash");
    if (envelope.planType !== "operating_action_plan") errors.push("行动计划 record type 不匹配。");
    if (envelope.schemaVersion !== OPERATING_ACTION_SCHEMA_VERSION) errors.push("行动计划 schema version 不匹配。");
    if (!recalculated.savable || !recalculated.result) errors.push("行动计划输入无法重新生成完整确定性结果。");
    if (envelope.actionPlanId !== recalculated.actionPlanId) errors.push("行动计划 action_plan_id 与确定性输入不一致。");
    if (envelope.targetPlanId !== recalculated.targetPlanId) errors.push("行动计划 target_plan_id 与确定性输入不一致。");
    if (envelope.targetInputHash !== recalculated.targetInputHash) errors.push("行动计划 target_input_hash 与确定性输入不一致。");
    if (envelope.breakdownInputHash !== recalculated.breakdownInputHash) errors.push("行动计划 breakdown_input_hash 已过期或被修改。");
    if (envelope.inputHash !== undefined && envelope.inputHash !== recalculated.breakdownInputHash) errors.push("行动计划 inputHash 与 breakdown_input_hash 不一致。");
    if (!deepEqual(envelope.result, recalculated.result)) errors.push("行动计划中的确定性数字或唯一动作与公式复算结果不一致。");
    if (envelope.deterministicInput && !deepEqual(envelope.deterministicInput, input)) errors.push("行动计划内外 deterministic input 不一致。");
    if (options.expectedTargetInputHash && recalculated.targetInputHash !== options.expectedTargetInputHash) errors.push("行动计划绑定的目标哈希不是当前最新有效哈希。");
    if (options.expectedTargetPlanId && recalculated.targetPlanId !== options.expectedTargetPlanId) errors.push("行动计划绑定的目标方案不是当前最新有效方案。");
    const expectedTargetPlan = options.expectedTargetPlan || options.targetPlan;
    if (expectedTargetPlan && typeof expectedTargetPlan === "object") {
      const targetValidation = validateBusinessTargetPlanRecord(expectedTargetPlan);
      if (!targetValidation.valid) {
        errors.push("守卫提供的当前目标方案本身未通过确定性复算。");
      } else {
        const targetEnvelope = recordEnvelope(expectedTargetPlan, "business_target_plan");
        const targetResult = targetEnvelope.result;
        if (recalculated.targetPlanId !== targetEnvelope.targetPlanId) errors.push("行动计划未绑定守卫提供的当前目标方案 ID。");
        if (recalculated.targetInputHash !== targetEnvelope.targetInputHash) errors.push("行动计划未绑定守卫提供的当前目标输入哈希。");
        const targetFieldMap = {
          targetMonth: "targetMonth",
          targetProfit: "targetProfit",
          minimumCashReceivedTarget: "minimumCashReceivedTarget",
          monthlySalesTarget: "monthlySalesTarget",
          executableProfitRevenue: "executableProfitRevenue",
          targetDeliveryUnits: "targetDeliveryUnits",
          unitContribution: "unitContribution",
          capacityFeasible: "capacityFeasible"
        };
        Object.keys(targetFieldMap).forEach((inputField) => {
          const resultField = targetFieldMap[inputField];
          if (!deepEqual(recalculated.deterministicInput[inputField], targetResult[resultField])) {
            errors.push("行动计划修改了当前目标方案的确定性字段“" + resultField + "”。");
          }
        });
      }
    }

    const recordSources = [record || {}, envelope];
    const recordBreakdownHash = firstText(recordSources, ["breakdown_input_hash"], "");
    const recordTargetHash = firstText(recordSources, ["target_input_hash"], "");
    const recordActionId = firstText(recordSources, ["action_plan_id"], "");
    if (recordBreakdownHash && recordBreakdownHash !== recalculated.breakdownInputHash) errors.push("行动计划 frontmatter 的 breakdown_input_hash 不匹配。");
    if (recordTargetHash && recordTargetHash !== recalculated.targetInputHash) errors.push("行动计划 frontmatter 的 target_input_hash 不匹配。");
    if (recordActionId && recordActionId !== recalculated.actionPlanId) errors.push("行动计划 frontmatter 的 action_plan_id 不匹配。");
    return { valid: errors.length === 0, errors, recalculated };
  }

  function calculate(input) {
    if (input && input.inputMode === "quick_v3") return calculateQuickV3(input);
    if (input && input.inputMode === "quick_v2") return calculateQuick(input);
    const validation = validate(input);
    const inputHash = hashInput(validation.state);
    if (!validation.ready) {
      return {
        calculationVersion: VERSION,
        hashAlgorithm: HASH_ALGORITHM,
        inputHash,
        dataStatus: "incomplete",
        mode: validation.state.mode,
        state: validation.state,
        missing: validation.missing,
        errors: validation.errors,
        warnings: validation.warnings,
        result: null
      };
    }
    const result = validation.state.mode === "actual"
      ? calculateActual(validation.state, validation)
      : calculateForecast(validation.state, validation);
    return {
      calculationVersion: VERSION,
      hashAlgorithm: HASH_ALGORITHM,
      inputHash,
      dataStatus: "ready",
      mode: validation.state.mode,
      state: validation.state,
      missing: [],
      errors: [],
      warnings: result.warnings || [],
      result
    };
  }

  return Object.freeze({
    VERSION,
    HASH_ALGORITHM,
    QUICK_V3_SCHEMA_VERSION,
    BUSINESS_TARGET_SCHEMA_VERSION,
    OPERATING_ACTION_SCHEMA_VERSION,
    MODES,
    DELIVERY_MODELS,
    MODEL_LABELS,
    FIELD_LABELS,
    QUICK_FIELD_LABELS,
    TARGET_FIELD_LABELS,
    BREAKDOWN_FIELD_LABELS,
    INPUT_MODES,
    CONVERSION_BASES,
    cleanState,
    cleanQuickState,
    cleanQuickV2State,
    cleanQuickV3State,
    cleanBusinessTargetState,
    cleanOperatingBreakdownState,
    validate,
    validateBusinessTargetPlan,
    validateOperatingBreakdown,
    validateBusinessTargetPlanRecord,
    validateOperatingActionPlanRecord,
    calculate,
    getPeriodProfile,
    classifyLegacyQuickPeriod,
    calculateBusinessTargetPlan,
    calculateOperatingBreakdown,
    hashInput,
    stableStringify,
    clone
  });
});

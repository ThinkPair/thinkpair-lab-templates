"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");

const engine = require(path.resolve(
  __dirname,
  "..",
  "2_一人公司经营空间_首次选择这个文件夹",
  "90_系统设置_不用先看",
  "创业算账引擎.js"
));

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    passed += 1;
    process.stdout.write(`PASS ${name}\n`);
  } catch (error) {
    failed += 1;
    process.stderr.write(`FAIL ${name}\n${error.stack}\n`);
  }
}

function actualProduct(overrides = {}) {
  return Object.assign({
    id: "product-1",
    name: "测试产品",
    model: "instant",
    salesUnit: "单",
    deliveryUnit: "次",
    recognizedRevenue: "0.00",
    cashReceived: "0.00",
    revenueRefund: "0.00",
    cashRefund: "0.00",
    unitsDelivered: "0",
    directCost: "0.00",
    productFixedCost: "0.00",
    platformFees: "0.00",
    unfulfilledCost: "0.00",
    capacityUnits: "0",
    acceptedReceivable: "0.00"
  }, overrides);
}

function actualState({ company = {}, products = null, product = {} } = {}) {
  return {
    mode: "actual",
    periodStart: "2026-06-01",
    periodEnd: "2026-06-30",
    currency: "CNY",
    company: Object.assign({
      sharedFixedCost: "0.00",
      ownerWage: "0.00",
      taxCost: "0.00",
      cashOperatingOutflow: "0.00",
      ownerCashDraw: "0.00",
      availableCash: "0.00",
      payableReserve: "0.00",
      nearTermRigidOutflow: "0.00"
    }, company),
    products: products || [actualProduct(product)]
  };
}

function forecastProduct(overrides = {}) {
  return Object.assign({
    id: "forecast-product-1",
    name: "预估产品",
    model: "instant",
    salesUnit: "单",
    deliveryUnit: "次",
    unitPrice: "100.00",
    unitVariableCost: "40.00",
    productFixedCost: "500.00",
    feeRate: "0",
    refundRate: "0",
    collectionRate: "100",
    commitmentRate: "0",
    unitsLow: "50",
    unitsBase: "100",
    unitsHigh: "150",
    capacityUnits: "120"
  }, overrides);
}

function forecastState({ company = {}, products = null, product = {} } = {}) {
  return {
    mode: "forecast",
    periodStart: "2026-08-01",
    periodEnd: "2026-08-31",
    currency: "CNY",
    company: Object.assign({
      sharedFixedCost: "1000.00",
      ownerWage: "2000.00",
      taxRate: "0",
      availableCash: "20000.00",
      payableReserve: "0.00",
      nearTermRigidOutflow: "0.00",
      startupInvestment: "0.00"
    }, company),
    products: products || [forecastProduct(product)]
  };
}

function ready(input) {
  const output = engine.calculate(input);
  assert.equal(output.dataStatus, "ready", JSON.stringify({
    missing: output.missing,
    errors: output.errors
  }, null, 2));
  assert.ok(output.result);
  return output;
}

function quickActual(overrides = {}, topLevel = {}) {
  return Object.assign({
    inputMode: "quick_v2",
    mode: "actual",
    periodStart: "2026-06-01",
    periodEnd: "2026-06-30",
    currency: "CNY",
    offerName: "一人公司经营诊断",
    deliveryModel: "instant",
    unitLabel: "单",
    quick: Object.assign({
      recognizedRevenue: null,
      cashIn: null,
      cashOut: null,
      directCost: null,
      fixedCostExOwner: null,
      ownerWage: null,
      availableCash: null,
      remainingFulfillmentCost: null,
      completedUnits: null,
      next30RigidOutflow: null
    }, overrides)
  }, topLevel);
}

function quickForecast(overrides = {}, topLevel = {}) {
  return Object.assign({
    inputMode: "quick_v2",
    mode: "forecast",
    periodStart: "2026-08-01",
    periodEnd: "2026-08-31",
    currency: "CNY",
    offerName: "创业预估方案",
    deliveryModel: "subscription",
    unitLabel: "客户·月",
    quick: Object.assign({
      unitPrice: null,
      unitDirectCost: null,
      fixedCostExOwner: null,
      ownerWage: null,
      baseUnits: null,
      capacityUnits: null,
      cashAfterStartup: null,
      startupInvestment: null
    }, overrides)
  }, topLevel);
}

function quickActualV3(overrides = {}, topLevel = {}) {
  return Object.assign({
    inputMode: "quick_v3",
    schemaVersion: "finance.v2",
    mode: "actual",
    periodStart: "2026-06-01",
    periodEnd: "2026-06-30",
    periodEndInclusive: true,
    currency: "CNY",
    offerName: "一人公司经营诊断",
    deliveryModel: "instant",
    unitLabel: "单",
    quick: Object.assign({
      recognizedRevenue: null,
      cashIn: null,
      cashOut: null,
      directCost: null,
      monthlyFixedCostExOwner: null,
      monthlyOwnerWage: null,
      availableCash: null,
      remainingFulfillmentCost: null,
      completedUnits: null,
      next30RigidOutflow: null
    }, overrides)
  }, topLevel);
}

function targetInput(overrides = {}) {
  return Object.assign({
    calculationId: "calc-2026-07-001",
    sourceInputHash: "0123456789abcdef",
    targetMonth: "2026-07",
    targetProfit: 5000,
    targetCashIncrease: 2000,
    fixedOperatingCost: 3500,
    ownerWage: 6000,
    contributionMarginRate: 75,
    unitRecognizedRevenue: 2000,
    unitDirectCost: 500,
    maxStableDeliveryUnits: 20,
    averageCashCollectedPerSale: 2000
  }, overrides);
}

function readyTarget(overrides = {}) {
  const output = engine.calculateBusinessTargetPlan(targetInput(overrides));
  assert.equal(output.dataStatus, "ready", JSON.stringify({ missing: output.missing, errors: output.errors }, null, 2));
  assert.equal(output.savable, true);
  assert.ok(output.result);
  return output;
}

function breakdownInput(targetPlan, overrides = {}) {
  return Object.assign({
    targetPlan,
    progress: {
      actualCashReceived: 2500,
      actualDeals: 1,
      actualRecognizedRevenue: 3000,
      actualDeliveredUnits: 2
    },
    remainingBusinessDays: 10,
    conversionRates: {
      outreachToResponse: 20,
      responseToDiscussion: 30,
      discussionToQuote: 50,
      quoteToSale: 40
    },
    conversionBasis: "historical",
    sprintFactor: 1
  }, overrides);
}

test("空值保持不完整，不会被当成 0", () => {
  const output = engine.calculate({});
  assert.equal(output.dataStatus, "incomplete");
  assert.equal(output.result, null);
  assert.ok(output.missing.length > 0);
  assert.ok(output.errors.some((item) => item.includes("至少需要一个产品")));
});

test("用户明确填写的 0 是合法事实", () => {
  const output = ready(actualState());
  assert.equal(output.missing.length, 0);
  assert.equal(output.result.sustainableProfit, 0);
  assert.equal(output.result.cashNetChange, 0);
  assert.equal(output.result.safetyValue, 0);
  assert.equal(output.result.status.code, "on_break_even");
});

test("实际核账分开计算利润、现金和交付安全", () => {
  const output = ready(actualState({
    company: {
      sharedFixedCost: "1000.00",
      ownerWage: "2000.00",
      taxCost: "200.00",
      cashOperatingOutflow: "4800.00",
      ownerCashDraw: "0.00",
      availableCash: "15000.00",
      payableReserve: "500.00",
      nearTermRigidOutflow: "2000.00"
    },
    product: {
      recognizedRevenue: "10000.00",
      revenueRefund: "500.00",
      cashReceived: "9000.00",
      cashRefund: "500.00",
      unitsDelivered: "100",
      directCost: "3000.00",
      platformFees: "300.00",
      productFixedCost: "500.00",
      unfulfilledCost: "1000.00",
      capacityUnits: "200"
    }
  }));
  assert.equal(output.result.totalRecognizedRevenue, 9500);
  assert.equal(output.result.sustainableProfit, 2500);
  assert.equal(output.result.cashNetChange, 3700);
  assert.equal(output.result.totalCommitmentReserve, 1500);
  assert.equal(output.result.safetyValue, 11500);
  assert.equal(output.result.unitContribution, 62);
  assert.equal(output.result.breakEvenUnits, 60);
});

test("老板合理工资只影响利润，老板实际取款只影响现金", () => {
  const wageOnly = ready(actualState({
    company: { ownerWage: "3000.00", ownerCashDraw: "0.00" },
    product: { recognizedRevenue: "10000.00", cashReceived: "10000.00", unitsDelivered: "1", capacityUnits: "1" }
  })).result;
  const drawOnly = ready(actualState({
    company: { ownerWage: "0.00", ownerCashDraw: "3000.00" },
    product: { recognizedRevenue: "10000.00", cashReceived: "10000.00", unitsDelivered: "1", capacityUnits: "1" }
  })).result;
  assert.equal(wageOnly.sustainableProfit, 7000);
  assert.equal(wageOnly.cashNetChange, 10000);
  assert.equal(drawOnly.sustainableProfit, 10000);
  assert.equal(drawOnly.cashNetChange, 7000);
});

test("单位贡献为负时不生成伪保本量", () => {
  const result = ready(actualState({
    product: {
      recognizedRevenue: "1000.00",
      unitsDelivered: "10",
      directCost: "1000.00",
      platformFees: "100.00",
      capacityUnits: "100"
    }
  })).result;
  assert.equal(result.unitContribution, -10);
  assert.equal(result.breakEvenUnits, null);
  assert.match(result.breakEvenLabel, /单位贡献不为正/);
  assert.ok(result.warnings.some((item) => item.includes("单位贡献不为正")));
});

test("多产品汇总时公司共同固定成本只扣一次", () => {
  const products = [
    actualProduct({
      id: "a",
      name: "产品 A",
      recognizedRevenue: "8000.00",
      unitsDelivered: "80",
      directCost: "3000.00",
      platformFees: "200.00",
      productFixedCost: "500.00",
      capacityUnits: "100"
    }),
    actualProduct({
      id: "b",
      name: "产品 B",
      recognizedRevenue: "4000.00",
      unitsDelivered: "40",
      directCost: "1500.00",
      platformFees: "100.00",
      productFixedCost: "300.00",
      capacityUnits: "100"
    })
  ];
  const result = ready(actualState({
    company: { sharedFixedCost: "2000.00", ownerWage: "2000.00" },
    products
  })).result;
  assert.equal(result.totalRecognizedRevenue, 12000);
  assert.equal(result.sustainableProfit, 2400);
  assert.equal(result.breakEvenUnits, null);
});

test("创业预估同时输出保守、基准、乐观三档", () => {
  const result = ready(forecastState()).result;
  assert.equal(result.mode, "forecast");
  assert.equal(result.scenarios.length, 3);
  assert.deepEqual(result.scenarios.map((item) => item.scenario), ["low", "base", "high"]);
  assert.deepEqual(result.scenarios.map((item) => item.sustainableProfit), [-500, 2500, 5500]);
  assert.equal(result.sustainableProfit, 2500);
  assert.match(result.status.text, /基准预估/);
});

test("三档预估逐档校验交付产能", () => {
  const result = ready(forecastState()).result;
  const low = result.scenarios.find((item) => item.scenario === "low");
  const base = result.scenarios.find((item) => item.scenario === "base");
  const high = result.scenarios.find((item) => item.scenario === "high");
  assert.equal(low.capacityFeasible, true);
  assert.equal(base.capacityFeasible, true);
  assert.equal(high.capacityFeasible, false);
  assert.ok(high.capacityWarnings.some((item) => item.includes("超过交付能力")));
  assert.ok(result.warnings.some((item) => item.includes("乐观情景")));
});

test("任一核心输入变化都会改变 inputHash", () => {
  const before = ready(actualState({ product: { recognizedRevenue: "100.00" } }));
  const after = ready(actualState({ product: { recognizedRevenue: "100.01" } }));
  assert.notEqual(before.inputHash, after.inputHash);
  assert.equal(before.calculationVersion, after.calculationVersion);
  assert.equal(before.hashAlgorithm, "fnv1a64");
});

test("金额 1500.25 与 800.10 的差额精确为 700.15", () => {
  const result = ready(actualState({
    product: {
      recognizedRevenue: "1500.25",
      cashReceived: "1500.25",
      cashRefund: "800.10",
      unitsDelivered: "1",
      capacityUnits: "1"
    }
  })).result;
  assert.equal(result.totalRecognizedRevenue, 1500.25);
  assert.equal(result.cashNetChange, 700.15);
});

test("显式 finance.v1 仍走旧详细核算且结果不变", () => {
  const implicit = ready(actualState({
    company: { sharedFixedCost: "100", ownerWage: "200" },
    product: { recognizedRevenue: "1000", unitsDelivered: "10", directCost: "300", capacityUnits: "20" }
  }));
  const explicitState = actualState({
    company: { sharedFixedCost: "100", ownerWage: "200" },
    product: { recognizedRevenue: "1000", unitsDelivered: "10", directCost: "300", capacityUnits: "20" }
  });
  explicitState.inputMode = "finance.v1";
  const explicit = ready(explicitState);
  assert.deepEqual(explicit.result, implicit.result);
  assert.equal(explicit.inputHash, implicit.inputHash);
});

test("quick_v2 保留产品名称、交付模型与默认单位并进入哈希", () => {
  assert.ok(engine.INPUT_MODES.includes("quick_v2"));
  assert.notEqual(engine.VERSION, "1.0.0");
  const first = engine.calculate(quickActual({ cashIn: "100" }, { offerName: "服务 A", unitLabel: "" }));
  const second = engine.calculate(quickActual({ cashIn: "100" }, { offerName: "服务 B", unitLabel: "" }));
  assert.equal(first.state.offerName, "服务 A");
  assert.equal(first.state.deliveryModel, "instant");
  assert.equal(first.state.unitLabel, "单");
  assert.notEqual(first.inputHash, second.inputHash);
});

test("quick_v2 actual 只够算利润时返回 partial，不再被其他缺失项阻断", () => {
  const output = engine.calculate(quickActual({
    recognizedRevenue: "10000",
    directCost: "3000",
    fixedCostExOwner: "2000",
    ownerWage: "1000"
  }));
  assert.equal(output.dataStatus, "partial");
  assert.equal(output.savable, true);
  assert.equal(output.metricReadiness.profit.status, "ready");
  assert.equal(output.metricReadiness.cash.status, "missing");
  assert.equal(output.metricReadiness.safety.status, "missing");
  assert.equal(output.preview.sustainableProfit, 4000);
  assert.equal(output.result.sustainableProfit, 4000);
  assert.ok(output.missing.some((item) => item.field === "cashIn"));
});

test("quick_v2 actual 八个核心数字同时还原利润、现金与交付安全", () => {
  const output = engine.calculate(quickActual({
    recognizedRevenue: "10000.00",
    cashIn: "9000.00",
    cashOut: "7000.00",
    directCost: "3000.00",
    fixedCostExOwner: "2000.00",
    ownerWage: "1000.00",
    availableCash: "15000.00",
    remainingFulfillmentCost: "4000.00"
  }));
  assert.equal(output.dataStatus, "ready");
  assert.equal(output.savable, true);
  assert.equal(output.preview.sustainableProfit, 4000);
  assert.equal(output.preview.cashNetChange, 2000);
  assert.equal(output.preview.safetyValue, 8000);
  assert.equal(output.preview.safetyAssumption, "fixed_plus_owner_wage");
  assert.equal(output.preview.contributionRate, 70);
  assert.equal(output.preview.breakEvenRevenue, 4285.72);
  assert.equal(output.preview.breakEvenUnits, null);
  assert.equal(output.metricReadiness.diagnosis.status, "ready");
  assert.equal(output.preview.status.code, "profit_cash_positive");
});

test("quick_v2 actual 可选交付数量只控制单位毛利和保本数量", () => {
  const withoutUnits = engine.calculate(quickActual({
    recognizedRevenue: "10000",
    cashIn: "0",
    cashOut: "0",
    directCost: "3000",
    fixedCostExOwner: "2000",
    ownerWage: "1000",
    availableCash: "10000",
    remainingFulfillmentCost: "0"
  }));
  const withUnits = engine.calculate(quickActual({
    recognizedRevenue: "10000",
    cashIn: "0",
    cashOut: "0",
    directCost: "3000",
    fixedCostExOwner: "2000",
    ownerWage: "1000",
    availableCash: "10000",
    remainingFulfillmentCost: "0",
    completedUnits: "100"
  }));
  assert.equal(withoutUnits.dataStatus, "ready");
  assert.equal(withoutUnits.metricReadiness.unitEconomics.status, "missing");
  assert.equal(withoutUnits.preview.breakEvenRevenue, 4285.72);
  assert.equal(withUnits.metricReadiness.unitEconomics.status, "ready");
  assert.equal(withUnits.preview.unitPrice, 100);
  assert.equal(withUnits.preview.unitDirectCost, 30);
  assert.equal(withUnits.preview.unitContribution, 70);
  assert.equal(withUnits.preview.breakEvenUnits, 43);
});

test("quick_v2 actual 单位贡献不为正时不生成伪保本结果", () => {
  const output = engine.calculate(quickActual({
    recognizedRevenue: "1000",
    cashIn: "1000",
    cashOut: "1200",
    directCost: "1200",
    fixedCostExOwner: "100",
    ownerWage: "100",
    availableCash: "2000",
    remainingFulfillmentCost: "0",
    completedUnits: "10"
  }));
  assert.equal(output.dataStatus, "ready");
  assert.equal(output.preview.unitContribution, -20);
  assert.equal(output.preview.breakEvenRevenue, null);
  assert.equal(output.preview.breakEvenUnits, null);
  assert.equal(output.metricReadiness.breakEvenRevenue.status, "invalid");
  assert.equal(output.metricReadiness.breakEvenUnits.status, "invalid");
  assert.match(output.preview.breakEvenLabel, /做得越多亏得越多/);
});

test("quick_v2 actual 允许用真实未来30天支出覆盖保守安全假设", () => {
  const output = engine.calculate(quickActual({
    availableCash: "10000",
    remainingFulfillmentCost: "2000",
    next30RigidOutflow: "1500"
  }));
  assert.equal(output.dataStatus, "partial");
  assert.equal(output.metricReadiness.safety.status, "ready");
  assert.equal(output.preview.safetyValue, 6500);
  assert.equal(output.preview.safetyAssumption, "provided_next30_rigid_outflow");
});

test("quick_v2 actual 现金结果使用总流入减总流出并保持分币精度", () => {
  const output = engine.calculate(quickActual({ cashIn: "1500.25", cashOut: "800.10" }));
  assert.equal(output.dataStatus, "partial");
  assert.equal(output.metricReadiness.cash.status, "ready");
  assert.equal(output.preview.cashNetChange, 700.15);
});

test("quick_v2 forecast 两个数字即可先看到单位经济性", () => {
  const output = engine.calculate(quickForecast({ unitPrice: "100", unitDirectCost: "40" }));
  assert.equal(output.dataStatus, "partial");
  assert.equal(output.savable, true);
  assert.equal(output.metricReadiness.unitEconomics.status, "ready");
  assert.equal(output.metricReadiness.baseProfit.status, "missing");
  assert.equal(output.preview.unitContribution, 60);
  assert.equal(output.preview.contributionRate, 60);
});

test("quick_v2 forecast 六个核心数字得到保本量、产能占比和自动三档", () => {
  const output = engine.calculate(quickForecast({
    unitPrice: "100",
    unitDirectCost: "40",
    fixedCostExOwner: "1000",
    ownerWage: "2000",
    baseUnits: "50",
    capacityUnits: "100"
  }));
  assert.equal(output.dataStatus, "ready");
  assert.equal(output.preview.unitContribution, 60);
  assert.equal(output.preview.breakEvenUnits, 50);
  assert.equal(output.preview.breakEvenRevenue, 5000);
  assert.equal(output.preview.capacityRate, 50);
  assert.equal(output.preview.sustainableProfit, 0);
  assert.equal(output.preview.status.code, "forecast_healthy");
  assert.deepEqual(output.preview.scenarios.map((item) => item.units), [35, 50, 65]);
  assert.deepEqual(output.preview.scenarios.map((item) => item.sustainableProfit), [-900, 0, 900]);
  assert.equal(output.preview.cashNetChange, null);
});

test("quick_v2 forecast 乐观情景不会超过用户填写的稳定产能", () => {
  const output = engine.calculate(quickForecast({
    unitPrice: "100",
    unitDirectCost: "50",
    fixedCostExOwner: "1000",
    ownerWage: "1000",
    baseUnits: "80",
    capacityUnits: "90"
  }));
  assert.equal(output.preview.scenarios.find((item) => item.scenario === "high").units, 90);
});

test("quick_v2 forecast 按保本产能占比分级", () => {
  const achievable = engine.calculate(quickForecast({
    unitPrice: "100",
    unitDirectCost: "40",
    fixedCostExOwner: "1000",
    ownerWage: "2000",
    baseUnits: "50",
    capacityUnits: "63"
  }));
  const pressured = engine.calculate(quickForecast({
    unitPrice: "100",
    unitDirectCost: "40",
    fixedCostExOwner: "1000",
    ownerWage: "2000",
    baseUnits: "50",
    capacityUnits: "55"
  }));
  const impossible = engine.calculate(quickForecast({
    unitPrice: "100",
    unitDirectCost: "40",
    fixedCostExOwner: "1000",
    ownerWage: "2000",
    baseUnits: "50",
    capacityUnits: "40"
  }));
  assert.equal(achievable.preview.status.code, "forecast_achievable");
  assert.equal(pressured.preview.status.code, "forecast_high_pressure");
  assert.equal(impossible.preview.status.code, "forecast_not_feasible");
});

test("quick_v2 forecast 单位贡献不为正时输入仍完整但不生成保本量", () => {
  const output = engine.calculate(quickForecast({
    unitPrice: "100",
    unitDirectCost: "120",
    fixedCostExOwner: "1000",
    ownerWage: "2000",
    baseUnits: "50",
    capacityUnits: "100"
  }));
  assert.equal(output.dataStatus, "ready");
  assert.equal(output.preview.status.code, "forecast_non_positive_contribution");
  assert.equal(output.preview.breakEvenUnits, null);
  assert.equal(output.metricReadiness.breakEven.status, "invalid");
  assert.equal(output.metricReadiness.capacityFeasibility.status, "invalid");
  assert.ok(output.preview.warnings.some((item) => item.includes("扩大销量")));
});

test("quick_v2 forecast 可选现金和投入不阻断核心结果", () => {
  const withoutOptional = engine.calculate(quickForecast({
    unitPrice: "100",
    unitDirectCost: "40",
    fixedCostExOwner: "1000",
    ownerWage: "2000",
    baseUnits: "80",
    capacityUnits: "100"
  }));
  const withOptional = engine.calculate(quickForecast({
    unitPrice: "100",
    unitDirectCost: "40",
    fixedCostExOwner: "1000",
    ownerWage: "2000",
    baseUnits: "80",
    capacityUnits: "100",
    cashAfterStartup: "6000",
    startupInvestment: "6000"
  }));
  assert.equal(withoutOptional.dataStatus, "ready");
  assert.equal(withoutOptional.metricReadiness.cashBuffer.status, "missing");
  assert.equal(withOptional.preview.startupRunwayMonths, 2);
  assert.equal(withOptional.preview.sustainableProfit, 1800);
  assert.equal(withOptional.preview.paybackMonths, 3.33);
});

test("quick_v2 明确填写 0 与未知 null 继续严格区分", () => {
  const unknown = engine.calculate(quickActual());
  const explicitZero = engine.calculate(quickActual({ cashIn: "0", cashOut: "0" }));
  assert.equal(unknown.metricReadiness.cash.status, "missing");
  assert.equal(unknown.preview.cashNetChange, null);
  assert.equal(explicitZero.metricReadiness.cash.status, "ready");
  assert.equal(explicitZero.preview.cashNetChange, 0);
});

test("quick_v2 负数输入被标为 invalid，不能伪装成完整核算", () => {
  const output = engine.calculate(quickActual({
    recognizedRevenue: "1000",
    cashIn: "1000",
    cashOut: "-1",
    directCost: "200",
    fixedCostExOwner: "100",
    ownerWage: "100",
    availableCash: "1000",
    remainingFulfillmentCost: "0"
  }));
  assert.equal(output.dataStatus, "partial");
  assert.equal(output.metricReadiness.cash.status, "invalid");
  assert.equal(output.preview.cashNetChange, null);
  assert.ok(output.errors.some((item) => item.includes("现金流出")));
});

test("quick_v2 固定种子随机样本继续复现旧利润、现金、安全与保本公式", () => {
  let seed = 20260712;
  const randomInteger = (minimum, maximum) => {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    return minimum + (seed % (maximum - minimum + 1));
  };
  for (let index = 0; index < 32; index += 1) {
    const recognizedRevenue = randomInteger(1000, 50000);
    const directCost = randomInteger(0, recognizedRevenue - 1);
    const fixedCostExOwner = randomInteger(0, 10000);
    const ownerWage = randomInteger(0, 10000);
    const cashIn = randomInteger(0, 50000);
    const cashOut = randomInteger(0, 50000);
    const availableCash = randomInteger(-5000, 50000);
    const remainingFulfillmentCost = randomInteger(0, 10000);
    const output = engine.calculate(quickActual({
      recognizedRevenue,
      cashIn,
      cashOut,
      directCost,
      fixedCostExOwner,
      ownerWage,
      availableCash,
      remainingFulfillmentCost
    }));
    const contribution = recognizedRevenue - directCost;
    const expectedBreakEven = Math.ceil(((fixedCostExOwner + ownerWage) * 100) * (recognizedRevenue * 100) / (contribution * 100)) / 100;
    assert.equal(output.preview.sustainableProfit, contribution - fixedCostExOwner - ownerWage);
    assert.equal(output.preview.cashNetChange, cashIn - cashOut);
    assert.equal(output.preview.safetyValue, availableCash - remainingFulfillmentCost - fixedCostExOwner - ownerWage);
    assert.equal(output.preview.breakEvenRevenue, expectedBreakEven);
  }
});

test("quick_v3 全年核账按12个月成本计算利润，但安全和保本仍使用月值", () => {
  const output = engine.calculate(quickActualV3({
    recognizedRevenue: 3800000,
    cashIn: 5100000,
    cashOut: 5760000,
    directCost: 0,
    monthlyFixedCostExOwner: 450000,
    monthlyOwnerWage: 30000,
    availableCash: 400000,
    remainingFulfillmentCost: 0
  }, { periodStart: "2025-01-01", periodEnd: "2025-12-31", offerName: "儿童培训" }));
  assert.equal(output.dataStatus, "ready");
  assert.equal(output.schemaVersion, "finance.v2");
  assert.equal(output.periodProfile.totalDays, 365);
  assert.equal(output.preview.periodMonthFactor, 12);
  assert.equal(output.preview.periodFixedCostExOwner, 5400000);
  assert.equal(output.preview.periodOwnerWage, 360000);
  assert.equal(output.preview.sustainableProfit, -1960000);
  assert.equal(output.preview.cashNetChange, -660000);
  assert.equal(output.preview.safetyValue, -80000);
  assert.equal(output.preview.safetyNext30RigidOutflow, 480000);
  assert.equal(output.preview.monthlyBreakEvenRevenue, 480000);
  assert.equal(output.preview.breakEvenRevenue, 480000);
});

test("quick_v3 现金变化只使用本期实际流入减流出，不把月成本重复扣除", () => {
  const output = engine.calculate(quickActualV3({
    recognizedRevenue: 3800000,
    cashIn: 5100000,
    cashOut: 5520000,
    directCost: 0,
    monthlyFixedCostExOwner: 450000,
    monthlyOwnerWage: 30000,
    availableCash: 400000,
    remainingFulfillmentCost: 0
  }, { periodStart: "2025-01-01", periodEnd: "2025-12-31" }));
  assert.equal(output.preview.cashNetChange, -420000);
  assert.equal(output.preview.sustainableProfit, -1960000);
});

test("quick_v3 部分月按各自然月天数逐月分币折算成本", () => {
  const output = engine.calculate(quickActualV3({
    recognizedRevenue: 10000,
    cashIn: 0,
    cashOut: 0,
    directCost: 0,
    monthlyFixedCostExOwner: 2900,
    monthlyOwnerWage: 3100,
    availableCash: 10000,
    remainingFulfillmentCost: 0
  }, { periodStart: "2024-02-15", periodEnd: "2024-03-15" }));
  assert.equal(output.periodProfile.totalDays, 30);
  assert.equal(output.periodProfile.monthSegments[0].daysInMonth, 29);
  assert.equal(output.periodProfile.monthSegments[0].coveredDays, 15);
  assert.equal(output.periodProfile.monthSegments[1].daysInMonth, 31);
  assert.equal(output.preview.periodFixedCostExOwner, 2903.23);
  assert.equal(output.preview.periodOwnerWage, 3103.45);
  assert.equal(output.preview.sustainableProfit, 3993.32);
  assert.ok(output.warnings.some((item) => item.includes("部分自然月")));
});

test("period profile 正确识别闰月、完整单月与旧版歧义", () => {
  const leapMonth = engine.getPeriodProfile("2024-02-01", "2024-02-29", "quick_v2");
  assert.equal(leapMonth.valid, true);
  assert.equal(leapMonth.totalDays, 29);
  assert.equal(leapMonth.monthFactor, 1);
  assert.equal(leapMonth.isFullCalendarMonth, true);
  assert.equal(leapMonth.isLegacyPeriodAmbiguous, false);
  const legacyAnnual = engine.classifyLegacyQuickPeriod({
    inputMode: "quick_v2",
    periodStart: "2025-01-01",
    periodEnd: "2025-12-31"
  });
  assert.equal(legacyAnnual.isLegacyPeriodAmbiguous, true);
});

test("period profile 对多选一年后的第一天给出明确警告", () => {
  const profile = engine.getPeriodProfile("2025-01-01", "2026-01-01", "quick_v3");
  assert.equal(profile.valid, true);
  assert.equal(profile.totalDays, 366);
  assert.equal(profile.monthFactor, 12.0322580645);
  assert.ok(profile.warnings.some((item) => item.includes("多包含下一年第一天")));
});

test("quick_v3 非法日期或结束早于开始时拒绝保存", () => {
  const impossible = engine.calculate(quickActualV3({ cashIn: 100, cashOut: 0 }, {
    periodStart: "2025-02-30",
    periodEnd: "2025-03-01"
  }));
  const reversed = engine.getPeriodProfile("2025-03-02", "2025-03-01", "quick_v3");
  assert.equal(impossible.dataStatus, "invalid");
  assert.equal(impossible.savable, false);
  assert.equal(impossible.result, null);
  assert.ok(impossible.errors.some((item) => item.includes("开始日期无效")));
  assert.equal(reversed.valid, false);
  assert.ok(reversed.errors.some((item) => item.includes("不能早于")));
});

test("quick_v3 用户填写的未来30天支出覆盖月成本安全假设", () => {
  const output = engine.calculate(quickActualV3({
    availableCash: 10000,
    remainingFulfillmentCost: 2000,
    monthlyFixedCostExOwner: 5000,
    monthlyOwnerWage: 2000,
    next30RigidOutflow: 1500
  }));
  assert.equal(output.dataStatus, "partial");
  assert.equal(output.preview.safetyValue, 6500);
  assert.equal(output.preview.safetyNext30RigidOutflow, 1500);
  assert.equal(output.preview.safetyAssumption, "provided_next30_rigid_outflow");
});

test("quick_v3 非法可选字段使整条核算 invalid 且不产生可保存结果", () => {
  const base = {
    recognizedRevenue: 10000,
    cashIn: 10000,
    cashOut: 5000,
    directCost: 2000,
    monthlyFixedCostExOwner: 2000,
    monthlyOwnerWage: 1000,
    availableCash: 10000,
    remainingFulfillmentCost: 0
  };
  [
    { next30RigidOutflow: -1 },
    { next30RigidOutflow: "不是数字" },
    { completedUnits: 0 },
    { completedUnits: -1 },
    { completedUnits: "不是数字" }
  ].forEach((invalidOptional) => {
    const output = engine.calculate(quickActualV3(Object.assign({}, base, invalidOptional)));
    assert.equal(output.dataStatus, "invalid", JSON.stringify(invalidOptional));
    assert.equal(output.savable, false);
    assert.equal(output.result, null);
    assert.ok(output.errors.length > 0);
    assert.equal(output.metricReadiness.schema.status, "invalid");
  });
});

test("quick_v3 明确拒绝 periodEndInclusive false，不能静默改为包含结束日", () => {
  const output = engine.calculate(quickActualV3({ cashIn: 100, cashOut: 0 }, { periodEndInclusive: false }));
  assert.equal(output.state.periodEndInclusive, true);
  assert.equal(output.dataStatus, "invalid");
  assert.equal(output.savable, false);
  assert.equal(output.result, null);
  assert.ok(output.errors.some((item) => item.includes("不能为 false")));
});

test("quick_v3 新契约拒绝旧月成本字段，不能静默解释为月均值", () => {
  const input = quickActualV3({
    recognizedRevenue: 10000,
    cashIn: 10000,
    cashOut: 5000,
    directCost: 2000,
    fixedCostExOwner: 2000,
    ownerWage: 1000,
    availableCash: 10000,
    remainingFulfillmentCost: 0
  });
  delete input.quick.monthlyFixedCostExOwner;
  delete input.quick.monthlyOwnerWage;
  const output = engine.calculate(input);
  assert.equal(output.state.quick.monthlyFixedCostExOwner, null);
  assert.equal(output.state.quick.monthlyOwnerWage, null);
  assert.equal(output.dataStatus, "invalid");
  assert.equal(output.savable, false);
  assert.equal(output.result, null);
  assert.ok(output.errors.some((item) => item.includes("不接受旧字段 fixedCostExOwner")));
  assert.ok(output.errors.some((item) => item.includes("不接受旧字段 ownerWage")));
});

test("quick_v3 forecast 保持原有月度模型并接受显式月成本字段", () => {
  const output = engine.calculate({
    inputMode: "quick_v3",
    schemaVersion: "finance.v2",
    mode: "forecast",
    periodStart: "2026-08-01",
    periodEnd: "2026-08-31",
    unitLabel: "客户·月",
    quick: {
      unitPrice: 100,
      unitDirectCost: 40,
      monthlyFixedCostExOwner: 1000,
      monthlyOwnerWage: 2000,
      baseUnits: 50,
      capacityUnits: 100
    }
  });
  assert.equal(output.dataStatus, "ready");
  assert.equal(output.preview.sustainableProfit, 0);
  assert.equal(output.preview.monthlyBreakEvenRevenue, 5000);
  assert.equal(output.preview.breakEvenRevenue, 5000);
  assert.equal(output.preview.periodMonthFactor, 1);
});

test("quick_v3 forecast 仅允许完整自然月，部分月和跨月都拒绝保存", () => {
  const base = {
    inputMode: "quick_v3",
    schemaVersion: "finance.v2",
    mode: "forecast",
    unitLabel: "客户·月",
    quick: {
      unitPrice: 100,
      unitDirectCost: 40,
      monthlyFixedCostExOwner: 1000,
      monthlyOwnerWage: 2000,
      baseUnits: 50,
      capacityUnits: 100
    }
  };
  [
    { periodStart: "2026-08-02", periodEnd: "2026-08-31" },
    { periodStart: "2026-08-01", periodEnd: "2026-09-30" }
  ].forEach((period) => {
    const output = engine.calculate(Object.assign({}, base, period));
    assert.equal(output.dataStatus, "invalid", JSON.stringify(period));
    assert.equal(output.savable, false);
    assert.equal(output.result, null);
    assert.ok(output.errors.some((item) => item.includes("完整自然月")));
  });
});

test("经营目标优先读取 quick_v3 归一化月值而不是年度期间成本", () => {
  const calculation = engine.calculate(quickActualV3({
    recognizedRevenue: 20000,
    cashIn: 20000,
    cashOut: 10000,
    directCost: 5000,
    monthlyFixedCostExOwner: 3500,
    monthlyOwnerWage: 6000,
    availableCash: 20000,
    remainingFulfillmentCost: 0,
    completedUnits: 10
  }, { periodStart: "2025-01-01", periodEnd: "2025-12-31" }));
  calculation.calculationId = "calc-v3-annual";
  const target = engine.calculateBusinessTargetPlan({
    sourceCalculation: calculation,
    targetMonth: "2026-07",
    targetProfit: 5000,
    targetCashIncrease: 2000,
    fixedOperatingCost: 999999,
    ownerWage: 999999,
    maxStableDeliveryUnits: 20,
    averageCashCollectedPerSale: 2000
  });
  assert.equal(target.dataStatus, "ready", JSON.stringify(target.errors));
  assert.equal(target.result.fixedOperatingCost, 3500);
  assert.equal(target.result.ownerWage, 6000);
  assert.equal(target.result.fixedOperatingNeed, 9500);
  assert.equal(target.result.targetDeliveryUnits, 10);
  assert.equal(engine.validateBusinessTargetPlanRecord(target).valid, true);
});

test("旧 quick_v2 跨月记录退出完整月目标，完整单月仍保持兼容", () => {
  const legacyAnnual = engine.calculate(quickActual({
    recognizedRevenue: 10000,
    cashIn: 10000,
    cashOut: 6000,
    directCost: 2500,
    fixedCostExOwner: 3500,
    ownerWage: 6000,
    availableCash: 20000,
    remainingFulfillmentCost: 0,
    completedUnits: 5
  }, { periodStart: "2025-01-01", periodEnd: "2025-12-31" }));
  legacyAnnual.calculationId = "calc-v2-annual";
  const blocked = engine.calculateBusinessTargetPlan({
    sourceCalculation: legacyAnnual,
    targetMonth: "2026-07",
    targetProfit: 5000,
    targetCashIncrease: 0,
    maxStableDeliveryUnits: 20,
    averageCashCollectedPerSale: 2000
  });
  assert.equal(blocked.dataStatus, "invalid");
  assert.equal(blocked.savable, false);
  assert.ok(blocked.errors.some((item) => item.includes("成本口径不明确")));

  const legacyMonth = engine.calculate(quickActual({
    recognizedRevenue: 10000,
    cashIn: 10000,
    cashOut: 6000,
    directCost: 2500,
    fixedCostExOwner: 3500,
    ownerWage: 6000,
    availableCash: 20000,
    remainingFulfillmentCost: 0,
    completedUnits: 5
  }));
  legacyMonth.calculationId = "calc-v2-month";
  const compatible = engine.calculateBusinessTargetPlan({
    sourceCalculation: legacyMonth,
    targetMonth: "2026-07",
    targetProfit: 5000,
    targetCashIncrease: 0,
    maxStableDeliveryUnits: 20,
    averageCashCollectedPerSale: 2000
  });
  assert.equal(compatible.dataStatus, "ready", JSON.stringify(compatible.errors));
});

test("v0.1.3 导出跨周期、目标计划、经营拆解与记录复算接口", () => {
  assert.equal(engine.VERSION, "1.3.0");
  assert.equal(engine.QUICK_V3_SCHEMA_VERSION, "finance.v2");
  assert.equal(engine.BUSINESS_TARGET_SCHEMA_VERSION, "business_target_plan.v1");
  assert.equal(engine.OPERATING_ACTION_SCHEMA_VERSION, "operating_action_plan.v1");
  [
    "calculateBusinessTargetPlan",
    "validateBusinessTargetPlan",
    "calculateOperatingBreakdown",
    "validateOperatingBreakdown",
    "validateBusinessTargetPlanRecord",
    "validateOperatingActionPlanRecord",
    "getPeriodProfile",
    "classifyLegacyQuickPeriod"
  ].forEach((name) => assert.equal(typeof engine[name], "function", name));
});

test("v0.1.2 目标与行动确定性哈希、记录复算保持兼容", () => {
  const target = engine.calculateBusinessTargetPlan(targetInput());
  assert.equal(target.targetInputHash, "6798aa12c80d9458");
  assert.equal(target.targetPlanId, "btp-6798aa12c80d9458");
  assert.equal(Object.prototype.hasOwnProperty.call(target.deterministicInput, "sourceCalculationInputMode"), false);
  assert.equal(Object.prototype.hasOwnProperty.call(target.deterministicInput, "sourcePeriodStatus"), false);
  assert.equal(Object.prototype.hasOwnProperty.call(target.deterministicInput, "sourcePeriodWarnings"), false);
  const oldTargetRecord = engine.clone(target);
  oldTargetRecord.calculationVersion = "1.2.0";
  delete oldTargetRecord.sourceDiagnostics;
  assert.equal(engine.validateBusinessTargetPlanRecord(oldTargetRecord).valid, true);

  const action = engine.calculateOperatingBreakdown(breakdownInput(oldTargetRecord));
  assert.equal(action.breakdownInputHash, "55abe1095e703dc8");
  assert.equal(action.actionPlanId, "oap-55abe1095e703dc8");
  const oldActionRecord = engine.clone(action);
  oldActionRecord.calculationVersion = "1.2.0";
  assert.equal(engine.validateOperatingActionPlanRecord(oldActionRecord).valid, true);
});

test("盈利目标示例同时得到保本、整数交付、现金与成交双闭环", () => {
  const result = readyTarget().result;
  assert.equal(result.fixedOperatingNeed, 9500);
  assert.equal(result.breakEvenRevenue, 12666.67);
  assert.equal(result.breakEvenDeliveryUnits, 7);
  assert.equal(result.executableBreakEvenRevenue, 14000);
  assert.equal(result.theoreticalProfitRevenue, 19333.34);
  assert.equal(result.targetDeliveryUnits, 10);
  assert.equal(result.executableProfitRevenue, 20000);
  assert.equal(result.estimatedVariableCashCost, 5000);
  assert.equal(result.rigidCashNeed, 9500);
  assert.equal(result.minimumCashReceivedTarget, 16500);
  assert.equal(result.monthlySalesTarget, 9);
  assert.equal(result.capacityUtilizationRate, 50);
  assert.equal(result.capacityFeasible, true);
});

test("目标计划可直接读取 quick_v2 核算输出并只补原核算没有的字段", () => {
  const calculation = engine.calculate(quickActual({
    recognizedRevenue: 10000,
    cashIn: 10000,
    cashOut: 6000,
    directCost: 2500,
    fixedCostExOwner: 3500,
    ownerWage: 6000,
    availableCash: 20000,
    remainingFulfillmentCost: 0,
    completedUnits: 5
  }));
  const target = engine.calculateBusinessTargetPlan({
    sourceCalculation: calculation,
    calculationId: "calc-from-quick",
    targetMonth: "2026-07",
    targetProfit: 5000,
    targetCashIncrease: 2000,
    maxStableDeliveryUnits: 20,
    averageCashCollectedPerSale: 2000
  });
  assert.equal(target.dataStatus, "ready");
  assert.equal(target.sourceInputHash, calculation.inputHash);
  assert.equal(target.result.fixedOperatingCost, 3500);
  assert.equal(target.result.ownerWage, 6000);
  assert.equal(target.result.unitRecognizedRevenue, 2000);
  assert.equal(target.result.unitDirectCost, 500);
  assert.equal(target.result.targetDeliveryUnits, 10);
});

test("目标现金增加默认 0，合理工资同时进入利润线与现金保底线", () => {
  const result = readyTarget({ targetCashIncrease: undefined }).result;
  assert.equal(result.targetCashIncrease, 0);
  assert.equal(result.fixedOperatingNeed, 9500);
  assert.equal(result.rigidCashNeed, 9500);
  assert.equal(result.minimumCashReceivedTarget, 14500);
});

test("合理工资缺失时不生成完整盈利或现金目标", () => {
  const output = engine.calculateBusinessTargetPlan(targetInput({ ownerWage: null }));
  assert.equal(output.savable, false);
  assert.equal(output.result, null);
  assert.equal(output.preview.fixedOperatingNeed, null);
  assert.equal(output.preview.theoreticalProfitRevenue, null);
  assert.equal(output.preview.minimumCashReceivedTarget, null);
  assert.ok(output.missing.some((item) => item.field === "ownerWage"));
});

test("单位贡献不为正时保存阻断事实但不生成任何伪目标", () => {
  const output = engine.calculateBusinessTargetPlan(targetInput({
    contributionMarginRate: null,
    unitRecognizedRevenue: 1000,
    unitDirectCost: 1200,
    maxStableDeliveryUnits: null
  }));
  assert.equal(output.dataStatus, "ready");
  assert.equal(output.savable, true);
  assert.equal(output.result.planStatus.code, "blocked_unit_economics");
  assert.equal(output.result.unitContribution, -200);
  assert.equal(output.result.breakEvenRevenue, null);
  assert.equal(output.result.theoreticalProfitRevenue, null);
  assert.equal(output.result.targetDeliveryUnits, null);
  assert.equal(output.result.executableProfitRevenue, null);
  assert.equal(output.result.minimumCashReceivedTarget, null);
  assert.equal(output.result.monthlySalesTarget, null);
});

test("单位贡献阻断可直达确定性的修定价成本唯一动作", () => {
  const target = engine.calculateBusinessTargetPlan(targetInput({
    contributionMarginRate: 0,
    unitRecognizedRevenue: 500,
    unitDirectCost: 500
  }));
  const action = engine.calculateOperatingBreakdown({ targetPlan: target });
  assert.equal(action.dataStatus, "ready");
  assert.equal(action.result.uniqueAction.code, "fix_unit_economics");
  assert.equal(action.result.acquisitionSuppressed, true);
  assert.equal(action.result.funnelTargets, null);
  assert.equal(action.result.calibrationMode, false);
});

test("盈利交付目标超过产能时判定不可行并禁止扩大获客", () => {
  const target = readyTarget({ maxStableDeliveryUnits: 9 });
  assert.equal(target.result.capacityFeasible, false);
  assert.equal(target.result.capacityStatus.code, "not_feasible");
  assert.equal(target.result.planStatus.code, "blocked_capacity");
  const action = engine.calculateOperatingBreakdown(breakdownInput(target, { cashRiskCritical: true }));
  assert.equal(action.result.uniqueAction.code, "fix_capacity_model");
  assert.equal(action.result.acquisitionSuppressed, true);
  assert.equal(action.result.funnelTargets, null);
});

test("缺少平均每单实收时保留实收金额目标但不伪造成交单数", () => {
  const target = readyTarget({ averageCashCollectedPerSale: null });
  assert.equal(target.result.minimumCashReceivedTarget, 16500);
  assert.equal(target.result.monthlySalesTarget, null);
  assert.equal(target.metricReadiness.salesCount.status, "missing");
  const action = engine.calculateOperatingBreakdown(breakdownInput(target));
  assert.equal(action.result.gaps.deals.target, null);
  assert.equal(action.result.funnelTargets.base, null);
  assert.equal(action.result.uniqueAction.code, "confirm_average_cash_per_sale");
});

test("已填未来刚性支出覆盖默认口径且现金公式仍单独显示来源", () => {
  const result = readyTarget({ futureRigidCashOutflow: 12000 }).result;
  assert.equal(result.rigidCashNeed, 12000);
  assert.equal(result.rigidCashNeedSource, "provided_future_rigid_outflow");
  assert.equal(result.minimumCashReceivedTarget, 19000);
});

test("已填未来刚性支出低于合理工资时拒绝保存且不生成现金伪目标", () => {
  const output = engine.calculateBusinessTargetPlan(targetInput({ futureRigidCashOutflow: 5000 }));
  assert.equal(output.dataStatus, "invalid");
  assert.equal(output.savable, false);
  assert.equal(output.result, null);
  assert.equal(output.metricReadiness.cashLine.status, "invalid");
  assert.equal(output.metricReadiness.salesCount.status, "invalid");
  assert.equal(output.preview.rigidCashNeed, null);
  assert.equal(output.preview.minimumCashReceivedTarget, null);
  assert.equal(output.preview.monthlySalesTarget, null);
  assert.ok(output.errors.some((item) => item.includes("必须包含创业者合理工资")));
});

test("目标输入任一变化都会改变 targetInputHash 并绑定来源核算哈希", () => {
  const before = readyTarget({ targetProfit: 5000 });
  const after = readyTarget({ targetProfit: 5001 });
  assert.notEqual(before.targetInputHash, after.targetInputHash);
  assert.equal(before.sourceInputHash, "0123456789abcdef");
  assert.equal(before.inputHash, before.targetInputHash);
});

test("目标接口接受 snake_case 且得到同一确定性结果", () => {
  const camel = readyTarget({ targetCashIncrease: 0 });
  const snake = engine.calculateBusinessTargetPlan({
    calculation_id: "calc-2026-07-001",
    source_input_hash: "0123456789abcdef",
    target_month: "2026-07",
    target_profit: 5000,
    target_cash_increase: 0,
    fixed_operating_cost: 3500,
    owner_wage: 6000,
    contribution_margin_rate: 75,
    unit_recognized_revenue: 2000,
    unit_direct_cost: 500,
    max_stable_delivery_units: 20,
    average_cash_collected_per_sale: 2000
  });
  assert.equal(snake.dataStatus, "ready");
  assert.deepEqual(snake.result, camel.result);
  assert.equal(snake.targetInputHash, camel.targetInputHash);
});

test("目标记录复算拒绝 AI 改数字与旧核算哈希", () => {
  const target = readyTarget();
  assert.equal(engine.validateBusinessTargetPlanRecord({ input: target.deterministicInput, result: target }).valid, true);
  const tampered = engine.clone(target);
  tampered.result.executableProfitRevenue = 999999;
  const tamperedCheck = engine.validateBusinessTargetPlanRecord(tampered);
  assert.equal(tamperedCheck.valid, false);
  assert.ok(tamperedCheck.errors.some((item) => item.includes("确定性数字")));
  const staleCheck = engine.validateBusinessTargetPlanRecord(target, "ffffffffffffffff");
  assert.equal(staleCheck.valid, false);
  assert.ok(staleCheck.errors.some((item) => item.includes("最新有效哈希")));
  const forgedSource = readyTarget({ fixedOperatingCost: 1 });
  const sourceGuard = engine.validateBusinessTargetPlanRecord(forgedSource, {
    expectedSourceInputHash: "0123456789abcdef",
    expectedSourceValues: targetInput()
  });
  assert.equal(sourceGuard.valid, false);
  assert.ok(sourceGuard.errors.some((item) => item.includes("来源字段")));
});

test("已知转化率逐级向上取整，并按每阶段真实进度计算当前差额", () => {
  const target = readyTarget();
  const output = engine.calculateOperatingBreakdown(breakdownInput(target, {
    funnelActuals: { outreach: 50, responses: 10, discussions: 4, quotes: 2, deals: 1 }
  }));
  assert.equal(output.dataStatus, "ready");
  assert.deepEqual(output.result.funnelTargets.base, {
    outreach: 770,
    responses: 154,
    discussions: 46,
    quotes: 23,
    deals: 9
  });
  assert.deepEqual(output.result.remainingFunnelTasks.base, {
    outreach: 720,
    responses: 144,
    discussions: 42,
    quotes: 21,
    deals: 8
  });
  assert.deepEqual(output.result.dailyTasks.base, {
    outreach: 72,
    responses: 15,
    discussions: 5,
    quotes: 3,
    deals: 1
  });
});

test("漏斗实际进度未知时显式标注按 0 保守计算，不冒充真实完成数", () => {
  const output = engine.calculateOperatingBreakdown(breakdownInput(readyTarget()));
  assert.equal(output.result.remainingFunnelTasks.base.outreach, output.result.funnelTargets.base.outreach);
  assert.equal(output.result.remainingFunnelTasks.base.quotes, output.result.funnelTargets.base.quotes);
  assert.equal(output.result.remainingFunnelTasks.base.deals, 8);
  assert.ok(output.warnings.some((item) => item.includes("保守口径")));
});

test("完全未知转化率进入七天校准且不生成伪精确漏斗", () => {
  const output = engine.calculateOperatingBreakdown(breakdownInput(readyTarget(), {
    conversionRates: {},
    conversionBasis: undefined
  }));
  assert.equal(output.dataStatus, "ready");
  assert.equal(output.result.calibrationMode, true);
  assert.equal(output.result.calibration.mode, "seven_day_calibration");
  assert.equal(output.result.calibration.generatesPreciseTargets, false);
  assert.equal(output.result.funnelTargets.base, null);
  assert.equal(output.result.dailyTasks.base, null);
  assert.equal(output.result.uniqueAction.code, "calibrate_funnel_7_days");
});

test("渠道占比和周权重不等于 100% 时拒绝行动计划", () => {
  const output = engine.calculateOperatingBreakdown(breakdownInput(readyTarget(), {
    channels: [
      { name: "私域", sharePercent: 60 },
      { name: "内容", sharePercent: 30 }
    ],
    weekWeights: [40, 40]
  }));
  assert.equal(output.dataStatus, "invalid");
  assert.equal(output.result, null);
  assert.ok(output.errors.some((item) => item.includes("渠道占比必须合计 100%")));
  assert.ok(output.errors.some((item) => item.includes("周权重占比必须合计 100%")));
});

test("冲刺系数单独显示，不会暗改基础漏斗目标", () => {
  const target = readyTarget();
  const base = engine.calculateOperatingBreakdown(breakdownInput(target, {
    funnelActuals: { outreach: 0, responses: 0, discussions: 0, quotes: 0, deals: 1 },
    channels: [
      { name: "私域", sharePercent: 60 },
      { name: "内容", sharePercent: 40 }
    ],
    weekWeights: [50, 50]
  }));
  const sprint = engine.calculateOperatingBreakdown(breakdownInput(target, {
    funnelActuals: { outreach: 0, responses: 0, discussions: 0, quotes: 0, deals: 1 },
    channels: [
      { name: "私域", sharePercent: 60 },
      { name: "内容", sharePercent: 40 }
    ],
    weekWeights: [50, 50],
    sprintFactor: 1.2
  }));
  assert.deepEqual(sprint.result.funnelTargets.base, base.result.funnelTargets.base);
  assert.equal(base.result.funnelTargets.sprint, null);
  assert.equal(sprint.result.sprintFactor, 1.2);
  assert.equal(sprint.result.sprintApplied, true);
  assert.ok(sprint.result.funnelTargets.sprint.outreach > sprint.result.funnelTargets.base.outreach);
  assert.equal(sprint.result.channelAllocation.base.reduce((sum, item) => sum + item.count, 0), sprint.result.remainingFunnelTasks.base.outreach);
  assert.equal(sprint.result.weeklyTasks.base.reduce((sum, item) => sum + item.tasks.quotes, 0), sprint.result.remainingFunnelTasks.base.quotes);
});

test("现金缺口危及经营时收款动作优先于普通漏斗断点", () => {
  const output = engine.calculateOperatingBreakdown(breakdownInput(readyTarget(), {
    cashRiskCritical: true,
    funnelActuals: { outreach: 0, responses: 0, discussions: 0, quotes: 0, deals: 1 }
  }));
  assert.equal(output.result.gaps.cashReceived.remaining, 14000);
  assert.equal(output.result.uniqueAction.code, "collect_cash_first");
});

test("销售、实收、确认收入与交付进度保持四条独立差额", () => {
  const output = engine.calculateOperatingBreakdown(breakdownInput(readyTarget(), {
    progress: {
      actualCashReceived: 16500,
      actualDeals: 9,
      actualRecognizedRevenue: 10000,
      actualDeliveredUnits: 2
    },
    funnelActuals: { outreach: 770, responses: 154, discussions: 46, quotes: 23, deals: 9 }
  }));
  assert.equal(output.result.gaps.cashReceived.remaining, 0);
  assert.equal(output.result.gaps.deals.remaining, 0);
  assert.equal(output.result.gaps.recognizedRevenue.remaining, 10000);
  assert.equal(output.result.gaps.delivery.remaining, 8);
});

test("行动计划哈希包含进度快照并拒绝被改数字或旧目标哈希", () => {
  const target = readyTarget();
  const before = engine.calculateOperatingBreakdown(breakdownInput(target));
  const after = engine.calculateOperatingBreakdown(breakdownInput(target, {
    progress: {
      actualCashReceived: 2501,
      actualDeals: 1,
      actualRecognizedRevenue: 3000,
      actualDeliveredUnits: 2
    }
  }));
  assert.notEqual(before.breakdownInputHash, after.breakdownInputHash);
  assert.equal(engine.validateOperatingActionPlanRecord({ input: before.deterministicInput, result: before }).valid, true);
  const tampered = engine.clone(before);
  tampered.result.uniqueAction.code = "ai_changed_number_or_action";
  assert.equal(engine.validateOperatingActionPlanRecord(tampered).valid, false);
  const stale = engine.validateOperatingActionPlanRecord(before, "ffffffffffffffff");
  assert.equal(stale.valid, false);
  assert.ok(stale.errors.some((item) => item.includes("最新有效哈希")));
  const forgedInput = engine.clone(before.deterministicInput);
  forgedInput.minimumCashReceivedTarget = 1;
  const forged = engine.calculateOperatingBreakdown(forgedInput);
  const targetGuard = engine.validateOperatingActionPlanRecord(forged, { expectedTargetPlan: target });
  assert.equal(targetGuard.valid, false);
  assert.ok(targetGuard.errors.some((item) => item.includes("确定性字段")));
});

process.stdout.write(`\nFinance engine tests: ${passed} passed, ${failed} failed.\n`);
if (failed > 0) process.exitCode = 1;

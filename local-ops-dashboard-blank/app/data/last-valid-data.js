window.DASHBOARD_DATA = {
  "schemaVersion": 1,
  "meta": {
    "dashboardTitle": "降噪实验室",
    "periodLabel": "演示样本周期（虚构数据）",
    "periodStart": "",
    "periodEnd": "",
    "generatedAt": "2026-08-01",
    "identityDeduplicated": false,
    "status": "demo"
  },
  "platforms": [
    { "id": "douyin", "label": "抖音" },
    { "id": "xhs", "label": "小红书" },
    { "id": "bilibili", "label": "B站" }
  ],
  "stages": [
    {
      "id": "reach",
      "values": {
        "douyin": { "value": 12400, "state": "estimated", "sourceRefs": ["演示样本"] },
        "xhs": { "value": 5680, "state": "estimated", "sourceRefs": ["演示样本"] },
        "bilibili": { "value": 2320, "state": "estimated", "sourceRefs": ["演示样本"] }
      },
      "sourceRefs": ["演示样本"]
    },
    {
      "id": "follow",
      "values": {
        "douyin": { "value": 218, "state": "estimated", "sourceRefs": ["演示样本"] },
        "xhs": { "value": 96, "state": "estimated", "sourceRefs": ["演示样本"] },
        "bilibili": { "value": 54, "state": "estimated", "sourceRefs": ["演示样本"] }
      },
      "sourceRefs": ["演示样本"]
    },
    {
      "id": "lead",
      "values": {
        "douyin": { "value": 14, "state": "estimated", "sourceRefs": ["演示样本"] },
        "xhs": { "value": 8, "state": "estimated", "sourceRefs": ["演示样本"] },
        "bilibili": { "value": 4, "state": "estimated", "sourceRefs": ["演示样本"] }
      },
      "sourceRefs": ["演示样本"]
    },
    {
      "id": "conversation",
      "values": {
        "douyin": { "value": 6, "state": "estimated", "sourceRefs": ["演示样本"] },
        "xhs": { "value": 3, "state": "estimated", "sourceRefs": ["演示样本"] },
        "bilibili": { "value": 2, "state": "estimated", "sourceRefs": ["演示样本"] }
      },
      "sourceRefs": ["演示样本"]
    },
    {
      "id": "paid",
      "values": {
        "douyin": { "value": 2, "state": "estimated", "sourceRefs": ["演示样本"] },
        "xhs": { "value": 1, "state": "estimated", "sourceRefs": ["演示样本"] },
        "bilibili": { "value": 1, "state": "estimated", "sourceRefs": ["演示样本"] }
      },
      "sourceRefs": ["演示样本"]
    },
    {
      "id": "renewal",
      "values": {
        "douyin": { "value": 1, "state": "estimated", "sourceRefs": ["演示样本"] },
        "xhs": { "value": 0, "state": "confirmed", "sourceRefs": ["演示样本"] },
        "bilibili": { "value": 0, "state": "confirmed", "sourceRefs": ["演示样本"] }
      },
      "sourceRefs": ["演示样本"]
    }
  ],
  "leadTrend": [
    { "week": "第1周", "douyin": 5, "xhs": 2, "bilibili": 1 },
    { "week": "第2周", "douyin": 8, "xhs": 4, "bilibili": 2 },
    { "week": "第3周", "douyin": 11, "xhs": 6, "bilibili": 3 },
    { "week": "第4周", "douyin": 14, "xhs": 8, "bilibili": 4 }
  ],
  "episodePlays": [
    { "episode": "第01期", "douyin": 1860, "xhs": 640, "bilibili": 220, "note": "演示样本" },
    { "episode": "第02期", "douyin": 3240, "xhs": 1180, "bilibili": 460, "note": "演示样本" },
    { "episode": "第03期", "douyin": 5420, "xhs": 2050, "bilibili": 780, "note": "演示样本" }
  ],
  "attribution": [
    { "title": "演示内容A：为什么老板需要一张经营看板", "platformId": "douyin", "leads": 8, "conversations": 4, "paid": 2, "sourceRefs": ["演示样本"] },
    { "title": "演示内容B：从评论区痛点到一个具体场景", "platformId": "xhs", "leads": 6, "conversations": 3, "paid": 1, "sourceRefs": ["演示样本"] },
    { "title": "演示内容C：知识库越积累越容易失真", "platformId": "bilibili", "leads": 4, "conversations": 2, "paid": 1, "sourceRefs": ["演示样本"] }
  ],
  "evidence": [
    {
      "time": "演示样本",
      "item": "本页全部为虚构演示数据，仅用于展示看板界面效果",
      "source": "演示模式（?demo=1）",
      "value": "非真实经营数据",
      "state": "estimated",
      "sourceRefs": ["演示样本"]
    }
  ]
};

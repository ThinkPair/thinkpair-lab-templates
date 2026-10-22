---
record_type: directory_readme
privacy: private
schema_version: "operating_action_plan.v1"
---

# 经营行动计划

本目录保存 AI 主持目标拆解后，经确定性脚本计算、一次完整预览和一次用户明确同意才新增的 `operating_action_plan`。空白母版只保留本说明，不包含进度、转化率、渠道占比、周权重或行动。

## 数据契约

- 文件名必须等于 `<action_plan_id>.md`，默认格式为 `oap-<16 位哈希>.md`；记录只允许新增，禁止 Edit 或覆盖旧文件。
- 记录绑定 `target_plan_id + target_input_hash + breakdown_input_hash`，使用 `hash_algorithm: fnv1a64`、`record_status: active` 与 `schema_version: operating_action_plan.v1`。
- `operating-action-plan-json` 数据块必须保存 `{ "input": <deterministicInput>, "result": <完整 operating_action_plan envelope> }`。
- 写入守卫调用 `validateOperatingActionPlanRecord` 和同一目标拆解脚本复算，拒绝旧目标、目标快照换绑、哈希失配、数字或唯一动作篡改、非法占比、隐藏冲刺系数和越权路径。
- 目标输入改变后，旧行动只保留历史并退出当前首页；进度更新必须生成新行动记录，不编辑旧行动。

## 权限与隐私

用户直接要求保存行动拆解时，该指令授权 AI Write 一条新的行动计划；如果是 AI 主动提议落库，则先展示一次目标、关键变化和唯一动作，再由用户或原生窗口确认一次。守卫在实际写入时校验目标来源、业务哈希和确定性公式，不让用户处理技术授权信息。实际实收、成交单数、确认收入、交付量、转化依据和渠道分配均为敏感经营数据。

备份必须保留本目录全部历史；脱敏发布必须删除除本 README 外的全部内容。

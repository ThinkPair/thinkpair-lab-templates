---
record_type: directory_readme
privacy: private
schema_version: "business_target_plan.v1"
---

# 盈利目标方案

本目录保存用户在创业算账页查看摘要并确认后，由确定性引擎新建的 `business_target_plan`。空白母版只保留本说明，不包含任何目标、进度或经营数字。

## 数据契约

- 文件名必须等于 `<target_plan_id>.md`，默认格式为 `btp-<16 位哈希>.md`。
- 记录绑定 `calculation_id + source_input_hash + target_input_hash`，使用 `hash_algorithm: fnv1a64` 与 `schema_version: business_target_plan.v1`。
- `business-target-plan-json` 数据块必须保存 `{ "input": <deterministicInput>, "result": <完整 business_target_plan envelope> }`，不能只保存预览数字。
- 读取时使用 `validateBusinessTargetPlanRecord` 重跑公式；核算 ID、来源哈希、目标哈希或确定性结果不一致时，该记录不得进入当前首页。
- 核算输入改变后，旧目标只保留历史，不覆盖、不删除、不继续作为当前目标。

## 权限

本目录对 AI 永久只读。AI 不得通过对话新建、编辑、覆盖、停用或修正目标方案；目标只能由创业算账页调用 `calculateBusinessTargetPlan` 并经用户页内摘要确认后创建。

备份必须保留本目录全部历史；脱敏发布必须删除除本 README 外的全部内容。

param(
  [Parameter(Mandatory = $true)]
  [string]$SuiteRoot
)

$ErrorActionPreference = 'Stop'
$suite = (Resolve-Path -LiteralPath $SuiteRoot).Path
$business = Join-Path $suite '4_一人公司商业运营驾驶舱\一人公司商业运营专家驾驶舱_根产品母版'
$tool = Join-Path $business '_tools\open-vault.ps1'
if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw "缺少商业驾驶舱启动工具：$tool" }
& $tool -PackageRoot $business

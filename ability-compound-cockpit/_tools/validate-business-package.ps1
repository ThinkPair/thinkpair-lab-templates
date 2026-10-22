param(
  [Parameter(Mandatory = $true)]
  [string]$SuiteRoot,
  [switch]$ReleaseMode
)

$ErrorActionPreference = 'Stop'
$suite = (Resolve-Path -LiteralPath $SuiteRoot).Path
$business = Join-Path $suite '4_一人公司商业运营驾驶舱\一人公司商业运营专家驾驶舱_根产品母版'
$tool = Join-Path $business '_tools\validate-package.ps1'
if (-not (Test-Path -LiteralPath $tool -PathType Leaf)) { throw "缺少商业驾驶舱检查工具：$tool" }
$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tool, '-PackageRoot', $business)
if ($ReleaseMode) { $arguments += '-ReleaseMode' }
& powershell.exe @arguments
exit $LASTEXITCODE

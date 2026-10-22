$ErrorActionPreference = "Stop"

$packageRoot = Split-Path -Parent $PSScriptRoot
$dataNote = Get-ChildItem -LiteralPath $packageRoot -File -Filter "01_*.md" | Select-Object -First 1
$appDataDir = Join-Path $packageRoot "app\data"
$currentData = Join-Path $appDataDir "current-data.js"
$lastValidData = Join-Path $appDataDir "last-valid-data.js"

if ($null -eq $dataNote) {
  throw "Dashboard data note 01_*.md was not found. Keep the package structure intact."
}

$markdown = Get-Content -LiteralPath $dataNote.FullName -Raw -Encoding UTF8
$match = [regex]::Match($markdown, '(?s)```json\s*(\{.*?\})\s*```')
if (-not $match.Success) {
  throw "A complete fenced json block was not found in the dashboard data note."
}

try {
  $dashboard = $match.Groups[1].Value | ConvertFrom-Json
} catch {
  throw "Invalid JSON: $($_.Exception.Message)"
}

$schemaVersion = if ($null -ne $dashboard.schemaVersion) { [int]$dashboard.schemaVersion } else { 0 }
if ($schemaVersion -ne 1) {
  throw "schemaVersion must be 1."
}

$requiredStageIds = @("reach", "follow", "lead", "conversation", "paid", "renewal")
$requiredPlatformIds = @("douyin", "xhs", "bilibili")

if ($dashboard.stages -isnot [System.Array]) {
  throw "stages must be an array."
}

foreach ($stageId in $requiredStageIds) {
  $stage = $dashboard.stages | Where-Object { $_.id -eq $stageId } | Select-Object -First 1
  if ($null -eq $stage) {
    throw "Missing stage: $stageId"
  }
  if ($null -eq $stage.values) {
    throw "Stage $stageId is missing values."
  }

  foreach ($platformId in $requiredPlatformIds) {
    $property = $stage.values.PSObject.Properties[$platformId]
    if ($null -eq $property) {
      throw "Stage $stageId is missing platform $platformId."
    }

    $cell = $property.Value
    $rawValue = if ($null -ne $cell -and $cell -isnot [ValueType] -and $cell -isnot [string] -and $null -ne $cell.PSObject.Properties["value"]) {
      $cell.value
    } else {
      $cell
    }

    if ($null -ne $rawValue) {
      $number = 0.0
      if (-not [double]::TryParse($rawValue.ToString(), [ref]$number) -or $number -lt 0) {
        throw "Stage $stageId / $platformId value must be a non-negative number or null."
      }
    }
  }
}

if (-not (Test-Path -LiteralPath $appDataDir)) {
  New-Item -ItemType Directory -Path $appDataDir -Force | Out-Null
}

if (Test-Path -LiteralPath $currentData) {
  Copy-Item -LiteralPath $currentData -Destination $lastValidData -Force
}

$json = $dashboard | ConvertTo-Json -Depth 100 -Compress
$javascript = "window.DASHBOARD_DATA = $json;"
Set-Content -LiteralPath $currentData -Value $javascript -Encoding UTF8

Write-Host "Dashboard data validated and synchronized."

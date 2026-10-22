Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:TimestampFormat = "yyyy-MM-dd'T'HH:mm:sszzz"
$script:CapabilitySchema = 'exchange.capability_transfer.v1'
$script:FeedbackSchema = 'exchange.market_feedback.v1'
$script:HashAlgorithm = 'sha256'
$script:Canonicalization = 'exchange-json-line.v1'
$script:CapabilitySourceProduct = 'personal_capability_cockpit'
$script:CapabilityTargetProduct = 'solo_business_operations_cockpit'
$script:FeedbackSourceProduct = 'solo_business_operations_cockpit'
$script:FeedbackTargetProduct = 'personal_capability_cockpit'

$script:CapabilityFrontmatterFields = @(
  'record_id', 'record_type', 'skill_id', 'record_status', 'transfer_id',
  'source_product', 'target_product', 'created_at', 'updated_at',
  'user_confirmed_at', 'privacy', 'schema_version', 'hash_algorithm',
  'canonicalization', 'capability_result', 'capability_version',
  'evidence_summary', 'evidence_refs_json', 'applicability_boundaries_json',
  'minimum_deliverable_candidate', 'potential_audiences_json', 'content_hash'
)

$script:CapabilityPayloadFields = @(
  'record_type', 'transfer_id', 'skill_id', 'source_product', 'target_product',
  'created_at', 'user_confirmed_at', 'privacy', 'schema_version',
  'hash_algorithm', 'canonicalization', 'capability_result',
  'capability_version', 'evidence_summary', 'evidence_refs',
  'applicability_boundaries', 'minimum_deliverable_candidate',
  'potential_audiences'
)

$script:FeedbackFrontmatterFields = @(
  'record_id', 'record_type', 'skill_id', 'record_status', 'feedback_id',
  'source_transfer_id', 'source_transfer_hash', 'source_validation_id',
  'source_product', 'target_product', 'created_at', 'updated_at', 'imported_at',
  'export_status', 'export_confirmed_at', 'redaction_confirmed',
  'redaction_confirmed_at', 'user_confirmed_at', 'privacy', 'schema_version',
  'hash_algorithm', 'canonicalization', 'feedback_summary', 'skill_gap',
  'next_practice_candidate', 'content_hash'
)

$script:FeedbackPayloadFields = @(
  'record_type', 'feedback_id', 'skill_id', 'source_transfer_id',
  'source_transfer_hash', 'source_validation_id', 'source_product',
  'target_product', 'created_at', 'export_status', 'export_confirmed_at',
  'redaction_confirmed', 'redaction_confirmed_at', 'privacy',
  'schema_version', 'hash_algorithm', 'canonicalization', 'feedback_summary',
  'skill_gap', 'next_practice_candidate'
)

function Throw-ExchangeError {
  param(
    [Parameter(Mandatory = $true)][string]$Code,
    [Parameter(Mandatory = $true)][string]$Message
  )

  $exception = New-Object System.InvalidOperationException($Message)
  $exception.Data['ExchangeCode'] = $Code
  throw $exception
}

function Get-ExchangeErrorCode {
  param([Parameter(Mandatory = $true)]$Exception)
  if ($null -ne $Exception.Data -and $Exception.Data.Contains('ExchangeCode')) {
    return [string]$Exception.Data['ExchangeCode']
  }
  return 'E_INTERNAL'
}

function Get-Sha256Hex {
  param([Parameter(Mandatory = $true)][string]$Text)
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $bytes = $script:Utf8NoBom.GetBytes($Text)
    return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
  } finally {
    $sha.Dispose()
  }
}

function Read-StrictUtf8Text {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Throw-ExchangeError 'E_IO' "Card does not exist: $Path"
  }
  $item = Get-Item -LiteralPath $Path -Force
  if ($item.Length -gt 262144) {
    Throw-ExchangeError 'E_IO' 'Exchange card exceeds the 256 KiB limit.'
  }
  if ($item.Extension -ine '.md') {
    Throw-ExchangeError 'E_IO' 'Exchange card must be a Markdown file.'
  }

  $bytes = [IO.File]::ReadAllBytes($item.FullName)
  if ($bytes -contains 0) {
    Throw-ExchangeError 'E_IO' 'Exchange card contains a NUL byte.'
  }
  try {
    $text = $script:Utf8Strict.GetString($bytes)
  } catch {
    Throw-ExchangeError 'E_IO' 'Exchange card is not valid UTF-8.'
  }
  if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) {
    $text = $text.Substring(1)
  }
  return $text
}

function Assert-PathInsideExchangeFolder {
  param(
    [Parameter(Mandatory = $true)][string]$CardPath,
    [Parameter(Mandatory = $true)][string]$ExchangeRoot,
    [Parameter(Mandatory = $true)][ValidateSet('CapabilityTransfer', 'MarketFeedback')][string]$Kind
  )

  if (-not (Test-Path -LiteralPath $ExchangeRoot -PathType Container)) {
    Throw-ExchangeError 'E_PATH' 'Exchange root does not exist.'
  }
  $root = (Resolve-Path -LiteralPath $ExchangeRoot).Path.TrimEnd('\', '/')
  $folderName = if ($Kind -eq 'CapabilityTransfer') { 'capability_to_business' } else { 'market_feedback_to_personal' }
  $expectedFolder = Join-Path $root $folderName
  if (-not (Test-Path -LiteralPath $expectedFolder -PathType Container)) {
    Throw-ExchangeError 'E_PATH' "Expected exchange folder is missing: $folderName"
  }
  $card = (Resolve-Path -LiteralPath $CardPath).Path
  $parent = [IO.Path]::GetDirectoryName($card).TrimEnd('\', '/')
  $resolvedExpected = (Resolve-Path -LiteralPath $expectedFolder).Path.TrimEnd('\', '/')
  if (-not [string]::Equals($parent, $resolvedExpected, [StringComparison]::OrdinalIgnoreCase)) {
    Throw-ExchangeError 'E_PATH' 'Card is not a direct child of the expected controlled exchange folder.'
  }

  $cursor = Get-Item -LiteralPath $card -Force
  while ($null -ne $cursor -and $cursor.FullName.Length -ge $root.Length) {
    if (($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      Throw-ExchangeError 'E_PATH' 'Reparse points are not allowed in the controlled exchange path.'
    }
    if ([string]::Equals($cursor.FullName.TrimEnd('\', '/'), $root, [StringComparison]::OrdinalIgnoreCase)) { break }
    if ($cursor -is [IO.FileInfo]) { $cursor = $cursor.Directory }
    else { $cursor = $cursor.Parent }
  }
}

function ConvertFrom-WireScalar {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Raw)
  $value = $Raw.Trim()
  if ($value -in @('null', '~')) { return $null }
  if ($value -eq 'true') { return $true }
  if ($value -eq 'false') { return $false }
  if ($value.StartsWith('"') -and $value.EndsWith('"')) {
    try { return ($value | ConvertFrom-Json) }
    catch { Throw-ExchangeError 'E_ENVELOPE' 'A quoted YAML scalar is not valid JSON string syntax.' }
  }
  if ($value -match '^[A-Za-z0-9_.-]+$') { return $value }
  Throw-ExchangeError 'E_ENVELOPE' 'Wire frontmatter only allows null, boolean, simple tokens, or JSON-quoted strings.'
}

function Read-WireFrontmatter {
  param([Parameter(Mandatory = $true)][string]$Content)

  $match = [regex]::Match($Content, '(?s)\A---\r?\n(.*?)\r?\n---(?:\r?\n|\z)')
  if (-not $match.Success) {
    Throw-ExchangeError 'E_ENVELOPE' 'Exchange card must begin with YAML frontmatter.'
  }
  $values = [ordered]@{}
  foreach ($line in ($match.Groups[1].Value -split '\r?\n')) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $field = [regex]::Match($line, '^([A-Za-z][A-Za-z0-9_]*):(?:\s*(.*))?$')
    if (-not $field.Success) {
      Throw-ExchangeError 'E_ENVELOPE' "Unsupported wire frontmatter line: $line"
    }
    $name = $field.Groups[1].Value
    if ($values.Contains($name)) {
      Throw-ExchangeError 'E_ENVELOPE' "Duplicate frontmatter field: $name"
    }
    $values[$name] = ConvertFrom-WireScalar -Raw $field.Groups[2].Value
  }
  return $values
}

function Assert-ExactFieldSet {
  param(
    [Parameter(Mandatory = $true)][string[]]$Actual,
    [Parameter(Mandatory = $true)][string[]]$Expected,
    [Parameter(Mandatory = $true)][string]$Label,
    [switch]$RequireOrder
  )

  if ($Actual.Count -ne $Expected.Count) {
    Throw-ExchangeError 'E_FIELD_SET' "$Label field count is invalid."
  }
  if ($RequireOrder) {
    for ($i = 0; $i -lt $Expected.Count; $i++) {
      if ($Actual[$i] -cne $Expected[$i]) {
        Throw-ExchangeError 'E_FIELD_SET' "$Label fields are not in canonical order."
      }
    }
    return
  }
  foreach ($name in $Expected) {
    if ($Actual -notcontains $name) {
      Throw-ExchangeError 'E_FIELD_SET' "$Label is missing field: $name"
    }
  }
}

function Read-CanonicalPayload {
  param([Parameter(Mandatory = $true)][string]$Content)

  $startCount = [regex]::Matches($Content, '<!-- exchange-json:start -->').Count
  $endCount = [regex]::Matches($Content, '<!-- exchange-json:end -->').Count
  if ($startCount -ne 1 -or $endCount -ne 1) {
    Throw-ExchangeError 'E_ENVELOPE' 'Exchange card must contain exactly one exchange JSON payload block.'
  }
  $match = [regex]::Match(
    $Content,
    '(?m)^<!-- exchange-json:start -->\r?\n```json\r?\n([^\r\n]+)\r?\n```\r?\n<!-- exchange-json:end -->$'
  )
  if (-not $match.Success) {
    Throw-ExchangeError 'E_ENVELOPE' 'Exchange JSON payload must be exactly one physical line.'
  }
  $line = $match.Groups[1].Value
  if ($line -cne $line.Trim()) {
    Throw-ExchangeError 'E_ENVELOPE' 'Exchange JSON payload has leading or trailing whitespace.'
  }
  try { $payload = $line | ConvertFrom-Json }
  catch { Throw-ExchangeError 'E_ENVELOPE' 'Exchange JSON payload cannot be parsed.' }
  if ($payload -isnot [pscustomobject]) {
    Throw-ExchangeError 'E_ENVELOPE' 'Exchange JSON payload must be an object.'
  }
  $roundTrip = ConvertTo-Json -InputObject $payload -Depth 20 -Compress
  if ($roundTrip -cne $line) {
    Throw-ExchangeError 'E_ENVELOPE' 'Exchange JSON payload is not canonical compact JSON.'
  }
  return [pscustomobject]@{ Line = $line; Value = $payload }
}

function Assert-NfcValue {
  param([AllowNull()]$Value)
  if ($null -eq $Value) { return }
  if ($Value -is [string]) {
    if ($Value.Normalize([Text.NormalizationForm]::FormC) -cne $Value) {
      Throw-ExchangeError 'E_FIELD_SET' 'All exchange strings must use Unicode NFC normalization.'
    }
    return
  }
  if ($Value -is [Array] -or $Value -is [Collections.IList]) {
    foreach ($entry in $Value) { Assert-NfcValue -Value $entry }
    return
  }
  if ($Value -is [pscustomobject]) {
    foreach ($property in $Value.PSObject.Properties) { Assert-NfcValue -Value $property.Value }
  }
}

function Assert-Timestamp {
  param(
    [Parameter(Mandatory = $true)][string]$Value,
    [Parameter(Mandatory = $true)][string]$Field
  )
  $parsed = [DateTimeOffset]::MinValue
  $ok = [DateTimeOffset]::TryParseExact(
    $Value,
    $script:TimestampFormat,
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::None,
    [ref]$parsed
  )
  if (-not $ok) { Throw-ExchangeError 'E_FIELD_SET' "$Field must be RFC 3339 with seconds and an explicit offset." }
}

function Assert-TextValue {
  param(
    [AllowNull()]$Value,
    [Parameter(Mandatory = $true)][string]$Field,
    [int]$Minimum = 1,
    [int]$Maximum = 500
  )
  if ($Value -isnot [string]) { Throw-ExchangeError 'E_FIELD_SET' "$Field must be a string." }
  if ($Value.Length -lt $Minimum -or $Value.Length -gt $Maximum -or $Value.Trim().Length -ne $Value.Length) {
    Throw-ExchangeError 'E_FIELD_SET' "$Field length or surrounding whitespace is invalid."
  }
}

function Assert-NoAbsolutePath {
  param([Parameter(Mandatory = $true)][string]$Value)
  if ($Value -match '(?i)(?:[A-Z]:[\\/]|\\\\[^\\\s]+\\)') {
    Throw-ExchangeError 'E_PRIVACY' 'Absolute local or UNC paths are forbidden in exchange content.'
  }
}

function ConvertTo-CompactJson {
  param([AllowNull()]$Value)
  return (ConvertTo-Json -InputObject $Value -Depth 20 -Compress)
}

function Assert-MirrorScalar {
  param(
    [Parameter(Mandatory = $true)]$Frontmatter,
    [Parameter(Mandatory = $true)]$Payload,
    [Parameter(Mandatory = $true)][string]$Name
  )
  $left = $Frontmatter[$Name]
  $right = $Payload.$Name
  if ($null -eq $left -and $null -eq $right) { return }
  if ($left -is [bool] -or $right -is [bool]) {
    if ($left -isnot [bool] -or $right -isnot [bool] -or $left -ne $right) {
      Throw-ExchangeError 'E_MIRROR' "Frontmatter does not match payload: $Name"
    }
    return
  }
  if ([string]$left -cne [string]$right) {
    Throw-ExchangeError 'E_MIRROR' "Frontmatter does not match payload: $Name"
  }
}

function Assert-JsonMirror {
  param(
    [Parameter(Mandatory = $true)]$Frontmatter,
    [Parameter(Mandatory = $true)]$PayloadValue,
    [Parameter(Mandatory = $true)][string]$FrontmatterName
  )
  $jsonText = $Frontmatter[$FrontmatterName]
  if ($jsonText -isnot [string]) {
    Throw-ExchangeError 'E_MIRROR' "$FrontmatterName must be a JSON string."
  }
  try { $parsed = $jsonText | ConvertFrom-Json }
  catch { Throw-ExchangeError 'E_MIRROR' "$FrontmatterName is not valid JSON."
  }
  # Windows PowerShell 5.1 attaches a transient `value` adapter to a top-level
  # JSON array returned by ConvertFrom-Json. Copying entries into a fresh array
  # removes that adapter and gives stable JSON on every supported Windows host.
  $parsedArray = @()
  foreach ($entry in @($parsed)) { $parsedArray += $entry }
  $payloadArray = @()
  foreach ($entry in @($PayloadValue)) { $payloadArray += $entry }
  if ((ConvertTo-CompactJson $parsedArray) -cne (ConvertTo-CompactJson $payloadArray)) {
    Throw-ExchangeError 'E_MIRROR' "Frontmatter does not match payload: $FrontmatterName"
  }
}

function Test-CapabilityCard {
  param(
    [Parameter(Mandatory = $true)]$Frontmatter,
    [Parameter(Mandatory = $true)]$Payload,
    [Parameter(Mandatory = $true)][string]$PayloadLine
  )

  Assert-ExactFieldSet -Actual @($Frontmatter.Keys) -Expected $script:CapabilityFrontmatterFields -Label 'Capability frontmatter'
  Assert-ExactFieldSet -Actual @($Payload.PSObject.Properties.Name) -Expected $script:CapabilityPayloadFields -Label 'Capability payload' -RequireOrder
  Assert-NfcValue -Value $Payload

  if ($Frontmatter.record_type -cne 'capability_transfer' -or $Payload.record_type -cne 'capability_transfer') {
    Throw-ExchangeError 'E_TYPE' 'Card is not a capability_transfer.'
  }
  if ($Frontmatter.schema_version -cne $script:CapabilitySchema -or $Payload.schema_version -cne $script:CapabilitySchema) {
    Throw-ExchangeError 'E_SCHEMA_UNSUPPORTED' "Supported capability schema is $($script:CapabilitySchema)."
  }
  if ($Frontmatter.record_status -cne 'confirmed') { Throw-ExchangeError 'E_STATUS' 'Capability card must be confirmed.' }
  if ($Frontmatter.source_product -cne $script:CapabilitySourceProduct -or $Frontmatter.target_product -cne $script:CapabilityTargetProduct) {
    Throw-ExchangeError 'E_TYPE' 'Capability transfer direction is invalid.'
  }
  if ($Frontmatter.hash_algorithm -cne $script:HashAlgorithm -or $Frontmatter.canonicalization -cne $script:Canonicalization) {
    Throw-ExchangeError 'E_HASH' 'Unsupported hash algorithm or canonicalization.'
  }

  $uuidPattern = '[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}'
  if ([string]$Frontmatter.transfer_id -notmatch "^ct-$uuidPattern$") { Throw-ExchangeError 'E_ID' 'transfer_id must be ct- plus a lowercase UUID v4.' }
  if ([string]$Frontmatter.record_id -cne [string]$Frontmatter.transfer_id) { Throw-ExchangeError 'E_ID' 'record_id must equal transfer_id.' }
  if ([string]$Frontmatter.skill_id -notmatch '^skill-[a-z0-9][a-z0-9._-]{2,95}$') { Throw-ExchangeError 'E_ID' 'skill_id format is invalid.' }
  if ([string]$Frontmatter.content_hash -notmatch '^[a-f0-9]{64}$') { Throw-ExchangeError 'E_HASH' 'content_hash must be 64 lowercase hexadecimal characters.' }
  $computedHash = Get-Sha256Hex -Text $PayloadLine
  if (-not [string]::Equals($computedHash, [string]$Frontmatter.content_hash, [StringComparison]::Ordinal)) {
    Throw-ExchangeError 'E_HASH' 'Capability payload hash does not match content_hash.'
  }

  foreach ($name in @(
    'record_type', 'transfer_id', 'skill_id', 'source_product', 'target_product',
    'created_at', 'user_confirmed_at', 'privacy', 'schema_version',
    'hash_algorithm', 'canonicalization', 'capability_result',
    'capability_version', 'evidence_summary', 'minimum_deliverable_candidate'
  )) { Assert-MirrorScalar -Frontmatter $Frontmatter -Payload $Payload -Name $name }
  Assert-JsonMirror -Frontmatter $Frontmatter -PayloadValue $Payload.evidence_refs -FrontmatterName 'evidence_refs_json'
  Assert-JsonMirror -Frontmatter $Frontmatter -PayloadValue $Payload.applicability_boundaries -FrontmatterName 'applicability_boundaries_json'
  Assert-JsonMirror -Frontmatter $Frontmatter -PayloadValue $Payload.potential_audiences -FrontmatterName 'potential_audiences_json'

  if ($Frontmatter.privacy -cne 'sensitive') { Throw-ExchangeError 'E_FIELD_SET' 'Capability transfer privacy must be sensitive.' }
  Assert-Timestamp -Value ([string]$Frontmatter.created_at) -Field 'created_at'
  Assert-Timestamp -Value ([string]$Frontmatter.updated_at) -Field 'updated_at'
  Assert-Timestamp -Value ([string]$Frontmatter.user_confirmed_at) -Field 'user_confirmed_at'
  Assert-TextValue -Value $Payload.capability_result -Field 'capability_result' -Maximum 500
  Assert-TextValue -Value $Payload.capability_version -Field 'capability_version' -Maximum 64
  Assert-TextValue -Value $Payload.evidence_summary -Field 'evidence_summary' -Maximum 2000
  Assert-TextValue -Value $Payload.minimum_deliverable_candidate -Field 'minimum_deliverable_candidate' -Maximum 500

  $evidence = @($Payload.evidence_refs)
  if ($evidence.Count -lt 1 -or $evidence.Count -gt 20) { Throw-ExchangeError 'E_FIELD_SET' 'evidence_refs must contain 1 to 20 entries.' }
  foreach ($entry in $evidence) {
    if ($entry -isnot [pscustomobject]) { Throw-ExchangeError 'E_FIELD_SET' 'Each evidence reference must be an object.' }
    Assert-ExactFieldSet -Actual @($entry.PSObject.Properties.Name) -Expected @('evidence_id', 'evidence_type', 'title', 'source_hash') -Label 'Evidence reference' -RequireOrder
    Assert-TextValue -Value $entry.evidence_id -Field 'evidence_id' -Maximum 96
    Assert-TextValue -Value $entry.evidence_type -Field 'evidence_type' -Maximum 32
    if ($entry.evidence_type -notin @('work_sample', 'before_after', 'external_feedback', 'certificate', 'other')) {
      Throw-ExchangeError 'E_FIELD_SET' 'evidence_type is unsupported.'
    }
    Assert-TextValue -Value $entry.title -Field 'evidence title' -Maximum 200
    if ($null -ne $entry.source_hash -and [string]$entry.source_hash -notmatch '^[a-f0-9]{64}$') {
      Throw-ExchangeError 'E_HASH' 'Evidence source_hash must be null or 64 lowercase hexadecimal characters.'
    }
    Assert-NoAbsolutePath -Value ([string]$entry.title)
  }

  $boundaries = @($Payload.applicability_boundaries)
  if ($boundaries.Count -lt 1 -or $boundaries.Count -gt 10) { Throw-ExchangeError 'E_FIELD_SET' 'applicability_boundaries must contain 1 to 10 entries.' }
  foreach ($entry in $boundaries) { Assert-TextValue -Value $entry -Field 'applicability boundary' -Maximum 300; Assert-NoAbsolutePath -Value $entry }

  $audiences = @($Payload.potential_audiences)
  if ($audiences.Count -lt 1 -or $audiences.Count -gt 5) { Throw-ExchangeError 'E_FIELD_SET' 'potential_audiences must contain 1 to 5 entries.' }
  foreach ($entry in $audiences) { Assert-TextValue -Value $entry -Field 'potential audience' -Maximum 160; Assert-NoAbsolutePath -Value $entry }

  foreach ($value in @($Payload.capability_result, $Payload.evidence_summary, $Payload.minimum_deliverable_candidate)) {
    Assert-NoAbsolutePath -Value ([string]$value)
  }
  return $computedHash
}

function Test-FeedbackPrivacy {
  param([Parameter(Mandatory = $true)][string]$Text)
  $patterns = @(
    '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    '(?<!\d)1[3-9]\d{9}(?!\d)',
    '(?i)(?:微信|wechat|wx)\s*[:：]\s*[A-Za-z0-9_-]{5,}',
    '(?i)(?:[¥￥$€£]\s*\d|\d+(?:\.\d{1,2})?\s*(?:元|人民币|RMB|CNY|USD|美元))'
  )
  foreach ($pattern in $patterns) {
    if ($Text -match $pattern) { Throw-ExchangeError 'E_PRIVACY' 'Market feedback contains contact or financial patterns.' }
  }
  Assert-NoAbsolutePath -Value $Text
}

function Test-MarketFeedbackCard {
  param(
    [Parameter(Mandatory = $true)]$Frontmatter,
    [Parameter(Mandatory = $true)]$Payload,
    [Parameter(Mandatory = $true)][string]$PayloadLine
  )

  Assert-ExactFieldSet -Actual @($Frontmatter.Keys) -Expected $script:FeedbackFrontmatterFields -Label 'Feedback frontmatter'
  Assert-ExactFieldSet -Actual @($Payload.PSObject.Properties.Name) -Expected $script:FeedbackPayloadFields -Label 'Feedback payload' -RequireOrder
  Assert-NfcValue -Value $Payload

  if ($Frontmatter.record_type -cne 'market_feedback' -or $Payload.record_type -cne 'market_feedback') {
    Throw-ExchangeError 'E_TYPE' 'Card is not market_feedback.'
  }
  if ($Frontmatter.schema_version -cne $script:FeedbackSchema -or $Payload.schema_version -cne $script:FeedbackSchema) {
    Throw-ExchangeError 'E_SCHEMA_UNSUPPORTED' "Supported feedback schema is $($script:FeedbackSchema)."
  }
  if ($Frontmatter.record_status -notin @('draft', 'confirmed', 'rejected')) {
    Throw-ExchangeError 'E_STATUS' 'Market feedback record_status must be draft, confirmed, or rejected.'
  }
  if ($Frontmatter.export_status -cne 'confirmed' -or $Frontmatter.redaction_confirmed -ne $true) {
    Throw-ExchangeError 'E_STATUS' 'Market feedback export and redaction must both be confirmed.'
  }
  if ($Frontmatter.source_product -cne $script:FeedbackSourceProduct -or $Frontmatter.target_product -cne $script:FeedbackTargetProduct) {
    Throw-ExchangeError 'E_TYPE' 'Market feedback direction is invalid.'
  }
  if ($Frontmatter.hash_algorithm -cne $script:HashAlgorithm -or $Frontmatter.canonicalization -cne $script:Canonicalization) {
    Throw-ExchangeError 'E_HASH' 'Unsupported hash algorithm or canonicalization.'
  }

  $uuidPattern = '[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}'
  if ([string]$Frontmatter.feedback_id -notmatch "^mf-$uuidPattern$") { Throw-ExchangeError 'E_ID' 'feedback_id must be mf- plus a lowercase UUID v4.' }
  if ([string]$Frontmatter.record_id -cne [string]$Frontmatter.feedback_id) { Throw-ExchangeError 'E_ID' 'record_id must equal feedback_id.' }
  if ([string]$Frontmatter.source_transfer_id -notmatch "^ct-$uuidPattern$") { Throw-ExchangeError 'E_ID' 'source_transfer_id format is invalid.' }
  if ([string]$Frontmatter.source_validation_id -notmatch "^validation-import-$uuidPattern$") { Throw-ExchangeError 'E_ID' 'source_validation_id format is invalid.' }
  if ([string]$Frontmatter.skill_id -notmatch '^skill-[a-z0-9][a-z0-9._-]{2,95}$') { Throw-ExchangeError 'E_ID' 'skill_id format is invalid.' }
  if ([string]$Frontmatter.source_transfer_hash -notmatch '^[a-f0-9]{64}$' -or [string]$Frontmatter.content_hash -notmatch '^[a-f0-9]{64}$') {
    Throw-ExchangeError 'E_HASH' 'Feedback hashes must be 64 lowercase hexadecimal characters.'
  }
  $computedHash = Get-Sha256Hex -Text $PayloadLine
  if (-not [string]::Equals($computedHash, [string]$Frontmatter.content_hash, [StringComparison]::Ordinal)) {
    Throw-ExchangeError 'E_HASH' 'Feedback payload hash does not match content_hash.'
  }

  foreach ($name in $script:FeedbackPayloadFields) { Assert-MirrorScalar -Frontmatter $Frontmatter -Payload $Payload -Name $name }
  if ($Frontmatter.privacy -cne 'private') { Throw-ExchangeError 'E_FIELD_SET' 'Market feedback privacy must be private.' }
  foreach ($name in @('created_at', 'updated_at', 'export_confirmed_at', 'redaction_confirmed_at')) {
    Assert-Timestamp -Value ([string]$Frontmatter[$name]) -Field $name
  }
  if ($null -ne $Frontmatter.imported_at) { Assert-Timestamp -Value ([string]$Frontmatter.imported_at) -Field 'imported_at' }
  if ($Frontmatter.record_status -eq 'confirmed') {
    if ($null -eq $Frontmatter.imported_at -or $null -eq $Frontmatter.user_confirmed_at) {
      Throw-ExchangeError 'E_STATUS' 'Confirmed market feedback requires imported_at and user_confirmed_at.'
    }
    Assert-Timestamp -Value ([string]$Frontmatter.user_confirmed_at) -Field 'user_confirmed_at'
  } elseif ($null -ne $Frontmatter.user_confirmed_at) {
    Throw-ExchangeError 'E_STATUS' 'Only confirmed market feedback may contain user_confirmed_at.'
  }
  Assert-TextValue -Value $Payload.feedback_summary -Field 'feedback_summary' -Maximum 2000
  Assert-TextValue -Value $Payload.skill_gap -Field 'skill_gap' -Maximum 800
  Assert-TextValue -Value $Payload.next_practice_candidate -Field 'next_practice_candidate' -Maximum 500
  foreach ($value in @($Payload.feedback_summary, $Payload.skill_gap, $Payload.next_practice_candidate)) {
    Test-FeedbackPrivacy -Text ([string]$value)
  }
  return $computedHash
}

function Assert-WireFeedbackLifecycle {
  param([Parameter(Mandatory = $true)]$Card)
  if ($Card.Kind -ne 'MarketFeedback') { return }
  if ($Card.Frontmatter.record_status -cne 'draft' -or
      $null -ne $Card.Frontmatter.imported_at -or
      $null -ne $Card.Frontmatter.user_confirmed_at) {
    Throw-ExchangeError 'E_STATUS' 'Wire market feedback must be an unimported draft.'
  }
}

function Read-ExchangeCard {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [ValidateSet('CapabilityTransfer', 'MarketFeedback')][string]$ExpectedKind
  )

  $content = Read-StrictUtf8Text -Path $Path
  $frontmatter = Read-WireFrontmatter -Content $content
  $payloadData = Read-CanonicalPayload -Content $content
  $recordType = [string]$frontmatter.record_type
  $kind = switch ($recordType) {
    'capability_transfer' { 'CapabilityTransfer' }
    'market_feedback' { 'MarketFeedback' }
    default { Throw-ExchangeError 'E_TYPE' "Unsupported record_type: $recordType" }
  }
  if (-not [string]::IsNullOrWhiteSpace($ExpectedKind) -and $kind -cne $ExpectedKind) {
    Throw-ExchangeError 'E_TYPE' "Expected $ExpectedKind but found $kind."
  }
  $hash = if ($kind -eq 'CapabilityTransfer') {
    Test-CapabilityCard -Frontmatter $frontmatter -Payload $payloadData.Value -PayloadLine $payloadData.Line
  } else {
    Test-MarketFeedbackCard -Frontmatter $frontmatter -Payload $payloadData.Value -PayloadLine $payloadData.Line
  }
  $id = if ($kind -eq 'CapabilityTransfer') { [string]$frontmatter.transfer_id } else { [string]$frontmatter.feedback_id }
  return [pscustomobject]@{
    Kind = $kind
    Id = $id
    Hash = $hash
    Path = (Resolve-Path -LiteralPath $Path).Path
    Content = $content
    Frontmatter = $frontmatter
    Payload = $payloadData.Value
    PayloadLine = $payloadData.Line
  }
}

function Test-ExchangeCard {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [ValidateSet('CapabilityTransfer', 'MarketFeedback')][string]$ExpectedKind
  )
  $card = Read-ExchangeCard -Path $Path -ExpectedKind $ExpectedKind
  return [pscustomobject]@{ valid = $true; kind = $card.Kind; id = $card.Id; content_hash = $card.Hash }
}

function ConvertTo-YamlScalar {
  param([AllowNull()]$Value)
  if ($null -eq $Value) { return 'null' }
  if ($Value -is [bool]) { return $(if ($Value) { 'true' } else { 'false' }) }
  return (ConvertTo-Json -InputObject ([string]$Value) -Compress)
}

function New-CapabilityValidationContent {
  param(
    [Parameter(Mandatory = $true)]$Card,
    [Parameter(Mandatory = $true)][string]$ImportedAt
  )
  $uuid = $Card.Id.Substring(3)
  $recordId = "validation-import-$uuid"
  $payload = $Card.Payload
  $audienceText = (@($payload.potential_audiences) -join '；')
  $evidenceJson = ConvertTo-CompactJson $payload.evidence_refs
  $boundariesJson = ConvertTo-CompactJson $payload.applicability_boundaries
  $audiencesJson = ConvertTo-CompactJson $payload.potential_audiences
  $userFact = '用户已确认将该能力候选送入商业验证；这只证明移交意图，不证明市场需求、客户回复、报价或成交。'

  $lines = @(
    '---',
    "record_id: $(ConvertTo-YamlScalar $recordId)",
    'record_type: monetization_validation',
    'validation_status: planned',
    'record_status: active',
    "created_at: $(ConvertTo-YamlScalar $ImportedAt)",
    "updated_at: $(ConvertTo-YamlScalar $ImportedAt)",
    'fact_gate_confirmed: false',
    'fact_gate_confirmed_at: null',
    "source_transfer_id: $(ConvertTo-YamlScalar $Card.Id)",
    "source_transfer_hash: $(ConvertTo-YamlScalar $Card.Hash)",
    "source_transfer_schema: $(ConvertTo-YamlScalar $script:CapabilitySchema)",
    "source_skill_id: $(ConvertTo-YamlScalar $payload.skill_id)",
    "source_capability_version: $(ConvertTo-YamlScalar $payload.capability_version)",
    "source_evidence_summary: $(ConvertTo-YamlScalar $payload.evidence_summary)",
    "source_evidence_refs_json: $(ConvertTo-YamlScalar $evidenceJson)",
    "source_applicability_boundaries_json: $(ConvertTo-YamlScalar $boundariesJson)",
    "source_potential_audiences_json: $(ConvertTo-YamlScalar $audiencesJson)",
    "imported_at: $(ConvertTo-YamlScalar $ImportedAt)",
    "能力或结果假设: $(ConvertTo-YamlScalar $payload.capability_result)",
    "对象假设: $(ConvertTo-YamlScalar $audienceText)",
    '问题假设: ""',
    "最小交付假设: $(ConvertTo-YamlScalar $payload.minimum_deliverable_candidate)",
    '价格假设: ""',
    '本次唯一动作: ""',
    '验收信号: ""',
    "用户事实: $(ConvertTo-YamlScalar $userFact)",
    '外部证据: ""',
    'AI建议: ""',
    '回应与讨论证据: ""',
    'converted_project_id: null',
    'privacy: sensitive',
    'schema_version: "1.0"',
    '---',
    '',
    '# 能力商品化验证记录',
    '',
    '> 本记录来自个人能力复利驾驶舱的受控能力移交。所有业务内容仍是待验证假设。',
    '',
    '## 待验证假设',
    '',
    '- 能力或结果假设：`= this.能力或结果假设`',
    '- 对象假设：`= this.对象假设`',
    '- 问题假设：`= this.问题假设`',
    '- 最小交付假设：`= this.最小交付假设`',
    '- 价格假设：`= this.价格假设`',
    '',
    '## 事实门',
    '',
    '- 项目事实门：`= this.fact_gate_confirmed`',
    '- 回应与讨论证据：`= this.回应与讨论证据`',
    '',
    '未通过项目事实门前，不得生成客户、项目、报价、回款或经营核算。',
    ''
  )
  return ($lines -join "`n")
}

function New-ImportedFeedbackContent {
  param(
    [Parameter(Mandatory = $true)]$Card,
    [Parameter(Mandatory = $true)][string]$ImportedAt
  )
  $fm = $Card.Frontmatter
  $lines = @('---')
  foreach ($name in $script:FeedbackFrontmatterFields) {
    $value = $fm[$name]
    if ($name -eq 'updated_at' -or $name -eq 'imported_at') { $value = $ImportedAt }
    if ($name -eq 'record_status') { $value = 'draft' }
    if ($name -eq 'user_confirmed_at') { $value = $null }
    if ($name -eq 'record_status') { $lines += 'record_status: draft' }
    else { $lines += "$name`: $(ConvertTo-YamlScalar $value)" }
  }
  $lines += @(
    '---',
    '',
    '# 市场反馈回流',
    '',
    '> 本记录由商业运营空间脱敏导出。导入后仍是草稿，用户确认前不得进入正式复盘或能力统计。',
    '',
    '## 脱敏反馈',
    '',
    '`= this.feedback_summary`',
    '',
    '## 暴露出的技能差距',
    '',
    '`= this.skill_gap`',
    '',
    '## 下一练习候选',
    '',
    '`= this.next_practice_candidate`',
    '',
    '<!-- exchange-json:start -->',
    '```json',
    $Card.PayloadLine,
    '```',
    '<!-- exchange-json:end -->',
    ''
  )
  return ($lines -join "`n")
}

function Get-SimpleFrontmatterScalar {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Name
  )
  try { $content = [IO.File]::ReadAllText($Path, $script:Utf8Strict) } catch { return $null }
  if ($content.Length -gt 0 -and $content[0] -eq [char]0xFEFF) { $content = $content.Substring(1) }
  $frontmatter = [regex]::Match($content, '(?s)\A---\s*\r?\n(.*?)\r?\n---')
  if (-not $frontmatter.Success) { return $null }
  $match = [regex]::Match($frontmatter.Groups[1].Value, '(?m)^' + [regex]::Escape($Name) + ':\s*(.*?)\s*$')
  if (-not $match.Success) { return $null }
  try { return ConvertFrom-WireScalar -Raw $match.Groups[1].Value } catch { return $null }
}

function Assert-NoDuplicateImport {
  param(
    [Parameter(Mandatory = $true)]$Card,
    [Parameter(Mandatory = $true)][string]$TargetDirectory
  )
  if (-not (Test-Path -LiteralPath $TargetDirectory -PathType Container)) { return }
  $idField = if ($Card.Kind -eq 'CapabilityTransfer') { 'source_transfer_id' } else { 'feedback_id' }
  $hashField = if ($Card.Kind -eq 'CapabilityTransfer') { 'source_transfer_hash' } else { 'content_hash' }
  foreach ($file in @(Get-ChildItem -LiteralPath $TargetDirectory -File -Filter '*.md' -Force)) {
    if ($file.Name -eq 'README.md') { continue }
    $existingId = Get-SimpleFrontmatterScalar -Path $file.FullName -Name $idField
    if ([string]$existingId -cne $Card.Id) { continue }
    $existingHash = Get-SimpleFrontmatterScalar -Path $file.FullName -Name $hashField
    if ([string]$existingHash -ceq $Card.Hash) {
      Throw-ExchangeError 'E_DUPLICATE' "The same exchange record is already imported: $($Card.Id)"
    }
    Throw-ExchangeError 'E_ID_CONFLICT' "The exchange ID already exists with a different hash: $($Card.Id)"
  }
}

function Assert-FeedbackSourceLink {
  param(
    [Parameter(Mandatory = $true)]$Card,
    [Parameter(Mandatory = $true)][string]$VaultRoot
  )
  $directory = Join-Path $VaultRoot '60_双工具交换\能力移交卡'
  if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
    Throw-ExchangeError 'E_SOURCE_LINK' 'Personal vault has no capability transfer directory.'
  }
  foreach ($file in @(Get-ChildItem -LiteralPath $directory -File -Filter '*.md' -Force)) {
    if ($file.Name -eq 'README.md') { continue }
    try { $source = Read-ExchangeCard -Path $file.FullName -ExpectedKind CapabilityTransfer } catch { continue }
    if ($source.Id -cne [string]$Card.Frontmatter.source_transfer_id) { continue }
    if ($source.Hash -cne [string]$Card.Frontmatter.source_transfer_hash -or [string]$source.Frontmatter.skill_id -cne [string]$Card.Frontmatter.skill_id) {
      Throw-ExchangeError 'E_SOURCE_LINK' 'Market feedback does not match the local source transfer hash or skill_id.'
    }
    return
  }
  Throw-ExchangeError 'E_SOURCE_LINK' 'Market feedback cannot find its local source capability transfer.'
}

function New-ExchangeImportPreview {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][ValidateSet('CapabilityTransfer', 'MarketFeedback')][string]$Kind,
    [Parameter(Mandatory = $true)][string]$CardPath,
    [Parameter(Mandatory = $true)][string]$VaultRoot,
    [Parameter(Mandatory = $true)][string]$ExchangeRoot,
    [string]$PreviewAt
  )

  Assert-PathInsideExchangeFolder -CardPath $CardPath -ExchangeRoot $ExchangeRoot -Kind $Kind
  if (-not (Test-Path -LiteralPath $VaultRoot -PathType Container)) { Throw-ExchangeError 'E_PATH' 'Target vault does not exist.' }
  $vault = (Resolve-Path -LiteralPath $VaultRoot).Path
  $card = Read-ExchangeCard -Path $CardPath -ExpectedKind $Kind
  if ($Kind -eq 'MarketFeedback') { Assert-WireFeedbackLifecycle -Card $card }
  if ([string]::IsNullOrWhiteSpace($PreviewAt)) { $PreviewAt = [DateTimeOffset]::Now.ToString($script:TimestampFormat) }
  Assert-Timestamp -Value $PreviewAt -Field 'PreviewAt'

  if ($Kind -eq 'CapabilityTransfer') {
    $targetDirectory = Join-Path $vault '40_能力商品化\验证记录'
    $uuid = $card.Id.Substring(3)
    $targetRelativePath = "40_能力商品化/验证记录/validation-import-$uuid.md"
    $targetContent = New-CapabilityValidationContent -Card $card -ImportedAt $PreviewAt
  } else {
    Assert-FeedbackSourceLink -Card $card -VaultRoot $vault
    $targetDirectory = Join-Path $vault '60_双工具交换\市场反馈'
    $targetRelativePath = "60_双工具交换/市场反馈/$($card.Id).md"
    $targetContent = New-ImportedFeedbackContent -Card $card -ImportedAt $PreviewAt
  }
  Assert-NoDuplicateImport -Card $card -TargetDirectory $targetDirectory
  $targetPath = Join-Path $vault ($targetRelativePath.Replace('/', '\'))
  if (Test-Path -LiteralPath $targetPath) { Throw-ExchangeError 'E_TARGET_COLLISION' 'Target file already exists.' }

  $targetHash = Get-Sha256Hex -Text $targetContent
  $tokenMaterial = "exchange-preview.v1`n$Kind`n$($card.Hash)`n$targetRelativePath`n$targetHash"
  $previewToken = Get-Sha256Hex -Text $tokenMaterial
  return [pscustomobject]@{
    valid = $true
    kind = $Kind
    source_id = $card.Id
    source_hash = $card.Hash
    preview_at = $PreviewAt
    target_relative_path = $targetRelativePath
    target_content_hash = $targetHash
    preview_token = $previewToken
    target_content = $targetContent
  }
}

function Write-Utf8NoBomAtomic {
  param(
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [Parameter(Mandatory = $true)][string]$Content
  )
  $directory = [IO.Path]::GetDirectoryName($TargetPath)
  [IO.Directory]::CreateDirectory($directory) | Out-Null
  if (Test-Path -LiteralPath $TargetPath) { Throw-ExchangeError 'E_TARGET_COLLISION' 'Target file already exists.' }
  $temporary = Join-Path $directory ('.exchange-' + [guid]::NewGuid().ToString('N') + '.tmp')
  try {
    [IO.File]::WriteAllText($temporary, $Content, $script:Utf8NoBom)
    if (Test-Path -LiteralPath $TargetPath) { Throw-ExchangeError 'E_TARGET_COLLISION' 'Target file appeared during import.' }
    [IO.File]::Move($temporary, $TargetPath)
    $readBack = [IO.File]::ReadAllText($TargetPath, $script:Utf8Strict)
    if ((Get-Sha256Hex -Text $readBack) -cne (Get-Sha256Hex -Text $Content)) {
      Throw-ExchangeError 'E_WRITE' 'Target verification failed after atomic write.'
    }
  } catch {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
    if ($_.Exception.Data.Contains('ExchangeCode')) { throw }
    Throw-ExchangeError 'E_WRITE' $_.Exception.Message
  }
}

function Import-ExchangeCard {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][ValidateSet('CapabilityTransfer', 'MarketFeedback')][string]$Kind,
    [Parameter(Mandatory = $true)][string]$CardPath,
    [Parameter(Mandatory = $true)][string]$VaultRoot,
    [Parameter(Mandatory = $true)][string]$ExchangeRoot,
    [Parameter(Mandatory = $true)][string]$ExpectedHash,
    [Parameter(Mandatory = $true)][string]$PreviewAt,
    [Parameter(Mandatory = $true)][string]$PreviewToken
  )

  if ($ExpectedHash -notmatch '^[a-f0-9]{64}$') { Throw-ExchangeError 'E_PREVIEW_STALE' 'ExpectedHash format is invalid.' }
  $preview = New-ExchangeImportPreview -Kind $Kind -CardPath $CardPath -VaultRoot $VaultRoot -ExchangeRoot $ExchangeRoot -PreviewAt $PreviewAt
  if ($preview.source_hash -cne $ExpectedHash -or $preview.preview_token -cne $PreviewToken) {
    Throw-ExchangeError 'E_PREVIEW_STALE' 'Source card or mapped target no longer matches the confirmed preview.'
  }
  $targetPath = Join-Path (Resolve-Path -LiteralPath $VaultRoot).Path ($preview.target_relative_path.Replace('/', '\'))
  Write-Utf8NoBomAtomic -TargetPath $targetPath -Content $preview.target_content
  return [pscustomobject]@{
    imported = $true
    kind = $Kind
    source_id = $preview.source_id
    source_hash = $preview.source_hash
    target_relative_path = $preview.target_relative_path
    target_content_hash = $preview.target_content_hash
  }
}

function Export-ExchangeCard {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][ValidateSet('CapabilityTransfer', 'MarketFeedback')][string]$Kind,
    [Parameter(Mandatory = $true)][string]$RecordPath,
    [Parameter(Mandatory = $true)][string]$ExchangeRoot,
    [Parameter(Mandatory = $true)][string]$ExpectedHash
  )

  if (-not (Test-Path -LiteralPath $ExchangeRoot -PathType Container)) { Throw-ExchangeError 'E_PATH' 'Exchange root does not exist.' }
  $card = Read-ExchangeCard -Path $RecordPath -ExpectedKind $Kind
  if ($Kind -eq 'MarketFeedback') { Assert-WireFeedbackLifecycle -Card $card }
  if ($card.Hash -cne $ExpectedHash) { Throw-ExchangeError 'E_PREVIEW_STALE' 'Source record does not match ExpectedHash.' }
  $folderName = if ($Kind -eq 'CapabilityTransfer') { 'capability_to_business' } else { 'market_feedback_to_personal' }
  $folder = Join-Path (Resolve-Path -LiteralPath $ExchangeRoot).Path $folderName
  if (-not (Test-Path -LiteralPath $folder -PathType Container)) { Throw-ExchangeError 'E_PATH' "Exchange folder is missing: $folderName" }
  $prefix = if ($Kind -eq 'CapabilityTransfer') { 'capability_transfer' } else { 'market_feedback' }
  foreach ($existing in @(Get-ChildItem -LiteralPath $folder -File -Filter "$prefix--*.md" -Force)) {
    try { $existingCard = Read-ExchangeCard -Path $existing.FullName -ExpectedKind $Kind } catch { continue }
    if ($existingCard.Id -cne $card.Id) { continue }
    if ($existingCard.Hash -ceq $card.Hash) { Throw-ExchangeError 'E_DUPLICATE' 'The same card is already exported.' }
    Throw-ExchangeError 'E_ID_CONFLICT' 'The exchange folder contains the same ID with another hash.'
  }
  $fileName = "$prefix--$($card.Id)--$($card.Hash.Substring(0, 8)).md"
  $targetPath = Join-Path $folder $fileName
  Write-Utf8NoBomAtomic -TargetPath $targetPath -Content $card.Content
  return [pscustomobject]@{ exported = $true; kind = $Kind; id = $card.Id; content_hash = $card.Hash; file = $fileName }
}

Export-ModuleMember -Function @(
  'Get-ExchangeErrorCode',
  'Read-ExchangeCard',
  'Test-ExchangeCard',
  'New-ExchangeImportPreview',
  'Import-ExchangeCard',
  'Export-ExchangeCard'
)

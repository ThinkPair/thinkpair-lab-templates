$script = Join-Path $PSScriptRoot 'test-guard-write.js'
& node $script
exit $LASTEXITCODE

$ErrorActionPreference = 'Stop'
$flutterCommand = Get-Command flutter -ErrorAction Stop
$flutterBin = Split-Path -Parent $flutterCommand.Source
$dartExecutable = Join-Path $flutterBin 'cache/dart-sdk/bin/dart.exe'
$flutterTool = Join-Path $flutterBin 'cache/flutter_tools.snapshot'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & $dartExecutable $flutterTool run -d web-server --web-hostname 127.0.0.1 --web-port 5173
    if ($LASTEXITCODE -ne 0) { throw "Flutter exited with code $LASTEXITCODE" }
} finally {
    Pop-Location
}

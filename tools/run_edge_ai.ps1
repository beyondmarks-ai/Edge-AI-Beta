[CmdletBinding()]
param(
  [ValidateSet('run', 'build-apk')]
  [string]$Action = 'run',
  [switch]$Release
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $workspace '.edge-ai-cloud.json'
if (-not (Test-Path -LiteralPath $configPath)) {
  throw 'Missing .edge-ai-cloud.json. Deploy AWS first with tools/deploy_aws.ps1.'
}
$config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutter = if ($null -ne $flutterCommand) {
  $flutterCommand.Source
} elseif (Test-Path -LiteralPath 'C:\src\flutter\bin\flutter.bat') {
  'C:\src\flutter\bin\flutter.bat'
} else {
  throw 'Flutter was not found on PATH or at C:\src\flutter\bin\flutter.bat.'
}
$defines = @(
  "--dart-define=EDGE_AI_API_URL=$($config.apiUrl)",
  "--dart-define=EDGE_AI_AWS_REGION=$($config.awsRegion)",
  "--dart-define=EDGE_AI_COGNITO_USER_POOL_ID=$($config.cognitoUserPoolId)",
  "--dart-define=EDGE_AI_COGNITO_CLIENT_ID=$($config.cognitoClientId)"
)

Push-Location $workspace
try {
  if ($Action -eq 'build-apk') {
    $mode = if ($Release) { '--release' } else { '--debug' }
    & $flutter build apk $mode @defines
  } else {
    & $flutter run @defines
  }
  if ($LASTEXITCODE -ne 0) { throw "Flutter exited with code $LASTEXITCODE." }
} finally {
  Pop-Location
}

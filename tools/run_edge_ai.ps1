[CmdletBinding()]
param(
  [ValidateSet('run', 'build-apk')]
  [string]$Action = 'run',
  [switch]$Release,
  [switch]$Portable
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $workspace '.edge-ai-cloud.json'
if (-not $Portable -and -not (Test-Path -LiteralPath $configPath)) {
  throw 'Missing .edge-ai-cloud.json. Deploy AWS first with tools/deploy_aws.ps1.'
}
$config = if (Test-Path -LiteralPath $configPath) {
  Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
} else {
  $null
}
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutter = if ($null -ne $flutterCommand) {
  $flutterCommand.Source
} elseif (Test-Path -LiteralPath 'C:\src\flutter\bin\flutter.bat') {
  'C:\src\flutter\bin\flutter.bat'
} else {
  throw 'Flutter was not found on PATH or at C:\src\flutter\bin\flutter.bat.'
}
$defines = if ($Portable) {
  @()
} else {
  @(
    "--dart-define=EDGE_AI_API_URL=$($config.apiUrl)",
    "--dart-define=EDGE_AI_AWS_REGION=$($config.awsRegion)",
    "--dart-define=EDGE_AI_COGNITO_USER_POOL_ID=$($config.cognitoUserPoolId)",
    "--dart-define=EDGE_AI_COGNITO_CLIENT_ID=$($config.cognitoClientId)"
  )
}

Push-Location $workspace
try {
  if ($Action -eq 'build-apk') {
    $mode = if ($Release) { '--release' } else { '--debug' }
    & $flutter build apk $mode --target-platform 'android-arm64,android-x64' @defines
    if ($LASTEXITCODE -eq 0) {
      $sourceName = if ($Release) { 'app-release.apk' } else { 'app-debug.apk' }
      $destinationName = if ($Portable) {
        'Edge-AI-portable.apk'
      } elseif ($Release) {
        'Edge-AI.apk'
      } else {
        'Edge-AI-debug.apk'
      }
      $dist = Join-Path $workspace 'dist'
      New-Item -ItemType Directory -Path $dist -Force | Out-Null
      Copy-Item -LiteralPath (Join-Path $workspace "build/app/outputs/flutter-apk/$sourceName") `
        -Destination (Join-Path $dist $destinationName) -Force
      Write-Host "APK copied to dist/$destinationName"
    }
  } else {
    & $flutter run @defines
  }
  if ($LASTEXITCODE -ne 0) { throw "Flutter exited with code $LASTEXITCODE." }
} finally {
  Pop-Location
}

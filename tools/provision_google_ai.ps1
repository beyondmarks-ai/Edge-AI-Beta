[CmdletBinding()]
param(
  [string]$ProjectId = 'edge-ai-280ac'
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$gcloud = 'C:\Users\rkmai\AppData\Local\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd'
$env:HTTP_PROXY = ''
$env:HTTPS_PROXY = ''
$env:http_proxy = ''
$env:https_proxy = ''

& $gcloud config set project $ProjectId | Out-Null
& $gcloud services enable apikeys.googleapis.com generativelanguage.googleapis.com serviceusage.googleapis.com --project $ProjectId

$keys = & $gcloud services api-keys list --format=json --project $ProjectId | ConvertFrom-Json
$keyName = ($keys | Where-Object { $_.displayName -eq 'Edge AI Gemini' } | Select-Object -First 1).name
if (-not $keyName) {
  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & $gcloud services api-keys create `
    --display-name='Edge AI Gemini' `
    --api-target='service=generativelanguage.googleapis.com' `
    --project $ProjectId `
    --quiet | Out-Null
  $createExitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorAction
  if ($createExitCode -ne 0) { throw 'Could not create the restricted Gemini API key.' }
  $keys = & $gcloud services api-keys list --format=json --project $ProjectId | ConvertFrom-Json
  $keyName = ($keys | Where-Object { $_.displayName -eq 'Edge AI Gemini' } | Select-Object -First 1).name
}
$geminiApiKey = & $gcloud services api-keys get-key-string $keyName --format='value(keyString)' --project $ProjectId
if (-not $geminiApiKey) { throw 'Could not retrieve the restricted Gemini API key.' }

$config = [ordered]@{
  projectId = $ProjectId
  keyResource = $keyName
  geminiApiKey = $geminiApiKey
  model = 'gemini-3.6-flash'
}
$configPath = Join-Path $workspace '.edge-ai-google.json'
$config | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding utf8
Write-Host "Restricted Gemini key provisioned in $ProjectId."
Write-Host "Private deployment values were written to $configPath. Do not commit this file."

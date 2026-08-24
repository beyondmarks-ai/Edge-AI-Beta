[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$AdminEmail,
  [Parameter(Mandatory = $true)]
  [SecureString]$AdminPassword,
  [string]$Region = 'us-east-1',
  [string]$StackName = 'edge-ai',
  [string]$AssistantUrl = '',
  [SecureString]$AssistantSharedSecret,
  [SecureString]$GeminiApiKey
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$backend = Join-Path $workspace 'backend'
$build = Join-Path $backend '.deploy-build'
$zip = Join-Path $backend 'edge-ai-backend.zip'
$template = Join-Path $workspace 'infra\aws\template.yaml'

$env:HTTP_PROXY = ''
$env:HTTPS_PROXY = ''
$env:http_proxy = ''
$env:https_proxy = ''

$identity = aws sts get-caller-identity --output json | ConvertFrom-Json
$accountId = $identity.Account
$bucket = "edge-ai-deploy-$accountId-$Region"
$collection = "$StackName-$accountId"
$codeKey = "backend/$((Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss'))-edge-ai.zip"

if (Test-Path -LiteralPath $build) {
  $resolved = (Resolve-Path -LiteralPath $build).Path
  if ($resolved -ne $build) { throw "Unexpected build path: $resolved" }
  Remove-Item -LiteralPath $build -Recurse -Force
}
New-Item -ItemType Directory -Path $build | Out-Null
Copy-Item -LiteralPath (Join-Path $backend 'package.json') -Destination $build
Copy-Item -LiteralPath (Join-Path $backend 'package-lock.json') -Destination $build
Copy-Item -LiteralPath (Join-Path $backend 'src') -Destination $build -Recurse

Push-Location $build
try {
  npm ci --omit=dev --include=optional --os=linux --cpu=x64
} finally {
  Pop-Location
}
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Compress-Archive -Path (Join-Path $build '*') -DestinationPath $zip -CompressionLevel Optimal

$bucketExists = $true
$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
aws s3api head-bucket --bucket $bucket 2>$null
$headBucketExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorAction
if ($headBucketExitCode -ne 0) { $bucketExists = $false }
if (-not $bucketExists) {
  if ($Region -eq 'us-east-1') {
    aws s3api create-bucket --bucket $bucket --region $Region | Out-Null
  } else {
    aws s3api create-bucket --bucket $bucket --region $Region --create-bucket-configuration "LocationConstraint=$Region" | Out-Null
  }
}
aws s3 cp $zip "s3://$bucket/$codeKey" --only-show-errors

$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
aws rekognition create-collection --collection-id $collection --region $Region 2>$null | Out-Null
$createCollectionExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorAction
if ($createCollectionExitCode -ne 0) {
  $description = aws rekognition describe-collection --collection-id $collection --region $Region --output json
  if (-not $description) { throw 'Could not create or access the Rekognition collection.' }
}

$assistantSecretText = ''
if ($null -ne $AssistantSharedSecret) {
  $assistantSecretText = [System.Net.NetworkCredential]::new('', $AssistantSharedSecret).Password
}
$geminiApiKeyText = ''
if ($null -ne $GeminiApiKey) {
  $geminiApiKeyText = [System.Net.NetworkCredential]::new('', $GeminiApiKey).Password
} else {
  $googleConfigPath = Join-Path $workspace '.edge-ai-google.json'
  if (Test-Path -LiteralPath $googleConfigPath) {
    $googleConfig = Get-Content -Raw -LiteralPath $googleConfigPath | ConvertFrom-Json
    $geminiApiKeyText = $googleConfig.geminiApiKey
  }
}
$parameterOverrides = @(
  "CodeS3Bucket=$bucket",
  "CodeS3Key=$codeKey",
  "RekognitionCollectionId=$collection",
  "AssistantUrl=$AssistantUrl",
  "AssistantSharedSecret=$assistantSecretText",
  "GeminiApiKey=$geminiApiKeyText"
)
aws cloudformation deploy `
  --template-file $template `
  --stack-name $StackName `
  --region $Region `
  --capabilities CAPABILITY_NAMED_IAM `
  --parameter-overrides $parameterOverrides `
  --no-fail-on-empty-changeset

$outputs = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query 'Stacks[0].Outputs' --output json | ConvertFrom-Json
$values = @{}
foreach ($output in $outputs) { $values[$output.OutputKey] = $output.OutputValue }

$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
aws cognito-idp admin-create-user `
  --user-pool-id $values.UserPoolId `
  --username $AdminEmail `
  --user-attributes "Name=email,Value=$AdminEmail" 'Name=email_verified,Value=true' `
  --message-action SUPPRESS `
  --region $Region 2>$null | Out-Null
$createUserExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorAction
if ($createUserExitCode -ne 0) {
  $existingUser = aws cognito-idp admin-get-user --user-pool-id $values.UserPoolId --username $AdminEmail --region $Region --output json
  if (-not $existingUser) { throw 'Could not create or access the Cognito administrator.' }
}
aws cognito-idp admin-add-user-to-group `
  --user-pool-id $values.UserPoolId `
  --username $AdminEmail `
  --group-name $values.AdminGroupName `
  --region $Region
$passwordText = [System.Net.NetworkCredential]::new('', $AdminPassword).Password
aws cognito-idp admin-set-user-password `
  --user-pool-id $values.UserPoolId `
  --username $AdminEmail `
  --password $passwordText `
  --permanent `
  --region $Region

$config = [ordered]@{
  apiUrl = $values.ApiUrl
  awsRegion = $Region
  cognitoUserPoolId = $values.UserPoolId
  cognitoClientId = $values.UserPoolClientId
  adminEmail = $AdminEmail
  initialAdminPassword = $passwordText
}
$configPath = Join-Path $workspace '.edge-ai-cloud.json'
$config | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding utf8
Write-Host "Edge AI AWS backend deployed. Configuration: $configPath"
Write-Host "Run Flutter with:"
Write-Host "flutter run --dart-define=EDGE_AI_API_URL=$($values.ApiUrl) --dart-define=EDGE_AI_AWS_REGION=$Region --dart-define=EDGE_AI_COGNITO_USER_POOL_ID=$($values.UserPoolId) --dart-define=EDGE_AI_COGNITO_CLIENT_ID=$($values.UserPoolClientId)"

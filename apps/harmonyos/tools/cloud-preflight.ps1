[CmdletBinding()]
param(
  [string]$DevEcoRoot = 'E:\DevEnviorment\DevEco Studio',
  [switch]$RequireCloudReady
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-ExternalStep {
  param(
    [string]$Name,
    [scriptblock]$Action
  )
  Write-Host "==> $Name"
  & $Action
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE"
  }
}

$harmonyRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$workspaceRoot = (Resolve-Path (Join-Path $harmonyRoot '..\..')).Path
$nodeExe = Join-Path $DevEcoRoot 'tools\node\node.exe'
$javaExe = Join-Path $DevEcoRoot 'jbr\bin\java.exe'
$hvigorExe = Join-Path $DevEcoRoot 'tools\hvigor\bin\hvigorw.bat'
$sdkRoot = Join-Path $DevEcoRoot 'sdk'
$signTool = Join-Path $sdkRoot 'default\openharmony\toolchains\lib\hap-sign-tool.jar'

@($nodeExe, $javaExe, $hvigorExe, $signTool) | ForEach-Object {
  if (-not (Test-Path -LiteralPath $_)) {
    throw "Required tool not found: $_"
  }
}

$env:DEVECO_SDK_HOME = $sdkRoot
$env:NODE_HOME = Split-Path $nodeExe -Parent
$env:JAVA_HOME = Split-Path (Split-Path $javaExe -Parent) -Parent
$env:Path = "$(Split-Path $javaExe -Parent);$(Split-Path $nodeExe -Parent);$env:Path"

Push-Location $workspaceRoot
try {
  Invoke-ExternalStep 'Public intent smoke' {
    & $nodeExe 'apps/harmonyos/tools/public-intent-smoke.mjs'
  }
  Invoke-ExternalStep 'App Agent domain smoke' {
    & $nodeExe 'apps/harmonyos/tools/review-engine-smoke.mjs'
  }
  Invoke-ExternalStep 'Web JavaScript syntax' {
    & $nodeExe '--check' 'apps/prototype-web/app.js'
  }
  Invoke-ExternalStep 'Web interaction smoke' {
    & $nodeExe 'apps/prototype-web/interaction-smoke.mjs'
  }
} finally {
  Pop-Location
}

Push-Location $harmonyRoot
try {
  Invoke-ExternalStep 'Release clean assembleHap' {
    & $hvigorExe '--mode' 'module' '-p' 'product=default' '-p' 'buildMode=release' 'clean' 'assembleHap'
  }
} finally {
  Pop-Location
}

$outputDir = Join-Path $harmonyRoot 'entry\build\default\outputs\default'
$hap = Get-ChildItem -LiteralPath $outputDir -Filter '*.hap' |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
if (-not $hap) {
  throw "No HAP found in $outputDir"
}

$packInfoPath = Join-Path $outputDir 'pack.info'
$packInfo = Get-Content -Raw -LiteralPath $packInfoPath | ConvertFrom-Json
$agentCardPath = Join-Path $harmonyRoot 'entry\src\main\resources\base\profile\agent_config.json'
$agentCard = (Get-Content -Raw -LiteralPath $agentCardPath | ConvertFrom-Json).agentCards[0]
$buildProfilePath = Join-Path $harmonyRoot 'build-profile.json5'
$buildProfile = Get-Content -Raw -LiteralPath $buildProfilePath | ConvertFrom-Json

$expectedSkills = @(
  'start_word_review_in_app',
  'quick_word_confusion_qa',
  'practice_word_confusion_in_app'
)
$actualSkills = @($agentCard.skills | ForEach-Object { $_.id })
$missingSkills = @($expectedSkills | Where-Object { $_ -notin $actualSkills })
$unexpectedSkills = @($actualSkills | Where-Object { $_ -notin $expectedSkills })
if ($missingSkills.Count -gt 0 -or $unexpectedSkills.Count -gt 0) {
  throw "AgentCard Skill mismatch. Missing=$($missingSkills -join ',') Unexpected=$($unexpectedSkills -join ',')"
}

$appVersion = $packInfo.summary.app.version
if ($appVersion.name -ne '0.4.0' -or $agentCard.version -ne '0.4.0') {
  throw "Version mismatch. app=$($appVersion.name) agent=$($agentCard.version)"
}

$signingConfigured = @($buildProfile.app.signingConfigs).Count -gt 0
$signatureVerified = $false
$signatureDetail = 'Signing config is empty.'

if ($signingConfigured) {
  $verifyDir = Join-Path ([IO.Path]::GetTempPath()) ("echo-word-sign-verify-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $verifyDir | Out-Null
  try {
    $certOut = Join-Path $verifyDir 'certificate-chain.cer'
    $profileOut = Join-Path $verifyDir 'profile.p7b'
    $verifyOutput = & $javaExe '-jar' $signTool 'verify-app' '-inFile' $hap.FullName `
      '-outCertChain' $certOut '-outProfile' $profileOut 2>&1 | Out-String
    $signatureVerified = $LASTEXITCODE -eq 0
    $signatureDetail = $verifyOutput.Trim()
  } finally {
    $resolvedVerifyDir = (Resolve-Path -LiteralPath $verifyDir).Path
    $resolvedTempRoot = (Resolve-Path -LiteralPath ([IO.Path]::GetTempPath())).Path
    if ($resolvedVerifyDir.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
      Remove-Item -LiteralPath $resolvedVerifyDir -Recurse -Force
    }
  }
}

$hash = (Get-FileHash -LiteralPath $hap.FullName -Algorithm SHA256).Hash
$cloudUploadReady = $signingConfigured -and $signatureVerified
$report = [ordered]@{
  LocalGate = 'PASS'
  HapPath = $hap.FullName
  HapBytes = $hap.Length
  Sha256 = $hash
  AppVersion = $appVersion.name
  VersionCode = $appVersion.code
  BuildVersion = $appVersion.build
  AgentVersion = $agentCard.version
  Skills = $actualSkills
  SigningConfigured = $signingConfigured
  SignatureVerified = $signatureVerified
  CloudUploadReady = $cloudUploadReady
  SignatureDetail = $signatureDetail
}

$report | ConvertTo-Json -Depth 5

if ($RequireCloudReady -and -not $cloudUploadReady) {
  [Console]::Error.WriteLine('CLOUD_UPLOAD_READY=False. Configure a release signingConfig and rerun.')
  exit 2
}

#requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$env:AWS_PAGER = ''
$env:AWS_CLI_AUTO_PROMPT = 'off'

function Invoke-LabAws {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $result = & aws @Arguments --region $script:Region --output json --no-cli-pager
    if ($LASTEXITCODE -ne 0) { throw "AWS CLI failed: $($Arguments[0]) $($Arguments[1]) (exit $LASTEXITCODE)." }
    if ($result) { return ($result -join "`n" | ConvertFrom-Json) }
}
function Write-LabJson {
    param($Value, [string]$Path)
    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}
function Save-LabState { Write-LabJson $script:State $script:StatePath }
function Get-LabTags {
    param([string]$Name)
    @(@{Key='Name'; Value=$Name}, @{Key='JenkinsLabId'; Value=$script:State.LabId})
}
function Get-LabResourceTagSpec {
    param([string]$Type, [string]$Name)
    "ResourceType=$Type,Tags=[{Key=Name,Value=$Name},{Key=JenkinsLabId,Value=$($script:State.LabId)}]"
}
function Read-LabState {
    $script:StatePath = Join-Path $PSScriptRoot '.local/jenkins-lab.json'
    if (!(Test-Path -LiteralPath $script:StatePath)) { throw 'No manifest found in .local. Use the original extracted lab folder.' }
    $script:State = Get-Content -LiteralPath $script:StatePath -Raw | ConvertFrom-Json -AsHashtable
    $script:Region = $script:State.Region
    if ($script:Region -ne 'us-west-2') { throw 'This package requires us-west-2.' }
    $identity = Invoke-LabAws @('sts','get-caller-identity')
    if ($identity.Account -ne $script:State.AccountId) { throw 'The active AWS account differs from the deployment account.' }
}
function Assert-LabOwnership {
    param([string]$ResourceId)
    $tags = Invoke-LabAws @('ec2','describe-tags','--filters',"Name=resource-id,Values=$ResourceId",'Name=key,Values=JenkinsLabId')
    if (!($tags.Tags | Where-Object Value -EQ $script:State.LabId)) { throw "Ownership tag missing or different on $ResourceId. Stopping." }
}
function Invoke-LabRetry {
    param([scriptblock]$Action)
    for ($attempt=1; $attempt -le 12; $attempt++) {
        try { & $Action; return } catch {
            if ($attempt -eq 12) { throw }
            Write-Warning "AWS dependency not ready; retry $attempt of 12 in 5 seconds."
            Start-Sleep -Seconds 5
        }
    }
}

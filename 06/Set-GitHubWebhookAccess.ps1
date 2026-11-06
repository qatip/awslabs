#requires -Version 7.4
[CmdletBinding()]
param([switch]$Enable, [switch]$Disable)
. "$PSScriptRoot/Lab.Common.ps1"
if ($Enable.IsPresent -eq $Disable.IsPresent) { throw 'Specify exactly one of -Enable or -Disable.' }
Read-LabState
Assert-LabOwnership $script:State.GroupId
if ($Enable) {
    $meta=Invoke-RestMethod -Uri 'https://api.github.com/meta' -Headers @{'User-Agent'='Jenkins-Training-Lab'} -TimeoutSec 30
    $cidrs=@($meta.hooks | Where-Object { $_ -notmatch ':' })
    if (!$cidrs.Count) { throw 'GitHub returned no IPv4 webhook ranges.' }
    foreach ($cidr in $cidrs) {
        if ($script:State.WebhookCidrs -contains $cidr) { continue }
        $null=Invoke-LabAws @('ec2','authorize-security-group-ingress','--group-id',$script:State.GroupId,'--protocol','tcp','--port','8080','--cidr',$cidr)
        $script:State.WebhookCidrs+=@($cidr); Save-LabState
    }
    Write-Host 'GitHub webhook IPv4 ranges can reach port 8080. Configure the webhook and Jenkins trigger separately.'
} else {
    foreach ($cidr in @($script:State.WebhookCidrs)) {
        $null=Invoke-LabAws @('ec2','revoke-security-group-ingress','--group-id',$script:State.GroupId,'--protocol','tcp','--port','8080','--cidr',$cidr)
        $script:State.WebhookCidrs=@($script:State.WebhookCidrs | Where-Object { $_ -ne $cidr }); Save-LabState
    }
    Write-Host 'Recorded webhook ingress removed. Workstation access remains.'
}

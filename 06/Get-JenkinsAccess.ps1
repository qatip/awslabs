#requires -Version 7.4
[CmdletBinding()]
param([ValidateRange(1,90)][int]$Attempts=30)
. "$PSScriptRoot/Lab.Common.ps1"
Read-LabState
if (!$script:State.InstanceId) { throw 'No EC2 instance was launched. Clean up this partial deployment.' }
$r=Invoke-LabAws @('ec2','describe-instances','--instance-ids',$script:State.InstanceId)
$ip=$r.Reservations[0].Instances[0].PublicIpAddress
$script:State.PublicIp=$ip; Save-LabState
$keyPath=Join-Path $PSScriptRoot ".local/$($script:State.KeyName).pem"
$knownHosts=Join-Path $PSScriptRoot '.local/known_hosts'
if (!(Test-Path -LiteralPath $keyPath)) { throw 'The private key is missing from .local.' }
Write-Host "Jenkins URL: http://$($ip):8080"
for ($attempt=1; $attempt -le $Attempts; $attempt++) {
    $result=& ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -o "UserKnownHostsFile=$knownHosts" -i $keyPath "ubuntu@$ip" 'sudo test -f /var/lib/jenkins/lab-bootstrap-complete && sudo cat /var/lib/jenkins/secrets/initialAdminPassword' 2>$null
    if ($LASTEXITCODE -eq 0 -and $result) {
        Write-Host "Initial admin password: $result"
        Write-Host 'Keep this password private. Use it in the Jenkins setup wizard.'
        return
    }
    if ($attempt -lt $Attempts) { Write-Host "Waiting for server setup ($attempt/$Attempts). Retrying in 20 seconds."; Start-Sleep -Seconds 20 }
}
throw 'Jenkins did not become ready. See the lab troubleshooting section. Do not launch another deployment.'

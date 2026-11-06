#requires -Version 7.4
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param()
. "$PSScriptRoot/Lab.Common.ps1"
Read-LabState
Write-Host "Target lab: $($script:State.LabId); account: $($script:State.AccountId); region: $script:Region"
Write-Host 'This removes Jenkins and its dedicated network. S3 buckets are handled separately in the lab.'
if (!$PSCmdlet.ShouldProcess($script:State.LabId, 'Terminate Jenkins and delete its recorded EC2 network and key pair')) { return }
if ($script:State.InstanceId) {
    Assert-LabOwnership $script:State.InstanceId
    $null=Invoke-LabAws @('ec2','terminate-instances','--instance-ids',$script:State.InstanceId)
    $null=Invoke-LabAws @('ec2','wait','instance-terminated','--instance-ids',$script:State.InstanceId)
    $script:State.InstanceId=$null; Save-LabState
}
if ($script:State.GroupId) {
    Assert-LabOwnership $script:State.GroupId
    Invoke-LabRetry { $null=Invoke-LabAws @('ec2','delete-security-group','--group-id',$script:State.GroupId) }
    $script:State.GroupId=$null; Save-LabState
}
if ($script:State.AssociationId) {
    $null=Invoke-LabAws @('ec2','disassociate-route-table','--association-id',$script:State.AssociationId)
    $script:State.AssociationId=$null; Save-LabState
}
if ($script:State.RouteTableId) {
    Assert-LabOwnership $script:State.RouteTableId
    $null=Invoke-LabAws @('ec2','delete-route-table','--route-table-id',$script:State.RouteTableId)
    $script:State.RouteTableId=$null; Save-LabState
}
if ($script:State.SubnetId) {
    Assert-LabOwnership $script:State.SubnetId
    Invoke-LabRetry { $null=Invoke-LabAws @('ec2','delete-subnet','--subnet-id',$script:State.SubnetId) }
    $script:State.SubnetId=$null; Save-LabState
}
if ($script:State.GatewayId) {
    Assert-LabOwnership $script:State.GatewayId
    if ($script:State.VpcId) { $null=Invoke-LabAws @('ec2','detach-internet-gateway','--internet-gateway-id',$script:State.GatewayId,'--vpc-id',$script:State.VpcId) }
    $null=Invoke-LabAws @('ec2','delete-internet-gateway','--internet-gateway-id',$script:State.GatewayId)
    $script:State.GatewayId=$null; Save-LabState
}
if ($script:State.VpcId) {
    Assert-LabOwnership $script:State.VpcId
    $null=Invoke-LabAws @('ec2','delete-vpc','--vpc-id',$script:State.VpcId)
    $script:State.VpcId=$null; Save-LabState
}
if ($script:State.KeyName) {
    $key=Invoke-LabAws @('ec2','describe-key-pairs','--key-names',$script:State.KeyName)
    if (!($key.KeyPairs[0].Tags | Where-Object { $_.Key -eq 'JenkinsLabId' -and $_.Value -eq $script:State.LabId })) { throw 'Key pair ownership tag differs. Stopping.' }
    $null=Invoke-LabAws @('ec2','delete-key-pair','--key-name',$script:State.KeyName)
    $keyPath=Join-Path $PSScriptRoot ".local/$($script:State.KeyName).pem"
    if (Test-Path -LiteralPath $keyPath) { Remove-Item -LiteralPath $keyPath -Force }
    $script:State.KeyName=$null; Save-LabState
}
Move-Item -LiteralPath $script:StatePath -Destination (Join-Path $PSScriptRoot ".local/removed-$($script:State.LabId).json")
Write-Host 'Recorded Jenkins resources removed. Complete S3 cleanup in the manual.'

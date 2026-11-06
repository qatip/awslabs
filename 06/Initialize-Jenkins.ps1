#requires -Version 7.4
[CmdletBinding()]
param(
    [ValidatePattern('^\d{1,3}(\.\d{1,3}){3}/32$')][string]$ClientCidr,
    [ValidatePattern('^ami-[0-9a-f]+$')][string]$AmiId,
    [ValidateSet('t3.small','t3.medium')][string]$InstanceType = 't3.small',
    [ValidatePattern('^us-west-2[a-z]$')][string]$AvailabilityZone = 'us-west-2a'
)
. "$PSScriptRoot/Lab.Common.ps1"
if (!$IsWindows) { throw 'Use PowerShell 7.4 or later on Windows.' }
foreach ($command in @('aws','ssh','icacls')) { Get-Command $command -ErrorAction Stop | Out-Null }
$script:Region = 'us-west-2'
$script:StatePath = Join-Path $PSScriptRoot '.local/jenkins-lab.json'
if (Test-Path -LiteralPath $script:StatePath) { throw 'A deployment manifest exists. Reconnect with Get-JenkinsAccess.ps1 or clean up with Remove-Jenkins.ps1.' }
$identity = Invoke-LabAws @('sts','get-caller-identity')
if (!$ClientCidr) {
    $address = (Invoke-RestMethod -Uri 'https://checkip.amazonaws.com' -TimeoutSec 20).Trim()
    $parsed = [System.Net.IPAddress]::Parse($address)
    if ($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { throw 'Supply your public IPv4 address with -ClientCidr x.x.x.x/32.' }
    $ClientCidr = "$address/32"
}
if (!$AmiId) {
    $ami = Invoke-LabAws @('ssm','get-parameter','--name','/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id')
    $AmiId = $ami.Parameter.Value
}
$image = Invoke-LabAws @('ec2','describe-images','--image-ids',$AmiId,'--owners','099720109477')
if ($image.Images.Count -ne 1 -or $image.Images[0].Architecture -ne 'x86_64' -or $image.Images[0].State -ne 'available' -or $image.Images[0].Name -notlike '*ubuntu-noble-24.04*') { throw 'Use an available Canonical Ubuntu Server 24.04 x86_64 AMI in us-west-2.' }
$labId = 'jenkins-' + [guid]::NewGuid().ToString('N').Substring(0,10)
New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot '.local') -Force | Out-Null
$script:State = [ordered]@{ LabId=$labId; Region=$script:Region; AccountId=$identity.Account; ClientCidr=$ClientCidr; AmiId=$AmiId; KeyName=$null; VpcId=$null; SubnetId=$null; GatewayId=$null; RouteTableId=$null; AssociationId=$null; GroupId=$null; InstanceId=$null; PublicIp=$null; WebhookCidrs=@() }
Save-LabState
try {
    Write-Host "Creating $labId in $script:Region for account $($identity.Account)."
    $r = Invoke-LabAws @('ec2','create-vpc','--cidr-block','10.0.0.0/16','--tag-specifications',(Get-LabResourceTagSpec 'vpc' "$labId-vpc"))
    $script:State.VpcId=$r.Vpc.VpcId; Save-LabState
    $r = Invoke-LabAws @('ec2','create-subnet','--vpc-id',$script:State.VpcId,'--cidr-block','10.0.1.0/24','--availability-zone',$AvailabilityZone,'--tag-specifications',(Get-LabResourceTagSpec 'subnet' "$labId-subnet"))
    $script:State.SubnetId=$r.Subnet.SubnetId; Save-LabState
    $r = Invoke-LabAws @('ec2','create-internet-gateway','--tag-specifications',(Get-LabResourceTagSpec 'internet-gateway' "$labId-igw"))
    $script:State.GatewayId=$r.InternetGateway.InternetGatewayId; Save-LabState
    $null = Invoke-LabAws @('ec2','attach-internet-gateway','--internet-gateway-id',$script:State.GatewayId,'--vpc-id',$script:State.VpcId)
    $r = Invoke-LabAws @('ec2','create-route-table','--vpc-id',$script:State.VpcId,'--tag-specifications',(Get-LabResourceTagSpec 'route-table' "$labId-routes"))
    $script:State.RouteTableId=$r.RouteTable.RouteTableId; Save-LabState
    $null = Invoke-LabAws @('ec2','create-route','--route-table-id',$script:State.RouteTableId,'--destination-cidr-block','0.0.0.0/0','--gateway-id',$script:State.GatewayId)
    $r = Invoke-LabAws @('ec2','associate-route-table','--route-table-id',$script:State.RouteTableId,'--subnet-id',$script:State.SubnetId)
    $script:State.AssociationId=$r.AssociationId; Save-LabState
    $r = Invoke-LabAws @('ec2','create-security-group','--group-name',"$labId-sg",'--description','Jenkins training access','--vpc-id',$script:State.VpcId,'--tag-specifications',(Get-LabResourceTagSpec 'security-group' "$labId-sg"))
    $script:State.GroupId=$r.GroupId; Save-LabState
    foreach ($port in @('22','8080')) { $null = Invoke-LabAws @('ec2','authorize-security-group-ingress','--group-id',$script:State.GroupId,'--protocol','tcp','--port',$port,'--cidr',$ClientCidr) }
    $r = Invoke-LabAws @('ec2','create-key-pair','--key-name',$labId,'--tag-specifications',(Get-LabResourceTagSpec 'key-pair' $labId))
    $script:State.KeyName=$labId; Save-LabState
    $keyPath=Join-Path $PSScriptRoot ".local/$labId.pem"
    $null=New-Item -ItemType File -Path $keyPath
    $sid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    & icacls $keyPath /inheritance:r /grant:r "*$($sid):(R,W)" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to set private key file permissions.' }
    [IO.File]::WriteAllText($keyPath, $r.KeyMaterial.Replace("`r`n","`n")+"`n", [Text.UTF8Encoding]::new($false))
    & icacls $keyPath /grant:r "*$($sid):(R)" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to restrict private key file permissions.' }
    $request = @{
        ImageId=$AmiId; MinCount=1; MaxCount=1; InstanceType=$InstanceType; KeyName=$labId
        NetworkInterfaces=@(@{DeviceIndex=0; SubnetId=$script:State.SubnetId; Groups=@($script:State.GroupId); AssociatePublicIpAddress=$true; DeleteOnTermination=$true})
        CreditSpecification=@{CpuCredits='standard'}
        MetadataOptions=@{HttpTokens='required'; HttpEndpoint='enabled'}
        BlockDeviceMappings=@(@{DeviceName='/dev/sda1'; Ebs=@{VolumeSize=16; VolumeType='gp3'; DeleteOnTermination=$true; Encrypted=$true}})
        TagSpecifications=@(@{ResourceType='instance'; Tags=(Get-LabTags "$labId-server")}, @{ResourceType='volume'; Tags=(Get-LabTags "$labId-disk")})
        UserData=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Get-Content "$PSScriptRoot/jenkins-user-data.sh" -Raw).Replace("`r`n","`n")))
    }
    $requestPath=Join-Path $PSScriptRoot '.local/launch.json'
    Write-LabJson $request $requestPath
    $r=Invoke-LabAws @('ec2','run-instances','--cli-input-json',"file://$requestPath")
    $script:State.InstanceId=$r.Instances[0].InstanceId; Save-LabState
    Write-Host 'Waiting for EC2 to run. Software installation continues on the server.'
    $null=Invoke-LabAws @('ec2','wait','instance-running','--instance-ids',$script:State.InstanceId)
    $r=Invoke-LabAws @('ec2','describe-instances','--instance-ids',$script:State.InstanceId)
    $script:State.PublicIp=$r.Reservations[0].Instances[0].PublicIpAddress; Save-LabState
    Write-Host "Jenkins URL: http://$($script:State.PublicIp):8080"
    Write-Host 'Next run .\Get-JenkinsAccess.ps1. Initial installation takes several minutes.'
} catch {
    Write-Warning 'Setup stopped. Keep .local intact and run Remove-Jenkins.ps1 before retrying.'
    throw
}

#requires -Version 5.1
<#
Run on the remote Windows VM, as the user who will run ssh.
Replaces this PEM file's access permissions with Read access for the current user.
Does not change directory permissions or the contents of the key file.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$KeyPath = (Join-Path $PSScriptRoot 'Oregon_lab_keypair.pem')
)
$ErrorActionPreference = 'Stop'
if ([Environment]::OSVersion.Platform -ne 'Win32NT') {
    throw 'Run this script in PowerShell on the remote Windows VM.'
}
$item = Get-Item -LiteralPath $KeyPath -ErrorAction Stop
if ($item.PSIsContainer -or $item.Extension -ne '.pem') {
    throw 'KeyPath must identify the downloaded .pem file.'
}
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = New-Object System.Security.AccessControl.FileSecurity
$acl.SetOwner($sid)
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($sid, 'Read', 'Allow')
$acl.AddAccessRule($rule)
if ($PSCmdlet.ShouldProcess($item.FullName, 'Restrict private key access to the current Windows user')) {
    Set-Acl -LiteralPath $item.FullName -AclObject $acl
    Write-Host 'Key permissions updated. Read access is granted only to the current user.'
}

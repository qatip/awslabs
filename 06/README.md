# Lab 6 Jenkins Terraform Pipelining

Extract this complete package to `C:\awslabs\06`, then open that folder in VS Code.
Follow `Lab6_Jenkins_Windows_PowerShell.docx` or `Student_Guide.md` from the beginning.

All AWS resources use **us-west-2 Oregon**.

- Run the PowerShell scripts on Windows with PowerShell 7.4 or later.
- Jenkins runs on the provisioned Ubuntu EC2 instance.
- Jenkins runs Terraform using the AWS credentials entered in Task 5 as `aws_user`.
- The Jenkinsfiles use Linux `sh` steps because they run on Ubuntu.
- `jenkins-user-data.sh` is sent to EC2 automatically; do not run it locally.
- Upload only the files specified in the guide to GitHub.
- Keep `.local` private and intact until cleanup is complete.

Start with the prerequisite and AWS identity checks in the guide. The normal script order is:

```powershell
.\Initialize-Jenkins.ps1
.\Get-JenkinsAccess.ps1
```

After the pipeline exercises and Terraform destruction, remove the Jenkins host with:

```powershell
.\Remove-Jenkins.ps1 -WhatIf
.\Remove-Jenkins.ps1
```

Complete the separate S3 state bucket cleanup in the guide.

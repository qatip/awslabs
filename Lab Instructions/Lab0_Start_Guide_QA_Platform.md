# Terraform in Practice AWS Lab 0

## Lab Setup

Last reviewed and tested - 24/11/26 18:22 - mcgreen@qa.com


## Contents

- [Lab Objectives](#lab-objectives)
- [Teaching Points](#teaching-points)
- [Before you begin](#before-you-begin)
- [Task1 Set up your Lab environment](#task1-set-up-your-lab-environment)
- [Task 2 Logging into AWS](#task-2-logging-into-aws)
- [Task 3 Lab Instructions](#task-3-lab-instructions)
- [Copyright](#copyright)

## Lab Objectives

In this lab, you will:

- Launch and configure Visual Studio Code (VSC) in your lab virtual machine ahead of running subsequent labs

- Access AWS using provided credentials.

## Teaching Points

This lab will configure your lab environment. The environment has a time limit of 48 hours after which it will be decommissioned. If the lab expires, ends or is restarted, you must repeat this lab before continuing.

## Before you begin

Access https://platform.qa.com and sign in.

Locate your scheduled live session…

Two lab booking should have been made for you, one for AWS based labs and another for Azure based labs. This document assumes that AWS is your preferred Cloud provider.

Select Hands on lab ‘QA Terraform in Practice  - AWS.. Click Start lab

A remote desktop will be provisioned for you. Wait until it is fully initialized.

## Task1 Set up your Lab environment

1. Open VSC from the taskbar

2. Verify that the Hashicorp Terraform and VSCode-pdf VSC extensions are installed..

3. Use windows File Explorer to verify that there is a course folder c:\awslabs present on the remote vm c: drive.

If this folder IS present, perform the following steps to ensure the course files are up to date:

Open a Powershell teminal (Right-click Start, then select ‘Terminal)

Enter the following commands:

```powershell
cd c:\awslabs
git pull
```

Close the Powershell terminal

4. If the folder is NOT present, then perform the following steps..

Open a Powershell teminal (Right-click Start, then select ‘Terminal)

Enter the following commands:

```powershell
cd \
git clone https://github.com/qatip/awslabs.git
```

Close the Powershell terminal

5. Verify c:\awslabs has been added to VSC Explorer;

If the course folder is not present in VSC Explorer, then select ‘Open Folder’ , navigate to, and select c:\awslabs

These class files are available at https://github.com/qatip/awslabs for local, post-class use.

## Task 2 Logging into AWS

6. Open a new web browser (Chrome recommended) tab and login to the AWS Console using your provided lab credentials (yours will differ from those shown below).

Note: This can be done from your local machine or on the remote desktop. The latter is recommended to avoid any possible local security restrictions.

<https://aws.amazon.com/console/>

7. When required to run Terraform commands from VSC terminal, you will need to authenticate to AWS.

8. Type `aws configure` in a VSC terminal session (Terminal, New Terminal).

9. Use the `AWS Access KEY ID` and `AWS Secret Access Key` provided at Step 3 of Section 2 in the sidebar.

10. Use `us-west-2` as your default region for this lab environment. If running these labs post-course then choose an appropriate region.

11. Leave Default output format blank.

12. These credentials are stored in `users\{username}\.aws` You can re-run aws configure at any point to change these settings.

## Task 3 Lab Instructions

13. Lab instructions are provided as MD files in `awslabs\Lab Instructions` Right-click the appropriate file and select `Open Preview`

**Congratulations, you have completed this lab**

## Copyright

© 2026 QA Michael Coulling-Green. All rights reserved. These lab materials are provided as part of an authorised training course. Course attendees may reuse these materials for their own personal learning and reference outside of the training session. Unauthorised copying, redistribution, publication, or use of these materials to deliver training is prohibited without prior written permission from the author.

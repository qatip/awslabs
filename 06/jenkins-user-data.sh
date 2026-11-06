#!/bin/bash
# Runs on Ubuntu EC2 only. Launched by Initialize-Jenkins.ps1 on Windows.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg fontconfig openjdk-21-jre-headless git unzip
install -d -m 0755 /etc/apt/keyrings
curl --retry 5 -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key -o /etc/apt/keyrings/jenkins-keyring.asc
echo 'deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/' > /etc/apt/sources.list.d/jenkins.list
curl --retry 5 -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor --batch --yes -o /etc/apt/keyrings/hashicorp.gpg
source /etc/os-release
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/hashicorp.list
apt-get update -y
apt-get install -y jenkins terraform
apt-mark hold jenkins terraform
terraform version
systemctl enable --now jenkins
touch /var/lib/jenkins/lab-bootstrap-complete

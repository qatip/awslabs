#!/bin/bash

set -euo pipefail

# =========================================================
# Variables
# =========================================================

VPC_NAME="Lab6VPC"
SUBNET_NAME="Lab6Subnet"
SECURITY_GROUP_NAME="Lab6SecurityGroup"
ROUTE_TABLE_NAME="Lab6RouteTable"
IGW_NAME="Lab6InternetGateway"

KEY_NAME="Jenkins"
INSTANCE_NAME="JenkinsServer"

INSTANCE_TYPE="t3.small"
REGION="us-east-1"

VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"

JENKINS_VERSION="2.541.1"

# =========================================================
# Helper Function
# =========================================================

resource_exists() {
    [[ "$1" != "None" && -n "$1" ]]
}

# =========================================================
# Retrieve Latest Ubuntu 22.04 AMI
# =========================================================
echo ""
echo "========================================================="
echo "Retrieving Latest Ubuntu 22.04 AMI..."
echo "========================================================="

AMI_ID=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters \
        "Name=name,Values=*22.04-amd64-server-*" \
        "Name=architecture,Values=x86_64" \
        "Name=virtualization-type,Values=hvm" \
        "Name=root-device-type,Values=ebs" \
    --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" \
    --region $REGION \
    --output text)

if [ "$AMI_ID" == "None" ] || [ -z "$AMI_ID" ]; then
    echo "Unable to locate Ubuntu AMI."
    exit 1
fi

echo "Using AMI: $AMI_ID"

# =========================================================
# Select Supported Availability Zone
# =========================================================

echo ""
echo "========================================================="
echo "Selecting Availability Zone..."
echo "========================================================="

AVAILABLE_AZS=($(aws ec2 describe-instance-type-offerings \
    --location-type availability-zone \
    --filters Name=instance-type,Values=$INSTANCE_TYPE \
    --region $REGION \
    --query "InstanceTypeOfferings[*].Location" \
    --output text))

if [ ${#AVAILABLE_AZS[@]} -eq 0 ]; then
    echo "No supported Availability Zones found for $INSTANCE_TYPE"
    exit 1
fi

RANDOM_AZ=${AVAILABLE_AZS[$RANDOM % ${#AVAILABLE_AZS[@]}]}

echo "Selected Availability Zone: $RANDOM_AZ"

# =========================================================
# Locate Existing Resources
# =========================================================

echo ""
echo "========================================================="
echo "Checking for existing resources..."
echo "========================================================="

VPC_ID=$(aws ec2 describe-vpcs \
    --region $REGION \
    --filters "Name=tag:Name,Values=$VPC_NAME" \
    --query "Vpcs[0].VpcId" \
    --output text 2>/dev/null || echo "")

SUBNET_ID=$(aws ec2 describe-subnets \
    --region $REGION \
    --filters "Name=tag:Name,Values=$SUBNET_NAME" \
    --query "Subnets[0].SubnetId" \
    --output text 2>/dev/null || echo "")

IGW_ID=$(aws ec2 describe-internet-gateways \
    --region $REGION \
    --filters "Name=tag:Name,Values=$IGW_NAME" \
    --query "InternetGateways[0].InternetGatewayId" \
    --output text 2>/dev/null || echo "")

ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
    --region $REGION \
    --filters "Name=tag:Name,Values=$ROUTE_TABLE_NAME" \
    --query "RouteTables[0].RouteTableId" \
    --output text 2>/dev/null || echo "")

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
    --region $REGION \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || echo "")

INSTANCE_ID=$(aws ec2 describe-instances \
    --region $REGION \
    --filters \
        "Name=tag:Name,Values=$INSTANCE_NAME" \
        "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text 2>/dev/null || echo "")

# =========================================================
# Create VPC
# =========================================================

if resource_exists "$VPC_ID"; then

    echo "VPC already exists: $VPC_ID"

else

    echo ""
    echo "========================================================="
    echo "Creating VPC..."
    echo "========================================================="

    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block $VPC_CIDR \
        --region $REGION \
        --query "Vpc.VpcId" \
        --output text)

    aws ec2 create-tags \
        --resources $VPC_ID \
        --tags Key=Name,Value=$VPC_NAME \
        --region $REGION

    echo "VPC created: $VPC_ID"
fi

# =========================================================
# Create Subnet
# =========================================================

if resource_exists "$SUBNET_ID"; then

    echo "Subnet already exists: $SUBNET_ID"

else

    echo ""
    echo "========================================================="
    echo "Creating Subnet..."
    echo "========================================================="

    SUBNET_ID=$(aws ec2 create-subnet \
        --vpc-id $VPC_ID \
        --cidr-block $SUBNET_CIDR \
        --availability-zone $RANDOM_AZ \
        --region $REGION \
        --query "Subnet.SubnetId" \
        --output text)

    aws ec2 create-tags \
        --resources $SUBNET_ID \
        --tags Key=Name,Value=$SUBNET_NAME \
        --region $REGION

    sleep 5

    aws ec2 modify-subnet-attribute \
        --subnet-id $SUBNET_ID \
        --map-public-ip-on-launch \
        --region $REGION

    echo "Subnet created: $SUBNET_ID"
fi

# =========================================================
# Create Internet Gateway
# =========================================================

if resource_exists "$IGW_ID"; then

    echo "Internet Gateway already exists: $IGW_ID"

else

    echo ""
    echo "========================================================="
    echo "Creating Internet Gateway..."
    echo "========================================================="

    IGW_ID=$(aws ec2 create-internet-gateway \
        --region $REGION \
        --query "InternetGateway.InternetGatewayId" \
        --output text)

    aws ec2 attach-internet-gateway \
        --internet-gateway-id $IGW_ID \
        --vpc-id $VPC_ID \
        --region $REGION

    aws ec2 create-tags \
        --resources $IGW_ID \
        --tags Key=Name,Value=$IGW_NAME \
        --region $REGION

    echo "Internet Gateway created: $IGW_ID"
fi

# =========================================================
# Create Route Table
# =========================================================

if resource_exists "$ROUTE_TABLE_ID"; then

    echo "Route Table already exists: $ROUTE_TABLE_ID"

else

    echo ""
    echo "========================================================="
    echo "Creating Route Table..."
    echo "========================================================="

    ROUTE_TABLE_ID=$(aws ec2 create-route-table \
        --vpc-id $VPC_ID \
        --region $REGION \
        --query "RouteTable.RouteTableId" \
        --output text)

    aws ec2 create-tags \
        --resources $ROUTE_TABLE_ID \
        --tags Key=Name,Value=$ROUTE_TABLE_NAME \
        --region $REGION

    aws ec2 create-route \
        --route-table-id $ROUTE_TABLE_ID \
        --destination-cidr-block 0.0.0.0/0 \
        --gateway-id $IGW_ID \
        --region $REGION

    aws ec2 associate-route-table \
        --route-table-id $ROUTE_TABLE_ID \
        --subnet-id $SUBNET_ID \
        --region $REGION

    echo "Route Table created: $ROUTE_TABLE_ID"
fi

# =========================================================
# Create Security Group
# =========================================================

if resource_exists "$SECURITY_GROUP_ID"; then

    echo "Security Group already exists: $SECURITY_GROUP_ID"

else

    echo ""
    echo "========================================================="
    echo "Creating Security Group..."
    echo "========================================================="

    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name $SECURITY_GROUP_NAME \
        --description "Allow SSH, HTTP and Jenkins" \
        --vpc-id $VPC_ID \
        --region $REGION \
        --query "GroupId" \
        --output text)

    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region $REGION

    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region $REGION

    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 8080 \
        --cidr 0.0.0.0/0 \
        --region $REGION

    echo "Security Group created: $SECURITY_GROUP_ID"
fi

# =========================================================
# Create Key Pair
# =========================================================

echo ""
echo "========================================================="
echo "Checking Key Pair..."
echo "========================================================="

if aws ec2 describe-key-pairs \
    --key-names "$KEY_NAME" \
    --region $REGION >/dev/null 2>&1; then

    echo "Key pair already exists."

else

    aws ec2 create-key-pair \
        --region $REGION \
        --key-name $KEY_NAME \
        --query "KeyMaterial" \
        --output text > ${KEY_NAME}.pem

    chmod 400 ${KEY_NAME}.pem

    echo "Key pair created."
fi

# =========================================================
# User Data
# =========================================================

USER_DATA=$(cat <<EOF
#!/bin/bash

set -e

apt-get update -y
apt-get upgrade -y

apt-get install -y \
    fontconfig \
    openjdk-21-jre \
    curl \
    gnupg \
    unzip
    git

mkdir -p /etc/apt/keyrings

curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key \
    | tee /etc/apt/keyrings/jenkins-keyring.asc > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
    > /etc/apt/sources.list.d/jenkins.list

apt-get update -y

apt-get install -y jenkins=${JENKINS_VERSION}

apt-mark hold jenkins

systemctl enable jenkins
systemctl start jenkins

echo "jenkins ALL=(ALL) NOPASSWD: /usr/bin/mv, /usr/bin/unzip" \
    > /etc/sudoers.d/jenkins

chmod 440 /etc/sudoers.d/jenkins

until [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; do
    sleep 10
done

cat /var/lib/jenkins/secrets/initialAdminPassword \
    > /home/ubuntu/jenkins_admin_password.txt

chown ubuntu:ubuntu /home/ubuntu/jenkins_admin_password.txt
EOF
)

# =========================================================
# Launch EC2 Instance
# =========================================================

if resource_exists "$INSTANCE_ID"; then

    echo "EC2 Instance already exists: $INSTANCE_ID"

else

    echo ""
    echo "========================================================="
    echo "Launching EC2 Instance..."
    echo "========================================================="

    INSTANCE_ID=$(aws ec2 run-instances \
        --region $REGION \
        --image-id $AMI_ID \
        --count 1 \
        --instance-type $INSTANCE_TYPE \
        --key-name $KEY_NAME \
        --security-group-ids $SECURITY_GROUP_ID \
        --subnet-id $SUBNET_ID \
        --associate-public-ip-address \
        --user-data "$USER_DATA" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
        --query "Instances[0].InstanceId" \
        --output text)

    echo "Waiting for instance to enter running state..."

    aws ec2 wait instance-running \
        --instance-ids $INSTANCE_ID \
        --region $REGION
fi

# =========================================================
# Retrieve Public IP
# =========================================================

INSTANCE_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

echo ""
echo "Instance Public IP: $INSTANCE_IP"

# =========================================================
# Wait for Jenkins
# =========================================================

echo ""
echo "========================================================="
echo "Waiting for Jenkins..."
echo "========================================================="

until curl -s http://$INSTANCE_IP:8080/login >/dev/null; do
    echo "Jenkins not ready yet..."
    sleep 15
done

echo "Jenkins is available."

# =========================================================
# Wait for SSH
# =========================================================

echo ""
echo "========================================================="
echo "Waiting for SSH..."
echo "========================================================="

until ssh -o StrictHostKeyChecking=no \
    -i ${KEY_NAME}.pem \
    ubuntu@$INSTANCE_IP "echo SSH Ready" >/dev/null 2>&1; do

    echo "SSH not ready yet..."
    sleep 15
done

# =========================================================
# Wait for Password File
# =========================================================

echo ""
echo "========================================================="
echo "Waiting for Jenkins password file..."
echo "========================================================="

until ssh -o StrictHostKeyChecking=no \
    -i ${KEY_NAME}.pem \
    ubuntu@$INSTANCE_IP \
    "test -f /home/ubuntu/jenkins_admin_password.txt" >/dev/null 2>&1; do

    echo "Password file not ready yet..."
    sleep 15
done

# =========================================================
# Retrieve Password
# =========================================================

PASSWORD=$(ssh -o StrictHostKeyChecking=no \
    -i ${KEY_NAME}.pem \
    ubuntu@$INSTANCE_IP \
    "cat /home/ubuntu/jenkins_admin_password.txt")

echo ""
echo "========================================================="
echo "Jenkins Setup Complete"
echo "========================================================="
echo "Jenkins URL: http://$INSTANCE_IP:8080"
echo "Username: admin"
echo "Password: $PASSWORD"
echo ""

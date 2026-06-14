#!/bin/bash
# Lab08 replacement script. Location updated to US-WEST-2 as SCP blocking london. (Note: Jenkins LAb Steps/Instructions also need update)

set -euo pipefail
export AWS_PAGER=""

# Variables
VPC_NAME="JenkinsVPC"
SUBNET_NAME="Jenkins"
SECURITY_GROUP_NAME="JenkinsSecurityGroup"
ROUTE_TABLE_NAME="JenkinsRouteTable"
IGW_NAME="JenkinsInternetGateway"
KEY_NAME="Jenkins"
INSTANCE_NAME="JenkinsServer"
AMI_ID="ami-0ba80f8099420ac44"
INSTANCE_TYPE="t3.small"
REGION="us-west-2"

# Function to handle errors
handle_error() {
  echo "Error occurred during $1. Exiting..."
  exit 1
}

# Preflight checks
command -v aws >/dev/null 2>&1 || handle_error "AWS CLI not found"
aws sts get-caller-identity >/dev/null || handle_error "AWS credentials check"
REGION_CHECK_ERR=""
if ! REGION_CHECK_ERR=$(aws ec2 describe-regions --region "$REGION" --region-names "$REGION" 2>&1 >/dev/null); then
  if echo "$REGION_CHECK_ERR" | grep -q "UnauthorizedOperation"; then
    echo "Warning: Skipping region validation due to SCP restriction on ec2:DescribeRegions."
  else
    echo "$REGION_CHECK_ERR"
    handle_error "Region validation for $REGION"
  fi
fi

echo "Using AMI_ID=$AMI_ID in region $REGION"

# Step 1: Create VPC
echo "Starting: Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region "$REGION" --query "Vpc.VpcId" --output text) || handle_error "VPC creation"
aws ec2 create-tags --resources "$VPC_ID" --tags "Key=Name,Value=$VPC_NAME" --region "$REGION" >/dev/null 2>&1

echo "Completed: VPC $VPC_NAME created with ID: $VPC_ID"

# Step 2: Create Subnet
echo "Starting: Creating Subnet..."
SUBNET_ID=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 --availability-zone "${REGION}a" --region "$REGION" --query "Subnet.SubnetId" --output text 2>/dev/null) || handle_error "Subnet creation"
aws ec2 create-tags --resources "$SUBNET_ID" --tags "Key=Name,Value=$SUBNET_NAME" --region "$REGION" >/dev/null 2>&1
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_ID" --map-public-ip-on-launch --region "$REGION" >/dev/null 2>&1

echo "Completed: Subnet $SUBNET_NAME created with ID: $SUBNET_ID"

# Step 3: Create Internet Gateway and Attach to VPC
echo "Starting: Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --region "$REGION" --query "InternetGateway.InternetGatewayId" --output text 2>/dev/null) || handle_error "Internet Gateway creation"
aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$REGION" >/dev/null 2>&1
aws ec2 create-tags --resources "$IGW_ID" --tags "Key=Name,Value=$IGW_NAME" --region "$REGION" >/dev/null 2>&1

echo "Completed: Internet Gateway $IGW_NAME created with ID: $IGW_ID"

# Step 4: Create Route Table and Associate with Subnet
echo "Starting: Creating Route Table..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --region "$REGION" --query "RouteTable.RouteTableId" --output text 2>/dev/null) || handle_error "Route Table creation"
aws ec2 create-tags --resources "$ROUTE_TABLE_ID" --tags "Key=Name,Value=$ROUTE_TABLE_NAME" --region "$REGION" >/dev/null 2>&1
aws ec2 create-route --route-table-id "$ROUTE_TABLE_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" --region "$REGION" >/dev/null 2>&1
aws ec2 associate-route-table --route-table-id "$ROUTE_TABLE_ID" --subnet-id "$SUBNET_ID" --region "$REGION" >/dev/null 2>&1

echo "Completed: Route Table $ROUTE_TABLE_NAME created and associated with Subnet $SUBNET_NAME"

# Step 5: Create Security Group
echo "Starting: Creating Security Group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "Allow SSH and HTTP traffic" --vpc-id "$VPC_ID" --region "$REGION" --query "GroupId" --output text 2>/dev/null) || handle_error "Security Group creation"
aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$REGION" >/dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 80 --cidr 0.0.0.0/0 --region "$REGION" >/dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region "$REGION" >/dev/null 2>&1

echo "Completed: Security Group $SECURITY_GROUP_NAME created with ID: $SECURITY_GROUP_ID"

# Step 6: Create Key Pair
echo "Starting: Creating Key Pair..."
aws ec2 create-key-pair --key-name "$KEY_NAME" --region "$REGION" --query "KeyMaterial" --output text > "${KEY_NAME}.pem" 2>/dev/null || handle_error "Key Pair creation"
chmod 400 "${KEY_NAME}.pem"

echo "Completed: Key Pair $KEY_NAME created and saved as ${KEY_NAME}.pem"

# Step 7: Launch EC2 Instance with User Data
echo "Starting: Launching EC2 Instance..."
JENKINS_VERSION="2.555.3"


USER_DATA=$(cat <<END
#!/bin/bash
set -e

apt-get update -y

apt-get install -y \
    fontconfig \
    openjdk-21-jre \
    curl \
    gnupg \
    unzip \
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
END
)


INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SECURITY_GROUP_ID" \
  --subnet-id "$SUBNET_ID" \
  --associate-public-ip-address \
  --user-data "$USER_DATA" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --region "$REGION" \
  --query "Instances[0].InstanceId" \
  --output text 2>/dev/null) || handle_error "EC2 Instance creation"

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

echo "Completed: EC2 Instance $INSTANCE_NAME launched with ID: $INSTANCE_ID"

# Retrieve public IP
INSTANCE_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region "$REGION" 2>/dev/null) || handle_error "Retrieving Instance IP"
echo "Instance is accessible at: http://$INSTANCE_IP:8080"

# =========================================================
# Wait for Jenkins and Retrieve Initial Password
# =========================================================

echo ""
echo "========================================================="
echo "Waiting for Jenkins to initialize..."
echo "========================================================="

PASSWORD=""

for i in {1..20}; do

    echo "Attempt $i of 20..."

    PASSWORD=$(ssh \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=10 \
        -i "${KEY_NAME}.pem" \
        "ubuntu@$INSTANCE_IP" \
        "sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null" \
        || true)

    if [ -n "$PASSWORD" ]; then
        break
    fi

    echo "Jenkins not ready yet. Waiting 30 seconds..."
    sleep 30

done

echo ""
echo "========================================================="
echo "Jenkins Deployment Complete"
echo "========================================================="

echo "Jenkins URL:"
echo "http://$INSTANCE_IP:8080"

if [ -n "$PASSWORD" ]; then
    echo ""
    echo "Initial Admin Password:"
    echo "$PASSWORD"
else
    echo ""
    echo "Unable to retrieve the Jenkins initial admin password automatically."
    echo "Connect using:"
    echo "ssh -i ${KEY_NAME}.pem ubuntu@$INSTANCE_IP"
    echo ""
    echo "Then run:"
    echo "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
fi

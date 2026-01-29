#!/bin/bash

# Variables
VPC_NAME="Lab6VPC"
SUBNET_NAME="Lab6Subnet"
SECURITY_GROUP_NAME="Lab6SecurityGroup"
ROUTE_TABLE_NAME="Lab6RouteTable"
IGW_NAME="Lab6InternetGateway"
KEY_NAME="Jenkins" # Change if teardown/recreate attempted
INSTANCE_NAME="JenkinsServer"
AMI_ID="ami-020cba7c55df1f615" # Replace with your desired AMI ID (Ubuntu 22.04 in us-east-1)
INSTANCE_TYPE="t3.small"
REGION="us-east-1"

# Function to handle errors
handle_error() {
    echo "Error occurred during $1. Exiting..."
    exit 1
}

# Step 1: Create VPC
echo "Starting: Creating VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region $REGION --query "Vpc.VpcId" --output text 2>/dev/null) || handle_error "VPC creation"
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=$VPC_NAME --region $REGION >/dev/null 2>&1
echo "Completed: VPC $VPC_NAME created with ID: $VPC_ID"

# Step 2: Create Subnet
echo "Starting: Creating Subnet..."
SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --region ${REGION} --query "Subnet.SubnetId" --output text 2>/dev/null) || handle_error "Subnet creation"
aws ec2 create-tags --resources $SUBNET_ID --tags Key=Name,Value=$SUBNET_NAME --region $REGION >/dev/null 2>&1
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch >/dev/null 2>&1
echo "Completed: Subnet $SUBNET_NAME created with ID: $SUBNET_ID"

# Step 3: Create Internet Gateway and Attach to VPC
echo "Starting: Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway --region $REGION --query "InternetGateway.InternetGatewayId" --output text 2>/dev/null) || handle_error "Internet Gateway creation"
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION >/dev/null 2>&1
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=$IGW_NAME --region $REGION >/dev/null 2>&1
echo "Completed: Internet Gateway $IGW_NAME created with ID: $IGW_ID"

# Step 4: Create Route Table and Associate with Subnet
echo "Starting: Creating Route Table..."
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query "RouteTable.RouteTableId" --output text 2>/dev/null) || handle_error "Route Table creation"
aws ec2 create-tags --resources $ROUTE_TABLE_ID --tags Key=Name,Value=$ROUTE_TABLE_NAME --region $REGION >/dev/null 2>&1
aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION >/dev/null 2>&1
aws ec2 associate-route-table --route-table-id $ROUTE_TABLE_ID --subnet-id $SUBNET_ID --region $REGION >/dev/null 2>&1
echo "Completed: Route Table $ROUTE_TABLE_NAME created and associated with Subnet $SUBNET_NAME"

# Step 5: Create Security Group
echo "Starting: Creating Security Group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name $SECURITY_GROUP_NAME --region ${REGION} --description "Allow SSH and HTTP traffic" --vpc-id $VPC_ID --query "GroupId" --output text 2>/dev/null) || handle_error "Security Group creation"
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION >/dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region $REGION >/dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id $SECURITY_GROUP_ID --protocol tcp --port 8080 --cidr 0.0.0.0/0 --region $REGION >/dev/null 2>&1
echo "Completed: Security Group $SECURITY_GROUP_NAME created with ID: $SECURITY_GROUP_ID"

# Step 6: Create Key Pair
echo "Starting: Creating Key Pair..."
aws ec2 create-key-pair --region ${REGION} --key-name $KEY_NAME --query "KeyMaterial" --output text > ${KEY_NAME}.pem 2>/dev/null || handle_error "Key Pair creation"
chmod 400 ${KEY_NAME}.pem
echo "Completed: Key Pair $KEY_NAME created and saved as ${KEY_NAME}.pem"

# Step 7: Launch EC2 Instance with User Data
echo "Starting: Launching EC2 Instance..."
JENKINS_VERSION="2.516.3"  # Change this to your desired Jenkins version

USER_DATA=$(cat <<-END
#!/bin/bash
set -e  # Exit on error

# Update and install dependencies
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y openjdk-17-jdk unzip curl gnupg lsb-release

# Add Jenkins repository and install specific version
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update -y
sudo apt install -y jenkins=$JENKINS_VERSION
sudo apt-mark hold jenkins  # Prevent automatic updates

# Start and enable Jenkins
sudo systemctl enable --now jenkins
sudo systemctl restart jenkins

# Configure sudoers for Jenkins
sudo bash -c 'echo "jenkins ALL=(ALL) NOPASSWD: /usr/bin/mv, /usr/bin/unzip" > /etc/sudoers.d/jenkins'
sudo chmod 440 /etc/sudoers.d/jenkins

# Save Jenkins initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword > /home/ubuntu/jenkins_admin_password.txt || true
END
)
INSTANCE_ID=$(aws ec2 run-instances \
    --region ${REGION} \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --subnet-id $SUBNET_ID \
    --associate-public-ip-address \
    --user-data "$USER_DATA" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
    --query "Instances[0].InstanceId" --output text 2>/dev/null) || handle_error "EC2 Instance creation"
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION
echo "Completed: EC2 Instance $INSTANCE_NAME launched with ID: $INSTANCE_ID"

# Retrieve the public IP address of the instance
INSTANCE_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PublicIpAddress" --output text --region $REGION 2>/dev/null) || handle_error "Retrieving Instance IP"
echo "Instance is accessible at IP: http://$INSTANCE_IP:8080"

# Wait for Jenkins initialization
echo "Waiting 5 minutes for Jenkins to initialize..."
sleep 60
echo "Waiting 4 minutes for Jenkins to initialize..."
sleep 60
echo "Waiting 3 minutes for Jenkins to initialize..."
sleep 60
echo "Waiting 2 minutes for Jenkins to initialize..."
sleep 60
echo "Waiting 1 minutes for Jenkins to initialize..."
sleep 60

# Retrieve the Jenkins admin password
echo "Retrieving the Jenkins initial admin password..."
PASSWORD=$(ssh -o StrictHostKeyChecking=no -i ${KEY_NAME}.pem ubuntu@$INSTANCE_IP "cat /home/ubuntu/jenkins_admin_password.txt" 2>/dev/null)

if [ -z "$PASSWORD" ]; then
    echo "Unable to retrieve the Jenkins admin password. Please SSH into the instance and check manually."
else
    echo "Jenkins setup complete!"
    echo "Access Jenkins at: http://$INSTANCE_IP:8080"
    echo "Initial Admin Password: $PASSWORD"
fi

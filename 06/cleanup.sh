#!/bin/bash

set -euo pipefail

# =========================================================
# Variables
# =========================================================

REGION="us-east-1"

VPC_NAME="Lab6VPC"
SUBNET_NAME="Lab6Subnet"
SECURITY_GROUP_NAME="Lab6SecurityGroup"
ROUTE_TABLE_NAME="Lab6RouteTable"
IGW_NAME="Lab6InternetGateway"
KEY_NAME="Jenkins"
INSTANCE_NAME="JenkinsServer"

# =========================================================
# Locate Resources
# =========================================================

echo ""
echo "========================================================="
echo "Locating AWS Resources..."
echo "========================================================="

VPC_ID=$(aws ec2 describe-vpcs \
    --region $REGION \
    --filters "Name=tag:Name,Values=$VPC_NAME" \
    --query "Vpcs[0].VpcId" \
    --output text)

SUBNET_ID=$(aws ec2 describe-subnets \
    --region $REGION \
    --filters "Name=tag:Name,Values=$SUBNET_NAME" \
    --query "Subnets[0].SubnetId" \
    --output text)

SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
    --region $REGION \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --query "SecurityGroups[0].GroupId" \
    --output text)

ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
    --region $REGION \
    --filters "Name=tag:Name,Values=$ROUTE_TABLE_NAME" \
    --query "RouteTables[0].RouteTableId" \
    --output text)

IGW_ID=$(aws ec2 describe-internet-gateways \
    --region $REGION \
    --filters "Name=tag:Name,Values=$IGW_NAME" \
    --query "InternetGateways[0].InternetGatewayId" \
    --output text)

INSTANCE_ID=$(aws ec2 describe-instances \
    --region $REGION \
    --filters \
        "Name=tag:Name,Values=$INSTANCE_NAME" \
        "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text)

# =========================================================
# Display Located Resources
# =========================================================

echo "VPC ID:              ${VPC_ID:-Not Found}"
echo "Subnet ID:           ${SUBNET_ID:-Not Found}"
echo "Security Group ID:   ${SECURITY_GROUP_ID:-Not Found}"
echo "Route Table ID:      ${ROUTE_TABLE_ID:-Not Found}"
echo "Internet Gateway ID: ${IGW_ID:-Not Found}"
echo "Instance ID:         ${INSTANCE_ID:-Not Found}"

# =========================================================
# Terminate EC2 Instance
# =========================================================

if [[ "$INSTANCE_ID" != "None" && -n "$INSTANCE_ID" ]]; then

    echo ""
    echo "========================================================="
    echo "Terminating EC2 Instance..."
    echo "========================================================="

    aws ec2 terminate-instances \
        --instance-ids $INSTANCE_ID \
        --region $REGION >/dev/null

    echo "Waiting for instance termination..."

    aws ec2 wait instance-terminated \
        --instance-ids $INSTANCE_ID \
        --region $REGION

    echo "EC2 Instance terminated."

else
    echo "No EC2 instance found."
fi

# =========================================================
# Delete Security Group
# =========================================================

if [[ "$SECURITY_GROUP_ID" != "None" && -n "$SECURITY_GROUP_ID" ]]; then

    echo ""
    echo "Deleting Security Group..."

    aws ec2 delete-security-group \
        --group-id $SECURITY_GROUP_ID \
        --region $REGION

    echo "Security Group deleted."

else
    echo "No Security Group found."
fi

# =========================================================
# Delete Route Table
# =========================================================

if [[ "$ROUTE_TABLE_ID" != "None" && -n "$ROUTE_TABLE_ID" ]]; then

    echo ""
    echo "Deleting Route Table..."

    ASSOCIATION_ID=$(aws ec2 describe-route-tables \
        --route-table-ids $ROUTE_TABLE_ID \
        --region $REGION \
        --query "RouteTables[0].Associations[?Main==\`false\`].RouteTableAssociationId" \
        --output text)

    if [[ "$ASSOCIATION_ID" != "None" && -n "$ASSOCIATION_ID" ]]; then

        aws ec2 disassociate-route-table \
            --association-id $ASSOCIATION_ID \
            --region $REGION

    fi

    aws ec2 delete-route-table \
        --route-table-id $ROUTE_TABLE_ID \
        --region $REGION

    echo "Route Table deleted."

else
    echo "No Route Table found."
fi

# =========================================================
# Detach and Delete Internet Gateway
# =========================================================

if [[ "$IGW_ID" != "None" && -n "$IGW_ID" ]]; then

    echo ""
    echo "Detaching Internet Gateway..."

    aws ec2 detach-internet-gateway \
        --internet-gateway-id $IGW_ID \
        --vpc-id $VPC_ID \
        --region $REGION

    echo "Deleting Internet Gateway..."

    aws ec2 delete-internet-gateway \
        --internet-gateway-id $IGW_ID \
        --region $REGION

    echo "Internet Gateway deleted."

else
    echo "No Internet Gateway found."
fi

# =========================================================
# Delete Subnet
# =========================================================

if [[ "$SUBNET_ID" != "None" && -n "$SUBNET_ID" ]]; then

    echo ""
    echo "Deleting Subnet..."

    aws ec2 delete-subnet \
        --subnet-id $SUBNET_ID \
        --region $REGION

    echo "Subnet deleted."

else
    echo "No Subnet found."
fi

# =========================================================
# Delete VPC
# =========================================================

if [[ "$VPC_ID" != "None" && -n "$VPC_ID" ]]; then

    echo ""
    echo "Deleting VPC..."

    aws ec2 delete-vpc \
        --vpc-id $VPC_ID \
        --region $REGION

    echo "VPC deleted."

else
    echo "No VPC found."
fi

# =========================================================
# Delete Key Pair
# =========================================================

if aws ec2 describe-key-pairs \
    --key-names "$KEY_NAME" \
    --region $REGION >/dev/null 2>&1; then

    echo ""
    echo "Deleting AWS Key Pair..."

    aws ec2 delete-key-pair \
        --key-name $KEY_NAME \
        --region $REGION

    echo "AWS Key Pair deleted."

else
    echo "No AWS Key Pair found."
fi

# =========================================================
# Delete Local PEM File
# =========================================================

if [ -f "${KEY_NAME}.pem" ]; then

    echo ""
    echo "Deleting local PEM file..."

    rm -f "${KEY_NAME}.pem"

    echo "Local PEM file deleted."

else
    echo "No local PEM file found."
fi



echo ""
echo "========================================================="
echo "Cleanup Complete"
echo "========================================================="
#!/bin/bash

set -u
export AWS_PAGER=""

REGION="us-west-2"

VPC_NAME="JenkinsVPC"
SUBNET_NAME="Jenkins"
SECURITY_GROUP_NAME="JenkinsSecurityGroup"
ROUTE_TABLE_NAME="JenkinsRouteTable"
IGW_NAME="JenkinsInternetGateway"
KEY_NAME="Jenkins"
INSTANCE_NAME="JenkinsServer"

echo ""
echo "========================================================="
echo "Robust Jenkins Lab Cleanup"
echo "Region: $REGION"
echo "========================================================="

run_safe() {
  "$@" >/dev/null 2>&1 || true
}

echo ""
echo "Finding EC2 instances..."
INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=tag:Name,Values=$INSTANCE_NAME" \
    "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text 2>/dev/null || true)

if [ -n "$INSTANCE_IDS" ] && [ "$INSTANCE_IDS" != "None" ]; then
  echo "Terminating instances: $INSTANCE_IDS"
  run_safe aws ec2 terminate-instances --region "$REGION" --instance-ids $INSTANCE_IDS
  run_safe aws ec2 wait instance-terminated --region "$REGION" --instance-ids $INSTANCE_IDS
else
  echo "No matching EC2 instances found."
fi

echo ""
echo "Finding VPCs..."
VPC_IDS=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=$VPC_NAME" \
  --query "Vpcs[].VpcId" \
  --output text 2>/dev/null || true)

if [ -z "$VPC_IDS" ] || [ "$VPC_IDS" = "None" ]; then
  echo "No matching VPCs found."
else
  for VPC_ID in $VPC_IDS; do
    echo ""
    echo "Cleaning VPC: $VPC_ID"

    echo "Deleting security groups..."
    SG_IDS=$(aws ec2 describe-security-groups \
      --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=$SECURITY_GROUP_NAME" \
      --query "SecurityGroups[].GroupId" \
      --output text 2>/dev/null || true)

    for SG_ID in $SG_IDS; do
      [ "$SG_ID" = "None" ] && continue
      echo "Deleting security group: $SG_ID"
      run_safe aws ec2 delete-security-group --region "$REGION" --group-id "$SG_ID"
    done

    echo "Disassociating and deleting custom route tables..."
    RT_IDS=$(aws ec2 describe-route-tables \
      --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=$ROUTE_TABLE_NAME" \
      --query "RouteTables[].RouteTableId" \
      --output text 2>/dev/null || true)

    for RT_ID in $RT_IDS; do
      [ "$RT_ID" = "None" ] && continue

      ASSOC_IDS=$(aws ec2 describe-route-tables \
        --region "$REGION" \
        --route-table-ids "$RT_ID" \
        --query "RouteTables[].Associations[?Main==\`false\`].RouteTableAssociationId" \
        --output text 2>/dev/null || true)

      for ASSOC_ID in $ASSOC_IDS; do
        [ "$ASSOC_ID" = "None" ] && continue
        echo "Disassociating route table association: $ASSOC_ID"
        run_safe aws ec2 disassociate-route-table --region "$REGION" --association-id "$ASSOC_ID"
      done

      echo "Deleting route table: $RT_ID"
      run_safe aws ec2 delete-route-table --region "$REGION" --route-table-id "$RT_ID"
    done

    echo "Detaching and deleting internet gateways..."
    IGW_IDS=$(aws ec2 describe-internet-gateways \
      --region "$REGION" \
      --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
      --query "InternetGateways[].InternetGatewayId" \
      --output text 2>/dev/null || true)

    for IGW_ID in $IGW_IDS; do
      [ "$IGW_ID" = "None" ] && continue
      echo "Detaching internet gateway: $IGW_ID"
      run_safe aws ec2 detach-internet-gateway --region "$REGION" --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID"
      echo "Deleting internet gateway: $IGW_ID"
      run_safe aws ec2 delete-internet-gateway --region "$REGION" --internet-gateway-id "$IGW_ID"
    done

    echo "Deleting subnets..."
    SUBNET_IDS=$(aws ec2 describe-subnets \
      --region "$REGION" \
      --filters "Name=vpc-id,Values=$VPC_ID" \
      --query "Subnets[].SubnetId" \
      --output text 2>/dev/null || true)

    for SUBNET_ID in $SUBNET_IDS; do
      [ "$SUBNET_ID" = "None" ] && continue
      echo "Deleting subnet: $SUBNET_ID"
      run_safe aws ec2 delete-subnet --region "$REGION" --subnet-id "$SUBNET_ID"
    done

    echo "Deleting VPC: $VPC_ID"
    run_safe aws ec2 delete-vpc --region "$REGION" --vpc-id "$VPC_ID"
  done
fi

echo ""
echo "Deleting AWS key pair if present..."
if aws ec2 describe-key-pairs --region "$REGION" --key-names "$KEY_NAME" >/dev/null 2>&1; then
  run_safe aws ec2 delete-key-pair --region "$REGION" --key-name "$KEY_NAME"
  echo "AWS key pair deleted."
else
  echo "No AWS key pair found."
fi

echo ""
echo "Deleting local PEM files if present..."
rm -f "${KEY_NAME}.pem"
rm -f "./${KEY_NAME}.pem"
rm -f "$HOME/${KEY_NAME}.pem"
rm -f "$HOME/environment/${KEY_NAME}.pem"

echo ""
echo "========================================================="
echo "Cleanup Complete"
echo "========================================================="
# make runable using chmod +x whichami.sh
# Usage: ./whichami.sh <region>

# See if a region is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <region>"
  exit 1
fi

# Set variables
REGION=$1
OWNER_ID="099720109477"  # Canonical's AWS account ID for Ubuntu AMIs
AMI_NAME_PATTERN="ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"

# Fetch the latest AMI ID
LATEST_AMI=$(aws ec2 describe-images \
  --owners "$OWNER_ID" \
  --filters "Name=name,Values=$AMI_NAME_PATTERN" \
  --query "Images[*].[ImageId,CreationDate]" \
  --region "$REGION" \
  --output text | sort -k2 -r | head -n1 | awk '{print $1}')

# Check if an AMI ID was found for the region entered
if [ -z "$LATEST_AMI" ]; then
  echo "No AMI found for region $REGION."
  exit 1
fi

# Output the result
echo "The latest Ubuntu 22.04 AMI ID in region $REGION is: $LATEST_AMI"

#!/bin/bash

# Set variables
NAMESPACE="udacity"
DEPLOYMENT_NAME_BLUE="blue-deployment"
DEPLOYMENT_NAME_GREEN="green-deployment"
SERVICE_NAME="blue-green-service"
CNAME_RECORD="blue-green.udacityproject.com"
ROUTE53_ZONE_ID="ZXXXXXXXXXXX"  # Replace with your actual Route53 Hosted Zone ID
AWS_REGION="us-east-1"
EC2_INSTANCE_ID="i-xxxxxxxxxxxx"  # Replace with your actual EC2 instance ID for curl
GREEN_CONFIGMAP="green-config"
SCREENSHOT_BLUE_GREEN="green-blue.png"
SCREENSHOT_GREEN_ONLY="green-only.png"

# Step 1: Deploy the green version mimicking the blue deployment configuration
echo "Starting Green Deployment..."

kubectl get deployment $DEPLOYMENT_NAME_BLUE -n $NAMESPACE -o yaml | sed "s/$DEPLOYMENT_NAME_BLUE/$DEPLOYMENT_NAME_GREEN/g" | kubectl apply -f -

# Replace the index.html content with values from the green-config ConfigMap
kubectl patch deployment $DEPLOYMENT_NAME_GREEN -n $NAMESPACE --patch "
spec:
  template:
    spec:
      containers:
      - name: nginx
        volumeMounts:
        - mountPath: /usr/share/nginx/html
          name: green-config-vol
      volumes:
      - name: green-config-vol
        configMap:
          name: $GREEN_CONFIGMAP
"

# Step 2: Wait for the green deployment to successfully roll out
echo "Waiting for Green Deployment to be ready..."
kubectl rollout status deployment/$DEPLOYMENT_NAME_GREEN -n $NAMESPACE

# Step 3: Create a new weighted CNAME record in Route53
echo "Creating weighted CNAME record in Route53..."
aws route53 change-resource-record-sets --hosted-zone-id $ROUTE53_ZONE_ID --change-batch '{
    "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "'$CNAME_RECORD'",
            "Type": "CNAME",
            "SetIdentifier": "Green Deployment",
            "Weight": 100,
            "TTL": 60,
            "ResourceRecords": [{"Value": "'$DEPLOYMENT_NAME_GREEN'.'$AWS_REGION'.compute.amazonaws.com"}]
        }
    }]
}'

# Step 4: Curl the blue-green URL and take a screenshot
echo "Curling the blue-green service and taking a screenshot..."
aws ec2-instance-connect send-ssh-public-key --instance-id $EC2_INSTANCE_ID --availability-zone $AWS_REGION --instance-os-user ec2-user --ssh-public-key file://~/.ssh/id_rsa.pub
ssh -o StrictHostKeyChecking=no ec2-user@$EC2_INSTANCE_ID <<EOF
  curl $CNAME_RECORD > curl_output.txt
  import -window root $SCREENSHOT_BLUE_GREEN
EOF

# Step 5: Simulate failover by destroying the blue deployment
echo "Simulating failover by destroying the blue environment..."
kubectl delete deployment $DEPLOYMENT_NAME_BLUE -n $NAMESPACE

# Step 6: Update Route53 to only route to the green environment
echo "Updating Route53 to route only to the Green environment..."
aws route53 change-resource-record-sets --hosted-zone-id $ROUTE53_ZONE_ID --change-batch '{
    "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
            "Name": "'$CNAME_RECORD'",
            "Type": "CNAME",
            "SetIdentifier": "Green Deployment",
            "Weight": 100,
            "TTL": 60,
            "ResourceRecords": [{"Value": "'$DEPLOYMENT_NAME_GREEN'.'$AWS_REGION'.compute.amazonaws.com"}]
        }
    }]
}'

# Step 7: Curl the URL again and take a final screenshot
echo "Curling the blue-green service (Green only) and taking a screenshot..."
ssh -o StrictHostKeyChecking=no ec2-user@$EC2_INSTANCE_ID <<EOF
  curl $CNAME_RECORD > curl_output_green.txt
  import -window root $SCREENSHOT_GREEN_ONLY
EOF

echo "Blue-Green Deployment Process Complete."

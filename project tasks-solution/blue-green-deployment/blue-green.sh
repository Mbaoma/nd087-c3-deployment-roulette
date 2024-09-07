#!/bin/bash

# Variables
BLUE_DEPLOYMENT="blue"
GREEN_DEPLOYMENT="green"
NAMESPACE="udacity"
BLUE_CONFIG="blue"
GREEN_CONFIG="green"
DOMAIN_NAME="blue-green.udacityproject.com"
ROUTE53_ZONE_ID="Z01135622M6HFF07XRP9C"  # Replace with your Route53 hosted zone ID

# Step 1: Deploy Green Version
echo "Deploying Green version..."
kubectl apply -f ./${GREEN_CONFIG}.yml --namespace ${NAMESPACE}

kubectl apply -f ./${BLUE_CONFIG}.yml --namespace ${NAMESPACE}

# Step 2: Wait for Green Deployment to complete
echo "Waiting for Green Deployment to complete..."
kubectl rollout status deployment/${GREEN_DEPLOYMENT} --namespace ${NAMESPACE}

# Step 3: Create weighted CNAME in Route53 for Blue-Green Deployment

# Update Route53 to give traffic to the green deployment (50% weighting)
echo "Creating/updating CNAME record in Route53..."
# Create Route 53 CNAME record with external IPs
# Create Route 53 CNAME record with external IPs
cat <<EOF > /tmp/route53-change.json
{
  "Comment": "Blue-green deployment for ${SERVICE_NAME}",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${DOMAIN_NAME}",
        "Type": "CNAME",  
        "SetIdentifier": "${BLUE_DEPLOYMENT}",
        "Weight": 50,
        "TTL": 60,
        "ResourceRecords": [{"Value": "a13ef7c10b82c4648a792fe732f387a4-2026617968.eu-north-1.elb.amazonaws.com"}]
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${DOMAIN_NAME}",
        "Type": "CNAME",  
        "SetIdentifier": "${GREEN_DEPLOYMENT}",
        "Weight": 50,
        "TTL": 60,
        "ResourceRecords": [{"Value": "a72dd8a2c9a2d4087abc9339da0425ec-1350843819.eu-north-1.elb.amazonaws.com"}]
      }
    }
  ]
}
EOF


# Submit Route 53 changes
aws route53 change-resource-record-sets --hosted-zone-id ${ROUTE53_ZONE_ID} --change-batch file:///tmp/route53-change.json

# Step 4: Curl the URL to verify both environments are working
echo "Testing blue-green environments..."
curl http://${DOMAIN_NAME}


# Use EC2 instance to take the screenshot (you may need to use other tools or log in to take the screenshot)
# Example: scrot green-blue.png

# Step 5: Simulate Failover by deleting the blue deployment
echo "Failing over to Green by destroying Blue..."
kubectl delete deployment ${BLUE_DEPLOYMENT} --namespace ${NAMESPACE}

# Step 6: Update Route 53 to route all traffic to Green
echo "Routing all traffic to Green in Route 53..."
cat <<EOF > /tmp/route53-green.json
{
  "Comment": "Failover to Green environment",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${DOMAIN_NAME}",
        "Type": "CNAME",
        "SetIdentifier": "${GREEN_DEPLOYMENT}",
        "Weight": 100,
        "TTL": 60,
        "ResourceRecords": [{"Value": "green-service.udacity.svc.cluster.local"}]
      }
    }
  ]
}
EOF

# Submit the failover change to Route 53
aws route53 change-resource-record-sets --hosted-zone-id ${ROUTE53_ZONE_ID} --change-batch file:///tmp/route53-green.json

# Step 7: Test the green environment only
echo "Testing Green environment only..."
curl http://${DOMAIN_NAME}
echo "Taking screenshot for green-only environment..."
# Use EC2 instance to take the screenshot
# Example: scrot green-only.png
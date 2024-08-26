#!/bin/bash

# Set the namespace
NAMESPACE="udacity"

# Step 1: Deploy the Blue Deployment
echo "Deploying Blue version..."
kubectl apply -f ./index_blue_html.yml --namespace=$NAMESPACE
kubectl apply -f ./blue.yml --namespace=$NAMESPACE
kubectl rollout status deployment/blue --namespace=$NAMESPACE

# Step 2: Deploy the Green Deployment mimicking the Blue Deployment
echo "Deploying Green version..."
kubectl apply -f ./index_green_html.yml --namespace=$NAMESPACE
kubectl apply -f ./green.yml --namespace=$NAMESPACE
kubectl rollout status deployment/green --namespace=$NAMESPACE

# Step 3: Wait for the Green Deployment to be reachable
sleep 20  # Adjust sleep time as needed to ensure the deployment is ready

# Port forward the service to localhost (using the blue deployment's service)
kubectl port-forward svc/blue 8080:80 --namespace=$NAMESPACE 

# Curl the localhost:8080 to simulate accessing the service
echo "Curling the blue service on localhost:8080..."
curl http://localhost:8080 > curl_output_blue.txt
cat curl_output_blue.txt | tee green-blue.txt

# Step 5: Simulate Failover by Deleting the Blue Deployment
echo "Deleting the Blue deployment..."
kubectl delete deployment blue --namespace=$NAMESPACE
kubectl rollout status deployment/green --namespace=$NAMESPACE


# # Port forward the green service to localhost (assuming same service)
kubectl port-forward svc/green 8080:80 --namespace=$NAMESPACE 

# Curl the localhost:8080 again to verify only Green is reachable
echo "Curling the green service on localhost:8080..."
curl http://localhost:8080 > curl_output_green_only.txt
cat curl_output_green_only.txt | tee green-only.txt

# Stop the port-forwarding for green
kill $GREEN_PID

echo "Blue-Green Deployment simulation on localhost complete."
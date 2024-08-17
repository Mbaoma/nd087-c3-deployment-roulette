#!/bin/bash

# Wait for the deployment to be ready
kubectl rollout status deployment/canary-v2 -n udacity

# Curl the service 10 times and save the results to canary.txt
echo "Curling the service 10 times..." > canary.txt
for i in {1..10}; do
  curl http://canary-svc.udacity.svc.cluster.local >> canary.txt
  echo "" >> canary.txt
done

# Check if the canary deployment is handling 50% of the traffic
echo "Checking if both versions are returning results..." >> canary.txt
if grep -q "Version 1" canary.txt && grep -q "Version 2" canary.txt; then
  echo "Both v1 and v2 are returning results." >> canary.txt
else
  echo "Traffic splitting is not working as expected." >> canary.txt
fi

# Output the current pods in all namespaces and save to canary2.txt
kubectl get pods --all-namespaces > canary2.txt

echo "Canary deployment script completed."
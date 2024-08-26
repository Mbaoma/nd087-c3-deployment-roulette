#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
NAMESPACE=udacity
SERVICE_NAME=canary-svc
V1_DEPLOYMENT=canary-v1
V2_DEPLOYMENT=canary-v2
CANARY_SVC_YAML=./canary-svc.yml
CANARY_V1_YAML=./canary-v1.yml
CANARY_V2_YAML=./canary-v2.yml
OUTPUT_FILE=canary.txt

#create config map
echo "creating configmap and svc..."
kubectl apply -f ./index_v1_html.yml
kubectl apply -f ./index_v2_html.yml
kubectl apply -f ./canary-svc.yml

# Apply canary-v1 and canary-v2 deployments
echo "Deploying canary-v1..."
kubectl apply -f "${CANARY_V1_YAML}"

echo "Deploying canary-v2..."
kubectl apply -f "${CANARY_V2_YAML}"

# Wait for canary-v1 deployment to be ready
echo "Waiting for ${V1_DEPLOYMENT} to be ready..."
kubectl rollout status deployment/${V1_DEPLOYMENT} -n ${NAMESPACE}

# Wait for canary-v2 deployment to be ready
echo "Waiting for ${V2_DEPLOYMENT} to be ready..."
kubectl rollout status deployment/${V2_DEPLOYMENT} -n ${NAMESPACE}

# Update the canary-svc to include both canary-v1 and canary-v2
# This is done by removing the version selector so the service selects all pods with app=canary
echo "Updating ${SERVICE_NAME} selector to include both canary-v1 and canary-v2..."
kubectl patch service ${SERVICE_NAME} -n ${NAMESPACE} -p '{"spec":{"selector":{"app":"canary"}}}'

# Scale canary-v1 and canary-v2 to have equal replicas for 50% traffic each
# Assuming 2 replicas for each to achieve roughly 50% traffic split
echo "Scaling ${V1_DEPLOYMENT} to 2 replicas..."
kubectl scale deployment ${V1_DEPLOYMENT} -n ${NAMESPACE} --replicas=2

echo "Scaling ${V2_DEPLOYMENT} to 2 replicas..."
kubectl scale deployment ${V2_DEPLOYMENT} -n ${NAMESPACE} --replicas=2

# Wait for the scaling operations to complete
echo "Waiting for scaling to complete..."
kubectl rollout status deployment/${V1_DEPLOYMENT} -n ${NAMESPACE}
kubectl rollout status deployment/${V2_DEPLOYMENT} -n ${NAMESPACE}

# Retrieve the external IP or hostname of the LoadBalancer service
echo "Retrieving the external address of ${SERVICE_NAME}..."
SERVICE_HOST=$(kubectl get svc ${SERVICE_NAME} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
SERVICE_IP=$(kubectl get svc ${SERVICE_NAME} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$SERVICE_HOST" ] && [ -z "$SERVICE_IP" ]; then
    echo "Error: Service ${SERVICE_NAME} does not have an external address yet."
    exit 1
elif [ -n "$SERVICE_HOST" ]; then
    SERVICE_URL="http://${SERVICE_HOST}"
elif [ -n "$SERVICE_IP" ]; then
    SERVICE_URL="http://${SERVICE_IP}"
fi

echo "Service URL: ${SERVICE_URL}"

# Optionally, wait until the service is reachable
echo "Waiting for the service to become reachable..."
MAX_RETRIES=30
SLEEP_INTERVAL=5
for ((i=1;i<=MAX_RETRIES;i++)); do
    if curl -s "${SERVICE_URL}" >/dev/null; then
        echo "Service is reachable."
        break
    fi
    echo "Service not reachable yet (attempt ${i}/${MAX_RETRIES}). Retrying in ${SLEEP_INTERVAL} seconds..."
    sleep ${SLEEP_INTERVAL}
    if [ $i -eq $MAX_RETRIES ]; then
        echo "Error: Service is still not reachable after waiting."
        exit 1
    fi
done

# Curl the service 10 times and save the results to canary.txt
echo "CURLing the service 10 times and saving results to ${OUTPUT_FILE}..."
> ${OUTPUT_FILE} # Truncate or create the file

for i in {1..10}; do
    RESPONSE=$(curl -s "${SERVICE_URL}")
    echo "Request $i: $RESPONSE" >> ${OUTPUT_FILE}
done

echo "Curl results saved to ${OUTPUT_FILE}."

# Output the current pods in all namespaces to verify deployments
echo "Fetching the list of all pods across namespaces..."
kubectl get pods --all-namespaces
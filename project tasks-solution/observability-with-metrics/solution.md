I deployed the metrics server
```
# Install the Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

I identified the service using most memory by running
```
kubectl top pods --all-namespaces > before_metrics.txt
cat before_metrics.txt
```

All my pods are running fine.
for autoscaling i ran
```
kubectl autoscale deployment bloaty-mcbloatface --cpu-percent=50 --min=10 --max=50 --namespace=udacity
```
the problem was the wrong path for livenessProbe. I changed the livenessProbe section from
```yaml
livenessProbe:
  httpGet:
    port: 9000
    path: /nginx_status
  initialDelaySeconds: 2
  periodSeconds: 2
```

to

```yaml
livenessProbe:
  httpGet:
    port: 9000
    path: /healthz
  initialDelaySeconds: 2
  periodSeconds: 2
```
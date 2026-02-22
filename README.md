# HomeLab

## TODO
- Right now I am having trouble with connecting to argo.lan from my home computer. It seems like I am being redirected from https://argo.lan to that same route...
  - Running `curl -k -I https://argo.lan` gives output showing that it is being redirected to itself. Same with `curl -k -v https://argo.lan`

## Helpful Commands

### Creating cert
```bash
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout argo.key \
  -out argo.crt \
  -subj "/CN=argo.lan"

kubectl create secret tls argo-lan-tls \
  --cert=argo.crt \
  --key=argo.key \
  -n traefik
```

### Creating secret example
```bash
kubectl create secret generic pihole-secret -n pihole --from-literal=password=<EnterPassword>
```


### Delete and setup argo
```bash
kubectl delete ns argocd
kubectl create ns argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Make the argocd-server service of type NodePort to access it from https://10.0.0.191:30245
kubectl patch svc argocd-server -n argocd -p '{
  "spec": {
    "type": "NodePort",
    "ports": [
      {
        "name": "http",
        "port": 80,
        "targetPort": 8080,
        "protocol": "TCP",
        "nodePort": 30245
      }
    ]
  }
}'

# Get the password from the argocd-server pod
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode

# Finally, apply the app of apps
kubectl apply -f app-of-apps.yaml
```

### Sync argo without UI
```bash
# Execute into the argocd-server pod
argocd login localhost:8080 --username admin --password <Password> --insecure
argocd app list
argocd app sync argocd/homelab-root
```
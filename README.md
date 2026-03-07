# HomeLab

## TODO
- Make the following scripts
  - Script to sync argo apps
  - Script to setup keys
  - Set target revision to a specific branch
  - Test new commit

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

### Trusting the internal CA on macOS (fixes "Not Secure" in browser)
`portfolio.lan` uses a certificate issued by your internal cert-manager CA (`internal-ca-issuer`).
HTTPS is encrypted already, but browsers will still show **Not Secure** until this CA is trusted on your device.

```bash
# Export the internal CA certificate from cert-manager
kubectl get secret internal-ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 --decode > internal-ca.crt

# Trust it in macOS System keychain
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain internal-ca.crt
```

Then fully restart your browser and revisit `https://portfolio.lan`.

If you need to remove trust later:

```bash
sudo security delete-certificate -c home-internal-ca /Library/Keychains/System.keychain
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

### Sealed secrets workflow
```bash
kubectl create secret generic pihole-secret -n pihole --from-literal=password=<EnterPassword> --dry-run=client -o yaml > secret.yaml
kubeseal -f secret.yaml -w sealed-secret.yaml --controller-namespace sealed-secrets --controller-name sealed-secrets
# Then add the sealed-secret.yaml file to git
```
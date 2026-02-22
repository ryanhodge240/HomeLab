# HomeLab

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
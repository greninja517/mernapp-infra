Once, the CI pipeline provision the GKE cluster. Then, folow these steps to access the argocd server ui on your local machine through ssh port forwarding using the bastion host.

1. SSH into bastion host from your local machine
```bash
ssh -i <private-key> username@BASTION_PUBLIC_IP
```
2. Verify the installation of tools like kubectl, helm, gcloud in the bastion host which is done by the bootstrap script 

3. Set up the kubectl context to interact with GKE on the bastion host
```bash
gcloud container clusters get-credentials CLUSTER_NAME --region REGION --project PROJECT_ID
```

4. Install argocd on the cluster ( Bastion Host )
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

5. Verify the argocd installation ( Bastion Host )
```bash
kubectl get all -n argocd
```

6. Get the ArgoCD admin password ( Bastion Host )
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

7. Set up Port Forwarding
i. SSH port forwarding ( Run on local machine )
```bash
ssh -i <private-key-path> -L 8080:localhost:8080 username@BASTION_PUBLIC_IP
```

ii. Kubectl port forwarding ( Run on bastion Host )
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

8. Now, You can Access ArgoCD in your `http:localhost:8080`

9. Now, Set up the ArgoCD for automated CD related tasks
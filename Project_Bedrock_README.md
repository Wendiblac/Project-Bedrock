
# Project Bedrock — InnovateMart EKS Deployment

**Author:** Wendy Amadi  
**Project:** Project Bedrock — Retail Store Sample App on EKS  
**Status:** Infrastructure & application deployed; managed persistence (RDS + DynamoDB) and ALB/ACM set up; CI/CD GitHub Actions configured; AWS Load Balancer Controller installed; Kubernetes manifests deployed.

---

## High-level summary / architecture
Project Bedrock provisions a production-like AWS environment for the retail-store-sample-app using Terraform and deploys the application into an EKS cluster. Bonus objectives implemented:
- Managed persistence: **RDS PostgreSQL** for `orders`, **RDS MySQL** for `catalog`, and **DynamoDB** for `carts`.
- Advanced networking: **AWS Load Balancer Controller** installed and an **ALB** created by a Kubernetes Ingress; **ACM** certificate provisioned and attached to ALB; sub-domain `innovatemart.wendiblac.com` routed to ALB via DNS record.

Key components created:
- VPC (public + private subnets)
- EKS cluster with node group(s)
- IAM roles/policies for EKS and AWS Load Balancer Controller
- RDS instances (Postgres + MySQL)
- DynamoDB table `carts`
- S3 backend and DynamoDB table for Terraform state locking
- Kubernetes namespace `retail`, ConfigMaps, Secrets, Deployments, Services, Ingress

ALB / Ingress DNS (example):  
`http://af142eea6260449539abb75b1fc62281-201448740.eu-west-1.elb.amazonaws.com/`  
Custom domain: `http://innovatemart.wendiblac.com` (ACM issued, ALB wired).

---

## Repo layout (important files & folders)
```
/                    # root Terraform + GitHub Actions
  ├─ provider.tf
  ├─ variables.tf
  ├─ main.tf
  ├─ rds.tf
  ├─ dynamodb.tf
  ├─ outputs.tf
  ├─ eks/                   
  │   ├─ main.tf
  │   ├─ outputs.tf
  ├─ vpc/                   
  │   ├─ main.tf
  │   ├─ outputs.tf
  │   ├─ variables.tf
  ├─ modules/
  │   └─ db/main.tf                # small module used to manage db subnet groups
  ├─ k8s/                   # kubernetes manifests
  │   ├─ namespace.yaml
  │   ├─ orders-config.yaml
  │   ├─ catalog-config.yaml
  │   ├─ carts-config.yaml
  │   ├─ ui-deployment.yaml
  │   ├─ ui-service.yaml
  │   └─ ingress.yaml
  └─ .github/workflows/terraform.yml
```
---

## Detailed step-by-step (what I executed and outcomes)

### (1) Terraform & IaC (local iteration)
**Files:** `provider.tf`, `variables.tf`, `main.tf`, `rds.tf`, `eks/`, `vpc/`, modules under `modules/`.

Commands run (examples):
```bash
terraform init
terraform validate
terraform plan -out plan.tfplan
export TF_VAR_private_subnet_ids='["subnet-...","subnet-..."]'
export TF_VAR_orders_db_password="(secure-password-meeting-AWS-rules)"
export TF_VAR_catalog_db_password="(secure-password)"
terraform apply "plan.tfplan"
```

**Notes & fixes encountered:**
- **S3 backend + DynamoDB lock table used.** I occasionally encountered a stuck lock (ConditionalCheckFailedException). In those cases, I used `terraform force-unlock <LOCK_ID>` *only* after confirming no other terraform runs were active. You can also inspect the DynamoDB items or safely delete the item for `innovatemart-tfstate/project-bedrock/terraform.tfstate` **only** when you are certain no operator is applying. Example to delete lock (use with caution):
```bash
aws dynamodb delete-item \
  --table-name innovatemart-tf-locks \
  --key '{"LockID":{"S":"innovatemart-tfstate/project-bedrock/terraform.tfstate"}}' \
  --region eu-west-1
```
- **RDS engine versions:** I attempted to set an engine version (e.g. `15.3`) that wasn’t available in the account/region; RDS returned `Cannot find version`. I fixed this by using `engine_version = "11.22-rds.XXXX"` (one returned by `aws rds describe-db-engine-versions`) Running `aws rds describe-db-engine-versions --engine postgres --region eu-west-1` helps discover available versions.

- **RDS password validation:** RDS rejects certain characters (e.g. `/`, `@`, `"` and spaces) and requires length 8-41. I implemented a Terraform `validation` block for `orders_db_password` to enforce length and disallow problematic characters. Example (validation rule included in repo):
```hcl
validation {
  condition = length(var.orders_db_password) >= 8 && length(var.orders_db_password) <= 41 && can(regex("^[^/@\" ]+$", var.orders_db_password))
  error_message = "orders_db_password must be 8-41 printable ASCII characters and must not contain '/', '@', '\"' or spaces."
}
```

**Resources created by Terraform (high level):**
- `aws_vpc` (module.vpc)
- `aws_eks_cluster` + nodegroups (module.eks)
- `aws_db_instance.orders_postgres` (RDS)
- `aws_db_instance.catalog_mysql` (RDS)
- `aws_dynamodb_table.carts`
- `aws_db_subnet_group.*`
- `aws_security_group.db_sg`

Outputs written to state (examples):
- `eks_cluster_name = "project-bedrock-eks-cluster"`
- `vpc_id = "vpc-..."`
- `public_subnets` / `private_subnets` arrays

### (2) Secrets & CI (GitHub Actions)
**Approach:** Never commit secrets to git. Store secrets in GitHub repo Settings → Secrets. Map secrets to Terraform via `TF_VAR_` env variables in the GitHub Actions workflow.

**Repository secrets used (names):**
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_DEFAULT_REGION`
- `ORDERS_DB_PASSWORD` (used as `TF_VAR_orders_db_password` in the workflow)
- `CATALOG_DB_PASSWORD` (used as `TF_VAR_catalog_db_password`)

**Workflow**: `.github/workflows/terraform.yml` performs init/validate/plan for feature/develop and apply on `main`. Key points:
- Use `hashicorp/setup-terraform@v2`
- Cache `.terraform/providers` to reduce provider installation time (improves speed in CI)
- Provide `TF_VAR_` variables on the `apply` step for db passwords
- Use `-lock-timeout` during apply and handle DynamoDB locks (avoid concurrent runs)

If you want the exact YAML, see the `terraform.yml` file in repo (it contains the final tested configuration).

### (3) EKS cluster & kube resources
**Installed/verified:**
- `kubectl` connectivity via `aws eks update-kubeconfig --name project-bedrock-eks-cluster --region eu-west-1`
- Kubernetes namespace `retail`
- Deployed manifests:

Applied in sequence:
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/orders-config.yaml
kubectl apply -f k8s/catalog-config.yaml
kubectl apply -f k8s/carts-config.yaml
kubectl apply -f k8s/ui-deployment.yaml
kubectl apply -f k8s/ui-service.yaml
kubectl apply -f k8s/ingress.yaml
```

**ConfigMaps & Secrets wiring**:
- `orders-db-config` and `catalog-db-config` store DB hostname, port, database name (updated to real RDS endpoints after RDS creation).
- DB **passwords** must not be checked into Git. I used Kubernetes `Secret` objects. In CI you can create the kubernetes secrets dynamically (e.g. using `kubectl create secret generic` with `--from-literal` and GitHub Actions secrets plugged into the action), or use a Kubernetes secrets manager (AWS Secrets Manager + ExternalSecrets) for production-grade security. Example secret creation (do not put password in repo):
```bash
kubectl create secret generic orders-db-secret -n retail \
  --from-literal=POSTGRES_USER=orders_admin \
  --from-literal=POSTGRES_PASSWORD="${ORDERS_DB_PASSWORD}"
```
**Outcome:** Deployments started, `ui` service created, Ingress created. Confirmed app reachable via ALB DNS and, after ALB + ACM steps, via custom domain (HTTP works; certificate issued; HTTPS configured on ALB listener).

### (4) ALB, ACM, DNS, AWS Load Balancer Controller (ALB ingress)
**Steps taken**:
1. Associate OIDC provider to EKS cluster (eksctl):
```bash
eksctl utils associate-iam-oidc-provider --region eu-west-1 --cluster project-bedrock-eks-cluster --approve
```
2. Create the IAM policy used by the Load Balancer Controller (policy downloaded from upstream), create it in account:
```bash
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
```
3. Create IAM role/service account (via `eksctl create iamserviceaccount`) to attach policy to in `kube-system` namespace and associate it with the `aws-load-balancer-controller` service account.
4. Install the AWS Load Balancer Controller via Helm (added `eks/` chart repo):
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=project-bedrock-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-west-1 \
  --set vpcId=$(aws eks describe-cluster --name project-bedrock-eks-cluster --region eu-west-1 --query "cluster.resourcesVpcConfig.vpcId" --output text)
```
**Validation**:
- Confirmed Controller pods running in `kube-system` (`kubectl get pods -n kube-system`).
- `aws-load-balancer-webhook-service` created for validating Ingress; ensured endpoints present.
- Deployed Ingress with annotations to use ACM cert and listen on 443. Observed ALB creation and listeners for port 80 and 443; verified certificate attached to 443 listener via `aws elbv2 describe-listeners`.

**Troubleshooting notes**:
- Initially had `FailedAddFinalizer` because webhook endpoints were not ready; reinstall / ensure SA mapping and webhook Service endpoints fixed it.
- ACM certificate must be in the same region as ALB (eu-west-1). Also must be `ISSUED`. DNS validation required adding the provided CNAME to the authoritative DNS provider (I used Netlify DNS entries to create the validation CNAME). Once ACM is "ISSUED", ALB listener creation with that certificate works.
- If HTTPS times out while HTTP works, check security groups attached to ALB and listener rules, check that certificate is `ISSUED`, and that ALB has healthy target groups. Use `kubectl describe ingress` for events and `aws elbv2 describe-listeners` / `describe-target-groups` and `describe-target-health` for troubleshooting.

---

## Developer IAM user & kubeconfig access (how to give read-only developer access)

**Goal:** developer can run `kubectl get pods`, `kubectl logs`, `kubectl describe` without having write privileges.

Recommended approach (outline):
1. **Create IAM user** `dev-readonly` (programmatic access only) in AWS console or via Terraform (do not hardcode keys). Attach a narrowly-scoped IAM policy that allows STS `GetCallerIdentity`, EKS `Describe*`/`List*` actions, CloudWatch Logs `Describe`/`GetLogEvents`, and read-only RDS/DynamoDB permissions as needed. Example managed policy for EKS read-only exists (or create custom minimal policy).
2. **Create a Kubernetes RBAC Role** (or use built-in `view` ClusterRole) and a `RoleBinding` or `ClusterRoleBinding` mapping the IAM user to a Kubernetes user. The mapping is done in the `aws-auth` ConfigMap if using IAM user or you can map an IAM role. Example: map an IAM role ARN with `groups: ["system:masters"]` (do NOT give system:masters for read-only), instead map to a group you manage and create a Kubernetes `ClusterRoleBinding` granting `view` to that group.
3. **Kubeconfig for developer:** generate kubeconfig that uses `exec` credential plugin (`aws eks get-token`) and shares how to set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` for the dev IAM user locally; then `kubectl` will use the IAM identity to get a token against the cluster. Example command to get token:
```bash
aws eks get-token --cluster-name project-bedrock-eks-cluster
```
Provide a sample kubeconfig in the repo (`kubeconfig-dev.md`) with steps to set env vars, how to run `aws eks update-kubeconfig` and switch context.

**Note:** I prepared these artifacts in the repo (Terraform snippet to create the user & policy, example kubeconfig instructions). For production, prefer IAM roles with short-lived credentials and an identity provider (SSO).

---

## How to reproduce full deployment (short checklist)
1. Create and export AWS credentials (prefer IAM user with limited privileges for Terraform).
2. Add GitHub repository secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `ORDERS_DB_PASSWORD`, `CATALOG_DB_PASSWORD`.
3. Locally or via CI: `terraform init && terraform apply` (with `TF_VAR_private_subnet_ids` and `TF_VAR_*_db_password` set).
4. After cluster up: `aws eks update-kubeconfig --name project-bedrock-eks-cluster --region eu-west-1`.
5. Install Load Balancer Controller (eksctl/iam + helm install).
6. Apply kubernetes manifests (`kubectl apply -f k8s/`).
7. Create DNS record (A/CNAME) pointing `innovatemart.wendiblac.com` to ALB DNS name.
8. Confirm app: `curl -I http://<ALB_DNS>` and `curl -I http://innovatemart.wendiblac.com` once ACM is `ISSUED` and ALB listener 443 reports the certificate.

---

## Verification commands & useful checks
- Terraform plan/state: `terraform plan -out plan.tfplan`, `terraform show -json plan.tfplan`  
- Check RDS endpoints: `aws rds describe-db-instances --region eu-west-1 --query "DBInstances[*].{DB:DBInstanceIdentifier,Endpoint:Endpoint.Address,Engine:Engine}"`  
- DynamoDB tables: `aws dynamodb list-tables --region eu-west-1`  
- Check ALB & listeners:  
```bash
ALB_DNS=$(kubectl get ingress ui-ingress -n retail -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
aws elbv2 describe-load-balancers --region eu-west-1 --query "LoadBalancers[?DNSName=='$ALB_DNS']"
aws elbv2 describe-listeners --load-balancer-arn <arn> --region eu-west-1
```  
- Kubernetes: `kubectl get all -n retail`, `kubectl describe ingress ui-ingress -n retail`

---

## Security considerations & next steps (recommended)
- Move DB credentials to **AWS Secrets Manager** or use **ExternalSecrets** (avoid Kubernetes plaintext secrets).  
- Enable RDS automated backups, snapshots, and consider Multi-AZ for production.  
- Lock down `aws-load-balancer-controller` IAM policy to minimum resources and use conditions.  
- Add monitoring: CloudWatch Container Insights, Prometheus, or Grafana.  
- Add Terraform workspace separation between environments (dev/staging/prod) and guardrails (pre-apply review).

---

## Troubleshooting log summary (selected items observed during work)
- `InvalidClientTokenId` initially — resolved by ensuring correct AWS credentials and `aws sts get-caller-identity` returned the expected user identity.
- RDS engine version mismatch errors — resolved by using available engine versions or leaving `engine_version` blank.
- DynamoDB `ConditionalCheckFailedException` locks — resolved by `terraform force-unlock` after confirming no active runs or by deleting the lock item in DynamoDB (careful!).
- ALB certificate errors: ALB reported `UnsupportedCertificate` until ACM validation finished. Solution: ensure ACM certificate `ISSUED` and that the domain validation record is present in the authoritative DNS provider.
- Webhook finalizer failures for Ingress — fixed by ensuring aws-load-balancer-controller webhook service has endpoints (controller pods running); sometimes reinstalling/updating the helm chart after properly creating the IAM role/service account fixes this.

---

**Notes:** This README intentionally avoids embedding any secret or credential values. All secret material (DB passwords, AWS access keys) should remain in GitHub Secrets / AWS Secrets Manager / encrypted vaults and never be committed to Git.

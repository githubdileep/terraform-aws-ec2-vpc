# terraform-vpc-ec2

Provisions a VPC in `us-east-1` with:

- 1 VPC
- 1 Internet Gateway
- 2 public subnets + 1 public route table (routes to IGW) + associations
- 2 private subnets + 1 private route table (routes to NAT Gateway) + associations
- 1 NAT Gateway (optional, toggle with `enable_nat_gateway`)
- 1 EC2 instance in a public subnet (public IP, SSH from your IP, HTTP open)
- 1 EC2 instance in a private subnet (no public IP, reachable only from within the VPC)

Deployed via Terraform, run manually or through GitHub Actions.

## Files

| File | Purpose |
|---|---|
| `versions.tf` | Terraform/provider version pins + S3 backend block |
| `variables.tf` | Input variables |
| `vpc.tf` | VPC, subnets, IGW, NAT, route tables, associations |
| `security_groups.tf` | SGs for public/private instances |
| `ec2.tf` | The 2 EC2 instances + AMI lookup |
| `outputs.tf` | IDs/IPs exposed after apply |
| `.github/workflows/terraform.yml` | CI/CD pipeline |

## One-time AWS setup (do this before running CI)

### 1. Remote state backend
Terraform state should not live on a laptop or in git. Create an S3 bucket
(versioned) and a DynamoDB table for locking:

```bash
aws s3api create-bucket --bucket <your-unique-tf-state-bucket> --region us-east-1
aws s3api put-bucket-versioning --bucket <your-unique-tf-state-bucket> \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. GitHub OIDC role (no static AWS keys in GitHub secrets)
Create an IAM OIDC identity provider for `token.actions.githubusercontent.com`
and an IAM role that trusts it, scoped to your repo. Attach permissions for
VPC/EC2 resources plus the state bucket/table.

Policy files are in `iam/`:
- `iam/oidc-trust-policy.json` — trust policy for the role (who can assume it)
- `iam/terraform-permissions-policy.json` — permissions policy (what the role can do)

Before using them, replace the placeholders:
- `ACCOUNT_ID` → your 12-digit AWS account ID
- `ORG/REPO` → your GitHub org/user and repo name, e.g. `myorg/terraform-vpc-ec2`
- `TF_STATE_BUCKET_NAME` → the S3 bucket name from step 1
- `TF_LOCK_TABLE_NAME` → the DynamoDB table name from step 1 (e.g. `terraform-locks`)

Create the OIDC provider (skip if one already exists in the account):

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

Create the role and attach the policy:

```bash
aws iam create-role \
  --role-name github-actions-terraform-vpc-ec2 \
  --assume-role-policy-document file://iam/oidc-trust-policy.json

aws iam put-role-policy \
  --role-name github-actions-terraform-vpc-ec2 \
  --policy-name terraform-vpc-ec2-permissions \
  --policy-document file://iam/terraform-permissions-policy.json
```

The permissions policy is scoped to:
- EC2/VPC actions, restricted to `us-east-1` via a `RequestedRegion` condition
- S3, restricted to the specific state bucket and the `terraform-vpc-ec2/*` key prefix
- DynamoDB, restricted to the specific lock table

It does not grant IAM, billing, or any other service access. Note that most
EC2/VPC resource-mutating actions (e.g. `ec2:CreateVpc`) don't support
resource-level ARN restrictions in IAM, so those are scoped by region instead —
this is a normal AWS limitation, not an oversight.

### 3. GitHub repo secrets
In the repo's Settings → Secrets and variables → Actions, add:

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | ARN of the IAM role created above |
| `TF_STATE_BUCKET` | Name of the S3 bucket from step 1 |
| `TF_LOCK_TABLE` | `terraform-locks` (or whatever you named it) |
| `MY_IP_CIDR` | Your public IP in CIDR form, e.g. `203.0.113.5/32` |
| `KEY_PAIR_NAME` | Existing EC2 key pair name, or leave empty |

Also create a GitHub Environment named `production` (Settings → Environments)
if you want manual approval gates before apply — the workflow references
`environment: production`.

## Running locally

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set my_ip_cidr, key_pair_name, etc.

terraform init \
  -backend-config="bucket=<your-tf-state-bucket>" \
  -backend-config="key=terraform-aws-ec2-vpc/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-locks"

terraform plan
terraform apply
```

## Running via GitHub Actions

- **PR opened**: runs `fmt`, `validate`, `plan` and comments the result on the PR.
- **Push to `main`**: runs plan then `apply` automatically.
- **Manual trigger** (`workflow_dispatch`): choose `plan`, `apply`, or `destroy`.

## Cost note

The NAT Gateway (`enable_nat_gateway = true`) costs ~$0.045/hr plus data
processing charges. Set it to `false` in `terraform.tfvars` if you don't need
the private instance to reach the internet (it'll still be reachable from
inside the VPC).

## Teardown

```bash
terraform destroy
```

or trigger the workflow manually with `action: destroy`.

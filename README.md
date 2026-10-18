# Maghad Infrastructure (AWS / Terraform)

Modular Terraform for the **Maghad development environment** in `ap-southeast-1`.

**Entry point:** `envs/dev`

```
maghad-infrastructure/
├── versions.tf / variables.tf / main.tf / outputs.tf   # reusable stack
├── terraform.tfvars.example
├── modules/
│   ├── vpc/                 # VPC, subnets, IGW, routes, NAT instance
│   ├── security-groups/     # ALB, ECS, PostgreSQL SGs
│   ├── ecr/                 # API + render-worker repositories
│   ├── ecs/                 # Fargate cluster, tasks, services, IAM
│   ├── alb/                 # Internet-facing ALB + API TG + HTTP:80
│   └── postgres-ec2/        # PostgreSQL on private EC2 + SSM
└── envs/dev/                # Dev environment entry point
```

---

## 1. Module overview

| Module | Purpose |
|--------|---------|
| **vpc** | VPC with DNS, 2 public subnets, private app + db subnets, IGW, route tables, optional NAT instance (`t3.micro` + EIP, SSM-managed, source/dest check disabled, IP forwarding + MASQUERADE). NAT SG lives here to avoid cycles. |
| **security-groups** | ALB (HTTP from configurable CIDRs), ECS (ingress from ALB only; egress to Postgres + HTTPS/DNS), PostgreSQL (5432 from ECS only). Standalone `aws_security_group_rule` resources. |
| **ecr** | `maghad-dev-api` and `maghad-dev-render-worker` with scan-on-push, AES256 encryption, lifecycle policies. |
| **alb** | Internet-facing ALB in both public subnets, IP target group for API, HTTP:80 listener. No ACM/HTTPS yet. |
| **ecs** | Fargate cluster; API + render-worker task defs/services; execution + task IAM (least privilege); 14-day CloudWatch logs; deployment circuit breaker with rollback. |
| **postgres-ec2** | `t3.medium` in private db subnet, encrypted gp3, SSM profile, user-data installs PostgreSQL without storing passwords. |

---

## 2. Resource dependency overview

```
vpc
 └─► security-groups  (needs vpc_id)
      ├─► alb         (needs public subnets + alb SG)
      │    └─► ecs    (needs private app subnet, ecs SG, API target group ARN)
      └─► postgres-ec2 (needs private db subnet + postgres SG)
ecr ─► ecs (execution role scoped to repository ARNs)
```

No circular module dependencies. ECS references the ALB target group ARN as an input; ALB does not reference ECS.

**NAT limitation:** A single NAT instance is a **dev cost optimization** and a **single point of failure**. Disable with `enable_nat = false` for testing only — private egress (ECR pulls, logs, package updates) will fail without NAT or VPC endpoints.

---

## 3. Format and validate

```bash
cd maghad-infrastructure
terraform fmt -recursive

cd envs/dev
cp terraform.tfvars.example terraform.tfvars
# Edit AMI IDs and image URIs in terraform.tfvars

terraform init
terraform validate
```

---

## 4. Initialize and review plan

```bash
cd envs/dev
terraform init
terraform plan -var-file="terraform.tfvars"
```

Do **not** run `terraform apply` until prerequisites below are complete and the plan is reviewed.

### Remote backend (later phase)

Do not create a remote-state bucket in this stack. When ready:

1. Create an S3 bucket (and optional DynamoDB lock table) manually.
2. Uncomment the `backend "s3"` block in `envs/dev/versions.tf`.
3. Run `terraform init -migrate-state`.

---

## 5. Prerequisites checklist (before apply)

- [ ] AWS credentials configured for the target account (`aws sts get-caller-identity`)
- [ ] Region set to `ap-southeast-1`
- [ ] IAM principal can create VPC, EC2, ECS, ECR, ELB, IAM roles, CloudWatch Logs
- [ ] Valid Amazon Linux 2023 AMI IDs for NAT and PostgreSQL in `ap-southeast-1`
- [ ] `terraform.tfvars` created from the example (no secrets)
- [ ] Confirm `allowed_http_cidrs` (restrict from `0.0.0.0/0` if possible)
- [ ] Confirm `enable_nat = true` unless you only need networking without private egress

Look up AL2023 AMI:

```bash
aws ssm get-parameters \
  --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query 'Parameters[0].Value' --output text \
  --region ap-southeast-1
```

---

## 6. Assumptions and manual steps before first ECS deployment

1. **Container images** — Terraform creates ECR repos and ECS services with placeholder image URIs. Push real images before tasks can start:
   ```bash
   aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.ap-southeast-1.amazonaws.com
   docker tag maghad-api:local <account>.dkr.ecr.ap-southeast-1.amazonaws.com/maghad-dev-api:latest
   docker push <account>.dkr.ecr.ap-southeast-1.amazonaws.com/maghad-dev-api:latest
   # same for maghad-dev-render-worker
   ```
   Then update `api_image` / `render_worker_image` and re-apply (or force a new deployment).

2. **Render worker** — No ALB listener or target group. It runs in the private app subnet with no public IP. Inbound is not opened for its port on the ECS SG.

3. **HTTPS** — Only HTTP:80 in this phase. ACM certificates and HTTPS listeners come later.

4. **PostgreSQL credentials** — No password is stored in Terraform, user data, outputs, or state as a secret value. Bootstrap creates DB `maghad` and role `maghad_app` **without a password**. Initialize via SSM:

   ```bash
   # From an operator workstation with SSM permissions:
   aws ssm start-session --target <postgres_instance_id> --region ap-southeast-1

   # On the instance:
   sudo -u postgres psql
   ALTER ROLE maghad_app WITH PASSWORD '<strong-password>';
   \q
   ```

   Inject the password into the API/worker at runtime via your app config mechanism (environment from CI, later Secrets Manager, etc.). Do not commit it.

5. **API health check** — Container must respond on `health_check_path` (default `/health`) with codes matching `health_check_matcher`.

6. **ECS egress** — Tasks need HTTPS (443) via NAT for ECR pulls and CloudWatch Logs. PostgreSQL needs HTTPS/HTTP during bootstrap for packages and SSM.

---

## 7. Cost drivers and safe cleanup

### What incurs cost

| Resource | Notes |
|----------|--------|
| NAT instance `t3.micro` + EIP | Always-on when enabled; SPOF |
| ALB | Hourly + LCU charges |
| ECS Fargate | Per vCPU/memory for running tasks |
| PostgreSQL `t3.medium` + 50 GB gp3 | Always-on |
| ECR storage | Per GB stored |
| CloudWatch Logs | Ingestion + storage (14-day retention) |
| Data transfer | NAT egress / ALB |

### Safe cleanup

```bash
cd envs/dev
terraform plan -destroy -var-file="terraform.tfvars"
terraform destroy -var-file="terraform.tfvars"
```

Before destroy:

- Scale ECS desired counts to 0 if needed, or let destroy remove services.
- Empty ECR repositories if lifecycle retention blocks delete (or delete images manually).
- Confirm no external resources (manual EIPs, ENIs) remain after destroy.

---

## Security notes (this phase)

- No SSH on NAT or PostgreSQL — SSM Session Manager only.
- No Secrets Manager / KMS CMK / S3 app buckets / SQS / ACM / Route 53 / CloudTrail / alarms.
- IAM: ECS execution (ECR pull + logs), ECS task role (no AWS API grants yet), EC2 SSM instance profiles for NAT and Postgres.

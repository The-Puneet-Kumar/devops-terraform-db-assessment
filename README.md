# DevOps Assessment — Terraform + Database Reliability

This repository demonstrates:

- AWS infrastructure design with Terraform: Internet → ALB → ECS/Fargate → private RDS PostgreSQL
- Separate `dev` and `prod` Terraform environments
- Local PostgreSQL with Docker Compose
- SQL migration + generated seed data
- Query optimization with a composite index
- Timestamped PostgreSQL backup and restore scripts
- GitHub Actions Terraform checks

> **AWS deployment is intentionally not performed.** Terraform is designed to be reviewable with `terraform fmt`, `terraform init`, `terraform validate`, and `terraform plan -refresh=false`.

## Repository structure

```text
.
├── .github/workflows/terraform.yml
├── infra/
│   ├── modules/
│   │   ├── network/
│   │   ├── ecs/
│   │   └── rds/
│   └── envs/
│       ├── dev/
│       └── prod/
├── db/
│   ├── migrations/001_init.sql
│   └── seed.sql
├── scripts/
│   ├── backup.sh
│   └── restore.sh
├── docker-compose.yml
└── README.md
```

## Prerequisites

- Terraform >= 1.6
- Docker + Docker Compose
- Git
- Bash (Git Bash/WSL on Windows)

---

# Part 1 — Terraform

## Architecture

```text
Internet
   |
   v
Application Load Balancer
   |
   | HTTP :80
   v
ECS/Fargate Service
   |
   | PostgreSQL :5432
   v
Private RDS PostgreSQL

VPC
├── Public subnets  -> ALB + NAT Gateways
└── Private subnets -> ECS + RDS
```

Security flow:

```text
Internet -> ALB SG :80
ALB SG   -> ECS SG :8080
ECS SG   -> RDS SG :5432
Internet -X-> RDS
Internet -X-> ECS task directly
```

The RDS security group only permits PostgreSQL traffic from the ECS security group. Private subnets use NAT gateways for controlled outbound access (for example, pulling application images or reaching external services) while remaining unreachable directly from the internet.

## Environment differences

| Setting | Dev | Prod |
|---|---|---|
| ECS CPU | 256 | 512 |
| ECS memory | 512 MiB | 1024 MiB |
| Desired tasks | 1 | 2 |
| RDS class | db.t4g.micro | db.t4g.small |
| Allocated storage | 20 GiB | 50 GiB |
| Backup retention | 3 days | 14 days |
| Deletion protection | false | true |
| Multi-AZ | false | true |

The values live in each environment's `terraform.tfvars`.

## Terraform validation

Run from the repository root:

```bash
cd infra/envs/dev
terraform fmt -recursive
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -refresh=false -var-file=terraform.tfvars
```

Then repeat for prod:

```bash
cd ../prod
terraform fmt -recursive
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -refresh=false -var-file=terraform.tfvars
```

The local backend files keep the assignment runnable without an existing AWS state bucket. For a real deployment, replace the local backend with an S3 backend + DynamoDB locking strategy.

> The AWS provider is configured for plan/review mode. No `terraform apply` is required for this assignment.

---

# Part 2 — Local PostgreSQL

Start the database:

```bash
docker compose up -d
docker compose ps
```

Check the database:

```bash
docker compose exec db pg_isready -U appuser -d bookings
```

The migration and seed SQL are mounted into PostgreSQL's initialization directory, so a fresh database automatically runs:

1. `db/migrations/001_init.sql`
2. `db/seed.sql`

Verify:

```bash
docker compose exec db psql -U appuser -d bookings -c "SELECT COUNT(*) AS bookings FROM hotel_bookings;"
docker compose exec db psql -U appuser -d bookings -c "SELECT COUNT(*) AS events FROM booking_events;"
```

Expected seed volume:

- 120 hotel bookings
- booking events for many bookings
- multiple cities
- multiple organizations
- multiple statuses

---

# Part 3 — Query optimization

Target query:

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

Index:

```sql
CREATE INDEX idx_hotel_bookings_city_created_org_status
ON hotel_bookings (city, created_at, org_id, status);
```

Why this order?

- `city` is an equality filter.
- `created_at` is a range filter.
- `org_id` and `status` are grouping columns and can reduce heap work after filtering.

Check the plan:

```bash
docker compose exec db psql -U appuser -d bookings -c "EXPLAIN (ANALYZE, BUFFERS) SELECT org_id, status, COUNT(*), SUM(amount) FROM hotel_bookings WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days' GROUP BY org_id, status;"
```

With only 120 rows, PostgreSQL may still choose a sequential scan because the table is tiny. That is normal. The important part is that the index is appropriate for the access pattern and should become more useful as the table grows.

---

# Part 4 — Backup

Make scripts executable:

```bash
chmod +x scripts/*.sh
```

Create a timestamped dump:

```bash
./scripts/backup.sh
```

The dump is written to:

```text
backups/bookings_YYYYMMDD_HHMMSS.dump
```

The script uses PostgreSQL custom format (`pg_dump -Fc`), which is suitable for `pg_restore`.

---

# Part 5 — Restore verification

Restore into a fresh database:

```bash
./scripts/restore.sh backups/bookings_YYYYMMDD_HHMMSS.dump
```

The script creates a fresh database named:

```text
bookings_restore
```

Verify:

```bash
docker compose exec db psql -U appuser -d bookings_restore -c "SELECT COUNT(*) FROM hotel_bookings;"
docker compose exec db psql -U appuser -d bookings_restore -c "SELECT COUNT(*) FROM booking_events;"
```

Verify the restored schema:

```bash
docker compose exec db psql -U appuser -d bookings_restore -c "\dt"
```

Verify the index:

```bash
docker compose exec db psql -U appuser -d bookings_restore -c "\di"
```

The restore is considered successful when the restored booking/event counts match the source database and the expected tables/indexes exist.

---

# Part 6 — GitHub Actions

`.github/workflows/terraform.yml` runs on pull requests and:

- checks Terraform formatting
- initializes both environments
- validates both environments
- creates a plan with `-refresh=false`

The workflow uploads plan output as artifacts. It does **not** apply infrastructure.

## Before pushing

```bash
terraform fmt -recursive
git status
git add .
git commit -m "feat: complete DevOps assessment"
git push
```

## Suggested GitHub repository description

> DevOps assessment demonstrating Terraform AWS architecture, ECS/Fargate + private RDS design, PostgreSQL backup/restore, query optimization, Docker Compose, and CI validation.

## What to explain in the interview

Be ready to explain:

1. Why ALB is public but RDS is private.
2. Why RDS allows traffic from ECS SG instead of an IP range.
3. Why ECS tasks are placed in private subnets.
4. How ALB reaches ECS tasks.
5. Why the database backup uses `pg_dump -Fc`.
6. How restore creates a separate database.
7. Why the composite index starts with `city, created_at`.
8. Why dev/prod have different sizing and deletion protection.
9. Why production RDS should use backups, Multi-AZ, encryption, monitoring and controlled access.
10. Why `terraform plan -refresh=false` is useful for an assignment that does not require live AWS access.

## Important production note

This repository is an assessment/demo, not a production deployment. In a real AWS environment, secrets should come from Secrets Manager/SSM rather than plain Terraform variables, state should use a secured S3 backend with locking, RDS should use encryption and monitoring, and ECS should use a real application image with health checks.

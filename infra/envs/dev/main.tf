module "network" {
  source = "../../modules/network"

  name                 = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP from internet"
  vpc_id      = module.network.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "ecs" {
  source = "../../modules/ecs"

  name                   = var.project_name
  aws_region             = var.aws_region
  environment            = var.environment
  vpc_id                 = module.network.vpc_id
  public_subnet_ids      = module.network.public_subnet_ids
  private_subnet_ids     = module.network.private_subnet_ids
  alb_security_group_id  = aws_security_group.alb.id
  container_image        = var.container_image
  container_port         = var.container_port
  cpu                    = var.ecs_cpu
  memory                 = var.ecs_memory
  desired_count          = var.desired_count
  log_retention_days     = var.rds_backup_retention
}

module "rds" {
  source = "../../modules/rds"

  name                   = var.project_name
  environment            = var.environment
  vpc_id                 = module.network.vpc_id
  private_subnet_ids     = module.network.private_subnet_ids
  ecs_security_group_id  = module.ecs.ecs_security_group_id
  engine_version         = "16.4"
  instance_class         = var.rds_instance_class
  allocated_storage      = var.rds_allocated_storage
  db_name                = var.db_name
  db_username            = var.db_username
  db_password            = var.db_password
  backup_retention_period = var.rds_backup_retention
  deletion_protection    = var.rds_deletion_protection
  multi_az               = var.rds_multi_az
}

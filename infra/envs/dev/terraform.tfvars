aws_region              = "ap-south-1"
project_name            = "hotel-booking-dev"
environment             = "dev"

vpc_cidr                = "10.10.0.0/16"
availability_zones      = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs     = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnet_cidrs    = ["10.10.11.0/24", "10.10.12.0/24"]

container_image         = "nginx:1.27-alpine"
container_port          = 80
ecs_cpu                 = 256
ecs_memory              = 512
desired_count           = 1

rds_instance_class      = "db.t4g.micro"
rds_allocated_storage   = 20
rds_backup_retention    = 3
rds_deletion_protection = false
rds_multi_az            = false

db_name                 = "hotelbookings"
db_username             = "appuser"
db_password             = "CHANGE_ME_IN_REAL_USE"

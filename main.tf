###########################
# Modules
###########################

module "vpc" {
  source  = "./vpc"
  project = var.project
}

module "eks" {
  source          = "./eks"
  project         = var.project
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnets
  private_subnets = module.vpc.private_subnets
}

module "db_subnets" {
  source             = "./modules/db"
  private_subnet_ids = module.vpc.private_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

###########################
# Security Group for DBs
###########################

resource "aws_security_group" "db_sg" {
  name        = "${var.project}-db-sg"
  description = "Allow DB access"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Postgres access from VPC
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # MySQL access from VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
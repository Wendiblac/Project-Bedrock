###########################
# Terraform Variables
###########################

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Project name prefix"
  type        = string
  default     = "project-bedrock"
}

variable "orders_db_username" {
  description = "Username for Orders PostgreSQL DB"
  type        = string
  default     = "orders_admin"
}

variable "orders_db_password" {
  description = "Password for Orders PostgreSQL DB (set via GitHub Actions secret TF_VAR_orders_db_password)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.orders_db_password) > 0
    error_message = "orders_db_password cannot be empty!"
  }
}

variable "catalog_db_username" {
  description = "Username for Catalog MySQL DB"
  type        = string
  default     = "catalog_admin"
}

variable "catalog_db_password" {
  description = "Password for Catalog MySQL DB (set via GitHub Actions secret TF_VAR_catalog_db_password)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.catalog_db_password) > 0
    error_message = "catalog_db_password cannot be empty!"
  }
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for DB subnet group"
  type        = list(string)
}

###########################
# AWS Provider
###########################

provider "aws" {
  region = var.region
}

###########################
# Security Group for DBs
###########################

resource "aws_security_group" "db_sg" {
  name        = "${var.project}-db-sg"
  description = "Allow DB access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # adjust based on your VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###########################
# DB Subnet Group
###########################

resource "aws_db_subnet_group" "private_subnets" {
  name       = "${var.project}-db-subnets"
  subnet_ids = var.private_subnet_ids
}

###########################
# RDS Instances
###########################

resource "aws_db_instance" "orders_postgres" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15.3"
  instance_class         = "db.t3.micro"
  name                   = "orders"
  username               = var.orders_db_username
  password               = var.orders_db_password
  publicly_accessible    = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.private_subnets.name
}

resource "aws_db_instance" "catalog_mysql" {
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  name                   = "catalog"
  username               = var.catalog_db_username
  password               = var.catalog_db_password
  publicly_accessible    = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.private_subnets.name
}



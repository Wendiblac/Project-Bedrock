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
    cidr_blocks = ["10.0.0.0/16"] # adjust based on your VPC
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # MySQL access
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


###########################
# RDS Subnet Groups
###########################

resource "aws_db_subnet_group" "orders" {
  name        = "${var.project}-orders-db-subnet-group"
  subnet_ids  = module.vpc.private_subnets
  description = "Private subnets for Orders PostgreSQL DB"
}

resource "aws_db_subnet_group" "catalog" {
  name        = "${var.project}-catalog-db-subnet-group"
  subnet_ids  = module.vpc.private_subnets
  description = "Private subnets for Catalog MySQL DB"
}

###########################
# RDS Instances
###########################

resource "aws_db_instance" "orders_postgres" {
  identifier             = "orders-postgres-db"
  engine                 = "postgres"
  engine_version         = "11.22-rds.20240418" # valid version in eu-west-1
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = var.orders_db_username
  password               = var.orders_db_password
  db_subnet_group_name   = aws_db_subnet_group.orders.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
}

resource "aws_db_instance" "catalog_mysql" {
  identifier             = "catalog-mysql-db"
  engine                 = "mysql"
  engine_version         = "8.0" # valid version in eu-west-1
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = var.catalog_db_username
  password               = var.catalog_db_password
  db_subnet_group_name   = aws_db_subnet_group.catalog.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
}
resource "aws_db_subnet_group" "catalog" {
  name       = "catalog-db-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_instance" "catalog_mysql" {
  identifier         = "catalog-mysql-db"
  engine             = "mysql"
  engine_version     = "8.1"
  instance_class     = "db.t3.micro"
  allocated_storage  = 20
  name               = "catalogdb"
  username           = var.catalog_db_username
  password           = var.catalog_db_password
  db_subnet_group_name = aws_db_subnet_group.catalog.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
}

resource "aws_db_subnet_group" "orders" {
  name       = "orders-db-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_instance" "orders_postgres" {
  identifier         = "orders-postgres-db"
  engine             = "postgres"
  engine_version     = "15.3"
  instance_class     = "db.t3.micro"
  allocated_storage  = 20
  name               = "ordersdb"
  username           = var.orders_db_username
  password           = var.orders_db_password
  db_subnet_group_name = aws_db_subnet_group.orders.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false
}

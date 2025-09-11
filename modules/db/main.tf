variable "private_subnet_ids" {
  type = list(string)
}

resource "aws_db_subnet_group" "this" {
  name       = "db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags = {
    Name = "db-subnet-group"
  }
}

output "private_subnet_ids" {
  value = var.private_subnet_ids
}

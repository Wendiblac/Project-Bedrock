resource "aws_dynamodb_table" "carts" {
  name         = "carts-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "cart_id"

  attribute {
    name = "cart_id"
    type = "S"
  }

  tags = {
    Environment = "dev"
    Project     = "bedrock"
  }
}

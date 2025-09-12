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
    condition     = length(var.orders_db_password) >= 8 && length(var.orders_db_password) <= 41
    error_message = "orders_db_password must be 8-41 characters."
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

variable "private_subnets" {
  description = "Optional list of private subnet IDs (unused at root, passed via modules)"
  type        = list(string)
  default     = []
}

variable "public_subnets" {
  description = "Optional list of public subnet IDs (unused at root, passed via modules)"
  type        = list(string)
  default     = []
}

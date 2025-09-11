variable "project" {
  description = "Project name"
  type        = string
  default     = "project-bedrock"
}

variable "vpc_id" {
  description = "VPC id"
  type        = string
}

variable "public_subnets" {
  description = "Public subnet ids (list)"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet ids (list)"
  type        = list(string)
}

variable "instance1_name" {
  description = "Name for the first EC2 instance"
  type        = string
}

variable "instance2_name" {
  description = "Name for the second EC2 instance"
  type        = string
}

variable "db_username" {
  description = "Username for the RDS database"
  type        = string
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  sensitive   = true
}

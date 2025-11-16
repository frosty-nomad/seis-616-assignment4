variable "instance1_name" {
  description = "EC2 instance 1"
  type        = string
}

variable "instance2_name" {
  description = "EC2 instance 2"
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

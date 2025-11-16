output "instance_public_ips" {
  description = "Public IP addresses of the EC2 instances"
  value       = aws_instance.web_server[*].public_ip
}

output "rds_address" {
  description = "RDS instance endpoint address"
  value       = aws_db_instance.mysql_rds.address
}

output "rds_endpoint" {
  description = "RDS endpoint in address:port form"
  value       = "${aws_db_instance.mysql_rds.address}:${aws_db_instance.mysql_rds.port}"
}

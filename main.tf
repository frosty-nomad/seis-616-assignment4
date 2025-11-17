# Configure the AWS provider
provider "aws" {
  region = "us-east-1" 
}

# Get availability zones for use in subnet creation
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main_vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main_igw"
  }
}

# Public subnets in 2 different AZs
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index) # 10.0.0.0/24, 10.0.1.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true # Automatically assign public IPs to EC2 instances

  tags = {
    Name = "public_subnet_${count.index + 1}"
  }
}

# Private subnets in 2 different AZs
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 2) # 10.0.2.0/24, 10.0.3.0/24
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private_subnet_${count.index + 1}"
  }
}

# Create a public route table and associate with public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public_route_table"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group for Web Servers (EC2)
resource "aws_security_group" "web_server_sg" {
  name        = "web_server_sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH - anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web_Server_SG"
  }
}

# Data source for the latest Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*x86_64-gp2"]
  }
}

# Launch EC2 instance in each public subnet
resource "aws_instance" "web_server" {
  count                  = 2
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]
  # Associate public IP automatically due to map_public_ip_on_launch on subnet

  tags = {
    Name = count.index == 0 ? var.instance1_name : var.instance2_name
  }
}

# Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "rds_sg"
  description = "Allow MySQL traffic from web servers SG only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from web servers SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web_server_sg.id] 
  }
  
  # Outbound access for updates etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS_SG"
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds_subnet_group"
  subnet_ids = aws_subnet.private[*].id 

  tags = {
    Name = "RDS Subnet Group"
  }
}

# RDS Instance with MySQL engine
resource "aws_db_instance" "mysql_rds" {
  identifier           = "my-mysql-db-instance"
  engine               = "mysql"
  engine_version       = "8.0" 
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp2"
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_name              = "mydb" # Initial database name
  username             = var.db_username
  password             = var.db_password
  skip_final_snapshot  = true # Set to false in production

  # Ensuring the RDS instance is not publicly accessible
  publicly_accessible = false 

  # Ensure the subnets are created before trying to create the RDS instance
  depends_on = [
    aws_subnet.private,
    aws_security_group.rds_sg
  ]
}

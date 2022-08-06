provider "aws" {
  region = "us-east-1"
  access_key = var.access-key
  secret_key = var.secret-key
}

# 1. Create VPC
resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "prod-vpc"
  }
}

# 2. Create Internet Gateway
resource "aws_internet_gateway" "prod_gateway" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "prod-internet-gateway"
  }
}

# 3. Create Custom Route Table
resource "aws_route_table" "prod_route" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_gateway.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.prod_gateway.id
  }

  tags = {
    Name = "prod-route"
  }
}

# 4. Create a Subnet
resource "aws_subnet" "prod_subnet" {
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  
  tags = {
    Name = "prod-subnet"
  }
}

# 5. Associate subnet with Route Table
resource "aws_route_table_association" "prod_route_table_association" {
  subnet_id = aws_subnet.prod_subnet.id
  route_table_id = aws_route_table.prod_route.id
}

# 6. Create Security Group to allow Port 22,80,443
resource "aws_security_group" "prod_security_group" {
  name        = "allow web traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod_vpc.id

  ingress {
    description      = "Allow HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Allow HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Allow SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "prod-security-group"
  }
}

# 7. Create a network interface with an IP in the subnet that was create in step 4
resource "aws_network_interface" "prod_nic" {
  subnet_id       = aws_subnet.prod_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.prod_security_group.id]
  
  tags = {
    Name = "prod_nic"
  }
}

# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "prod_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.prod_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.prod_gateway]

  tags = {
    Name  = "prod_eip"
  }
}

# 9. Create Centos server and install/ enable Apache
resource "aws_instance" "prod_instance" {
  ami           = "ami-065efef2c739d613b"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "prod_key"
  user_data_replace_on_change = true

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.prod_nic.id
  }

  user_data = <<EOF
                #!/bin/bash
                sudo yum update -y
                sudo yum install httpd -y
                sudo systemctl start httpd
                sudo bash -c 'echo Web server deployed through Terraform > /var/www/html/index.html'
                EOF
  tags = {
    Name = "prod_instance"
  }
}

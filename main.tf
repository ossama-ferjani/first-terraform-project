provider "aws" {
  region ="eu-west-3"
}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable key_pair {}

resource "aws_vpc" "myapp_vpc" {
   cidr_block = var.vpc_cidr_block
   tags ={
     Name = "${var.env_prefix}-vpc"
   }
}

resource "aws_subnet" "myapp_subnet-1" {
   vpc_id =aws_vpc.myapp_vpc.id
   cidr_block = var.subnet_cidr_block
   availability_zone = var.avail_zone
   tags = {
      Name = "${var.env_prefix}-subnet-1"
   }
}
resource "aws_route_table" "myapp_route_table"{
    vpc_id=aws_vpc.myapp_vpc.id 
    route {
      cidr_block="0.0.0.0/0"
      gateway_id=aws_internet_gateway.myapp_igw.id
    }
    tags = {
      Name = "${var.env_prefix}-rtb"
    }
}

resource "aws_internet_gateway" "myapp_igw"{
    vpc_id=aws_vpc.myapp_vpc.id
    tags = {
      Name = "${var.env_prefix}-igw"
    }
}

resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id = aws_subnet.myapp_subnet-1.id 
  route_table_id = aws_route_table.myapp_route_table.id
}
  

resource "aws_security_group" "myapp_sg" {
  name ="myapp_sg"
  vpc_id = aws_vpc.myapp_vpc.id
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.my_ip]
}
ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}

egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
}
}
data "aws_ami" "latest_amazon_linux" {
 most_recent = true
  owners = ["amazon"] 
  filter {
    name = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
}
}
resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
  public_key = "${file(var.key_pair)}"
  tags = {
    Name = "${var.env_prefix}-key"
  }
}

resource "aws_instance" "myapp_instance" {
ami= data.aws_ami.latest_amazon_linux.id 
instance_type = var.instance_type
subnet_id = aws_subnet.myapp_subnet-1.id
associate_public_ip_address = true
vpc_security_group_ids = [aws_security_group.myapp_sg.id]
availability_zone = var.avail_zone

user_data = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker

    # Start the Docker service
    sudo systemctl start docker
    sudo systemctl enable docker

    # Run Nginx container
    sudo docker run -d -p 80:80 nginx
EOF
tags = {
  Name = "${var.env_prefix}-instance"
}
#key-pair or password authentication needed
key_name = aws_key_pair.ssh-key.key_name


}

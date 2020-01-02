###
# This config stands up the following 
# 1 VPC with a dynamially supplied name in eu-west-2 

###
# Declare variables for use in config
###

variable "vpc_name" {
  type = string
}

variable "az_list" {
  type = list
}

variable "public_cidr" {
  type = list
}

variable "ec2_ami" {
  type = string
}

variable "ec2_instance_type" {
  type = string
}

variable "ec2_keypair" {
  type = string
}

###
# configure backend
###

terraform {
    backend "s3" {
        bucket = "telios-terraform-s3-backend"
        key = "zdt-demo"
        encrypt = true
        dynamodb_table = "devops-zdt-demo-lock-table"
        region = "eu-west-2"
    }
}

###
# Define provider
###

provider "aws" {
    version = "~> 2.43"
    region = "eu-west-2"
}

###
# Resource creation begins...
###

###
# Create VPC using comand line name
###

resource "aws_vpc" "devops" {
    tags = {
        Name = var.vpc_name
    }
    cidr_block = "10.0.0.0/16"    
}

###
# Create public subnets and allow public IP to be autoassigned to instances
###

resource "aws_subnet" "public" {
    count = length(var.az_list)
    tags = {
        Name = "${var.vpc_name}-public-${var.az_list[count.index]}"
    }
    availability_zone = var.az_list[count.index]
    vpc_id = aws_vpc.devops.id
    cidr_block = var.public_cidr[count.index]
    map_public_ip_on_launch = true    
}

###
# Create IGW atatched to VPC
###

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.devops.id
    tags = {
        Name = "${var.vpc_name}-igw"
    }
}

###
# Create public RT resolving via IGW and associate with public subnets
###

# create Public RT

resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.devops.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "${var.vpc_name}_public_rt"
    }
    depends_on =[aws_internet_gateway.igw]
}

# associate public RT with public subnets

resource "aws_route_table_association" "public" {
    count = length(var.az_list)
    subnet_id = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public_rt.id
    depends_on =[aws_route_table.public_rt]
}

###
# Create secgrp for EC2 and LB
###

resource "aws_security_group" "webtraffic" {
    name = "web"
    vpc_id = aws_vpc.devops.id
    ingress {
        from_port = 80
        to_port = 80
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

###
# Create 3 EC2 in public subnets
###

resource "aws_instance" "web" {
    count = length(var.az_list)
    ami = var.ec2_ami
    key_name = var.ec2_keypair
    instance_type = var.ec2_instance_type
    subnet_id = aws_subnet.public[count.index].id
    user_data = file("files/ec2-user-data.sh")
    vpc_security_group_ids = [aws_security_group.webtraffic.id]
    tags = {
        Name = "${var.vpc_name}-webserver-${var.az_list[count.index]}"
    }
    depends_on =[aws_route_table_association.public]
}

###
# Create loadbalancer and attach ec2s to it
###

resource "aws_elb" "web-lb" {
    depends_on =[aws_instance.web]
    name = "${var.vpc_name}-elb"
    subnets = [aws_subnet.public[0].id, aws_subnet.public[1].id, aws_subnet.public[2].id]
    security_groups = [aws_security_group.webtraffic.id]
    instances = [aws_instance.web[0].id, aws_instance.web[1].id, aws_instance.web[2].id]
    cross_zone_load_balancing = true
    idle_timeout = 100
    connection_draining_timeout = 300
    listener {
        instance_port = 80
        instance_protocol = "http"
        lb_port = 80
        lb_protocol = "http"
    }
    health_check {
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        target = "HTTP:80/"
        interval = 30
    }
    tags = {
        Name = "${var.vpc_name}-elb"
    }
}

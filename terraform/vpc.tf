#create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block           = var.myvpc_cidr
  enable_dns_support   = true # Enables DNS resolution
  enable_dns_hostnames = true # Enables public DNS hostnames

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

#create subnets for each availability zone, limited by the number of elements of assigned cidr in tfvars
resource "aws_subnet" "public_subnets" {
  for_each = {
    for i, az in var.azs : i => {
      az   = az
      cidr = var.public_subnet_cidrs[i]
    }
    if i < length(var.public_subnet_cidrs)
  }

  vpc_id                  = aws_vpc.my_vpc.id
  map_public_ip_on_launch = true
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az

  tags = {
    Name = "${local.name_prefix}-public-subnet-${each.key + 1}"
  }
}


#create igw
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "${local.name_prefix}-IGW"
  }

  timeouts {
    create = "5m"
    update = "5m"
    delete = "5m"
  }
  # Add this lifecycle block
  lifecycle {
    create_before_destroy = true
  }
}



#Create public route
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "${local.name_prefix}-Public-Route-Table"
  }
}

#associate public subnets with public route
resource "aws_route_table_association" "public_subnet_asso" {
  for_each = aws_subnet.public_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}


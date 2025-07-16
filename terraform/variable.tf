variable "name" {
  type        = string
  description = "Ownership of resources"
  default     = "growfatlikeme"
}

variable "environment" {
  type        = string
  description = "Environment type (dev, staging, prod)"
  default     = "ndev"
}


################################################################################
# VPC
################################################################################

variable "create_vpc" {
  description = "Controls if VPC should be created (it affects almost all resources)"
  type        = bool
  default     = true
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "ap-southeast-1"
}

variable "myvpc_cidr" {
  type        = string
  description = "VPC CIDR range"
  default     = "172.16.16.0/20"
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
}

################################################################################
# Subnets
################################################################################

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public Subnet CIDR values"
  default     = ["172.16.17.0/24", "172.16.18.0/24", "172.16.19.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private Subnet CIDR values"
  default     = ["172.16.20.0/24", "172.16.21.0/24", "172.16.22.0/24"]
}

variable "database_subnet_cidrs" {
  type        = list(string)
  description = "Database Subnet CIDR values"
  default     = ["172.16.23.0/24", "172.16.24.0/24", "172.16.25.0/24"]
}

################################################################################
# NAT Gateway
################################################################################

variable "create_natgw" {
  description = "Whether to create NAT Gateway"
  type        = bool
  default     = false
}
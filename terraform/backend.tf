terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "sctp-ce10-tfstate"
    key    = "growfatflask.tfstate"
    region = "ap-southeast-1"
  }
}
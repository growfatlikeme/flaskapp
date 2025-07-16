terraform {
  backend "s3" {
    bucket = "sctp-ce10-tfstate"
    key    = "growfatflask.tfstate" #The name of the file in the bucket
    region = "ap-southeast-1"
  }
}
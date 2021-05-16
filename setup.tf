terraform {
  backend "s3" {
    bucket = "devsandbox-tf-state-121918142008"
    key    = "state.tfstate"
    region = "us-west-1"
    dynamodb_table = "devsandbox-tf-lock"
    encrypt = true
    shared_credentials_file = "/Users/zacho/.aws/credentials"
    profile = "terraform"
  }
}

provider "aws" {
  shared_credentials_file = "/Users/zacho/.aws/credentials"
  profile = "terraform"
  region = "us-west-1"
}
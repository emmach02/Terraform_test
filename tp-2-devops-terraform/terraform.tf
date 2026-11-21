terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws" #Sandbox terraform
      version = "5.87.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = { Proyecto = "FintechNova", Gestion = "terraform" }
  }
}

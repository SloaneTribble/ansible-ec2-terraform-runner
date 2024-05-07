terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"

  backend "s3" {
    bucket = "stribble-bucket"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"

}

# module "vpc" {
#   source  = "terraform-aws-modules/vpc/aws"
#   version = "3.18.1"

#   name = var.vpc_name
#   cidr = var.vpc_cidr

#   azs            = var.vpc_azs
#   public_subnets = var.vpc_public_subnets

#   enable_nat_gateway = var.vpc_enable_nat_gateway

#   tags = var.vpc_tags
# }


module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "4.3.0"

  count = 1
  name  = "stribble-ansible-ec2-cluster-${count.index}"

  ami                         = "ami-04e5276ebb8451442" # linux x86 image
  instance_type               = "t2.micro"
  key_name                    = "stribble-tf-ec2-runner"
  associate_public_ip_address = true

  vpc_security_group_ids = ["sg-06198c96f581e0a30"]
  subnet_id              = "subnet-019c03f7b62349192"

  tags = {
    Terraform            = "true"
    Environment          = "sandbox"
    Application          = "stribble-modules-exercise"
    Owner                = "stribble"
    Project              = "dob"
    Automation-Candidate = "true"
    Client               = "internal"
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    ips = module.ec2_instance[*].public_ip
  })
  filename   = "${path.module}/inventory.ini"
  depends_on = [module.ec2_instance]
}

resource "null_resource" "ansible_provisioner" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i ${local_file.ansible_inventory.filename} playbook.yaml"
  }

  depends_on = [
    module.ec2_instance,
    local_file.ansible_inventory
  ]
}

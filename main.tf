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



module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "4.3.0"

  count = 2
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
    # this will always be different so our ansible provisioner will always run when running terraform apply
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

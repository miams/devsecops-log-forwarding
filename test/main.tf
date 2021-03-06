data "aws_region" "current" {
  current = true
}

locals {
  azs = ["${data.aws_region.current.name}${var.az}"]
}

module "network" {
  source = "terraform-aws-modules/vpc/aws"
  version = ">= 1.11.0"

  azs = ["${local.azs}"]
  cidr = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support = true
  enable_nat_gateway = true
  name = "devsecops-log-forwarding-test"
  public_subnets = ["${var.public_subnet_cidr}"]
  private_subnets = ["${var.private_subnet_cidr}"]
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["*ubuntu-xenial-16.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "deployer" {
  key_name_prefix = "log-forwarding-deployer-key-"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

module "log_forwarding" {
  source = ".."

  vpc_id = "${module.network.vpc_id}"
  # TODO make private
  lb_subnets = "${module.network.public_subnets}"
  instance_subnets = "${module.network.public_subnets}"
  ami_id = "${data.aws_ami.ubuntu.id}"
  key_pair = "${aws_key_pair.deployer.key_name}"
  ssh_cidr = "${var.ssh_cidr}"
}

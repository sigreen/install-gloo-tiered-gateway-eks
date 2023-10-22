provider "aws" {
  profile = var.profile
  region = var.region
}

data "aws_availability_zones" "available" {}

locals {
  cluster_name = format("%s-%s", basename(path.cwd), "shared")
  region       = var.region

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    created-by  = var.created-by
    team = var.team
  }
}

################################################################################
# VPC 2
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.cluster_name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

################################################################################
# Cluster 3 additional security group for cross cluster communication
################################################################################

resource "aws_security_group" "cluster3_additional_sg" {
  name        = "cluster3_additional_sg"
  description = "Allow communication from cluster4 SG to cluster3 SG"
  vpc_id      = module.vpc.vpc_id
  tags = {
    Name = "cluster3_additional_sg"
    created-by  = var.created-by
    team = var.team
  }
}

resource "aws_vpc_security_group_egress_rule" "cluster3_additional_sg_allow_all_4" {
  security_group_id = aws_security_group.cluster3_additional_sg.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "cluster3_additional_sg_allow_all_6" {
  security_group_id = aws_security_group.cluster3_additional_sg.id

  ip_protocol = "-1"
  cidr_ipv6   = "::/0"
}

################################################################################
# Cluster 4 additional security group for cross cluster communication
################################################################################

resource "aws_security_group" "cluster4_additional_sg" {
  name        = "cluster4_additional_sg"
  description = "Allow communication from cluster3 SG to cluster4 SG"
  vpc_id      = module.vpc.vpc_id
  tags = {
    Name = "cluster4_additional_sg"
    created-by  = var.created-by
    team = var.team
  }
}

resource "aws_vpc_security_group_egress_rule" "cluster4_additional_sg_allow_all_4" {
  security_group_id = aws_security_group.cluster4_additional_sg.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}
resource "aws_vpc_security_group_egress_rule" "cluster4_additional_sg_allow_all_6" {
  security_group_id = aws_security_group.cluster4_additional_sg.id

  ip_protocol = "-1"
  cidr_ipv6   = "::/0"
}

################################################################################
# Management 2 cluster additional security group for cross cluster communication
################################################################################

resource "aws_security_group" "mgmt2cluster_additional_sg" {
  name        = "mgmt2cluster_additional_sg"
  description = "Allow communication between all clusters"
  vpc_id      = module.vpc.vpc_id
  tags = {
    Name = "mgmt2cluster_additional_sg"
    created-by  = var.created-by
    team = var.team
  }
}

resource "aws_vpc_security_group_egress_rule" "mgmt2cluster_additional_sg_allow_all_4" {
  security_group_id = aws_security_group.mgmt2cluster_additional_sg.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}
resource "aws_vpc_security_group_egress_rule" "mgmt2cluster_additional_sg_allow_all_6" {
  security_group_id = aws_security_group.mgmt2cluster_additional_sg.id

  ip_protocol = "-1"
  cidr_ipv6   = "::/0"
}

################################################################################
# cross SG  ingress rules Cluster 4 allow to cluster 3
################################################################################

resource "aws_vpc_security_group_ingress_rule" "cluster4_to_cluster_3" {
  security_group_id = aws_security_group.cluster3_additional_sg.id

  referenced_security_group_id = aws_security_group.cluster4_additional_sg.id
  ip_protocol                  = "-1"
}

################################################################################
# cross SG  ingress rules Cluster 3 allow to cluster 4
################################################################################

resource "aws_vpc_security_group_ingress_rule" "cluster3_to_cluster_4" {
  security_group_id = aws_security_group.cluster4_additional_sg.id

  referenced_security_group_id = aws_security_group.cluster3_additional_sg.id
  ip_protocol                  = "-1"
}

################################################################################
# cross SG  ingress rules management cluster allow to cluster 3 + 4
################################################################################

resource "aws_vpc_security_group_ingress_rule" "cluster3_to_mgmt2cluster" {
  security_group_id = aws_security_group.mgmt2cluster_additional_sg.id

  referenced_security_group_id = aws_security_group.cluster3_additional_sg.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "cluster4_to_mgmt2cluster" {
  security_group_id = aws_security_group.mgmt2cluster_additional_sg.id

  referenced_security_group_id = aws_security_group.cluster4_additional_sg.id
  ip_protocol                  = "-1"
}
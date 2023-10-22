provider "aws" {
  profile = var.profile
  region = var.region
}

data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "${path.module}/../0.vpc/terraform.tfstate"
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

locals {
  cluster_name = var.name
  region       = var.region
  license      = var.gloo-license

  cluster1_additional_sg_id = data.terraform_remote_state.vpc.outputs.cluster1_additional_sg_id
  cluster2_additional_sg_id = data.terraform_remote_state.vpc.outputs.cluster2_additional_sg_id
  mgmtcluster_additional_sg_id = data.terraform_remote_state.vpc.outputs.mgmtcluster_additional_sg_id

  tags = {
    created-by  = var.created-by
    team = var.team
  }
}

################################################################################
# Cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.16"

  cluster_name                   = local.cluster_name
  cluster_version                = "1.27"
  cluster_endpoint_public_access = true

  # EKS Addons
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  vpc_id     = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.vpc.outputs.subnet_ids

  eks_managed_node_groups = {
    mgmtcluster = {
      instance_types = ["m5.large"]

      min_size               = 1
      max_size               = 5
      desired_size           = 2
      vpc_security_group_ids = [local.mgmtcluster_additional_sg_id]

    }
  }
  # SG Rule for nodes in cluster 2 to be able to reach to the cluster1 control plane
  cluster_security_group_additional_rules = {
    ingress_allow_from_other_cluster = {
      description              = "Access EKS from EC2 instances in other cluster."
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      source_security_group_id = local.cluster1_additional_sg_id
    }
  }

  #  EKS K8s API cluster needs to be able to talk with the EKS worker nodes with port 15017/TCP and 15012/TCP which is used by Istio
  #  Istio in order to create sidecar needs to be able to communicate with webhook and for that network passage to EKS is needed.
  node_security_group_additional_rules = {
    ingress_15017 = {
      description                   = "Cluster API - Istio Webhook namespace.sidecar-injector.istio.io"
      protocol                      = "TCP"
      from_port                     = 15017
      to_port                       = 15017
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_15012 = {
      description                   = "Cluster API to nodes ports/protocols"
      protocol                      = "TCP"
      from_port                     = 15012
      to_port                       = 15012
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }

  tags = local.tags
}

################################################################################
# EKS Blueprints Addons
################################################################################

module "addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  # This is required to expose Istio Ingress Gateway
  enable_aws_load_balancer_controller = true
  enable_cert_manager                 = true

  tags = local.tags
}

################################################################################
# Install Gloo Mesh Management Plane
################################################################################

resource "kubernetes_namespace" "gloo-mesh" {
  metadata {
    name = "gloo-mesh"
  }
  depends_on = [
    module.addons,
  ]
}

resource "helm_release" "gloo-platform-crds" {
  name              = "gloo-platform-crds"
  chart             = "gloo-platform-crds"
  repository = "https://storage.googleapis.com/gloo-platform/helm-charts"
  namespace         = "gloo-mesh"
  dependency_update = true

  set {
    name  = "version"
    value = "2.4.2"
  }

  set {
    name  = "namespace"
    value = "gloo-mesh"
  }

  depends_on = [
    kubernetes_namespace.gloo-mesh
  ]
}

resource "helm_release" "gloo-platform" {
  name              = "gloo-platform"
  chart             = "gloo-platform"
  repository = "https://storage.googleapis.com/gloo-platform/helm-charts"
  namespace         = "gloo-mesh"
  dependency_update = true

  values = [
    "${file("data/gloo-mgmt-values.yaml")}"
  ]

  set {
    name  = "licensing.glooMeshLicenseKey"
    value = var.gloo-license
  }

  set {
    name  = "licensing.glooTrialLicenseKey"
    value = var.gloo-license
  }

  set {
    name  = "licensing.glooGatewayLicenseKey"
    value = var.gloo-license
  }

  depends_on = [
    kubernetes_namespace.gloo-mesh
  ]
}
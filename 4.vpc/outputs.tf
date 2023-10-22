output "vpc_id" {
  description = "Amazon EKS VPC ID"
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "Amazon EKS Subnet IDs"
  value       = module.vpc.private_subnets
}

output "vpc_cidr" {
  description = "Amazon EKS VPC CIDR Block."
  value       = local.vpc_cidr
}

output "cluster3_additional_sg_id" {
  description = "Cluster 3 additional SG"
  value       = aws_security_group.cluster3_additional_sg.id
}

output "cluster4_additional_sg_id" {
  description = "Cluster 4 additional SG"
  value       = aws_security_group.cluster4_additional_sg.id
}

output "mgmt2cluster_additional_sg_id" {
  description = "Management 2 cluster additional SG"
  value       = aws_security_group.mgmt2cluster_additional_sg.id
}
# outputs.tf
output "cluster_endpoint" {
  value       = aws_eks_cluster.cluster.endpoint
  description = "EKS cluster endpoint"
}

output "cluster_arn" {
  value       = aws_eks_cluster.cluster.arn
  description = "EKS cluster ARN"
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "List of public subnet IDs"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "List of private subnet IDs"
}

output "nat_gateway_ids" {
  value       = aws_nat_gateway.nat[*].id
  description = "List of NAT Gateway IDs"
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region}"
  description = "Command to configure kubectl"
}
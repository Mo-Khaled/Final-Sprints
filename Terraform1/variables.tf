variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "stage-eks-cluster"
}

variable "node_desired_capacity" {
  description = "Desired number of nodes in the EKS cluster"
  type        = number
  default     = 2
}

variable "node_max_capacity" {
  description = "Maximum number of nodes in the EKS cluster"
  type        = number
  default     = 4
}

variable "node_min_capacity" {
  description = "Minimum number of nodes in the EKS cluster"
  type        = number
  default     = 1
}

variable "node_instance_types" {
  description = "Instance types for the EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}
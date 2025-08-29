# main.tf
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "mokhaled-bucket-1286"  # ← CHANGE ME
    key            = "terraform.tfstate"
    region         = "us-west-2"  # ← CHANGE ME
    dynamodb_table = "terraform-lock"         # ← Ensure this exists
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project}-${var.environment}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

# Get AZs dynamically
data "aws_availability_zones" "available" {
  state = "available"
}

# Public Subnets (using cidrsubnet)
resource "aws_subnet" "private-subnet" {
  count             = length(var.private-subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private-subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name                                      = "${var.project}-${var.environment}-private-subnet-${var.azs[count.index]}"
    "Kubernetes.io/role/internal-elb"       = "1"
    "Kubernetes.io/cluster/sprints-cluster" = "owned"
  }
}

resource "aws_subnet" "public-subnet" {
  count             = length(var.public-subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public-subnets[count.index]
  availability_zone = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                      = "${var.project}-${var.environment}-public-subnet-${var.azs[count.index]}"
    "Kubernetes.io/role/elb"                = "1"
   "Kubernetes.io/cluster/sprints-cluster" = "owned"
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "eip" {
  domain = "vpc"
  tags = {
    Name = "${var.project}-${var.environment}_nat_eip"
  }

}

# NAT Gateway
resource "aws_nat_gateway" "nat" {

  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public-subnet[0].id

  tags = {
    Name = "${var.project}-${var.environment}_nat"
  }

  depends_on = [aws_internet_gateway.igw]
}


# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-${var.environment}_igw"
  }
}

# Public Route Table
resource "aws_route_table" "sprints_rt_public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project}-${var.environment}_rt_public"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public_subnet_ta" {
  count          = length(var.public-subnets)
  subnet_id      = aws_subnet.public-subnet[count.index].id
  route_table_id = aws_route_table.sprints_rt_public.id
}


# Private Route Table
resource "aws_route_table" "sprints_rt_private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project}-${var.environment}_rt_private"
  }
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private_subnet_ta" {
  count          = length(var.private-subnets)
  subnet_id      = aws_subnet.private-subnet[count.index].id
  route_table_id = aws_route_table.sprints_rt_private.id
}


# Security Group for EKS Control Plane
resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for EKS control plane"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict in production
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

# Security Group for Node Group
resource "aws_security_group" "node" {
  name        = "${var.cluster_name}-node-sg"
  description = "Security group for EKS nodes"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-node-sg"
  }
}

# IAM Roles (unchanged)
# data "aws_iam_policy_document" "eks_cluster_assume_role_policy" {
#   statement {
#     effect = "Allow"
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["eks.amazonaws.com"]
#     }
#   }
# }

resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "service_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# Node IAM Role
resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "cni_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "registry_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name          = var.cluster_name
  version       = var.cluster_version
  role_arn      = aws_iam_role.eks_cluster_role.arn

  access_config {
    authentication_mode                           = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions   = true
  }

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = false
    endpoint_public_access  = true
  }

  

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy_attachment,
    aws_iam_role_policy_attachment.service_policy_attachment
  ]

  timeouts {
    create = "60m"
    delete = "15m"
  }
}

# EKS Node Group (placed in private subnets)
resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.private[*].id  # Nodes in private subnets

  scaling_config {
    desired_size = var.node_desired_capacity
    max_size     = var.node_max_capacity
    min_size     = var.node_min_capacity
  }
  
  update_config {
    max_unavailable = 1
  }

  instance_types = ["t3.small"]

  labels = {
    environment = "stage"
  }

  tags = {
    Name = "${var.cluster_name}-node-group"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policy_attachment,
    aws_iam_role_policy_attachment.cni_policy_attachment,
    aws_iam_role_policy_attachment.registry_policy_attachment
  ]
}
# terraform.tfvars
region                  = "us-west-2"
vpc_cidr                = "10.0.0.0/16"
public-subnets          = ["10.0.1.0/24", "10.0.2.0/24"]
private-subnets         = ["10.0.3.0/24", "10.0.4.0/24"]
azs                     = ["us-west-2a", "us-west-2b"]
cluster_name            = "stage-eks-cluster"
node_desired_capacity   = 2
node_min_capacity       = 1
node_max_capacity       = 3
public_key_path         = "id_rsa.pub"
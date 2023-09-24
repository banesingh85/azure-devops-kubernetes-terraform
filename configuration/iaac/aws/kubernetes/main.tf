# Define the Terraform backend configuration for storing state.
terraform {
  backend "s3" {
    bucket = "mybucket" # Specify the S3 bucket where Terraform state will be stored (will be overridden during build).
    key    = "path/to/my/key" # Specify the key or path within the S3 bucket for Terraform state (will be overridden during build).
    region = "us-east-1" # Set the AWS region for the S3 bucket.
  }
}

# Create an AWS default VPC resource.
resource "aws_default_vpc" "default" {
  # This resource represents the default Virtual Private Cloud (VPC) in your AWS account.
}

# Define a data source to fetch subnet IDs within the default VPC.
data "aws_subnet_ids" "subnets" {
  # vpc_id = aws_default_vpc.default.id
  # Uncomment and specify the VPC ID to fetch subnet IDs within a specific VPC.
}

# Configure the Kubernetes provider to interact with the EKS cluster.
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  version                = "~> 2.12" # Specify the desired Kubernetes provider version.
}

# Create an Amazon EKS cluster using the specified module.
module "eks_cluster" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "in28minutes-cluster"
  cluster_version = "1.14" # Specify the desired EKS cluster version.
  vpc_id          = aws_default_vpc.default.id
}

# Create a node group within the EKS cluster.
module "node_group" {
  source = "terraform-aws-modules/eks/aws//modules/node_groups"

  cluster_name = module.eks_cluster.cluster_name
  node_groups = {
    eks_nodes = {
      desired_capacity = 2
      max_capacity     = 2
      min_capacity     = 2
      instance_type    = "t2.micro"
    }
  }

  subnets = data.aws_subnet_ids.subnets.ids
}

# Fetch information about the EKS cluster.
data "aws_eks_cluster" "cluster" {
  name = module.in28minutes-cluster.cluster_id
}

# Fetch authentication details for the EKS cluster.
data "aws_eks_cluster_auth" "cluster" {
  name = module.in28minutes-cluster.cluster_id
}

# Create a Kubernetes cluster role binding for ServiceAccount permissions.
resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "fabric8-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
}

# Configure the AWS provider with the default AWS region.
provider "aws" {
  region  = "us-east-1"
}

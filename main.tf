# Archivo para contener los datos del provider
terraform {
  required_version = ">=0.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=3.37.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

data "aws_availability_zones" "available" {

}

resource "aws_security_group" "worker_group_one" {
  name        = "${local.project_id}-worker_group_one"
  description = "Allow all inbound traffic to ssh and http"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "ssh from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  tags = {
    Name = "${local.project_id}-sg-worker-one"
  }
}

resource "aws_security_group" "all_worker_group" {
  name        = "${local.project_id}-all_worker_group"
  description = "Allow all inbound traffic to ssh and http"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "ssh from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  tags = {
    Name = "${local.project_id}-sg-worker-all"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.9.0"

  name                 = "${local.project_id}-vpc"
  cidr = var.vpc_cidr
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "${local.project_id}-${var.cluster_name}" = "shared"
    "${local.project_id}-role-elb"              = "1"
  }

  private_subnet_tags = {
    "${local.project_id}-${var.cluster_name}" = "shared"
    "${local.project_id}-internal-elb"          = "1"
  }
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_version = "17.22.0"
  cluster_name    = "${local.project_id}-${var.cluster_name}"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.private_subnets

  cluster_create_timeout          = "1h"
  cluster_endpoint_private_access = true

  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = var.instance_type
      additional_userdata           = "echo foo bar"
      asg_derired_capacity          = 1
      additional_security_group_ids = [aws_security_group.worker_group_one.id]
    },
  ]

  worker_additional_security_group_ids = [aws_security_group.all_worker_group.id]
  map_roles                            = var.map_roles
  map_users                            = var.map_users
  map_accounts                         = var.map_accounts
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)

  token            = data.aws_eks_cluster_auth.cluster.token
}


resource "kubernetes_deployment" "eks_deploy" {
  metadata {
    name = "${local.project_id}-kubernetes-deploy"
    labels = {
      test = "MyKubernetesApp"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        test = "MyKubernetesApp"
      }
    }

    template {
      metadata {
        labels = {
          test = "MyKubernetesApp"
        }
      }

      spec {
        container {
          image = "nginx:1.7.8"
          name  = "nginx-container"

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/nginx_status"
              port = 80

              http_header {
                name  = "X-Custom-Header"
                value = "Awesome"
              }
            }

            initial_delay_seconds = 3
            period_seconds        = 3
          }

        }
      }
    }
  }
}

resource "kubernetes_service" "kubernetes_service" {
  metadata {
    name = "${local.project_id}-${var.cluster_name}-service"
  }
  spec {
    selector = {
      test = "MyKubernetesApp"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}

# Archivo para contener las variables del proyecto
variable "project_name" {
  description = "Name of Project"
  type        = string
  default     = "gft-lsms-nlp"
}

variable "environment" {
  description = "Project environment"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "Selected Region"
  type        = string
  default     = "us-west-1"
}


variable "azs" {
  description = "Availability zones for VPC"
  type        = list(string)
  default     = ["us-west-1a", "us-west-1b", "us-west-1c"]
}

variable "instance_type" {
  description = "Type of intances"
  type        = string
  default     = "t2.micro"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  description = "Kubernetes Cluster Name"
  type        = string
  default     = "eks-cluster"
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))

  default = [
    {
      rolearn  = "arn:aws:iam:66666666:role/role1"
      username = "role1"
      groups   = ["system:masters"]
    },
  ]
}

variable "map_accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap."
  type        = list(string)
  default = [
    "777777777777",
    "888888888888",
  ]
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))

  default = [
    {
      userarn  = "arn:aws:iam::66666666666:user/user1"
      username = "user1"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::66666666666:user/user2"
      username = "user2"
      groups   = ["system:masters"]
    },
  ]
}

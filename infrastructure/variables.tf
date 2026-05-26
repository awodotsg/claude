variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "ID of the VPC shared with the Workspaces instance"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the EC2 instance (must have internet access for dnf/k3s install)"
  type        = string
}

variable "workspaces_cidr" {
  description = "CIDR block of the Workspaces subnet — granted SSH (22) and NodePort (30080) access"
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the k3s node"
  type        = string
  default     = "t3.medium"
}

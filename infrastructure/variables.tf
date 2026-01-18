variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "psut-graduation-project"
}

variable "instance_type" {
  default = "t3.large" # Recommended for MicroK8s + Docker
}

variable "key_name" {
  description = "The name of your existing AWS SSH key pair"
}
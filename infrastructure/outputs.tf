output "ec2_public_ip" {
  value = aws_instance.dev_prod_server.public_ip
}

output "ecr_repository_url" {
  value = aws_ecr_repository.app_repo.repository_url
}
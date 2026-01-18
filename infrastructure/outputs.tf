output "ec2_public_ip" {
  value = aws_instance.dev_prod_server.public_ip
}

output "ecr_public_uri" {
  value = aws_ecrpublic_repository.app_repo.repository_uri
}

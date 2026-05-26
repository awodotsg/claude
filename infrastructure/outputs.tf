output "ec2_private_ip" {
  description = "Private IP of the cityapp EC2 instance"
  value       = aws_instance.cityapp.private_ip
}

output "ecr_repository_uri" {
  description = "Full ECR repository URI — use as the image reference in k8s/04-app-deployment.yaml"
  value       = aws_ecr_repository.claude_city.repository_url
}

output "ssh_command" {
  description = "Ready-to-run SSH command from Workspaces"
  value       = "ssh -i $HOME\\.ssh\\${var.key_name}.pem ec2-user@${aws_instance.cityapp.private_ip}"
}

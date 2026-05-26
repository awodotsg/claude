resource "aws_ecr_repository" "claude_city" {
  name                 = "claude_city"
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # allows `terraform destroy` to remove images

  image_scanning_configuration {
    scan_on_push = true
  }
}

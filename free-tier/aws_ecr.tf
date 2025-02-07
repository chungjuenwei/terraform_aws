resource "aws_ecr_repository" "demo_repo" {
  name = "demo-repo"  # Name of the ECR repository

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.demo_repo.repository_url
}
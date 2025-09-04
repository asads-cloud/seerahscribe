resource "aws_ecr_repository" "whisper_faster" {
  name                 = "whisper-faster"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration { scan_on_push = true }

  encryption_configuration { encryption_type = "AES256" }

  # keep the repo even if not empty (safest); set true if you prefer terraform destroy to nuke
  force_delete = false
}

# Keep last 10 tagged images; expire untagged after 7 days
resource "aws_ecr_lifecycle_policy" "whisper_faster" {
  repository = aws_ecr_repository.whisper_faster.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "expire untagged after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "keep last 10 images (any tag)"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}

output "ecr_repository_url" {
  value = aws_ecr_repository.whisper_faster.repository_url
}

output "ecr_repository_arn" {
  value = aws_ecr_repository.whisper_faster.arn
}

resource "aws_iam_role" "cityapp_ec2" {
  name = "cityapp-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_readonly" {
  role       = aws_iam_role.cityapp_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Scoped to cityapp/* secrets only — GetSecretValue is all the Secrets Hub provider needs
resource "aws_iam_role_policy" "secrets_hub_read" {
  name = "cityapp-secrets-hub-read"
  role = aws_iam_role.cityapp_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = "arn:aws:secretsmanager:${var.region}:*:secret:cityapp/*"
    }]
  })
}

resource "aws_iam_instance_profile" "cityapp" {
  name = "cityapp-ec2-profile"
  role = aws_iam_role.cityapp_ec2.name
}

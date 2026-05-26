resource "aws_security_group" "cityapp" {
  name        = "cityapp-sg"
  description = "CityApp demo — SSH and NodePort from Workspaces"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from Workspaces"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.workspaces_cidr]
  }

  ingress {
    description = "k3s NodePort — cityapp"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = [var.workspaces_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "cityapp" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.cityapp.id]
  iam_instance_profile   = aws_iam_instance_profile.cityapp.name

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    dnf install -y docker unzip
    systemctl enable --now docker
    usermod -aG docker ec2-user

    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.30.2+k3s1" sh -

    # Give ec2-user kubectl access without sudo
    mkdir -p /home/ec2-user/.kube
    cp /etc/rancher/k3s/k3s.yaml /home/ec2-user/.kube/config
    chown ec2-user:ec2-user /home/ec2-user/.kube/config
    chmod 600 /home/ec2-user/.kube/config
  EOF

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "cityapp-demo"
  }
}

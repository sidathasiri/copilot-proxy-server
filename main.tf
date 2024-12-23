# Create an ECR repository
resource "aws_ecr_repository" "copilot_proxy_repo" {
  name = var.ecr_repo_name
}

# Use an existing security group or create a new one
resource "aws_security_group" "allow_http" {
  vpc_id = var.vpc_id

  name          = "copilot-proxy-http-sg"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an IAM role for EC2 instances
resource "aws_iam_role" "ec2_instance_role" {
  name = "copilot-proxy-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Create IAM policy to allow access to ECR and SQS
resource "aws_iam_policy" "ec2_ecr_sqs_policy" {
  name = "ec2-ecr-sqs-policy"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the EC2 role
resource "aws_iam_role_policy_attachment" "attach_ecr_sqs_policy" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.ec2_ecr_sqs_policy.arn
}

# Create an instance profile for the EC2 IAM role
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "copilot-proxy-ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name
}

# Define the user data script in a local variable
locals {
  copilot_proxy_user_data = <<-EOF
    #!/bin/bash
    # Update the instance
    yum update -y

    # Install Docker
    yum install -y docker

    # Start Docker service
    service docker start

    # Add the EC2 user to the docker group so you can execute Docker commands without using sudo
    usermod -a -G docker ec2-user

    # Enable Docker to start on boot
    chkconfig docker on

    # Install AWS CLI (if not already installed)
    yum install -y aws-cli

    # Log in to ECR (replace the region if necessary)
    aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 039612847997.dkr.ecr.eu-central-1.amazonaws.com

    # Run the Docker container
    docker run -d -p 80:8080 --restart=always -e AWS_DEFAULT_REGION=eu-central-1 039612847997.dkr.ecr.eu-central-1.amazonaws.com/copilot-proxy:latest
  EOF
}

# Launch template for EC2 instances with your user data script
resource "aws_launch_template" "copilot_proxy" {
  name_prefix   = "copilot-proxy"
  image_id      = var.ami_id
  instance_type = "t3.small" 

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  vpc_security_group_ids = [aws_security_group.allow_http.id]

  user_data = base64encode(local.copilot_proxy_user_data)
}

# CloudWatch Alarm for scaling up when CPU utilization > 60%
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "copilot_proxy_server_cpu_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 60
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.copilot_proxy_asg.name
  }
}

# CloudWatch Alarm for scaling down when CPU utilization < 15%
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "copilot_proxy_server_cpu_low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 15
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.copilot_proxy_asg.name
  }
}

# Auto Scaling group
resource "aws_autoscaling_group" "copilot_proxy_asg" {
  launch_template {
    id      = aws_launch_template.copilot_proxy.id
    version = "$Latest"
  }

  name                = "copilot-proxy-asg"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.min_count
  max_size            = var.max_count
  desired_capacity    = var.desired_count

  target_group_arns = [aws_lb_target_group.tcp.arn]
}

# Application Load Balancer for the Auto Scaling group
resource "aws_lb" "copilot_proxy_lb" {
  name               = "copilot-proxy-lb" 
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.allow_http.id]
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "tcp" {
  name        = "copilot-proxy-targets" 
  port        = 80
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"
}

resource "aws_lb_listener" "tcp" {
  load_balancer_arn = aws_lb.copilot_proxy_lb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tcp.arn
  }
}

# Auto scaling policy based on CPU utilization
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale_up"
  scaling_adjustment      = 1
  adjustment_type         = "ChangeInCapacity"
  cooldown                = 300
  autoscaling_group_name  = aws_autoscaling_group.copilot_proxy_asg.name
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale_down"
  scaling_adjustment      = -1
  adjustment_type         = "ChangeInCapacity"
  cooldown                = 300
  autoscaling_group_name  = aws_autoscaling_group.copilot_proxy_asg.name
}


# # SQS Queue for sending events
resource "aws_sqs_queue" "queue" {
  name = "copilot-proxy-queue"
}

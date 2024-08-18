# Create an ECR repository
resource "aws_ecr_repository" "copilot_proxy_repo" {
  name = var.ecr_repo_name
}

# IAM role for ECS task execution
resource "aws_iam_role" "copilot_proxy_ecs_task_execution_role" {
  name = "copilot_proxy_ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "copilot_proxy_ecs_task_execution_role_policy" {
  role       = aws_iam_role.copilot_proxy_ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Add a custom policy for CloudWatch Logs permissions
resource "aws_iam_policy" "copilot_proxy_cloudwatch_logs_policy" {
  name = "copilot_proxy_cloudwatch_logs_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "copilot_proxy_cloudwatch_logs_policy_attachment" {
  role       = aws_iam_role.copilot_proxy_ecs_task_execution_role.name
  policy_arn = aws_iam_policy.copilot_proxy_cloudwatch_logs_policy.arn
}

# IAM policy for SQS access
resource "aws_iam_policy" "copilot_proxy_sqs_policy" {
  name = "copilot_proxy_sqs_policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = "sqs:SendMessage",
      Resource = aws_sqs_queue.copilot_events_queue.arn
    }]
  })
}

# Attach the SQS policy to the ECS task execution role
resource "aws_iam_role_policy_attachment" "copilot_proxy_sqs_policy_attachment" {
  role       = aws_iam_role.copilot_proxy_ecs_task_execution_role.name
  policy_arn = aws_iam_policy.copilot_proxy_sqs_policy.arn
}

# Create an ECS cluster
resource "aws_ecs_cluster" "copilot_proxy_cluster" {
  name = var.ecs_cluster_name
}

# Define the ECS task definition
resource "aws_ecs_task_definition" "copilot_proxy_task" {
  family                   = "copilot_proxy_task"
  cpu                      = "1024"
  memory                   = "2048"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.copilot_proxy_ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.copilot_proxy_ecs_task_execution_role.arn
  container_definitions = jsonencode([{
    name  = "copilot_proxy_container"
    image = "${aws_ecr_repository.copilot_proxy_repo.repository_url}:latest"
    essential = true
    portMappings = [{
      name            = "8080"
      containerPort   = 8080
      hostPort        = 8080
      protocol        = "tcp"
      appProtocol     = "http"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group          = "/ecs/copilot-proxy-server"
        awslogs-region         = "us-east-1"
        awslogs-create-group   = "true"
        awslogs-stream-prefix  = "ecs"
        max-buffer-size        = "25m"
        mode                   = "non-blocking"
      }
    }
    environment = [
      {
        name  = "SQS_QUEUE_URL"
        value = aws_sqs_queue.copilot_events_queue.url
      }
    ]
  }])
}

# Create a Security Group
resource "aws_security_group" "copilot_proxy_sg" {
  name   = "copilot-proxy-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

# Create an ECS Service
resource "aws_ecs_service" "copilot_proxy_service" {
  name            = "copilot-proxy-service"
  cluster         = aws_ecs_cluster.copilot_proxy_cluster.id
  task_definition = aws_ecs_task_definition.copilot_proxy_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.copilot_proxy_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.copilot_proxy_target_group.arn
    container_name   = "copilot_proxy_container"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.front_end]
}

# Create a NLB
resource "aws_lb" "copilot_proxy_nlb" {
  name               = "copilot-proxy-nlb"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.copilot_proxy_sg.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = false
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "copilot-proxy-nlb"
  }
}


# Create a Listener for the ALB
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.copilot_proxy_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.copilot_proxy_target_group.arn
  }
}


# Create a Target Group for the ALB
resource "aws_lb_target_group" "copilot_proxy_target_group" {
  name     = "copilot-proxy-tg"
  port     = 8080
  protocol = "TCP"
  vpc_id   = var.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

## ECS service auto-scaling
resource "aws_appautoscaling_target" "copilot_proxy_scaling_target" {
  max_capacity       = 7
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.copilot_proxy_cluster.id}/${aws_ecs_service.copilot_proxy_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "copilot_proxy_scaling_policy_up" {
  name               = "copilot-proxy-scale-up"
  scalable_dimension = aws_appautoscaling_target.copilot_proxy_scaling_target.scalable_dimension
  resource_id        = aws_appautoscaling_target.copilot_proxy_scaling_target.resource_id
  service_namespace  = aws_appautoscaling_target.copilot_proxy_scaling_target.service_namespace
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60

    step_adjustment {
      scaling_adjustment = 1
      metric_interval_lower_bound = 0
    }
  }
}

resource "aws_appautoscaling_policy" "copilot_proxy_scaling_policy_down" {
  name               = "copilot-proxy-scale-down"
  scalable_dimension = aws_appautoscaling_target.copilot_proxy_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.copilot_proxy_scaling_target.service_namespace
  resource_id        = aws_appautoscaling_target.copilot_proxy_scaling_target.resource_id
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60

    step_adjustment {
      scaling_adjustment = -1
      metric_interval_upper_bound = 0
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "copilot_proxy_high_cpu" {
  alarm_name                = "copilot-proxy-high-cpu"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ECS"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = "75"
  alarm_actions             = [aws_appautoscaling_policy.copilot_proxy_scaling_policy_up.arn]
  dimensions = {
    ClusterName = aws_ecs_cluster.copilot_proxy_cluster.id
    ServiceName = aws_ecs_service.copilot_proxy_service.name
  }
}

resource "aws_cloudwatch_metric_alarm" "copilot_proxy_low_cpu" {
  alarm_name                = "copilot-proxy-low-cpu"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/ECS"
  period                    = "60"
  statistic                 = "Average"
  threshold                 = "20"
  alarm_actions             = [aws_appautoscaling_policy.copilot_proxy_scaling_policy_down.arn]
  dimensions = {
    ClusterName = aws_ecs_cluster.copilot_proxy_cluster.id
    ServiceName = aws_ecs_service.copilot_proxy_service.name
  }
}

# Create an SQS queue
resource "aws_sqs_queue" "copilot_events_queue" {
  name = "copilot-events"
}
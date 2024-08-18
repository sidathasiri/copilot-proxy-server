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
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.copilot_proxy_ecs_task_execution_role.arn
  container_definitions = jsonencode([{
    name  = "copilot_proxy_container"
    image = "${aws_ecr_repository.copilot_proxy_repo.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
    environment = [
      {
        name  = "SQS_QUEUE_URL"
        value = aws_sqs_queue.copilot_events_queue.url
      },
      {
        name  = "AWS_REGION"
        value = "us-west-2"
      }
    ]
  }])
}

# Create an SQS queue
resource "aws_sqs_queue" "copilot_events_queue" {
  name = "copilot-events"
}
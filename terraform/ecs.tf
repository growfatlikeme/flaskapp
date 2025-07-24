# Get current AWS account ID and region
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_ecs_cluster" "main" {
  name = "growfat-flask-ecs"
}

# Create CloudWatch log group for ECS task
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/growfat-task"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "growfat_task" {
  family                   = "growfat-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "growfat-flask-container"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com/growfat-flask-private-repository:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "SERVICE_NAME"
          value = "growfat-flask-service"
        }
      ]
      secrets = [
        {
          name      = "MY_APP_CONFIG"
          valueFrom = "arn:aws:ssm:ap-southeast-1:${data.aws_caller_identity.current.account_id}:parameter/growfat/config"
        },
        {
          name      = "MY_DB_PASSWORD"
          valueFrom = "arn:aws:secretsmanager:ap-southeast-1:${data.aws_caller_identity.current.account_id}:secret:growfat/db_password"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/growfat-task"
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = "flask-app"
        }
      }
    },
    {
      name      = "xray-sidecar"
      image     = "amazon/aws-xray-daemon:latest"
      essential = false
      portMappings = [
        {
          containerPort = 2000
          protocol      = "udp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/growfat-task"
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = "xray-sidecar"
        }
      }
    }
  ])
  depends_on = [aws_vpc.my_vpc, aws_subnet.public_subnets]
}

resource "aws_ecs_service" "growfat_service" {
  name            = "growfat-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.growfat_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = values(aws_subnet.public_subnets)[*].id
    security_groups  = [aws_security_group.growfat_sg.id]
    assign_public_ip = true
  }
}

# ECS Task Role for X-Ray
resource "aws_iam_role" "ecs_task_role" {
  name = "growfat-ecs-xray-taskrole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_xray" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_execution_role" {
  name = "growfat-ecs-xray-taskexecutionrole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_ssm" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_policy" "secrets_policy" {
  name = "growfat-secrets-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:ap-southeast-1:${data.aws_caller_identity.current.account_id}:secret:growfat/db_password*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_secrets" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.secrets_policy.arn
}

resource "aws_security_group" "growfat_sg" {
  name        = "growfat-flask-sg"
  description = "Allow inbound traffic on port 8080"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
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


# Output the ECS cluster name
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

# Output the ECS service name
output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.growfat_service.name
}

# Get current AWS account ID and region
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_ecr_repository" "ecr" {
  name         = "growfat-flask-private-repository"
  force_delete = true
}

resource "aws_ecs_cluster" "main" {
  name = "growfat-flask-ecs"
}

resource "aws_ecs_task_definition" "growfat_task" {
  family                   = "growfat-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

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

resource "aws_iam_role" "ecs_execution_role" {
  name = "${local.name_prefix}-ecs-execution-role"

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

# Output the public IP of the ECS task
data "aws_network_interface" "ecs_eni" {
  filter {
    name   = "subnet-id"
    values = values(aws_subnet.public_subnets)[*].id
  }
  
  filter {
    name   = "group-id"
    values = [aws_security_group.growfat_sg.id]
  }
  
  depends_on = [aws_ecs_service.growfat_service]
}

output "flask_app_url" {
  description = "URL to access the Flask application"
  value       = "http://${data.aws_network_interface.ecs_eni.association[0].public_ip}:8080"
}

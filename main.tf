provider "aws" {
  region = "us-east-1"  # Modify this to your desired region
}

# Create a VPC
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "example-vpc"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "example-igw"
  }
}

# Create a public subnet
resource "aws_subnet" "example" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"  # Modify if needed
  map_public_ip_on_launch = true

  tags = {
    Name = "example-public-subnet"
  }
}

# Create a private subnet (optional, in case you want to use private subnets)
resource "aws_subnet" "example_private" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"  # Modify if needed
  map_public_ip_on_launch = false

  tags = {
    Name = "example-private-subnet"
  }
}

# Create a security group
resource "aws_security_group" "example" {
  name        = "example-security-group"
  vpc_id      = aws_vpc.example.id
  description = "Allow all inbound and outbound traffic"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "example-sg"
  }
}

# Create an ECS cluster
resource "aws_ecs_cluster" "example" {
  name = "example-cluster"
}

# Create an ECR repository for the Docker image
resource "aws_ecr_repository" "example" {
  name = "example-repo"
}

# Create an IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

# Attach the necessary policy for ECS task execution (to pull images from ECR)
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECSTaskExecutionRolePolicy"
}

# Create the ECS task definition
resource "aws_ecs_task_definition" "example" {
  family                   = "example-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "example-container"
    image     = "${aws_ecr_repository.example.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
  }])
}

# Create ECS service to run the task definition
resource "aws_ecs_service" "example" {
  name            = "example-service"
  cluster         = aws_ecs_cluster.example.id
  task_definition = aws_ecs_task_definition.example.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.example.id]  # Use the public subnet
    security_groups = [aws_security_group.example.id]
    assign_public_ip = true
  }
}

# Output the ECS service URL
output "ecs_service_url" {
  value = aws_ecs_service.example.id
}

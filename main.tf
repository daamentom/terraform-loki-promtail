provider "aws" {
  region = "eu-central-1"
}

# ---------------
# VPC
# ---------------
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name           = "dev"
  cidr           = "10.0.0.0/16"
  azs            = ["eu-central-1a"]
  public_subnets = ["10.0.101.0/24"]


  tags = {
    Terraform  = "true"
    Enviroment = "dev"
  }
}

# ---------------
# EFS
# ---------------
resource "aws_efs_file_system" "efs_volume" {
  performance_mode = "generalPurpose"

  creation_token = "grafana-efs-volume"
}

resource "aws_security_group" "efs_security_group" {
  name        = "efs"
  description = "efs"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port        = 2049
    to_port          = 2049
    protocol         = "nfs"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 2049
    to_port          = 2049
    protocol         = "nfs"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "efs"
  }
}

resource "aws_efs_mount_target" "ecs_temp_space_az0" {
  file_system_id  = aws_efs_file_system.efs_volume.id
  subnet_id       = element(module.vpc.public_subnets, 0)
  security_groups = [aws_security_group.efs_security_group.id, aws_security_group.grafana.id]
}


# ---------------
# ECS - task role and policy
# ---------------
resource "aws_iam_role" "task_role" {
  name = "task_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "policy" {
  name = "ecs-task-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Effect   = "Allow",
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.policy.arn
}

# ---------------
# ECS - cluster, security group and task definition
# ---------------
resource "aws_ecs_cluster" "grafana" {
  name = "grafana"
}

resource "aws_security_group" "grafana" {
  name        = "grafana"
  description = "Grafana"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # you should change this. really.
  }

  ingress {
    description = "Loki"
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # you should change this. really.
  }

  ingress {
    description = "promtail"
    from_port = 3200
    to_port = 3200
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # you should change this. really.
  }

  ingress {
    description = "nodelogger"
    from_port = 8888
    to_port = 8888
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # you should change this. really.
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "grafana"
  }
}


############
# tasks
############

resource "aws_ecs_task_definition" "grafana" {
  family                   = "grafana"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = aws_iam_role.task_role.arn
  execution_role_arn       = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name      = "grafana",
      image     = "grafana/grafana:latest",
      essential = true,
      portMappings = [
        {
          containerPort = 3000,
          hostPort      = 3000
        }
      ],
      mountPoints = [
        {
          sourceVolume  = "efs_volume",
          containerPath = "/grafana",
        }
      ]
    },
    {
      name      = "loki",
      image     = "grafana/loki:latest",
      essential = true,
      portMappings = [
        {
          containerPort = 3100,
          hostPort      = 3100
        }
      ],
      mountPoints = [
        {
          sourceVolume  = "efs_volume",
          containerPath = "/loki",
        }
      ]
    },
    {
      name      = "promtail",
      image     = "custom/promtail:latest",
      essential = true,
      portMappings = [
        {
          containerPort = 3200,
          hostPort = 3200
        }
      ],
      mountPoints = [
        {
          sourceVolume  = "efs_volume",
          containerPath = "/promtail",
        }
      ]
    },
    {
      name      = "nodelogger",
      image     = "custom/nodelogger:latest",
      essential = true,
      portMappings =[
        {
          containerPort = 8888,
          hostPort = 8888
        }
      ],
      mountPoints = [
        {
          sourceVolume  = "efs_volume",
          containerPath = "/nodelogger",
        }
      ]
    },
  ])

  volume {
    name = "efs_volume"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.efs_volume.id
      root_directory = "/"
    }
  }
}



############
# ecs services
############

resource "aws_ecs_service" "grafana" {
  name                   = "grafana"
  cluster                = aws_ecs_cluster.grafana.id
  task_definition        = aws_ecs_task_definition.grafana.arn
  desired_count          = 1
  enable_execute_command = true
  network_configuration {
    subnets          = module.vpc.public_subnets
    security_groups  = [aws_security_group.grafana.id]
    assign_public_ip = true
  }
  launch_type = "FARGATE"
}

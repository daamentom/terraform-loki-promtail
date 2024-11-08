# provider "aws" {
#   region                   = "eu-central-1"
#   access_key               = "test"
#   secret_key               = "test"
#   skip_credentials_validation = true
#   skip_requesting_account_id  = true
#   endpoints {
#     ecs = "http://localhost:4566"
#     ec2 = "http://localhost:4566"  # Added EC2 endpoint for LocalStack
#     s3 = "http://localhost:4566"
#   }
# }

# ##########################
# # ECS Cluster 
# ##########################

# resource "aws_ecs_cluster" "main" {
#   name = "local-ecs-cluster"
# }
# #########################################
# # EC2 Instance for ECS Tasks 
# #########################################

# # Define an EC2 instance to serve as the infrastructure for the ECS tasks
# resource "aws_instance" "ecs_instance" {
#   ami                    = "ami-024f768332f0"  # Replace with an appropriate LocalStack-compatible AMI ID
#   instance_type          = "t2.micro"
#   associate_public_ip_address = true

#   # Add user data to install ECS agent on the instance
#   user_data = <<-EOF
#               #!/bin/bash
#               echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
#               EOF

#   tags = {
#     Name = "ecs-instance"
#   }
# }

# ###############################
# # TASK DEFINITIONS
# ###############################

# resource "aws_ecs_task_definition" "grafana_task" {
#   family                   = "grafana"
#   network_mode             = "bridge"
#   requires_compatibilities = ["EC2"]
#   cpu                      = "256"
#   memory                   = "512"
#   container_definitions = jsonencode([
#     {
#       name      = "grafana"
#       image     = "grafana/grafana:latest"
#       essential = true
#       memory    = 256
#       portMappings = [
#         {
#           containerPort = 3000
#           hostPort      = 3000
#         }
#       ]
#     }
#   ])
# }

# resource "aws_ecs_task_definition" "loki_task" {
#   family                   = "loki"
#   network_mode             = "bridge"
#   requires_compatibilities = ["EC2"]
#   cpu                      = "256"
#   memory                   = "512"
#   container_definitions = jsonencode([
#     {
#       name      = "loki"
#       image     = "grafana/loki:latest"
#       essential = true
#       memory    = 256
#       portMappings = [
#         {
#           containerPort = 3100
#           hostPort      = 3100
#         }
#       ]
#     }
#   ])
# }

# resource "aws_ecs_task_definition" "promtail_task" {
#   family                   = "promtail"
#   network_mode             = "bridge"
#   requires_compatibilities = ["EC2"]
#   cpu                      = "256"
#   memory                   = "512"
#   container_definitions = jsonencode([
#     {
#       name      = "promtail"
#       image     = "custom/promtail:latest"
#       essential = true
#       memory    = 256
#       portMappings = [
#         {
#           containerPort = 3200
#           hostPort      = 3200
#         }
#       ]
#     }
#   ])
# }

# resource "aws_ecs_task_definition" "node_task" {
#   family                   = "node_app"
#   network_mode             = "bridge"
#   requires_compatibilities = ["EC2"]
#   cpu                      = "256"
#   memory                   = "512"
#   container_definitions = jsonencode([
#     {
#       name      = "node_app"
#       image     = "test" 
#       essential = true
#       memory    = 256
#       environment = [
#         {
#           name  = "LOG_LEVEL"
#           value = "info"
#         }
#       ]
#     }
#   ])
# }
# ##################################
# # SERVICE DEFINITIONS 
# ##################################

# resource "aws_ecs_service" "grafana_service" {
#   name            = "grafana-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.grafana_task.arn
#   desired_count   = 1
#   launch_type     = "EC2"
# }

# resource "aws_ecs_service" "loki_service" {
#   name            = "loki-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.loki_task.arn
#   desired_count   = 1
#   launch_type     = "EC2"
# }

# resource "aws_ecs_service" "promtail_service" {
#   name            = "promtail-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.promtail_task.arn
#   desired_count   = 1
#   launch_type     = "EC2"
# }

# resource "aws_ecs_service" "node_service" {
#   name            = "node-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.node_task.arn
#   desired_count   = 1
#   launch_type     = "EC2"
# }
# ########################
# # S3 Bucket 
# ########################

# resource "aws_s3_bucket" "log_bucket" {
#   bucket = "ecs-logs-bucket"

#   # Enable versioning (optional for tracking changes to objects)
#   versioning {
#     enabled = true
#   }

#   # Enable server-side encryption (optional)
#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256"
#       }
#     }
#   }

#   # Tags (optional)
#   tags = {
#     Name = "ECS Logs Bucket"
#     Environment = "local"
#   }
# }
# ##############################################
# # IAM Role and Policy for Logging 
# ##############################################

# # IAM policy for S3 bucket write access
# resource "aws_iam_policy" "s3_write_policy" {
#   name        = "S3WritePolicy"
#   description = "Allows ECS tasks to write logs to S3 bucket"
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "s3:PutObject",
#           "s3:PutObjectAcl"
#         ],
#         Resource = "${aws_s3_bucket.log_bucket.arn}/*"
#       }
#     ]
#   })
# }

# # IAM role for ECS task execution
# resource "aws_iam_role" "ecs_task_execution_role" {
#   name = "ecsTaskExecutionRole"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = {
#           Service = "ecs-tasks.amazonaws.com"
#         },
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })

#   # Attach S3 write policy to the role
#   inline_policy {
#     name   = "s3-write-access"
#     policy = aws_iam_policy.s3_write_policy.policy
#   }
# }



###

# resource "aws_ecs_task_definition" "nodelogger" {
#   family                   = "nodelogger"
#   requires_compatibilities = ["FARGATE"]
#   network_mode             = "awsvpc"
#   cpu                      = "256"
#   memory                   = "512"
#   execution_role_arn       = aws_iam_role.task_role.arn
#   task_role_arn            = aws_iam_role.task_role.arn

#   container_definitions = jsonencode([
#     {
#       name      = "nodelogger",
#       image     = "custom/nodelogger:latest", 
#       essential = true,
#       portMappings = [
#         {
#           containerPort = 3333,  
#           hostPort      = 3333
#         }
#       ],
#       mountPoints = [
#         {
#           sourceVolume  = "efs_volume",
#           containerPath = "/nodelogs",
#         }
#       ]
#     }
#   ])
#   volume {
#     name = "efs_volume"
#     efs_volume_configuration {
#       file_system_id = aws_efs_file_system.efs_volume.id
#       root_directory = "/nodelogs"  # Directory within EFS for Node logs
#     }
#   }
# }


# resource "aws_ecs_service" "nodelogger" {
#   name                   = "nodelogger"
#   cluster                = aws_ecs_cluster.grafana.id  # Link to your existing ECS cluster
#   task_definition        = aws_ecs_task_definition.nodelogger.arn
#   desired_count          = 1
#   enable_execute_command = true
#   network_configuration {
#     subnets          = module.vpc.public_subnets
#     security_groups  = [aws_security_group.grafana.id]  # Use the relevant security group
#     assign_public_ip = true
#   }
#   launch_type = "FARGATE"
# }
  # ingress {
  #   description = "nodelogger"
  #   from_port = 3333
  #   to_port = 3333
  #   protocol = "tcp"
  # }
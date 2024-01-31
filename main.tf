# Creating resources: ECS cluster, SG, EFS, Load Balancer  

provider "aws" {    # Change to your credentials. 
  access_key = "<>"
  secret_key = "<>"
  region     = "<>" # Change to your desired AWS region
}

# ECS cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-fargate-cluster"
}

resource "aws_security_group" "prisma_cloud_security_group" {
  name        = "pc-security-group"
  description = "Prisma Cloud Compute Console on Fargate"
  vpc_id      = "<VPC_ID>" # Replace with your VPC ID

  ingress {
    from_port   = 8083
    to_port     = 8084
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_efs_file_system" "prisma_cloud_efs" {
  throughput_mode                  = "provisioned"
  provisioned_throughput_in_mibps  = 1.0  # Minimum value is 1.0

  tags = {
    Name = "pc-efs-console"
  }
}

# Replace with the IDs of your VPC and security group
resource "aws_efs_mount_target" "prisma_cloud_mount_target_1" {
  file_system_id  = aws_efs_file_system.prisma_cloud_efs.id
  subnet_id       = "<SUBNET_ID>"
  security_groups = [aws_security_group.prisma_cloud_security_group.id]
}

resource "aws_efs_mount_target" "prisma_cloud_mount_target_2" {
  file_system_id  = aws_efs_file_system.prisma_cloud_efs.id
  subnet_id       = "<SUBNET_2_ID>"
  security_groups = [aws_security_group.prisma_cloud_security_group.id]
}

resource "aws_efs_mount_target" "prisma_cloud_mount_target_3" {
  file_system_id  = aws_efs_file_system.prisma_cloud_efs.id
  subnet_id       = "<SUBNET_3_ID>"
  security_groups = [aws_security_group.prisma_cloud_security_group.id]
}

resource "aws_lb_target_group" "pc_tgt_8083" {
  name        = "pc-tgt-8083"
  port        = 8083
  protocol    = "TCP"
  vpc_id      = "<VPC_ID>" # Replace with your VPC ID
  target_type = "ip"

  health_check {
    protocol           = "HTTPS"
    path               = "/"
    port               = "traffic-port"
    healthy_threshold  = 3
    unhealthy_threshold = 3
    interval           = 30
    timeout            = 6
  }
}

resource "aws_lb_target_group" "pc_tgt_8084" {
  name        = "pc-tgt-8084"
  port        = 8084
  protocol    = "TCP"
  vpc_id      = "<VPC_ID>"  # Replace with your VPC ID
  target_type = "ip"

  health_check {
    protocol           = "HTTPS"
    path               = "/"
    port               = "traffic-port"
    healthy_threshold  = 3
    unhealthy_threshold = 3
    interval           = 30
    timeout            = 6
  }
}

# Network Load Balancer
resource "aws_lb" "pc_ecs_nlb" {
  name               = "pc-ecs-lb"
  internal           = false
  load_balancer_type = "network"
  enable_deletion_protection = false

  subnet_mapping {
    subnet_id = "<SUBNET_ID>"  # Replace with your subnet ID
  }

  subnet_mapping {
    subnet_id = "<SUBNET_2_ID>"  # Replace with your subnet ID
  }

  subnet_mapping {
    subnet_id = "<SUBNET_3_ID>"  # Replace with your subnet ID
  }

  enable_cross_zone_load_balancing = true
}

# Network Load Balancer Listeners
resource "aws_lb_listener" "listener_8083" {
  load_balancer_arn = aws_lb.pc_ecs_nlb.arn
  port              = 8083
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pc_tgt_8083.arn 
  }
}

resource "aws_lb_listener" "listener_8084" {
  load_balancer_arn = aws_lb.pc_ecs_nlb.arn
  port              = 8084
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pc_tgt_8084.arn
  }
}

# Creating Task Definition and Service
 
/* Please uncomment this part when the initial setup was completed.

# ECS Task Definition
resource "aws_ecs_task_definition" "pc_task_definition" {
  family                   = "pc-console"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = "2048"
  memory = "8192"

  execution_role_arn = "arn:aws:iam::***:role/ecsTaskExecutionRole" # Change to your TaskExecutionRole arn.

  volume {
    name = "compute_root_volume"

    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.prisma_cloud_efs.id
      transit_encryption      = "ENABLED"
      root_directory          = "/"
    }
  }
  
  # Please generate the Task Definition json file using the following documentation and change the values.  (https://docs.prismacloud.io/en/compute-edition/30/admin-guide/install/deploy-console/console-on-fargate#create-task-definition)

  container_definitions = jsonencode([
    {
      name            = "twistlock-console"
      image           = "registry-auth.twistlock.com/tw_<TOKEN>/twistlock/console:console_31_00_129" # Change the version if needed.
      portMappings    = [
        {
          hostPort      = 8083
          protocol      = "tcp"
          containerPort = 8083
        },
        {
          hostPort      = 8084
          protocol      = "tcp"
          containerPort = 8084
        },
      ]
      environment     = [
        {
          name  = "COMMUNICATION_PORT"
          value = "8084"
        },
        {
          name  = "CONSOLE_CN"
          value = "<>" # Replace with your Load Balancer DNS 
        },
        {
          name  = "DATA_RECOVERY_ENABLED"
          value = "true"
        },
        {
          name  = "LOG_PROD"
          value = "true"
        },
        {
          name  = "MANAGEMENT_PORT_HTTPS"
          value = "8083"
        },
        {
          name  = "FIPS_ENABLED"
          value = "false"
        },
        {
          name  = "CONFIG_DATA"
          value = "<>"}
      ]
      mountPoints     = [
        {
          containerPath = "/var/lib/"
          sourceVolume  = "compute_root_volume"
        }
      ]
    },
  ])
}

# ECS Fargate Service
resource "aws_ecs_service" "pc_fargate_service" {
  name            = "pc-console"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.pc_task_definition.arn
  

  launch_type             = "FARGATE"
  desired_count           = 1
  platform_version        = "1.4.0"
  enable_ecs_managed_tags = true

  network_configuration {
    subnets = ["<>", "<>"]  # Replace with your subnet IDs
    security_groups = [aws_security_group.prisma_cloud_security_group.id]  # Replace with your security group ID
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.pc_tgt_8083.arn
    container_name   = "twistlock-console"
    container_port   = 8083
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.pc_tgt_8084.arn
    container_name   = "twistlock-console"
    container_port   = 8084
  }
}
*/


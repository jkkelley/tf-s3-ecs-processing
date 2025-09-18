# Enabled this for logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/tf-${var.name}-logs"
  retention_in_days = 14
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.name}-cluster"
}

# Minimal task roles (execution pulls image & writes logs; task role for S3 access)
data "aws_iam_policy_document" "task_execution_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${var.name}-task-exec"
  assume_role_policy = data.aws_iam_policy_document.task_execution_assume.json
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_role" {
  name               = "${var.name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

# Permit read/write to the processing bucket (adjust to least privilege you need)
data "aws_iam_policy_document" "task_s3" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_policy" "task_s3" {
  name   = "${var.name}-task-s3"
  policy = data.aws_iam_policy_document.task_s3.json
}

resource "aws_iam_role_policy_attachment" "task_s3" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.task_s3.arn
}

# Security group for tasks (internal only)
resource "aws_security_group" "tasks" {
  name   = "${var.name}-tasks-sg"
  vpc_id = aws_vpc.private_vpc.id

  # Ingress closed by default; open if your app needs east-west traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.private_vpc.cidr_block]
  }
  tags = { Name = "${var.name}-tasks-sg" }
}


# Example Fargate task definition (your app image is referenced; no coupling of code)
resource "aws_ecs_task_definition" "processor" {
  family                   = "${var.name}-processor"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_role.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  # container_definitions = jsonencode([
  #   {
  #    name      = var.ecr_app_name,
  #    image     = var.container_image,
  #     essential = true
  #     logConfiguration = {
  #       logDriver = "awslogs"
  #       options = {
  #         awslogs-group         = aws_cloudwatch_log_group.app.name
  #         awslogs-region        = var.region
  #         awslogs-stream-prefix = "ecs"
  #       }
  #     }
  #     environment = [
  #       { name = "S3_BUCKET", value = var.s3_bucket_name }
  #     ]
  #   }
  # ])

  # This is for testing, use above for Prod
  container_definitions = jsonencode([
    {
      name      = var.ecr_app_name,
      image     = var.container_image,
      essential = true,
      command   = ["bash", "-c", "echo Processing $S3_BUCKET/$S3_KEY; sleep 10"],
      environment = [
        { name = "S3_BUCKET", value = "" },
        { name = "S3_KEY", value = "" }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  depends_on = [aws_cloudwatch_log_group.app]
}

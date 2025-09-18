# turn on S3 -> EventBridge notifications (bucket-level)
resource "aws_s3_bucket_notification" "to_eventbridge" {
  bucket      = var.s3_bucket_name
  eventbridge = true
}

# IAM role EventBridge uses to call RunTask
data "aws_iam_policy_document" "events_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

#### IAM
resource "aws_iam_role" "events_invoke_ecs" {
  name               = "${var.name}-events-invoke-ecs"
  assume_role_policy = data.aws_iam_policy_document.events_assume.json
}

# Policy to let Events run tasks & pass roles
data "aws_iam_policy_document" "events_run_task" {
  statement {
    actions   = ["ecs:RunTask"]
    resources = [aws_ecs_task_definition.processor.arn]
  }
  statement {
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.task_execution.arn, aws_iam_role.task_role.arn]
  }
}

resource "aws_iam_policy" "events_run_task" {
  name   = "${var.name}-events-run-task"
  policy = data.aws_iam_policy_document.events_run_task.json
}

resource "aws_iam_role_policy_attachment" "events_run_task" {
  role       = aws_iam_role.events_invoke_ecs.name
  policy_arn = aws_iam_policy.events_run_task.arn
}

# Event pattern: S3 Object Created for this bucket/prefix/suffix
# Set s3_prefix/s3_suffix to non-empty → filtered.
locals {
  want_filters = length(var.s3_prefix) > 0 || length(var.s3_suffix) > 0
  key_filters  = concat(
    var.s3_prefix != "" ? [{ prefix = var.s3_prefix }] : [],
    var.s3_suffix != "" ? [{ suffix = var.s3_suffix }] : []
  )
}

resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "${var.name}-s3-create"
  description = "S3 object created triggers ECS task"

  event_pattern = jsonencode(
    merge(
      {
        source       = ["aws.s3"]
        "detail-type" = ["Object Created"]
        detail = {
          bucket = { name = [var.s3_bucket_name] }
        }
      },
      local.want_filters ? {
        detail = merge(
          {
            bucket = { name = [var.s3_bucket_name] }
          },
          { object = { key = local.key_filters } }
        )
      } : {}
    )
  )
}

# Target: run the task (Fargate) in private subnets with task SG
resource "aws_cloudwatch_event_target" "run_task" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  target_id = "run-ecs-task"
  arn       = aws_ecs_cluster.ecs_cluster.arn
  role_arn  = aws_iam_role.events_invoke_ecs.arn

  ecs_target {
    launch_type         = "FARGATE"
    task_definition_arn = aws_ecs_task_definition.processor.arn
    network_configuration {
      subnets          = [for subnet in aws_subnet.private : subnet.id]
      security_groups  = [aws_security_group.tasks.id]
      assign_public_ip = false
    }
    platform_version = "LATEST"
    # Optionally override container env with the specific key
    # enable_execute_command = false
  }
}

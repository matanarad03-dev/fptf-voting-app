# Map 3 · S2 · What the kit hands back: the shift manager's name.
output "service_name" {
  value = aws_ecs_service.this.name
}

# Map 3 · S2 · The job card's number (ARN). The pipeline's version check uses it (P10).
output "task_definition_arn" {
  value = aws_ecs_task_definition.this.arn
}

# Map 3 · S3 · The kitchen diary's name, to find the logs.
output "log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}

# Map 4 · S5 · Reads (does not create) the 3 pantry shelves the bootstrap built.
# Used in ecs.tf: the image = <shelf URL>:<image_tag>.
data "aws_ecr_repository" "service" {
  for_each = toset(["vote", "result", "worker"])
  name     = "${var.name_prefix}-${each.key}"
}

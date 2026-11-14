# Map 3 · S2 · The kit's required inputs: the worker's name, which staff room, which meal kit.
variable "name" {
  description = "Full service name, for example fptf-dev-vote"
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster to run in"
  type        = string
}

# Map 3 · S5 · The meal kit from the pantry: <ECR URL>:<tag>.
variable "image" {
  description = "Full image address: <ECR URL>:<tag>"
  type        = string
}

# Map 3 · S7 · The shift manager's keycard: pull the image, write the diary, open the safe.
variable "execution_role_arn" {
  description = "Role ECS uses to pull the image, write logs and read the secret"
  type        = string
}

# Map 3 · S3 · Where the worker stands (public subnets) and its bouncer (ecs-sg).
variable "subnet_ids" {
  description = "Subnets for the tasks (the public ones)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups for the tasks (ecs-sg)"
  type        = list(string)
}

# Map 3 · E2 · How many workers on shift (dev 1, prod 2).
variable "desired_count" {
  description = "How many copies to run (dev 1, prod 2)"
  type        = number
}

# Map 3 · S4 / D4 · Instructions on the job card: plain settings, and secrets as "which safe".
variable "environment" {
  description = "Plain settings: NAME = value"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secret settings: NAME = secret ARN"
  type        = map(string)
  default     = {}
}

# Map 3 · S2 · Optional door and host: null = none (the worker/cook).
variable "container_port" {
  description = "Port the app listens on, or null for none (worker)"
  type        = number
  default     = null
}

variable "target_group_arn" {
  description = "Load balancer target group, or null for none (worker)"
  type        = string
  default     = null
}

# Map 5 · E1 · Which building: the test kitchen (dev) or the real restaurant (prod).
variable "env" {
  description = "Environment name: dev or prod"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be dev or prod."
  }
}

# Map 5 · E5 · The owner's prefix in every name (fptf).
variable "name_prefix" {
  description = "Prefix for every name. Lowercase letters, digits and hyphens, up to 12 characters"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,12}$", var.name_prefix))
    error_message = "name_prefix: lowercase letters, digits and hyphens, up to 12 characters."
  }
}

# Map 2a · N1 · The building's address range (no default: comes from envs/*.tfvars).
variable "vpc_cidr" {
  description = "IP address range of the VPC, for example 10.10.0.0/16"
  type        = string
}

# Map 4 / 6 · S5 · Which meal-kit version from the pantry (ECR). "none" until step 4.
variable "image_tag" {
  description = "Image tag to deploy"
  type        = string
}

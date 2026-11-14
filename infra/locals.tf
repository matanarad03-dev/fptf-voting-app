# Map 2a · The building's name, e.g. fptf-dev. Used in every resource name
# (in every file, so it lives here: C3).

locals {
  name = "${var.name_prefix}-${var.env}"
}

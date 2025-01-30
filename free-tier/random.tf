provider "random" {}

resource "random_pet" "rds_name" {
  length = 2  # Generates a 2-word name (e.g., "happy-penguin")
}
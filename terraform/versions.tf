terraform {
  required_version = ">= 1.3.0"

  required_providers {
    harvester = {
      source  = "harvester/harvester"
      version = "~> 1.8.0"
    }
  }
}

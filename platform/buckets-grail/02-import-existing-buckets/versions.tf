terraform {
  required_version = ">= 1.7.0"

  required_providers {
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.105"
    }
  }
}

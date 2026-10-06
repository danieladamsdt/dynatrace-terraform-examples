terraform {
  required_version = ">= 1.5.0"

  required_providers {
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.105"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

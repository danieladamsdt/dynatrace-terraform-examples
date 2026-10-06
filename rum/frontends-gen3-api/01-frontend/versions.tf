terraform {
  required_version = ">= 1.9.0" # variable validation that references other variables

  required_providers {
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.105"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }
}

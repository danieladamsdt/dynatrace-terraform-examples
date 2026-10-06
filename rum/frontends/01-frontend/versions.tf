terraform {
  required_version = ">= 1.5.0"

  required_providers {
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.105"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }
}

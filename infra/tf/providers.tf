terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.7"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 7.7"
    }
  }

  backend "gcs" {
    bucket = "tf-state-platform-vm"
    prefix = "gke-platform"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

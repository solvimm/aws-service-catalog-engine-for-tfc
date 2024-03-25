# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  cloud {
    organization = "e-core-cloud"
    workspaces {
      name = var.workspaces
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.12.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "0.45.0"
    }
  }
}

terraform {
  backend "remote" {
    organization = "e-core-cloud"

    workspaces {
      name = var.workspaces
    }
  }
}


terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  # backend "s3" {
  #   bucket         = "lz-tfstate-<management-account-id>"
  #   key            = "landing-zone/sandbox/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

# Management (payer) account: organization, OUs, SCPs, org trail, delegated admins.
provider "aws" {
  region = var.home_region

  default_tags {
    tags = local.tags
  }
}

# Each core account is reached by assuming its admin role from the management account.
provider "aws" {
  alias  = "log_archive"
  region = var.home_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.account_ids.log_archive}:role/${var.cross_account_role_name}"
    session_name = "landing-zone-terraform"
  }

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias  = "security"
  region = var.home_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.account_ids.security}:role/${var.cross_account_role_name}"
    session_name = "landing-zone-terraform"
  }

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias  = "network"
  region = var.home_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.account_ids.network}:role/${var.cross_account_role_name}"
    session_name = "landing-zone-terraform"
  }

  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias  = "workload"
  region = var.home_region

  assume_role {
    role_arn     = "arn:aws:iam::${var.account_ids.sandbox_workload}:role/${var.cross_account_role_name}"
    session_name = "landing-zone-terraform"
  }

  default_tags {
    tags = local.tags
  }
}

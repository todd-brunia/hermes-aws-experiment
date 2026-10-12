terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}
variable "management_account_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "Supply the AWS Organizations management account ID."
  }
}
variable "account_email" {
  type      = string
  sensitive = true
}
variable "account_name" {
  type    = string
  default = "hermes-experiment"
}
provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = [var.management_account_id]
}
resource "aws_organizations_account" "hermes" {
  name              = var.account_name
  email             = var.account_email
  role_name         = "OrganizationAccountAccessRole"
  close_on_deletion = false
  tags              = { Project = "hermes-experiment", ManagedBy = "terraform" }
  lifecycle { prevent_destroy = true }
}
output "member_account_id" { value = aws_organizations_account.hermes.id }

variable "portal_assignment" {
  description = "Optional existing IAM Identity Center permission set and principal to assign to the new account."
  type = object({
    instance_arn       = string
    permission_set_arn = string
    principal_id       = string
    principal_type     = string
  })
  default = null
  validation {
    condition     = var.portal_assignment == null ? true : contains(["USER", "GROUP"], var.portal_assignment.principal_type)
    error_message = "Principal type must be USER or GROUP."
  }
}
resource "aws_ssoadmin_account_assignment" "hermes" {
  for_each           = var.portal_assignment == null ? {} : { portal = var.portal_assignment }
  instance_arn       = each.value.instance_arn
  permission_set_arn = each.value.permission_set_arn
  principal_id       = each.value.principal_id
  principal_type     = each.value.principal_type
  target_id          = aws_organizations_account.hermes.id
  target_type        = "AWS_ACCOUNT"
}

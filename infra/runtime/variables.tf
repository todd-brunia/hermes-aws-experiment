variable "aws_account_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Supply the intended member account ID."
  }
}
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "instance_type" {
  type    = string
  default = "t4g.small"
  validation {
    condition     = contains(["t4g.micro", "t4g.small", "t4g.medium"], var.instance_type)
    error_message = "Use a supported ARM t4g size. Start with small (2 GiB)."
  }
}
variable "hermes_image" {
  type        = string
  description = "Official multi-architecture image pinned to a reviewed sha256 digest."
  validation {
    condition     = can(regex("^nousresearch/hermes-agent@sha256:[a-f0-9]{64}$", var.hermes_image))
    error_message = "Pin the official image by digest. See README."
  }
}
variable "openai_model" {
  type        = string
  description = "OpenAI model enabled in your dedicated project."
  validation {
    condition     = can(regex("^[a-zA-Z0-9._:-]+$", var.openai_model))
    error_message = "Supply a model ID, not a shell expression."
  }
}
variable "openai_key_parameter" {
  type    = string
  default = "/hermes-experiment/openai-api-key"
  validation {
    condition     = can(regex("^/hermes-experiment/[a-zA-Z0-9/_-]+$", var.openai_key_parameter))
    error_message = "Use a parameter under /hermes-experiment/."
  }
}

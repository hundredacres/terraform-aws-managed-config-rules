variable "rules" {
  description = "The rules to process"
}

variable "excluded_accounts" {
  description = "AWS accounts to exclude from the managed config rules"
  default     = []
  type        = list(string)
}

variable "rule_name_prefix" {
  description = "Rule names created should start with the specified string"
  default     = ""
  type        = string
}

variable "ssm_documents" {
  description = "Map of SSM documents to create for remediation actions. Only created if associated config rule is enabled."
  type = map(object({
    content             = string
    document_type       = optional(string, "Automation")
    document_format     = optional(string, "YAML")
    target_type         = optional(string)
    version_name        = optional(string)
    tags                = optional(map(string), {})
    attachments_source  = optional(list(object({
      key    = string
      values = list(string)
      name   = optional(string)
    })), [])
    config_rule         = optional(string)  # Associated config rule name - if not set, document is always created
  }))
  default = {}
}

variable "remediation_configurations" {
  description = "Map of remediation configurations for Config rules"
  type = map(object({
    rule_name               = string
    target_type             = string
    target_id               = string
    target_version          = optional(string)
    resource_type           = optional(string)
    maximum_automatic_attempts = optional(number, 5)
    retry_attempt_seconds   = optional(number, 60)
    automatic               = optional(bool, false)
    execution_controls = optional(object({
      ssm_controls = optional(object({
        concurrent_execution_rate_percentage = optional(number)
        error_percentage                     = optional(number)
      }))
    }))
    parameters = optional(map(object({
      static_value    = optional(string)
      static_values   = optional(list(string))
      resource_value  = optional(string)
    })), {})
  }))
  default = {}
}
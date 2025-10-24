resource "aws_config_organization_managed_rule" "rule" {
  for_each = var.rules

  name                 = "${var.rule_name_prefix}${each.key}"

  # Custom rules don't have identifiers like AWS managed rules, so we need to
  # fall back to the key if an identifier is not provided.
  rule_identifier      = try(each.value["identifier"], upper(replace(each.key, "-", "_")))
  excluded_accounts    = var.excluded_accounts
  description          = try(each.value["description"], "")
  resource_types_scope = try(each.value["resource_types_scope"], [])

  input_parameters = (
    # AWS Config expects all values as strings. This list comprehension
    # removes optional parameter attributes whose value is 'null'.
    try(jsonencode(each.value["input_parameters"]), null) != "null" ?
    try(jsonencode(
      { for k, v in each.value["input_parameters"] :
        k => tostring(v) if v != null }), null) :
    null
  )
}

resource "aws_ssm_document" "this" {
  # Only create SSM documents if:
  # 1. No config_rule is specified (document is standalone), OR
  # 2. The associated config_rule is in the rules map (rule is enabled)
  for_each = {
    for k, v in var.ssm_documents :
    k => v if v.config_rule == null || contains(keys(var.rules), v.config_rule)
  }

  name            = each.key
  content         = each.value.content
  document_type   = each.value.document_type
  document_format = each.value.document_format
  target_type     = each.value.target_type
  version_name    = each.value.version_name
  tags            = each.value.tags

  dynamic "attachments_source" {
    for_each = each.value.attachments_source
    content {
      key    = attachments_source.value.key
      values = attachments_source.value.values
      name   = attachments_source.value.name
    }
  }
}

resource "aws_config_remediation_configuration" "this" {
  # Only create remediation configurations if:
  # 1. The associated config rule is in the rules map (rule is enabled), AND
  # 2. Automatic remediation is enabled OR manual remediation is configured
  for_each = {
    for k, v in var.remediation_configurations :
    k => v if contains(keys(var.rules), v.rule_name)
  }

  config_rule_name = "${var.rule_name_prefix}${each.value.rule_name}"
  target_type      = each.value.target_type
  target_id        = each.value.target_id
  target_version   = each.value.target_version
  resource_type    = each.value.resource_type

  maximum_automatic_attempts = each.value.maximum_automatic_attempts
  retry_attempt_seconds      = each.value.retry_attempt_seconds
  automatic                  = each.value.automatic

  dynamic "execution_controls" {
    for_each = each.value.execution_controls != null ? [each.value.execution_controls] : []
    content {
      dynamic "ssm_controls" {
        for_each = execution_controls.value.ssm_controls != null ? [execution_controls.value.ssm_controls] : []
        content {
          concurrent_execution_rate_percentage = ssm_controls.value.concurrent_execution_rate_percentage
          error_percentage                     = ssm_controls.value.error_percentage
        }
      }
    }
  }

  dynamic "parameter" {
    for_each = each.value.parameters
    content {
      name = parameter.key

      static_value  = parameter.value.static_value
      static_values = parameter.value.static_values
      resource_value = parameter.value.resource_value
    }
  }

  depends_on = [
    aws_config_organization_managed_rule.rule,
    aws_ssm_document.this
  ]
}
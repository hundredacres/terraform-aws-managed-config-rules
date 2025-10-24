output "rules" {
  description = "The AWS-managed Config Rules applied"
  value       = aws_config_organization_managed_rule.rule
}

output "ssm_documents" {
  description = "The SSM documents created for remediation actions"
  value       = aws_ssm_document.this
}

output "remediation_configurations" {
  description = "The remediation configurations applied to Config rules"
  value       = aws_config_remediation_configuration.this
}
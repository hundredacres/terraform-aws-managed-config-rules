locals {
  remediation_configurations = {
    vpc-flow-logs-enabled = {
      config_rule_name           = "vpc-flow-logs-enabled"
      resource_type              = ["AWS::EC2::VPC"]
      target_id                  = file("${path.module}/ssm_documents/enable_vpc_flow_logs.yaml")
      target_type                = "SSM_DOCUMENT"
      automatic                  = true
      maximum_automatic_attempts = 3
      parameters = {
        AutomationAssumeRole = {
          static_value = var.assumable_role
        }
        VpcId = {
          resource_value = "RESOURCE_ID"
        }
      }
    }
  }
}
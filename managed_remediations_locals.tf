locals {
  remediation_configurations = {
    vpc-flow-logs-enabled = {
      rule_name                  = "vpc-flow-logs-enabled"
      resource_type              = "AWS::EC2::VPC"
      target_id                  = "AWSSupport-EnableVPCFlowLogs"
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
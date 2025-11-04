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
        LogGroupNamePrefix = {
          static_value = "/aws/vpc/flow-logs"
        }
        TrafficType = {
          static_value = "REJECT"
        }
        DestinationType = {
          static_value = "CloudWatchLogs"
        }
        VpcId = {
          resource_value = "RESOURCE_ID"
        }
      }
    }
  }
}
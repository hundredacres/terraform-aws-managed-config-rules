# AWS Config Organization Managed Rules Module

This module creates AWS Config organization managed rules, SSM documents for remediation, and remediation configurations.

## Features

- Deploy AWS Config organization managed rules across an AWS Organization
- Create SSM automation documents for remediation actions
- Configure automatic remediation for non-compliant resources
- Exclude specific AWS accounts from organization rules
- Support for custom rule name prefixes
- **Conditional resource creation**: SSM documents and remediation configurations are only created when their associated Config rules are enabled

## Usage

### Basic Example

```hcl
module "org_config_rules" {
  source = "./modules/organization"

  rules = {
    s3-bucket-public-read-prohibited = {
      identifier  = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
      description = "Checks that S3 buckets do not allow public read access"
    }
  }

  rule_name_prefix  = "org-"
  excluded_accounts = ["123456789012"]
}
```

### Example with SSM Documents and Remediation

```hcl
module "org_config_rules_with_remediation" {
  source = "./modules/organization"

  rules = {
    iam-user-unused-credentials-check = {
      identifier = "IAM_USER_UNUSED_CREDENTIALS_CHECK"
      description = "Checks whether your AWS Identity and Access Management (IAM) users have passwords or active access keys that have not been used within the specified number of days"
      input_parameters = {
        maxCredentialUsageAge = "90"
      }
    }
  }

  ssm_documents = {
    deactivate-unused-credentials = {
      content = templatefile("${path.module}/ssm_documents/deactivate_unused_credentials.yaml", {
        MaxCredentialUsageAge = 90
        SNSTopicArn          = ""
      })
      document_type   = "Automation"
      document_format = "YAML"
      config_rule     = "iam-user-unused-credentials-check"  # Links document to rule
      tags = {
        Purpose = "ConfigRemediation"
      }
    }
  }

  remediation_configurations = {
    iam-user-unused-credentials-remediation = {
      rule_name   = "iam-user-unused-credentials-check"
      target_type = "SSM_DOCUMENT"
      target_id   = "deactivate-unused-credentials"
      automatic   = true
      maximum_automatic_attempts = 5
      retry_attempt_seconds      = 60

      parameters = {
        AutomationAssumeRole = {
          static_value = "arn:aws:iam::ACCOUNT_ID:role/ConfigRemediationRole"
        }
        IAMUser = {
          resource_value = "RESOURCE_ID"
        }
      }

      execution_controls = {
        ssm_controls = {
          concurrent_execution_rate_percentage = 10
          error_percentage                     = 10
        }
      }
    }
  }

  rule_name_prefix  = "org-"
  excluded_accounts = []
}
```

### Example with S3 Public Access Remediation

```hcl
module "org_config_s3_remediation" {
  source = "./modules/organization"

  rules = {
    s3-bucket-public-read-prohibited = {
      identifier  = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
      description = "Checks that S3 buckets do not allow public read access"
    }
  }

  ssm_documents = {
    enable-s3-public-access-block = {
      content = file("${path.module}/ssm_documents/enable_s3_public_access_block.yaml")
      document_type   = "Automation"
      document_format = "YAML"
      config_rule     = "s3-bucket-public-read-prohibited"  # Links document to rule
    }
  }

  remediation_configurations = {
    s3-public-read-remediation = {
      rule_name   = "s3-bucket-public-read-prohibited"
      target_type = "SSM_DOCUMENT"
      target_id   = "enable-s3-public-access-block"
      automatic   = false

      parameters = {
        AutomationAssumeRole = {
          static_value = "arn:aws:iam::ACCOUNT_ID:role/ConfigRemediationRole"
        }
        BucketName = {
          resource_value = "RESOURCE_ID"
        }
      }
    }
  }

  rule_name_prefix = "org-"
}
```

### Example: Conditional Resource Creation

This example shows how SSM documents and remediation configurations are only created when their associated Config rules are enabled:

```hcl
module "org_config_conditional" {
  source = "./modules/organization"

  # Only enable the IAM credentials check rule
  rules = {
    iam-user-unused-credentials-check = {
      identifier = "IAM_USER_UNUSED_CREDENTIALS_CHECK"
      description = "Checks for unused IAM credentials"
      input_parameters = {
        maxCredentialUsageAge = "90"
      }
    }
    # Note: s3-bucket-public-read-prohibited is NOT included
  }

  # This SSM document WILL be created (linked to enabled rule)
  ssm_documents = {
    deactivate-unused-credentials = {
      content     = file("${path.module}/ssm_documents/deactivate_unused_credentials.yaml")
      config_rule = "iam-user-unused-credentials-check"
    }
    # This SSM document will NOT be created (linked to disabled rule)
    enable-s3-block = {
      content     = file("${path.module}/ssm_documents/enable_s3_public_access_block.yaml")
      config_rule = "s3-bucket-public-read-prohibited"  # This rule is not in the rules map
    }
  }

  # This remediation WILL be created (linked to enabled rule)
  remediation_configurations = {
    iam-remediation = {
      rule_name   = "iam-user-unused-credentials-check"
      target_type = "SSM_DOCUMENT"
      target_id   = "deactivate-unused-credentials"
      automatic   = true
      parameters = {
        AutomationAssumeRole = { static_value = "arn:aws:iam::ACCOUNT_ID:role/ConfigRemediationRole" }
        IAMUser              = { resource_value = "RESOURCE_ID" }
      }
    }
    # This remediation will NOT be created (linked to disabled rule)
    s3-remediation = {
      rule_name   = "s3-bucket-public-read-prohibited"  # This rule is not in the rules map
      target_type = "SSM_DOCUMENT"
      target_id   = "enable-s3-block"
      automatic   = false
      parameters = {
        AutomationAssumeRole = { static_value = "arn:aws:iam::ACCOUNT_ID:role/ConfigRemediationRole" }
        BucketName           = { resource_value = "RESOURCE_ID" }
      }
    }
  }

  rule_name_prefix = "org-"
}
```

**Key Points:**

- SSM documents are only created if their `config_rule` is `null` (standalone) or exists in the `rules` map
- Remediation configurations are only created if their `rule_name` exists in the `rules` map
- This prevents creating unused remediation resources when rules are disabled via `rules_to_exclude` or not included in `rules_to_include`

## Variables

### Required Variables

- `rules` - Map of AWS Config rules to create

### Optional Variables

- `excluded_accounts` - List of AWS account IDs to exclude from organization rules (default: `[]`)
- `rule_name_prefix` - Prefix to add to all rule names (default: `""`)
- `ssm_documents` - Map of SSM documents to create for remediation (default: `{}`)
- `remediation_configurations` - Map of remediation configurations for Config rules (default: `{}`)

### SSM Document Object Structure

```hcl
ssm_documents = {
  document-name = {
    content             = string           # Required: Document content
    document_type       = string           # Optional: Default "Automation"
    document_format     = string           # Optional: Default "YAML"
    target_type         = string           # Optional: Target resource type
    version_name        = string           # Optional: Document version name
    tags                = map(string)      # Optional: Tags for the document
    config_rule         = string           # Optional: Associated config rule name (without prefix)
                                           #           If set, document only created when rule is enabled
                                           #           If null, document is always created
    attachments_source  = list(object({    # Optional: Attachments
      key    = string
      values = list(string)
      name   = string
    }))
  }
}
```

### Remediation Configuration Object Structure

```hcl
remediation_configurations = {
  config-name = {
    rule_name                   = string  # Required: Config rule name (without prefix)
    target_type                 = string  # Required: "SSM_DOCUMENT"
    target_id                   = string  # Required: SSM document name or ARN
    target_version              = string  # Optional: SSM document version
    resource_type               = string  # Optional: AWS resource type
    maximum_automatic_attempts  = number  # Optional: Default 5
    retry_attempt_seconds       = number  # Optional: Default 60
    automatic                   = bool    # Optional: Default false

    execution_controls = object({         # Optional
      ssm_controls = object({
        concurrent_execution_rate_percentage = number
        error_percentage                     = number
      })
    })

    parameters = map(object({             # Optional
      static_value    = string            # Use one of: static_value, static_values, or resource_value
      static_values   = list(string)
      resource_value  = string
    }))
  }
}
```

## Outputs

- `rules` - The AWS Config organization managed rules created
- `ssm_documents` - The SSM documents created for remediation
- `remediation_configurations` - The remediation configurations applied

## IAM Permissions

### For Config Rules

The AWS Config service role needs permissions to evaluate resources. This is typically managed at the organization level.

### For Remediation Actions

Create an IAM role with permissions for the remediation actions. Example policy for SSM automation:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:StartAutomationExecution",
        "ssm:GetAutomationExecution"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "config:GetComplianceDetailsByConfigRule",
        "config:DescribeConfigRules"
      ],
      "Resource": "*"
    }
  ]
}
```

The SSM automation document will also need permissions to perform the actual remediation actions (e.g., IAM permissions to deactivate credentials, S3 permissions to modify bucket settings, etc.).

## Notes

- Organization managed rules are created in the management account and applied across the organization
- Remediation configurations created in the organization module apply to individual member accounts
- **SSM documents are only created when their associated Config rule is enabled** (if `config_rule` is specified)
- **Remediation configurations are only created when their associated Config rule is enabled**
- SSM documents must exist before remediation configurations reference them (managed via `depends_on`)
- Automatic remediation should be tested carefully before enabling in production
- Some remediation actions may require specific IAM permissions in member accounts
- When rules are excluded via `rules_to_exclude` or not included in `rules_to_include`, their associated remediation resources will not be created

## References

- [AWS Config Organization Managed Rules](https://docs.aws.amazon.com/config/latest/developerguide/config-rule-multi-account-deployment.html)
- [AWS Config Remediation](https://docs.aws.amazon.com/config/latest/developerguide/remediation.html)
- [AWS Systems Manager Documents](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-ssm-docs.html)

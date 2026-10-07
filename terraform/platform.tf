data "aws_partition" "current" {}
locals {
  account_arn  = "arn:${data.aws_partition.current.partition}"
  database_arn = "${local.account_arn}:rds:${var.aws_region}:${var.aws_account_id}:db:${var.resource_prefix}-gp-piloto-*"
}
resource "aws_secretsmanager_secret" "github" {
  name                    = "${var.resource_prefix}/github-app"
  description             = "GitHub App and Backstage auth settings. Values are provisioned outside Terraform."
  recovery_window_in_days = 7
  depends_on              = [terraform_data.deployment_gate]
}
resource "aws_security_group" "pilot_workloads" {
  name   = "${var.resource_prefix}-pilot-workloads"
  vpc_id = module.network.vpc_id
}
resource "aws_security_group" "pilot_database" {
  name   = "${var.resource_prefix}-pilot-db"
  vpc_id = module.network.vpc_id
}
resource "aws_vpc_security_group_ingress_rule" "pilot_database" {
  security_group_id            = aws_security_group.pilot_database.id
  referenced_security_group_id = aws_security_group.pilot_workloads.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
resource "aws_vpc_security_group_egress_rule" "pilot_database" {
  security_group_id            = aws_security_group.pilot_workloads.id
  referenced_security_group_id = aws_security_group.pilot_database.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}
resource "aws_vpc_security_group_egress_rule" "pilot_dns" {
  for_each                     = toset(["tcp", "udp"])
  security_group_id            = aws_security_group.pilot_workloads.id
  referenced_security_group_id = module.eks.node_security_group_id
  ip_protocol                  = each.value
  from_port                    = 53
  to_port                      = 53
}
resource "aws_vpc_security_group_ingress_rule" "node_dns_from_pilot" {
  for_each                     = toset(["tcp", "udp"])
  security_group_id            = module.eks.node_security_group_id
  referenced_security_group_id = aws_security_group.pilot_workloads.id
  ip_protocol                  = each.value
  from_port                    = 53
  to_port                      = 53
}
resource "aws_vpc_security_group_ingress_rule" "pilot_mesh" {
  security_group_id            = aws_security_group.pilot_workloads.id
  referenced_security_group_id = module.eks.node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 15008
  to_port                      = 15008
}
resource "aws_vpc_security_group_ingress_rule" "pilot_probe" {
  security_group_id            = aws_security_group.pilot_workloads.id
  referenced_security_group_id = module.eks.node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}
resource "aws_db_subnet_group" "pilot" {
  name       = "${var.resource_prefix}-pilot"
  subnet_ids = module.network.data_subnet_ids
}
data "aws_iam_policy_document" "crossplane" {
  statement {
    sid       = "ObserveRDS"
    actions   = ["rds:DescribeDBInstances", "rds:DescribeDBSubnetGroups", "rds:DescribeDBParameterGroups", "rds:DescribeDBEngineVersions", "rds:DescribeOrderableDBInstanceOptions", "rds:ListTagsForResource"]
    resources = ["*"]
  }
  statement {
    sid       = "CreateOnlyPlatformDatabases"
    actions   = ["rds:CreateDBInstance"]
    resources = [local.database_arn]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.resource_prefix]
    }
    condition {
      test     = "StringEquals"
      variable = "rds:DatabaseEngine"
      values   = ["postgres"]
    }
    condition {
      test     = "StringEquals"
      variable = "rds:DatabaseClass"
      values   = [var.pilot_small_database_instance_class, var.pilot_medium_database_instance_class]
    }
  }
  statement {
    sid       = "UseDedicatedSubnetGroup"
    actions   = ["rds:CreateDBInstance"]
    resources = [aws_db_subnet_group.pilot.arn]
  }
  # RDS authorizes the default parameter and option groups during instance creation too.
  # They are AWS defaults, so the instance's Project request tag must not be required here.
  statement {
    sid     = "UsePostgresDefaults"
    actions = ["rds:CreateDBInstance"]
    resources = [
      "${local.account_arn}:rds:${var.aws_region}:${var.aws_account_id}:pg:default.postgres16",
      "${local.account_arn}:rds:${var.aws_region}:${var.aws_account_id}:og:default:postgres-16"
    ]
  }
  statement {
    sid       = "TagOnlyPilotDatabases"
    actions   = ["rds:AddTagsToResource"]
    resources = [local.database_arn]
    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:RequestTag/Project"
      values   = [var.resource_prefix]
    }
  }

  statement {
    sid       = "ReconcileOwnedDatabases"
    actions   = ["rds:ModifyDBInstance", "rds:DeleteDBInstance", "rds:RemoveTagsFromResource"]
    resources = [local.database_arn]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.resource_prefix]
    }
  }
}
module "crossplane_identity" {
  source          = "./modules/pod-identity"
  role_name       = "${var.resource_prefix}-crossplane-rds"
  cluster_name    = module.eks.cluster_name
  namespace       = "crossplane-system"
  service_account = "provider-aws-rds"
  policy_json     = data.aws_iam_policy_document.crossplane.json
  depends_on      = [module.eks]
}
data "aws_iam_policy_document" "external_secrets" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.github.arn, module.backstage_database.master_secret_arn]
  }
}
module "external_secrets_identity" {
  source          = "./modules/pod-identity"
  role_name       = "${var.resource_prefix}-external-secrets"
  cluster_name    = module.eks.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  policy_json     = data.aws_iam_policy_document.external_secrets.json
  depends_on      = [module.eks]
}

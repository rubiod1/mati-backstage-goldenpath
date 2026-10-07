variable "deployment_enabled" {
  description = "Explicit deployment gate. Keep false during preparation."
  type        = bool
  default     = false
}

variable "aws_account_id" {
  description = "Target account ID, explicitly supplied for this platform."
  type        = string
}

variable "aws_region" {
  description = "Target AWS region."
  type        = string
  default     = "us-east-1"
}

variable "resource_prefix" {
  description = "Dedicated resource prefix."
  type        = string
  default     = "goldenpath-dev"
}

variable "owner" {
  description = "Platform owner."
  type        = string
}

variable "cost_center" {
  description = "Academic project cost center."
  type        = string
}

variable "availability_zones" {
  description = "Three AZs matching the target region."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "kubernetes_version" {
  description = "Supported Kubernetes version; select before deployment."
  type        = string
}

variable "eks_addon_versions" {
  description = "Exact compatible versions of four required EKS add-ons."
  type        = map(string)
}

variable "eks_admin_principal_arns" {
  description = "Explicit existing admin roles."
  type        = map(string)
}

variable "eks_public_access_cidrs" {
  description = "Admin CIDRs; empty is private-only and requires a VPC access path."
  type        = list(string)
  default     = []
}

variable "postgres_engine_version" {
  description = "Available PostgreSQL 16 minor version; verify before deployment."
  type        = string
}

variable "backstage_database_instance_class" {
  description = "Backstage DB class; db.t3.micro is a same-size fallback when Graviton capacity is unavailable."
  type        = string
  default     = "db.t4g.micro"
  validation {
    condition     = contains(["db.t4g.micro", "db.t3.micro"], var.backstage_database_instance_class)
    error_message = "Backstage must use db.t4g.micro or the db.t3.micro capacity fallback."
  }
}

variable "pilot_small_database_instance_class" {
  description = "Class for the piloto pequena contract, propagated to Crossplane and its IAM permissions."
  type        = string
  default     = "db.t4g.micro"
  validation {
    condition     = contains(["db.t4g.micro", "db.t3.micro"], var.pilot_small_database_instance_class)
    error_message = "The pequena size must use db.t4g.micro or the db.t3.micro capacity fallback."
  }
}

variable "pilot_medium_database_instance_class" {
  description = "Class for the piloto mediana contract, propagated to Crossplane and its IAM permissions."
  type        = string
  default     = "db.t4g.small"
  validation {
    condition     = contains(["db.t4g.small", "db.t3.small"], var.pilot_medium_database_instance_class)
    error_message = "The mediana size must use db.t4g.small or the db.t3.small capacity fallback."
  }
}

variable "final_snapshot_suffix" {
  description = "Unique final snapshot suffix for this lifecycle."
  type        = string
}

variable "enable_portal_edge" {
  description = "Enable the managed HTTPS REST API Gateway and WAF entry point for Backstage."
  type        = bool
  default     = false
}

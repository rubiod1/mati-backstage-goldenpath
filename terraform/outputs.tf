output "cluster_name" { value = module.eks.cluster_name }
output "vpc_id" { value = module.network.vpc_id }
output "data_subnet_ids" { value = module.network.data_subnet_ids }
output "backstage_database_endpoint" { value = module.backstage_database.endpoint }
output "backstage_master_secret_arn" { value = module.backstage_database.master_secret_arn }
output "ecr_repository_urls" { value = module.ecr.repository_urls }
output "portal_url" { value = try(module.portal_edge[0].api_gateway_url, null) }

output "platform_configuration" {
  value = {
    aws             = { accountId = var.aws_account_id, region = var.aws_region, resourcePrefix = var.resource_prefix }
    git             = { repoURL = "https://github.com/rubiod1/mati-backstage-goldenpath", revision = "main", owner = "rubiod1", repo = "mati-backstage-goldenpath" }
    clusterName     = module.eks.cluster_name
    portalUrl       = try(module.portal_edge[0].api_gateway_url, "http://localhost:7007")
    githubSecretArn = aws_secretsmanager_secret.github.arn
    backstage       = { databaseHost = module.backstage_database.endpoint, databaseSecretArn = module.backstage_database.master_secret_arn, image = "${module.ecr.repository_urls["${var.resource_prefix}/backstage"]}:v1" }
    serviceImage    = "${module.ecr.repository_urls["${var.resource_prefix}/service-v0"]}:v1"
    pilot           = { namespace = "equipo-piloto", subnetGroup = aws_db_subnet_group.pilot.name, databaseSecurityGroup = aws_security_group.pilot_database.id, workloadSecurityGroup = aws_security_group.pilot_workloads.id, postgresVersion = var.postgres_engine_version, smallInstanceClass = var.pilot_small_database_instance_class, mediumInstanceClass = var.pilot_medium_database_instance_class }
  }
}

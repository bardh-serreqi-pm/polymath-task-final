module "network" {
  source = "./modules/network"

  project_name         = var.project_name
  environment          = var.environment
  tags                 = var.tags
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "data" {
  source = "./modules/data"

  providers = {
    aws           = aws
    aws.us_west_2 = aws.us_west_2
  }

  project_name                = var.project_name
  environment                 = var.environment
  tags                        = var.tags
  vpc_id                      = module.network.vpc_id
  private_subnet_ids          = module.network.private_subnet_ids
  vpc_cidr_block              = module.network.vpc_cidr_block
  db_name                     = var.db_name
  db_master_username          = var.db_master_username
  aurora_min_capacity         = var.aurora_min_capacity
  aurora_max_capacity         = var.aurora_max_capacity
  frontend_bucket_name        = var.frontend_bucket_name
  django_secret_key           = var.django_secret_key
  django_debug                = var.django_debug
  django_allowed_hosts        = var.django_allowed_hosts
  django_csrf_trusted_origins = var.django_csrf_trusted_origins
}

module "compute" {
  source = "./modules/compute"

  project_name                 = var.project_name
  environment                  = var.environment
  tags                         = var.tags
  vpc_id                       = module.network.vpc_id
  private_subnet_ids           = module.network.private_subnet_ids
  aurora_security_group_id     = module.data.aurora_security_group_id
  redis_security_group_id      = module.data.redis_security_group_id
  aurora_secret_arn            = module.data.aurora_secret_arn
  aurora_writer_endpoint_param = module.data.aurora_writer_endpoint_param_name
  redis_endpoint_param         = module.data.redis_endpoint_param_name
  lambda_image_uri             = var.lambda_image_uri
  lambda_environment           = var.lambda_environment
}

module "edge" {
  source = "./modules/edge"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project_name                         = var.project_name
  environment                          = var.environment
  tags                                 = var.tags
  frontend_bucket_name                 = module.data.frontend_bucket_name
  frontend_bucket_arn                  = module.data.frontend_bucket_arn
  frontend_bucket_regional_domain_name = module.data.frontend_bucket_regional_domain_name
  api_gateway_domain                   = module.compute.api_gateway_domain
  api_gateway_stage_name               = module.compute.api_gateway_stage_name
  frontend_domain_name                 = var.frontend_domain_name
}

module "observability" {
  source = "./modules/observability"

  project_name           = var.project_name
  environment            = var.environment
  tags                   = var.tags
  api_gateway_id         = module.compute.api_gateway_id
  api_gateway_stage_name = module.compute.api_gateway_stage_name
  lambda_function_name   = module.compute.lambda_function_name
  aurora_cluster_id      = module.data.aurora_cluster_id
  redis_cluster_id       = module.data.redis_cluster_id
  alert_email            = var.alert_email
}


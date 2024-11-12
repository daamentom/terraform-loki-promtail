provider "aws" {
  region  = "eu-north-1"
}

data "aws_availability_zones" "available" {}

locals {
  region      = "eu-north-1"
  cidr        = "10.5.0.0/16"
  name_suffix = "monitoring"
  zones = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
  tags        = { Terraform = true }
}

##########################
# VPC
##########################
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name                 = "loki-promtail"
  cidr                 = local.cidr
  azs                  = local.zones
  enable_nat_gateway   = true
  single_nat_gateway   = true

  create_database_subnet_group = true
  enable_dns_support           = true
  enable_dns_hostnames         = true

  public_subnets       = [for k, v in local.zones : cidrsubnet(local.cidr, 8, k + 0)]
  private_subnets      = [for k, v in local.zones : cidrsubnet(local.cidr, 8, k + 3)]
  database_subnets     = [for k, v in local.zones : cidrsubnet(local.cidr, 8, k + 6)]
  tags                 = local.tags
}

##########################
# ECS Cluster
##########################
module "cluster" {
  source       = "terraform-aws-modules/ecs/aws//modules/cluster"
  cluster_name = "cluster-loki-promtail"
  tags         = local.tags
}

###############################
# EFS for Shared Storage
###############################
module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  name    = "grafana-loki-efs"
  tags    = local.tags
  
  mount_targets = {
    for k, v in zipmap(local.zones, module.vpc.private_subnets) : k => {
      subnet_id = v
    }
  }

  security_group_vpc_id = module.vpc.vpc_id
  attach_policy         = false

  security_group_rules = {
    vpc = {
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
  }

}
##########################
# Grafana Service
##########################
module "grafana" {
  source             = "terraform-aws-modules/ecs/aws//modules/service"
  name               = "service-grafana"
  cluster_arn        = module.cluster.arn
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [module.vpc.default_security_group_id]

  container_definitions = {
    grafana = {
      image = "grafana/grafana:latest"
      port_mappings = [{ containerPort = 3000, hostPort = 3000 }]
      mount_points  = [{ sourceVolume = "grafana", containerPath = "/var/lib/grafana" }]
      environment   = [{ name = "GF_SECURITY_ADMIN_PASSWORD", value = "grafanaPassword" }]
    }
  }

  volume = {
    grafana = {
      efs_volume_configuration = { file_system_id = module.efs.id }
    }
  }
}

##########################
# Loki Service
##########################
module "loki" {
  source = "terraform-aws-modules/ecs/aws//modules/service"

  name               = "service-loki"
  cluster_arn        = module.cluster.arn
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [module.vpc.default_security_group_id]

  container_definitions = {
    loki = {
      image = "grafana/loki:latest"
      port_mappings = [
        { containerPort = 3100, hostPort = 3100 }
      ]
      mount_points = [
        { sourceVolume = "loki", containerPath = "/loki" }
      ]
      environment = [
        { name = "LOKI_STORAGE_PATH", value = "/loki" },
        { name = "LOKI_CONFIG_FILE", value = "/etc/loki/local-config.yaml" }
      ]
    }
  }

  volume = {
    loki = {
      efs_volume_configuration = {
        file_system_id = module.efs.id
      }
    }
  }
}

##########################
# Promtail Service
##########################
module "promtail" {
  source = "terraform-aws-modules/ecs/aws//modules/service"

  name               = "service-promtail"
  cluster_arn        = module.cluster.arn
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [module.vpc.default_security_group_id]

  container_definitions = {
    promtail = {
      image = "grafana/promtail:latest"
      port_mappings = [
        { containerPort = 3200, hostPort = 3200 }
      ]
      mount_points = [
        { sourceVolume = "promtail", containerPath = "/etc/promtail" }
      ]
      environment = [
        { name = "LOKI_URL", value = "http://loki:3100/loki/api/v1/push" }
      ]
    }
  }

  volume = {
    promtail = {
      efs_volume_configuration = {
        file_system_id = module.efs.id
      }
    }
  }
}


##########################
# Log Storage (S3 Bucket)
##########################
module "log_bucket" {
  source          = "terraform-aws-modules/s3-bucket/aws"
  bucket_prefix   = "${local.name_suffix}-logs-"
  acl             = "log-delivery-write"
  tags            = local.tags
  attach_lb_log_delivery_policy = true
}

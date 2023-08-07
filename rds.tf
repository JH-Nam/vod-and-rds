################################################################################
# RDS Aurora Module
################################################################################

resource "aws_rds_global_cluster" "this" {
  global_cluster_identifier = local.name
  engine                    = "aurora-mysql"
  engine_version            = "5.7.mysql_aurora.2.11.2"
  database_name             = "example_db"
  storage_encrypted         = true
}

module "aurora_primary" {
  source = "./rds_module"

  name                      = local.name
  database_name             = aws_rds_global_cluster.this.database_name
  engine                    = aws_rds_global_cluster.this.engine
  engine_version            = aws_rds_global_cluster.this.engine_version
  master_username           = local.master_username
  global_cluster_identifier = aws_rds_global_cluster.this.id
  instance_class            = "db.r5.large"
  instances                 = { for i in range(2) : i => {} }
  kms_key_id                = aws_kms_key.primary.arn
  publicly_accessible = local.publicly_accessible

  vpc_id               = module.primary_vpc.vpc_id
  db_subnet_group_name = module.primary_vpc.database_subnet_group_name
  security_group_rules = {
    vpc_ingress = {
      # cidr_blocks = module.primary_vpc.private_subnets_cidr_blocks
      cidr_blocks = local.ingress_all
    }
  }

  # Global clusters do not support managed master user password
  manage_master_user_password = false
  master_password             = local.password

  skip_final_snapshot = true

  tags = local.tags
}

module "aurora_secondary" {
  source = "./rds_module"

  providers = { aws = aws.secondary }

  is_primary_cluster = false

  name                      = local.name
  engine                    = aws_rds_global_cluster.this.engine
  engine_version            = aws_rds_global_cluster.this.engine_version
  global_cluster_identifier = aws_rds_global_cluster.this.id
  source_region             = local.primary_region
  instance_class            = "db.r5.large"
  instances                 = { for i in range(2) : i => {} }
  kms_key_id                = aws_kms_key.secondary.arn
  publicly_accessible = local.publicly_accessible

  vpc_id               = module.secondary_vpc.vpc_id
  db_subnet_group_name = module.secondary_vpc.database_subnet_group_name
  security_group_rules = {
    vpc_ingress = {
      # cidr_blocks = module.primary_vpc.private_subnets_cidr_blocks
      cidr_blocks = local.ingress_all
    }
  }

  # Global clusters do not support managed master user password
  master_password = local.password

  skip_final_snapshot = true

  depends_on = [
    module.aurora_primary
  ]

  tags = local.tags
}

################################################################################
# Supporting Resources
################################################################################

module "primary_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.primary_vpc_cidr

  azs              = local.primary_azs
  public_subnets   = [for k, v in local.primary_azs : cidrsubnet(local.primary_vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.primary_azs : cidrsubnet(local.primary_vpc_cidr, 8, k + 3)]
  database_subnets = [for k, v in local.primary_azs : cidrsubnet(local.primary_vpc_cidr, 8, k + 6)]

  create_database_subnet_route_table = local.create_database_subnet_route_table
  create_database_internet_gateway_route = local.create_database_internet_gateway_route

  tags = local.tags
}


module "secondary_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  providers = { aws = aws.secondary }

  name = local.name
  cidr = local.secondary_vpc_cidr

  azs              = local.secondary_azs
  public_subnets   = [for k, v in local.secondary_azs : cidrsubnet(local.secondary_vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.secondary_azs : cidrsubnet(local.secondary_vpc_cidr, 8, k + 3)]
  database_subnets = [for k, v in local.secondary_azs : cidrsubnet(local.secondary_vpc_cidr, 8, k + 6)]

  create_database_subnet_route_table = local.create_database_subnet_route_table
  create_database_internet_gateway_route = local.create_database_internet_gateway_route
  
  tags = local.tags
}

data "aws_iam_policy_document" "rds" {
  statement {
    sid       = "Enable IAM User Permissions"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
        data.aws_caller_identity.current.arn,
      ]
    }
  }

  statement {
    sid = "Allow use of the key"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    principals {
      type = "Service"
      identifiers = [
        "monitoring.rds.amazonaws.com",
        "rds.amazonaws.com",
      ]
    }
  }
}

resource "aws_kms_key" "primary" {
  policy = data.aws_iam_policy_document.rds.json
  tags   = local.tags
}

resource "aws_kms_key" "secondary" {
  provider = aws.secondary

  policy = data.aws_iam_policy_document.rds.json
  tags   = local.tags
}
module "vpc" {
  source  = "./vpc"
  project = var.project
}

module "eks" {
  source          = "./eks"
  project         = var.project
  vpc_id          = module.vpc.vpc_id
  public_subnets  = module.vpc.public_subnets
  private_subnets = module.vpc.private_subnets
}

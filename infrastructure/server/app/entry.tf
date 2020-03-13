#intializes variables from the ecs module to take variibles from the stage enviorment i.e. production, production
module "app" {
  source = "../modules/app"
  image = "${var.image}"
  environment = "${var.environment}"
  repository_name = "${var.repository_name}"
  ecs_IAMROLE = "${var.ecs_IAMROLE}"
  public_subnets = "${var.public_subnets}"
  private_subnets = "${var.private_subnets}"
  sg_security_groups = "${var.sg_security_groups}"
  region = "${var.region}"
  availability_zones = "${var.availability_zone}"
  ecr_account_path = "${var.ecr_account_path}"
  ecs_cluster = "${var.ecs_cluster}-${var.environment}"
}
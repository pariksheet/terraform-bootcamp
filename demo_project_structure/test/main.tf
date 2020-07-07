
module "vpc" {
  source            = "../modules/vpc"
  subnet_index      = var.subnet_index
}

module "nginx" {
  source            = "../modules/nginx"
  instance_type     = var.nginx_instance_type
  key_name          = "DEMO-KEY"
  eip               = "new"
  subnet_id         = lookup(module.vpc.vpc_map, "public_subnet_id")
  security_groups   = [lookup(module.vpc.vpc_map, "nginx_security_group")]
}

output "nginx_url" {
  description = "nginx url"
  value       = module.nginx.nginx_url
}
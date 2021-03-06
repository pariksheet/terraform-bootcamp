variable "subnet_index" {
  type = number
  description = "subnet index in 10.{}.0.0"
  default = 22
}

variable "nginx_instance_type" {
  default = "t2.nano"
}
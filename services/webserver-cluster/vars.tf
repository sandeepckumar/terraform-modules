variable "cluster-name" {
  type    = string
  default = "webserver-cluster"

}

variable "instance-type" {
  type = string

}

variable "ami" {
  type = string

}

variable "asg-min" {
  type = number
  default = 2

}

variable "asg-max" {
  type = number
  default = 5

}

variable "env" {
  type = string
  default = "dev"

}

variable "webserver-port" {
  type = number
  default = 8080

}

variable "lb-port" {
  type = number
  default = 80
}


variable "http_protocol" {
  type    = string
  default = "HTTP"

}


locals {
  allow-webserver-port = 8080
  allow-all-port       = 0
  allow-all-ip         = ["0.0.0.0/0"]
  allow-all-protocol   = "-1"
  tcp-protocol         = "tcp"
  allow-http-port      = 80
  sg_groups            = ["sg-webserver", "sg-elb"]
}
# VPC & Subnets data resource

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ASG & Launch Configuration 

data "template_file" "user_data" {
  template = file("${path.module}/user-data.sh")

  vars = {
    server-port = var.webserver-port
    env         = var.env
  }

}

resource "aws_launch_configuration" "example-launch-config" {
  image_id      = var.ami
  instance_type = var.instance-type
  user_data     = data.template_file.user_data.rendered
  security_groups = [
    for group in aws_security_group.example-sg : group.id
    if endswith(group.name, "sg-webserver")
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "webserver-asg" {
  name                 = "${var.env}-webserver-asg"
  health_check_type    = "ELB"
  target_group_arns    = [aws_lb_target_group.webserver-tg.arn]
  launch_configuration = aws_launch_configuration.example-launch-config
  vpc_zone_identifier  = data.aws_subnets.default.ids
  max_size             = var.asg-max
  min_size             = var.asg-min
  lifecycle {
    create_before_destroy = true
  }

}


# Security groups
resource "aws_security_group" "example-sg" {
  for_each = toset(local.sg_groups)
  name     = "${var.env}-${var.cluster-name}-${each.value}"
  vpc_id   = data.aws_vpc.default.id

}

resource "aws_security_group_rule" "allow_traffic_inbound" {
  for_each          = aws_security_group.example-sg
  type              = "ingress"
  security_group_id = each.value.id
  from_port         = endswith(each.value.name, "sg-webserver") ? local.allow-webserver-port : local.allow-http-port
  to_port           = endswith(each.value.name, "sg-webserver") ? local.allow-webserver-port : local.allow-http-port
  protocol          = local.tcp-protocol
  cidr_blocks       = local.allow-all-ip

}

resource "aws_security_group_rule" "allow_all_outbound" {
  for_each          = aws_security_group.example-sg
  type              = "egress"
  security_group_id = each.value.id
  from_port         = local.allow-all-port
  to_port           = local.allow-all-port
  protocol          = local.allow-all-protocol
  cidr_blocks       = local.allow-all-ip

}

# ELB Resources

resource "aws_lb_target_group" "webserver-tg" {
  name     = "${var.env}-webserver-tg"
  port     = var.webserver-port
  protocol = var.http_protocol
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = var.http_protocol
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

}

resource "aws_lb" "example-lb" {
  name               = "${var.env}-${var.cluster-name}-elb"
  load_balancer_type = "application"
  security_groups = [
    for group in aws_security_group.example-sg : group.id
    if endswith(group.name, "sg-elb")
  ]
  subnets = data.aws_subnets.default.ids

}

resource "aws_lb_listener" "example-elb-listener" {
  load_balancer_arn = aws_lb.example-lb.arn
  port              = var.lb-port
  protocol          = var.http_protocol

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }

}

resource "aws_lb_listener_rule" "example-elb-rule" {
  listener_arn = aws_lb_listener.example-elb-listener.arn
  priority     = 100
  condition {
    path_pattern {
      values = ["*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webserver-tg.arn
  }

}
/*====
ECS task definitions, this resource is only useful when building a service. It looks for a cluster or service (container)
to resgister task to.
======*/

  resource "aws_ecs_task_definition" "orderhistory" {
  family = "sg-orderhistoryclient-td-${var.environment}"
  requires_compatibilities = [
    "FARGATE"]
  network_mode = "awsvpc"
  cpu = "4 vCPU"
  memory = "30 GB"
  execution_role_arn = "${var.ecs_IAMROLE}"
  task_role_arn = "${var.ecs_IAMROLE}"
  container_definitions = <<EOF
        [
            {
              "name": "sg-orderhistoryclient-${var.environment}",
              "image": "${var.image}",
              "essential": true,
              "portMappings": [
                {
                    "containerPort": 9092,
                    "hostPort": 9092,
                    "protocol": "tcp"
                }
              ],
              "cpu": 4024,
              "memory": 30000,
              "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                  "awslogs-group": "orderhistory-client-${var.environment}",
                  "awslogs-region": "us-west-2",
                  "awslogs-stream-prefix": "orderhistory-client-${var.environment}"
                }
              }
            }
      ]
  EOF
}

data "aws_vpc" sg-vpc {
  tags {
    Name = "sg-vpc-${var.environment}"
  }
}

/*====
Security group
====*/
resource "aws_security_group" "orderhistory_cli_security_group" {
  name = "orderhistory-cli-security-group-${var.environment}"
  description = "orderhistory alb access rules"
  vpc_id = "${data.aws_vpc.sg-vpc.id}"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    # cidr_blocks = ["0.0.0.0/0"]
    self = "true"
  }

  #orderhistory client Port
  ingress {
    from_port = "9092"
    to_port = "9092"
    protocol = "TCP"
    # cidr_blocks = ["0.0.0.0/0"]
    self = "true"
  }

  #orderhistory server Port
  ingress {
    from_port = "50051"
    to_port = "50051"
    protocol = "TCP"
    # cidr_blocks = ["0.0.0.0/0"]
    self = "true"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  tags {
    Environment = "${var.environment}"
    Name = "orderhistory-cli-security-group-${var.environment}"
    Description = "orderhistory client SG"
  }
}

/*====
Load Balancer
orderhistory Gotcha: AWS ALB's DO NOT support HTTP/2
  -Can't put a front end ALB on a orderhistory service
  https://stackoverflow.com/questions/50345084/deploy-orderhistory-supporting-application-on-aws-using-alb
====*/
/*resource "aws_lb" "orderhistory" {
  name = "sg-bd-alb-orderhistory-${var.environment}"
  internal = true
  load_balancer_type = "application"
  security_groups = [
    "${aws_security_group.orderhistory_alb_security_group.id}"]
  subnets = [
    "${split(",", var.private_subnets[var.environment])}"]
  # enable_cross_zone_load_balancing = true -> network only
  enable_deletion_protection = false

  tags = {
    Name = "sg-bd-alb-orderhistory-${var.environment}"
    Environment = "${var.environment}"
  }
}

resource "aws_alb_target_group" "sg_orderhistory_alb_target_grp_cli" {
  name = "alb-orderhistory-grp-client-${var.environment}"
  target_type = "ip"
  port = 9092
  protocol = "HTTP"
  vpc_id = "${data.aws_vpc.sg-vpc.id}"
  health_check {
    path = "/"
    port = "traffic-port"
    protocol = "HTTP"
    healthy_threshold = 2
    unhealthy_threshold = 2
    interval = 30
    timeout = 10
    matcher = "302"
  }
  depends_on = [
    "aws_lb.orderhistory"]
}

resource "aws_alb_listener" "alb_orderhistory_listener_cli" {
  load_balancer_arn = "${aws_lb.orderhistory.arn}"
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = "${aws_alb_target_group.sg_orderhistory_alb_target_grp_cli.arn}"
    type = "forward"
  }
}

data "aws_route53_zone" "private" {
  name = "sg.orderhistory-${var.environment}"
  private_zone = true
}

resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.private.zone_id}"
  name = "sg.orderhistory-${var.environment}"
  type = "A"

  alias {
    name = "${aws_lb.orderhistory.dns_name}"
    zone_id = "${aws_lb.orderhistory.zone_id}"
    evaluate_target_health = true
  }
}*/
/*====
Load Balancer
====*/

resource "aws_service_discovery_service" "orderhistory_prvs_service" {
  name = "orderhistory-client"

  dns_config {
    /*
    already defined in the server, need to get Route 53 DNS to map to discoery service:

    aws_service_discovery_private_dns_namespace.orderhistory_prvs_dns: CANNOT_CREATE_HOSTED_ZONE: The VPC that you chose, vpc-0f6ca4e0694881aee
    in region us-west-2, is already associated with another private hosted zone that has an overlapping name space, sg.orderhistory
    */
    namespace_id = "${var.namespace}"

    dns_records {
      ttl = 100
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 2
  }
}

data "aws_ecs_task_definition" "td_orderhistoryclient" {
  task_definition = "${aws_ecs_task_definition.orderhistory.family}"
  depends_on = [
    "aws_ecs_task_definition.orderhistory"]
}

resource "aws_ecs_service" "orderhistoryclientservice" {
  name = "sg-orderhistoryclient-${var.environment}"
  task_definition = "${aws_ecs_task_definition.orderhistory.family}:${max("${aws_ecs_task_definition.orderhistory.revision}", "${data.aws_ecs_task_definition.td_orderhistoryclient.revision}")}"
  desired_count = 3
  launch_type = "FARGATE"
  cluster = "${var.ecs_cluster}"

  network_configuration {
    security_groups = [
      "${split(",", var.sg_security_groups[var.environment])}",
      "${aws_security_group.orderhistory_cli_security_group.id}"]
    subnets = [
      "${split(",", var.private_subnets[var.environment])}"]
    assign_public_ip = false
  }

  /*load_balancer {
    target_group_arn = "${aws_alb_target_group.sg_orderhistory_alb_target_grp_cli.arn}"
    container_name = "sg-orderhistoryclient-${var.environment}"
    container_port = 9092
  }*/

  service_registries {
    registry_arn = "${aws_service_discovery_service.orderhistory_prvs_service.arn}"
    container_name = "sg-orderhistoryclient-${var.environment}"
  }
}
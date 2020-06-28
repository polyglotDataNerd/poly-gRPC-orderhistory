/*====
ECS task definitions, this resource is only useful when building a service. It looks for a cluster or service (container)
to resgister task to.
======*/

resource "aws_ecs_task_definition" "orderhistory" {
  family = "sg-orderhistory-td-${var.environment}"
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
              "name": "sg-orderhistory-${var.environment}",
              "image": "${var.image}",
              "essential": true,
              "portMappings": [
                {
                    "containerPort": 50051,
                    "hostPort": 50051,
                    "protocol": "tcp"
                }
              ],
              "cpu":4024,
              "memory": 30000,
              "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                  "awslogs-group": "orderhistory-server-${var.environment}",
                  "awslogs-region": "us-west-2",
                  "awslogs-stream-prefix": "orderhistory-server-${var.environment}"
                }
              }
            }
      ]
  EOF
}

/*====
Security group
====*/
resource "aws_security_group" "orderhistory_srv_security_group" {
  name = "orderhistory-srv-security-group-${var.environment}"
  description = "orderhistory alb access rules"
  vpc_id = "${data.aws_vpc.sg-vpc.id}"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    #cidr_blocks = ["0.0.0.0/0"]
    self = "true"
  }

  #orderhistory server Port
  ingress {
    from_port = "50051"
    to_port = "50051"
    protocol = "TCP"
    #cidr_blocks = ["0.0.0.0/0"]
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
    Name = "orderhistory-srv-security-group-${var.environment}"
    Description = "orderhistory client SG"
  }
}


data "aws_vpc" sg-vpc {
  tags {
    Name = "sg-vpc-${var.environment}"
  }
}


data "aws_ecs_task_definition" "td_orderhistory" {
  task_definition = "${aws_ecs_task_definition.orderhistory.family}"
  depends_on = [
    "aws_ecs_task_definition.orderhistory"]
}


/*
service discovery for ECS server to talk to ECS client without ALB
https://aws.amazon.com/blogs/aws/amazon-ecs-service-discovery/
*/
resource "aws_service_discovery_private_dns_namespace" "orderhistory_prvs_dns" {
  name = "orderhistory-${var.environment}"
  description = "private dns namespace for orderhistory discovery service: ${var.environment}"
  vpc = "${data.aws_vpc.sg-vpc.id}"
}

resource "aws_service_discovery_service" "orderhistory_prvs_service" {
  name = "orderhistory-server"

  dns_config {
    namespace_id = "${aws_service_discovery_private_dns_namespace.orderhistory_prvs_dns.id}"

    dns_records {
      ttl = 100
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_service" "orderhistoryservice" {
  name = "sg-orderhistory-${var.environment}"
  task_definition = "${aws_ecs_task_definition.orderhistory.family}:${max("${aws_ecs_task_definition.orderhistory.revision}", "${data.aws_ecs_task_definition.td_orderhistory.revision}")}"
  desired_count = 3
  launch_type = "FARGATE"
  cluster = "${var.ecs_cluster}"

  network_configuration {
    security_groups = [
      "${split(",", var.sg_security_groups[var.environment])}",
      "${aws_security_group.orderhistory_srv_security_group.id}"]
    subnets = [
      "${split(",", var.private_subnets[var.environment])}"]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = "${aws_service_discovery_service.orderhistory_prvs_service.arn}"
    container_name = "sg-orderhistory-${var.environment}"
  }
}
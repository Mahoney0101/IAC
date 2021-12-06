terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

resource "aws_instance" "testapi" {
  ami           = "ami-05cd35b907b4ffe77"
  instance_type = "t2.micro"
  key_name      = "skel"
}

resource "aws_ecs_cluster" "ecs_cluster"{
  name = "ecs_cluster"
}

resource "aws_ecs_task_definition" "ecs_task" {
  family                   = "ecs_task" 
  container_definitions    = <<DEFINITION
  [
    {
      "name": "ecs_task",
      "image": "public.ecr.aws/n8r1x3c4/testapi:0.0.0.1",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 443,
          "hostPort": 443
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] 
  network_mode             = "awsvpc"    
  memory                   = 512         
  cpu                      = 256         
  execution_role_arn       = "${aws_iam_role.ecsTaskExecutionRole.arn}"
}

resource "aws_iam_role" "ecsTaskExecutionRole"{
  name			= "ecsTaskExecutionRole"
  assume_role_policy	= "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy"{
  statement{
    actions = ["sts:AssumeRole"]

    principals{
      type = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role		      = "${aws_iam_role.ecsTaskExecutionRole.name}"
  policy_arn    = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_service" "ecs_service" {
  name            = "ecs_service"
  cluster         = "${aws_ecs_cluster.ecs_cluster.id}"
  task_definition = "${aws_ecs_task_definition.ecs_task.arn}" 
  launch_type     = "FARGATE"
  desired_count   = 1
  
  load_balancer {
    target_group_arn = "${aws_lb_target_group.target_group.arn}"
    container_name   = "${aws_ecs_task_definition.ecs_task.family}"
    container_port   = 443 # Specifying the container port
  }

    network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}", "${aws_default_subnet.default_subnet_c.id}"]
    assign_public_ip = true 
  }
}

  resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0 
    to_port     = 0 
    protocol    = "-1" 
    cidr_blocks = ["0.0.0.0/0"] 
  }
}

resource "aws_default_vpc" "default_vpc" {
}

resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "eu-west-1a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "eu-west-1b"
}

resource "aws_default_subnet" "default_subnet_c" {
  availability_zone = "eu-west-1c"
}

resource "aws_alb" "application_load_balancer" {
  name               = "test-lb-tf" 
  load_balancer_type = "application"
  subnets = [ 
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}",
    "${aws_default_subnet.default_subnet_c.id}"
  ]

  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

# Creating a security group for the load balancer:
resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = 443 
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0 
    to_port     = 0 
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 443
  protocol    = "HTTPS"
  target_type = "ip"
  vpc_id      = "${aws_default_vpc.default_vpc.id}"
  health_check {
    matcher = "200,301,302"
    path = "/"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_alb.application_load_balancer.arn}"
  port              = "443"
  protocol          = "HTTPS"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}"
  }
}

resource "aws_route53_record" "SOA" {
  zone_id     = "Z025977923QVVK03STT5E"
  type        ="SOA"
  name        ="mahoney0101.com"
  ttl         ="900"
  records     = [
              "ns-1354.awsdns-41.org. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"
            ]
}

resource "aws_route53_record" "A" {
  zone_id     = "Z025977923QVVK03STT5E"
  type        ="A"
  name        ="mahoney0101.com"
  records     = [
              "54.74.71.162"
            ]
  ttl         =300
}

resource "aws_route53_record" "NS" {
  zone_id     = "Z025977923QVVK03STT5E"
  type        ="NS"
  name        ="mahoney0101.com"
  records     =[
              "ns-1354.awsdns-41.org.",
              "ns-1634.awsdns-12.co.uk.",
              "ns-258.awsdns-32.com.",
              "ns-577.awsdns-08.net."
            ]
  ttl         = 172800
}

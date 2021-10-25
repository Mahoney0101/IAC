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
  family                   = "ecs_task" # Naming our first task
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
    actions = ["sts.AssumeRole"]

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

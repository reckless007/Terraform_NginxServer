provider "aws" {
  region = var.aws_region
}

resource "aws_security_group" "security_nginx_port" {
  name        = "security_nginx_port"
  description = "security group for nginx"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 # outbound from jenkis server
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags= {
    Name = "security_nginx_port"
  }
}

resource "aws_instance" "myFirstInstance" {
  ami           = "ami-04505e74c0741db8d"
  key_name = var.key_name
  instance_type = var.instance_type
  security_groups= [ "security_nginx_port"]
  tags= {
    Name = "nginx_instance"
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get update -y
              sudo apt-get install python3 -y
              sudo apt-get install python3-pip -y
              sudo pip3 install flask
              sudo apt-get install nginx -y
              sudo apt-get install gunicorn -y
              sudo rm -rf /etc/nginx/sites-enabled/default
              git clone https://github.com/reckless007/PythonForm.git /home/ubuntu/flaskapp
              sudo git clone https://github.com/reckless007/gunicorn.git /etc/nginx/sites-enabled/
              sudo systemctl restart nginx
              chmod +x /home/ubuntu/flaskapp/script.sh
              gunicorn --chdir /home/ubuntu/flaskapp  app:app --daemon
              EOF  
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}
data "aws_subnet_ids" "subnet" {
  vpc_id = "${aws_default_vpc.default.id}"
  
}
resource "aws_lb_target_group" "my-nginx-group" {
  health_check {
    interval            = 10
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "my-nginx-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = "${aws_default_vpc.default.id}"
}

resource "aws_lb" "my_nginx_elb" {
  name = "nginx-elb"
  internal = false
  security_groups = [
    "${aws_security_group.security_nginx_port.id}",
  ]
  subnets = data.aws_subnet_ids.subnet.ids
  tags = {
    Name = "nginx-elb"
  }
  ip_address_type = "ipv4"
  load_balancer_type = "application"
}
resource "aws_lb_listener" "name" {
  load_balancer_arn = aws_lb.my_nginx_elb.arn
       port = 80
       protocol = "HTTP"
       default_action {
         target_group_arn = "${aws_lb_target_group.my-nginx-group.arn}"
         type = "forward"
       }
}
resource "aws_lb_target_group_attachment" "my_nginx_ec2" {
  target_group_arn = aws_lb_target_group.my-nginx-group.arn
  target_id        = aws_instance.myFirstInstance.id
  port             = 80
}
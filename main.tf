variable "access_key" {
    type = string
}

variable "secret_key" {
    type = string
}

provider "aws" {
    region = "eu-west-2"
    access_key = var.access_key 
    secret_key = var.secret_key 
}

resource "aws_vpc" "my-vpc" {
    cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "my-gateway" {
    vpc_id = aws_vpc.my-vpc.id
}

resource "aws_route_table" "my-route-table" {
    vpc_id = aws_vpc.my-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my-gateway.id
    }

    route {
        ipv6_cidr_block = "::/0"
        gateway_id =aws_internet_gateway.my-gateway.id
    }
}

resource "aws_subnet" "my-subnet" {
    vpc_id = aws_vpc.my-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-west-2a"
}

resource "aws_route_table_association" "my-association" {
    subnet_id = aws_subnet.my-subnet.id
    route_table_id = aws_route_table.my-route-table.id
}

resource "aws_security_group" "my-security-group" {
    name = "allow_web_traffic"
    description = "Allow web traffic on 22, 80, 443"
    vpc_id = aws_vpc.my-vpc.id

    ingress {
        description = "HTTPS"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "HTTP"
        from_port = 80 
        to_port = 80 
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "SSH"
        from_port = 22 
        to_port = 22 
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

}

resource "aws_network_interface" "my-interface" {
    subnet_id = aws_subnet.my-subnet.id
    private_ips = ["10.0.1.50"]
    security_groups = [aws_security_group.my-security-group.id]
}

resource "aws_eip" "my-elastic-ip" {
    vpc = true
    network_interface = aws_network_interface.my-interface.id
    associate_with_private_ip = "10.0.1.50"
    depends_on = [aws_internet_gateway.my-gateway]
}

resource "aws_instance" "my-ubuntu-server" {
    ami = "ami-0fb391cce7a602d1f" 
    instance_type = "t2.micro"
    availability_zone = "eu-west-2a"
    key_name = "terraform-learning"

    network_interface {
        device_index = 0    
        network_interface_id = aws_network_interface.my-interface.id
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y 
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c "echo your very first web server > /var/www/html/index.html"
                EOF
    tags = {
        Name = "web-server"
    }
}

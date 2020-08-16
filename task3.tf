provider "aws"{
    region = "ap-south-1"
    profile = "tasks"
}

#vpc
resource "aws_vpc" "vpc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags= {
     Name = "vpc"
}
}

# public_subnet
resource "aws_subnet" "subnet_pub" {

  vpc_id            = aws_vpc.vpc.id
  availability_zone = "ap-south-1a"
  cidr_block        = "192.168.1.0/24"
  map_public_ip_on_launch = true
  depends_on = [aws_vpc.vpc]
  tags= {
     Name = "subnet_pub"
}
}

# private_subnet
resource "aws_subnet" "subnet_pri" {

  vpc_id            = aws_vpc.vpc.id
  availability_zone = "ap-south-1b"
  cidr_block        = "192.168.2.0/24"
  map_public_ip_on_launch = false
  depends_on = [aws_vpc.vpc]
  tags= {
     Name = "subnet_pri"
}
}

# Internet Gateway
resource "aws_internet_gateway" "IG" {

  vpc_id = aws_vpc.vpc.id
  depends_on = [aws_vpc.vpc]
  tags = {
    Name = "IG"
  }
}
# routetable for IG
 resource "aws_route_table" "IGroute" {

  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IG.id
  }
  depends_on = [aws_vpc.vpc]
  tags = {
    Name = "IGroute"
  }
}

resource "aws_route_table_association" "IG-assoc" {
   subnet_id      = aws_subnet.subnet_pub.id
  route_table_id = aws_route_table.IGroute.id
  depends_on = [aws_subnet.subnet_pub]
}


resource "aws_security_group" "sg_pub" {
  name        = "sg_pub"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc.id

 ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [aws_vpc.vpc]

  tags = {
    Name = "sg_pub"
  }
}

resource "aws_instance" "wp_pub" {
  ami           = "ami-049cbce295a54b26b"
  instance_type = "t2.micro"
  key_name      = "mycloudtrain"
  subnet_id =  aws_subnet.subnet_pub.id
  vpc_security_group_ids = [ "${aws_security_group.sg_pub.id}"]
  
  tags = {
    Name = "wp_pub"
  }
}

output "WpIp"{
  value=aws_instance.wp_pub.public_ip
}

resource "aws_security_group" "sg_mysql" {
  name        = "basic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "sg_mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [aws_vpc.vpc]

  tags = {
    Name = "sg_mysql"
  }
}

resource "aws_instance" "mysql_pri" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name      = "mycloudtrain"
  subnet_id =  aws_subnet.subnet_pri.id
  vpc_security_group_ids = [aws_security_group.sg_mysql.id]
  
  tags = {
    Name = "mysql_pri"
  }
}

resource "null_resource" "ret" {
depends_on = [aws_instance.wp_pub,aws_instance.mysql_pri]

connection {
        type        = "ssh"
    	user        = "ec2-user"
    	private_key = file("C:/Users/SaiSundarMasetty/Downloads/mycloudtrain.ppk")
        host     = aws_instance.wp_pub.public_ip
        }

provisioner "local-exec" {    
      command = "start msedge  http://${aws_instance.wp_pub.public_ip}/wordpress"
   }
}


 

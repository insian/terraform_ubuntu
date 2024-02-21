resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "My VPC"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a" # Replace with your desired AZ

  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Internet Gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table_association" "public_subnet_route_table_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_security_group" "ssh" {
  name   = "SSH"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict this for production environments
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SSH Security Group"
  }
}

resource "tls_private_key" "my_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

data "tls_public_key" "my_key_pair_public" {
  private_key_pem = tls_private_key.my_key_pair.private_key_pem
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = "my-keypair"  # Name of the key pair
  public_key = data.tls_public_key.my_key_pair_public.public_key_openssh
}

resource "local_file" "ssh_key" { 
  filename = "${aws_key_pair.my_key_pair.key_name}.pem"
  content = tls_private_key.my_key_pair.private_key_pem
  file_permission = "0400"
}

resource "aws_instance" "webserver" {
  ami                    = "ami-06aa3f7caf3a30282" # Replace with your desired AMI
  instance_type          = "t2.micro"             # Replace with your desired instance type
  vpc_security_group_ids = [aws_security_group.ssh.id]
  subnet_id              = aws_subnet.public.id
  associate_public_ip_address = true
  key_name        = aws_key_pair.my_key_pair.key_name  # Specify the key pair name here

  tags = {
    Name = "Ubuntu Server"
  }

  # Consider adding user data script for initial configuration like installing java, jenkins, mysql,etc
  # user_data = file("user_data.sh")  
}

output "public_ip" {
  value = aws_instance.webserver.public_ip
}



# 1. Networking: VPC & Subnet
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # Makes it a Public Subnet
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# 2. Security: Firewall Rules
resource "aws_security_group" "web_sg" {
  name   = "allow_web_traffic"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # SSH Access
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Production (K8s via Nginx)
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Development (Docker via Nginx)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow server to talk to internet
  }
}

# 3. Storage: ECR Repository
resource "aws_ecr_repository" "app_repo" {
  name                 = "book-shop"
  image_tag_mutability = "MUTABLE" # Allows re-tagging for promotion
}

# 4. Compute: EC2 Instance
resource "aws_instance" "dev_prod_server" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS (Verify for your region)
  instance_type = var.instance_type
  user_data = file("scripts/setup.sh")
  subnet_id     = aws_subnet.public.id
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  root_block_device {
    volume_size = 30 # Your requirement: 30GB
  }

  tags = { Name = "${var.project_name}-server" }
}
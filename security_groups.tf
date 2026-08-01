# Public instance: allow SSH from your IP only, and HTTP from anywhere
# (adjust to your actual use case, e.g. remove HTTP if not running a web server).
resource "aws_security_group" "public" {
  name        = "${var.project_name}-public-sg"
  description = "Public instance SG: SSH from admin IP, HTTP from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project_name}-public-sg" })
}

# Private instance: only reachable from inside the VPC (e.g. from the
# public instance acting as a bastion/app tier talking to it).
resource "aws_security_group" "private" {
  name        = "${var.project_name}-private-sg"
  description = "Private instance SG: access only from within the VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from within VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "All TCP from within VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project_name}-private-sg" })
}

# Latest Amazon Linux 2023 AMI, resolved at plan/apply time so we never
# hardcode a stale/region-specific AMI ID.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "public" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.public.id]
  associate_public_ip_address = true
  key_name                    = var.key_pair_name != "" ? var.key_pair_name : null

  tags = merge(local.tags, { Name = "${var.project_name}-public-ec2" })
}

resource "aws_instance" "private" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.private.id]
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  tags = merge(local.tags, { Name = "${var.project_name}-private-ec2" })
}

resource "aws_ec2_instance_state" "public" {
  instance_id = aws_instance.public.id
  state       = var.instance_state
}

resource "aws_ec2_instance_state" "private" {
  instance_id = aws_instance.private.id
  state       = var.instance_state
}

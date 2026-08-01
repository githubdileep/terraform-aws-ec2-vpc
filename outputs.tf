output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_instance_id" {
  value = aws_instance.public.id
}

output "public_instance_public_ip" {
  value = aws_instance.public.public_ip
}

output "private_instance_id" {
  value = aws_instance.private.id
}

output "private_instance_private_ip" {
  value = aws_instance.private.private_ip
}

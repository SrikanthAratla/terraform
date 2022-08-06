output "vpc_id" {
  value = aws_vpc.prod_vpc.id
}

output "vpc_arn" {
  value = aws_vpc.prod_vpc.arn
}

output "server_public_ip" {
  value = aws_instance.prod_instance.public_ip
}

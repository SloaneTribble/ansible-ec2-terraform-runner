output "ec2_public_ip" {
  value = [for instance in module.ec2_instance : instance.public_ip]
}

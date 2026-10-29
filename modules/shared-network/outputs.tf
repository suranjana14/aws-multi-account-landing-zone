output "transit_gateway_id" {
  description = "Transit Gateway that workload VPCs attach to."
  value       = aws_ec2_transit_gateway.this.id
}

output "egress_vpc_id" {
  description = "Central egress VPC ID."
  value       = aws_vpc.egress.id
}

output "ram_share_arn" {
  description = "RAM share making the TGW visible to every org account."
  value       = aws_ram_resource_share.tgw.arn
}

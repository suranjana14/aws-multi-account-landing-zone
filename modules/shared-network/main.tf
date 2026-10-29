data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  # /22 split into /26s: public[0..2], tgw-attachment[4..6]
  public_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  tgw_cidrs    = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 4)]
}

################################################################################
# Transit Gateway (hub), shared to every account in the organization
################################################################################

resource "aws_ec2_transit_gateway" "this" {
  description                     = "${var.name} hub"
  amazon_side_asn                 = 64512
  auto_accept_shared_attachments  = "enable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  tags                            = merge(var.tags, { Name = "${var.name}-tgw" })
}

resource "aws_ram_resource_share" "tgw" {
  name                      = "${var.name}-tgw"
  allow_external_principals = false
  tags                      = var.tags
}

resource "aws_ram_resource_association" "tgw" {
  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

resource "aws_ram_principal_association" "org" {
  principal          = var.organization_arn
  resource_share_arn = aws_ram_resource_share.tgw.arn
}

################################################################################
# Egress VPC
################################################################################

resource "aws_vpc" "egress" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "${var.name}-egress" })
}

resource "aws_default_security_group" "egress" {
  vpc_id = aws_vpc.egress.id
  tags   = merge(var.tags, { Name = "${var.name}-default-deny" })
  # No ingress/egress blocks: the default SG allows nothing.
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.egress.id
  tags   = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id            = aws_vpc.egress.id
  cidr_block        = local.public_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags              = merge(var.tags, { Name = "${var.name}-public-${local.azs[count.index]}" })
}

resource "aws_subnet" "tgw" {
  count = var.az_count

  vpc_id            = aws_vpc.egress.id
  cidr_block        = local.tgw_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags              = merge(var.tags, { Name = "${var.name}-tgw-${local.azs[count.index]}" })
}

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? var.az_count : 0
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-nat-${local.azs[count.index]}" })
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? var.az_count : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = merge(var.tags, { Name = "${var.name}-nat-${local.azs[count.index]}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_ec2_transit_gateway_vpc_attachment" "egress" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = aws_vpc.egress.id
  subnet_ids         = aws_subnet.tgw[*].id
  dns_support        = "enable"
  tags               = merge(var.tags, { Name = "${var.name}-egress" })
}

# Public subnets: internet via IGW, spokes back via TGW.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.egress.id
  tags   = merge(var.tags, { Name = "${var.name}-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route" "public_to_spokes" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = var.spoke_cidr_supernet
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.egress]
}

resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# TGW subnets: everything leaving the org goes to the NAT in the same AZ.
resource "aws_route_table" "tgw" {
  count = var.az_count

  vpc_id = aws_vpc.egress.id
  tags   = merge(var.tags, { Name = "${var.name}-tgw-${local.azs[count.index]}" })
}

resource "aws_route" "tgw_to_nat" {
  count = var.enable_nat_gateway ? var.az_count : 0

  route_table_id         = aws_route_table.tgw[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index].id
}

resource "aws_route_table_association" "tgw" {
  count = var.az_count

  subnet_id      = aws_subnet.tgw[count.index].id
  route_table_id = aws_route_table.tgw[count.index].id
}

# Default route on the TGW so every spoke egresses through this VPC.
resource "aws_ec2_transit_gateway_route" "default_egress" {
  count = var.enable_nat_gateway ? 1 : 0

  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.egress.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway.this.association_default_route_table_id
}

################################################################################
# Flow logs to the central archive
################################################################################

resource "aws_flow_log" "egress" {
  count = var.flow_log_bucket_arn == null ? 0 : 1

  vpc_id               = aws_vpc.egress.id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = "${var.flow_log_bucket_arn}/vpc-flow-logs/"

  destination_options {
    file_format                = "parquet"
    per_hour_partition         = true
    hive_compatible_partitions = true
  }

  tags = var.tags
}

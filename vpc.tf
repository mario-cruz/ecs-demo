resource "aws_vpc" "vpc_app" {
  #checkov:skip=CKV2_AWS_11
  #checkov:skip=CKV2_AWS_12
  cidr_block = var.network_cidr
  tags = merge(
    var.additional-tags,
    {
      Name = "MyVPC"
    },
  )
}

resource "aws_subnet" "public" {
  #checkov:skip=CKV_AWS_130
  count                   = 2
  cidr_block              = cidrsubnet(aws_vpc.vpc_app.cidr_block, 3, count.index)
  availability_zone       = data.aws_availability_zones.available_zones.names[count.index]
  vpc_id                  = aws_vpc.vpc_app.id
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private" {
  count             = 2
  cidr_block        = cidrsubnet(aws_vpc.vpc_app.cidr_block, 3, 2 + count.index)
  availability_zone = data.aws_availability_zones.available_zones.names[count.index]
  vpc_id            = aws_vpc.vpc_app.id
}

resource "aws_subnet" "db" {
  count             = 2
  cidr_block        = cidrsubnet(aws_vpc.vpc_app.cidr_block, 3, 4 + count.index)
  availability_zone = data.aws_availability_zones.available_zones.names[count.index]
  vpc_id            = aws_vpc.vpc_app.id
}

resource "aws_internet_gateway" "igateway" {
  vpc_id = aws_vpc.vpc_app.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.vpc_app.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igateway.id
}

resource "aws_eip" "gateway" {
  #checkov:skip=CKV2_AWS_19
  count      = 2
  depends_on = [aws_internet_gateway.igateway]
}

resource "aws_nat_gateway" "ngateway" {
  count         = 2
  subnet_id     = element([for subnet in aws_subnet.public : subnet.id], count.index)
  allocation_id = element([for eip in aws_eip.gateway : eip.id], count.index)
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.vpc_app.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element([for nat_gateway in aws_nat_gateway.ngateway : nat_gateway.id], count.index)
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = element([for subnet in aws_subnet.private : subnet.id], count.index)
  route_table_id = element([for route_table in aws_route_table.private : route_table.id], count.index)
}
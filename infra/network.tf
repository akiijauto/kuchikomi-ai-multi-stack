# NATゲートウェイもALBも作らない。
# NATは月$40前後、ALBは月$20前後の固定費になり、$10予算では成立しないため。
# その代わり ECSタスクをパブリックサブネットに置き、パブリックIPを直接付ける。
#   → 公開範囲は var.allowed_cidr（セキュリティグループ）だけで決まる点に注意。

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name}-igw" }
}

# RDSのサブネットグループは2AZ以上を要求するため、パブリックサブネットも2つ作る
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.name}-public-${count.index}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.name}-public" }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- セキュリティグループ ---

resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "ECS task. inbound app port only"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.name}-app" }
}

resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  description       = "アプリへの直接アクセス（ALBを置かないため）"
  cidr_ipv4         = var.allowed_cidr
  from_port         = 3000
  to_port           = 3000
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "ECRからのpull・Supabase/Anthropicへの外向き通信"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db"
  description = "RDS. only from app security group"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.name}-db" }
}

# 送信元をCIDRではなくアプリのセキュリティグループにする。
# パブリックサブネット上にあってもDBへ届くのはアプリのタスクだけになる。
resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from app tasks only"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

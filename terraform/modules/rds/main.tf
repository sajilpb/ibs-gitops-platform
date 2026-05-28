resource "random_password" "db_password" {
  length  = var.db_password_length
  special = false
}

resource "aws_db_subnet_group" "default" {
  name        = "${var.db_name}-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "Subnet group for ${var.db_name} RDS instance"
}

resource "aws_security_group" "db_access" {
  name        = "${var.db_name}-db-sg"
  description = "Allow EKS nodes to access RDS"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "db_ingress" {
  description              = "Allow EKS node group access to RDS"
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db_access.id
  source_security_group_id = var.eks_security_group_id
}

resource "aws_security_group_rule" "db_egress" {
  description       = "Allow RDS outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.db_access.id
}

resource "aws_db_instance" "default" {
  allocated_storage          = var.db_allocated_storage
  db_name                    = var.db_name
  engine                     = var.db_engine
  engine_version             = var.db_engine_version
  instance_class             = var.db_instance_class
  username                   = var.db_username
  password                   = random_password.db_password.result
  port                       = 5432
  db_subnet_group_name       = aws_db_subnet_group.default.name
  vpc_security_group_ids     = [aws_security_group.db_access.id]
  publicly_accessible        = false
  skip_final_snapshot        = true
  deletion_protection        = false
  backup_retention_period    = 0
  apply_immediately          = true
  storage_type               = "gp3"
  multi_az                   = false
  auto_minor_version_upgrade = true
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = var.secrets_manager_secret_name
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    host     = aws_db_instance.default.address
    port     = tostring(aws_db_instance.default.port)
    name     = var.db_name
    ssl      = "true"
  })
}
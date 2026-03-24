provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "myntra_vpc" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "myntra-vpc"
  }
}

resource "aws_subnet" "myntra_subnet" {
  vpc_id            = aws_vpc.myntra_vpc.id
  cidr_block        = cidrsubnet  (aws_vpc.myntra_vpc.cidr_block, 8, count.index)
  availability_zone = element(([us-east-1a, us-east-1b]), count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "myntra-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "myntra_igw" {
  vpc_id = aws_vpc.myntra_vpc.id

  tags = {
    Name = "myntra-igw"
  }
}

resource "aws_route_table" "myntra_route_table" {
  vpc_id = aws_vpc.myntra_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myntra_igw.id
}
  tags = {
    Name = "myntra-route-table"
  }
}

resource "aws_route_table_association" "a" {
  count = 2
  subnet_id      = aws_subnet.myntra_subnet[count.index].id
  route_table_id = aws_route_table.myntra_route_table.id
}

resource "aws_security_group" "myntra_cluster_sg" {
  vpc_id = aws_vpc.myntra_vpc.id


  egress = {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "myntra-cluster-sg"
  }
}

resource "aws_security_group" "myntra_node_sg" {
  vpc_id = aws_vpc.myntra_vpc.id

  ingress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "myntra-node-sg"
    }
}

resource "aws_eks_cluster" "myntra" {
  name     = "myntra-eks-cluster"
  role_arn = aws_iam_role.myntra_eks_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.myntra_subnet[*].id
    security_group_ids = [aws_security_group.myntra_cluster_sg.id]
  }

  tags = {
    Name = "myntra-eks-cluster"
  }
}

resource "aws_eks_node_group" "myntra" {
  cluster_name = aws_eks_cluster.myntra.name
  node_group_name = "myntra-node-group"
  node_role_arn = aws_iam_role.myntra_node_role.arn
  subnet_ids = aws_subnet.myntra_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  tags = {
    Name = "myntra-node-group"
  }

  instance_types = ["c7i-Flex.large"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.myntra_node_sg.id]
  }
}

resource "aws_iam_role" "myntra_cluster_role" {
  name = "myntra-eks-cluster-role"

  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
    {
      "Effect":"Allow",
      "Principal":{
        "Service":"eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
      ]
  }
  
  EOF
}

resource "aws_iam_role_policy_attachment" "mytra_node_cluster_role_policy" {
  role = aws_iam_role.myntra_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "myntra_node_group_role" {
  name = "myntra-eks-node-group-role"

  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
    {
      "Effect":"Allow",
      "Principal":{
        "Service":"ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
      ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "myntra_node_group_role_policy" {
  role = aws_iam_role.myntra_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "myntra_cni_policy" {
  role = aws_iam_role.myntra_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "myntra_registry_policy" {
  role = aws_iam_role.myntra_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


  
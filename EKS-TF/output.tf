output "cluster_id" {
    value = aws_eks_cluster.myntra.id
}

output "node_group_id" {
    value = aws_eks_node_group.myntra.id
}

output "vpc_id" {
    value = aws_vpc.myntra_vpc.id
}

output "subnet_id" {
    value = aws_subnet.myntra_subnet[*].id
}
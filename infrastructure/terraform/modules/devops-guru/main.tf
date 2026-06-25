
resource "aws_devopsguru_resource_collection" "this" {
  count = var.enable_devops_guru ? 1 : 0

  type = "AWS_TAGS"

  tags {
    app_boundary_key = var.app_boundary_key
    tag_values       = var.tag_values
  }
}

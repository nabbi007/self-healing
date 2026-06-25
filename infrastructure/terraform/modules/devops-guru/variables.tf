variable "enable_devops_guru" {
  description = "Whether to enable DevOps Guru (incurs cost)."
  type        = bool
  default     = true
}

variable "app_boundary_key" {
  description = "Tag key defining the DevOps Guru analysis boundary (must start with 'Devops-guru-')."
  type        = string
  default     = "Devops-guru-techstream"
}

variable "tag_values" {
  description = "Tag values included in the DevOps Guru boundary."
  type        = list(string)
  default     = ["enabled"]
}

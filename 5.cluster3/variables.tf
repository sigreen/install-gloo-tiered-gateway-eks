
variable "name" {
  description = "cluster name"
  type        = string
  default     = "cluster-3"
}

variable "region" {
  default     = "us-east-2"
  type = string
  description = "AWS region"
}

variable "profile" {
  default     = "customer-poc"
  type = string
  description = "AWS credentials profile"
}

variable "aws-tag-name" {
  default = "simongreen"
  type = string
  description = "AWS descriptive tag"
}

variable "created-by" {
  default = "simon_green"
  type = string
  description = "AWS descriptive tag"
}

variable "team" {
  default = "field-engineering"
  type = string
  description = "AWS descriptive tag"
}

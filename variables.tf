variable "region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "resume-api"
}

variable "environment" {
  description = "Deployment environment (staging or production)"
  type        = string
}
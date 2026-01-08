terraform {
  backend "s3" {
    bucket         = "dlittle-cloud-resume-terraform-state"
    key            = "resume-api/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks" 
    encrypt        = true
  }
}
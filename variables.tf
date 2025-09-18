variable "region" {
  type    = string
  default = "us-west-2"  # UPDATE THIS ~
}

variable "name" {
  type    = string
  default = ""  # UPDATE THIS ~
}
variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16" # Only use this, if it doesn't overlap with current setup # UPDATE THIS ~
}
variable "azs" {
  type    = list(string)
  default = ["us-west-2a", "us-west-2b"] # UPDATE THIS ~
}
variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.42.1.0/24", "10.42.2.0/24"] # Only use this, if it doesn't overlap with current setup # UPDATE THIS ~
}

# Change your image here.
variable "container_image" {
  type    = string
  default = "<# ACC ID HERE #>.dkr.ecr.us-west-2.amazonaws.com/<# NAME OF IMAGE HERE #>:latest" # UPDATE THIS ~
}

variable "ecr_app_name" {
  type = string
  default = "" # UPDATE THIS ~ # Use account pattern if one is present
}

# Need more power, i.e. processing, increase
variable "cpu" {
  type    = number
  default = 256
}

# Need concurrent requests, or large file parsing, increase
variable "memory" {
  type    = number
  default = 512
}

variable "s3_bucket_arn" {
  type    = string
  default = "arn:aws:s3:::<ADD BUCKET NAME HERE>" # UPDATE THIS ~
}


variable "s3_bucket_name" {
  type    = string
  default = "<ADD BUCKET NAME HERE>" # UPDATE THIS ~
}


# If you need filtering for the uploads, # UPDATE THIS ~
# e.g., "inbound/"
variable "s3_prefix" {
  type    = string
  default = ""
}

# If you need filtering for the uploads, # UPDATE THIS ~
# e.g., ".csv"
variable "s3_suffix" {
  type    = string
  default = ""
}

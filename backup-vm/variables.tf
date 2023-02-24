variable "project" {
  type = string
}

variable "bucket_prefix" {
  type = string
}

variable "exclude_tables" {
  type    = string
  default = ""
}

variable "location" {
  type = string
}

variable "dbhost" {
  type = string
}

variable "dbname" {
  type = string
}

variable "dbpass" {
  type = string
}

variable "script_name" {
  type = string
}

variable "username" {
  type = string
}

variable "zone" {
  type = string
}
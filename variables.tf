variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "default_zone" {
  type    = string
  default = "ru-central1-a"
}

variable "default_cidr" {
  type    = list(string)
  default = ["10.0.1.0/24"]
}

variable "vpc_name" {
  type    = string
  default = "develop"
}

variable "sa_key_file" {
  type    = string
  default = "/home/mulen/key.json"
}

variable "ssh_user" {
  type    = string
  default = "mulenkois"
}
variable "db_password" {
  type      = string
  sensitive = true
}
variable "vm_sa_name" {
  type        = string
  default     = "mulenkois"
  description = "Имя сервисного аккаунта для VM"
}
variable "registry_id" {
  type    = string
  default = "crpbu001cr8n89t1f5ua"
}

variable "mysql_host" {
  type    = string
  default = "rc1a-pka2gj7qf1i5robc.mdb.yandexcloud.net"
}

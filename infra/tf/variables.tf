variable "project_id" {
  description = "ID проекта GCP"
  type        = string
}

variable "region" {
  description = "Регион GCP (например us-central1)"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Зона для ресурсоёмких сервисов (например us-central1-a)"
  type        = string
  default     = "us-central1-a"
}

variable "master_ipv4_cidr_block" {
  description = "CIDR блок для приватного доступа control plane к нодам"
  type        = string
  default     = "172.16.0.0/28"
}

variable "network_name" {
  description = "Имя VPC сети"
  type        = string
  default     = "vpc-platform"
}

variable "subnet_name" {
  description = "Имя подсети"
  type        = string
  default     = "subnet-platform"
}

variable "subnet_cidr" {
  description = "CIDR диапазон подсети"
  type        = string
  default     = "10.10.0.0/20"
}

variable "cluster_name" {
  description = "Имя GKE кластера"
  type        = string
  default     = "gke-platform"
}

variable "master_authorized_networks" {
  description = "Список CIDR блоков, которым разрешён доступ к control plane"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
}

variable "domain_name" {
  description = "Имя DNS зоны (например example.com)"
  type        = string
}

variable "host" {
  description = "Имя поддомена для A/CNAME записи (например app.example.com)"
  type        = string
}

variable "lb_ip" {
  description = "Внешний IP балансера (если нужно создать A-запись)"
  type        = string
  default     = ""
}

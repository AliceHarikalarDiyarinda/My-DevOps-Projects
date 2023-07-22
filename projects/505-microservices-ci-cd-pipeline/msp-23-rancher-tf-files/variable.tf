//variable "aws_secret_key" {}
//variable "aws_access_key" {}
variable "region" {
  default = "us-east-1"
}
variable "mykey" {
  default = "petclinic-ranchertr"
}
variable "tags" {
  default = "petclinic-rancher-server"
}
variable "myami" {
  description = "ubuntu 20.04 ami"
  default = "ami-0261755bbcb8c4a84"
}
variable "instancetype" {
  default = "t3a.medium"
}

variable "secgrname" {
  default = "rancher-server-sec-gr-oliver"
}

variable "domain-name" {
  default = "*.clarusway.us"
}

variable "rancher-subnet" {
  default = "subnet-3ccd235a"
}

variable "hostedzone" {
  default = "clarusway.us"
}

variable "tg-name" {
  default = "clarus-rancher-http-80-tg-oliver"
}

variable "alb-name" {
  default = "petclinic-rancher-alb-oliver"
}

variable "controlplane-policy-name" {
  default = "petclinic_policy_for_rke-controlplane_role"
}

variable "worker-policy-name" {
  default = "petclinic_policy_for_rke_etcd_worker_role"
}

variable "rancher-role" {
  default = "petclinic_role_rancher-oliver"
}

variable "controlplane-attach" {
  default = "petclinic_attachment_for_rancher_controlplane"
}

variable "worker-attach" {
  default = "petclinic_attachment_for_rancher_controlplane"
}
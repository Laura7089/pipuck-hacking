variable "playbook" {
  default = "./playbooks/full_provision.yml"
  type    = string
}

variable "ssh_key" {
  default = "./.packer_ssh.key"
  type = string
}

variable "target_image_size" {
  default = 4294967296
  type    = number
}

variable "local_iso_url" {
  type    = string
}

variable "local_iso_checksum" {
  type    = string
}

source "arm-image" "pipuck" {
  iso_checksum      = "${var.local_iso_checksum}"
  iso_url           = "${var.local_iso_url}"
  target_image_size = var.target_image_size
}

build {
  sources = ["source.arm-image.pipuck"]

  provisioner "ansible" {
    playbook_file = "${var.playbook}"
    galaxy_file = "./requirements.yml"
  }
}

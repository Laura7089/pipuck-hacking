variable "upstream_iso_url" {
  default = "https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2022-01-28/2022-01-28-raspios-bullseye-armhf-lite.zip"
  type    = string
}

variable "target_image_size" {
  default = 4294967296
  type    = number
}

variable "upstream_iso_checksum" {
  default = "sha256:f6e2a3e907789ac25b61f7acfcbf5708a6d224cf28ae12535a2dc1d76a62efbc"
  type    = string
}

source "arm-image" "pipuck" {
  iso_checksum      = "${var.upstream_iso_checksum}"
  iso_url           = "${var.upstream_iso_url}"
  target_image_size = var.target_image_size
}

build {
  sources = ["source.arm-image.pipuck"]

  provisioner "shell" {
    inline = [
      "apt-get -y update",
      "apt-get install -y ansible",
    ]
  }

  provisioner "ansible-local" {
    playbook_dir = "./playbooks"
    galaxy_file   = "./playbooks/requirements.yml"
    playbook_file = "./playbooks/full_provision.yml"
  }
}

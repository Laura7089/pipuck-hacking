source "arm-image" "pipuck" {
  iso_checksum      = "sha256:f6e2a3e907789ac25b61f7acfcbf5708a6d224cf28ae12535a2dc1d76a62efbc"
  iso_url           = "https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2022-01-28/2022-01-28-raspios-bullseye-armhf-lite.zip"
  target_image_size = 4294967296
}

build {
  sources = ["source.arm-image.pipuck"]

  provisioner "ansible" {
    playbook_file = "./playbooks/ros2.yml"
  }

}

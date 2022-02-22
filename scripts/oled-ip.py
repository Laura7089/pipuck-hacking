#!/usr/bin/env python3
"""
Display hostname and IP address.

"""

import subprocess

from luma.core.error import DeviceNotFoundError
from luma.core.interface.serial import i2c
from luma.core.render import canvas
from luma.oled.device import ssd1306
from PIL import ImageFont

try:
    device = ssd1306(i2c(port=3, address=0x3C), width=128, height=32, rotate=0)
except:
    device = ssd1306(i2c(port=13, address=0x3D),
                     width=128,
                     height=32,
                     rotate=0)

device.persist = True

width = 128
height = 32

padding = 0
top = padding
bottom = height - padding
x = 4

font1 = ImageFont.truetype(
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 18)
font2 = ImageFont.truetype(
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 9)

with canvas(device) as draw:
    # Draw a black filled box to clear the image.
    draw.rectangle((0, 0, width, height), outline=0, fill=0)

    cmd = "hostname"
    hostname = subprocess.check_output(cmd, shell=True).decode("utf-8")
    cmd = "hostname -I"
    ip = subprocess.check_output(cmd, shell=True).decode("utf-8")
    # ip = ".".join(ip.split(".")[-2:])

    # Write lines of text.
    draw.text((x, top + 0), hostname, font=font1, fill=255)
    draw.text((x, top + 23), ip, font=font2, fill=255)

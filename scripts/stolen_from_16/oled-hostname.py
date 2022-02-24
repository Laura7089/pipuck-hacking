#!/usr/bin/env python3

"""
Display hostname.

"""

import subprocess
from luma.core.interface.serial import i2c
from luma.core.render import canvas
from luma.oled.device import ssd1306
from PIL import ImageFont

serial = i2c(port=3, address=0x3C)
device = ssd1306(serial, width=128, height=32, rotate=0)
device.persist = True

width = 128
height = 32
 
padding = 4
top = padding
bottom = height-padding
x = 2

font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 20)

with canvas(device) as draw:
    # Draw a black filled box to clear the image.
    draw.rectangle((0, 0, width, height), outline=0, fill=0)
 
    cmd = "hostname"
    hostname = subprocess.check_output(cmd, shell=True).decode("utf-8")
 
    # Write four lines of text.
    draw.text((x, top+0), hostname, font=font, fill=255)
    #draw.text((x, top+8), CPU, font=font, fill=255)
    #draw.text((x, top+16), MemUsage, font=font, fill=255)
    #draw.text((x, top+25), Disk, font=font, fill=255)
 

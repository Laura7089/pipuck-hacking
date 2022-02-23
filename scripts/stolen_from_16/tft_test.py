#!/usr/bin/env python3

import digitalio
import board
import busio

from adafruit_rgb_display.rgb import color565
import adafruit_rgb_display.st7789 as st7789
from adafruit_mcp230xx.mcp23017 import MCP23017

# Set up MCP23017
i2c = busio.I2C(board.SCL, board.SDA)
mcp = MCP23017(i2c, address=0x21)

# Configuration for CS and DC pins for Raspberry Pi
cs_pin = digitalio.DigitalInOut(board.CE0)
dc_pin = mcp.get_pin(7)
reset_pin = None
BAUDRATE = 64000000   # The pi can be very fast!
# Create the ST7789 display:
display = st7789.ST7789(board.SPI(), cs=cs_pin, dc=dc_pin, rst=reset_pin, baudrate=BAUDRATE,
						width=135, height=240, x_offset=53, y_offset=40)

backlight = mcp.get_pin(0)
backlight.switch_to_output()
backlight.value = True
buttonA = mcp.get_pin(5)
buttonB = mcp.get_pin(6)
buttonA.switch_to_input()
buttonB.switch_to_input()

# Main loop:
while True:
	if buttonA.value and buttonB.value:
		backlight.value = False              # turn off backlight
	else:
		backlight.value = True               # turn on backlight
	if buttonB.value and not buttonA.value:  # just button A pressed
		display.fill(color565(255, 0, 0))    # red
	if buttonA.value and not buttonB.value:  # just button B pressed
		display.fill(color565(0, 0, 255))    # blue
	if not buttonA.value and not buttonB.value:      # none pressed
		display.fill(color565(0, 255, 0))    # green

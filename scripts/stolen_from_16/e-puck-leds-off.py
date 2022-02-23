#!/usr/bin/env python3

import time
import sys
import smbus

I2C_CHANNEL = 4
EPUCK_I2C_ADDR = 0x1e

print('e-puck RGB LEDs off')

print('Initialising I2C...')

bus = smbus.SMBus(I2C_CHANNEL)

print('Turning off LEDs...')

bus.write_byte_data(EPUCK_I2C_ADDR, 0x01, 0x00)
bus.write_byte_data(EPUCK_I2C_ADDR, 0x00, 0x00)

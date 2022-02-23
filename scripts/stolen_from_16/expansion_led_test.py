#!/usr/bin/env python3

import time
import sys
import smbus

I2C_CHANNEL = 3
MCP23017_I2C_ADDR = 0x21

IODIRA = 0x00
IODIRB = 0x01
GPIOA  = 0x12
GPIOB  = 0x13

print('Pi-puck Expansion Board RGB LED example')

print('Initialising I2C...')

bus = smbus.SMBus(I2C_CHANNEL)

print('Initialising GPIO expander...')

bus.write_byte_data(MCP23017_I2C_ADDR, GPIOB, 0b11100000) # Set GPB7-5 high
bus.write_byte_data(MCP23017_I2C_ADDR, IODIRB, 0b00011111) # Set GPB7-5 as outputs

print('Cycling LED...')

print('Red')
bus.write_byte_data(MCP23017_I2C_ADDR, GPIOB, 0b01100000) # Set LED to red
time.sleep(1)

print('Yellow')
bus.write_byte_data(MCP23017_I2C_ADDR, GPIOB, 0b00100000) # Set LED to yellow
time.sleep(1)

print('Green')
bus.write_byte_data(MCP23017_I2C_ADDR, GPIOB, 0b10100000) # Set LED to green
time.sleep(1)

print('Cyan')
bus.write_byte_data(MCP23017_I2C_ADDR, GPIOB, 0b10000000) # Set LED to cyan
time.sleep(1)

print('Blue')
bus.write_byte_data(MCP23017_I2C_ADDR, GPIOB, 0b11000000) # Set LED to blue
time.sleep(1)

print('Magenta')
bus.write_byte_data(MCP23017_I2C_ADDR, GPIOB, 0b01000000) # Set LED to magenta
time.sleep(1)

print('White')
bus.write_byte_data(MCP23017_I2C_ADDR, GPIOB, 0b00000000) # Set LED to white
time.sleep(1)

print('Off')
bus.write_byte_data(MCP23017_I2C_ADDR, GPIOB, 0b11100000) # Set LED to off

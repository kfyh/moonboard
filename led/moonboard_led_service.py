# -*- coding: utf-8 -*-
import argparse
from moonboard import MoonBoard
from functools import partial
import json
import RPi.GPIO as GPIO
import os
#import signal
import sys
import logging
import time
import paho.mqtt.client as paho # FIXME pip install 
import math # floor

# external power LED and power button
LED_GPIO = 26
BUTTON_GPIO = 3


import logging
logging.basicConfig(level=logging.DEBUG,
                    format='Display(%(threadName)-10s) %(message)s',
                    )

class Database():
    def __init__(self, driver_type="", led_layout=""):
        self._MOONBOARD = MoonBoard(driver_type, led_layout)

        # Init timers
        self._time_current = time.time()
        self._time_last = self._time_current 
        self._update_interval = 1.0 #0.5 # Update interval for display in seconds


    def _on_message(self, client, userdata, message):
        logging.debug("Received message " + str(message.payload.decode("utf-8")))
        #mm = message.payload.decode("utf-8")
        msg = json.loads(message.payload.decode("utf-8"))

        color_start = (0,255,0)
        color_moves = (0,0,255)
        color_top = (255,0,0)
        self._MOONBOARD.clear()
        for s in msg["START"]:
            self._MOONBOARD.layout.set(self._MOONBOARD.MAPPING[s], color_start)
        for m in msg["MOVES"]:
            self._MOONBOARD.layout.set(self._MOONBOARD.MAPPING[m], color_moves)        
        for t in msg["TOP"]:
            self._MOONBOARD.layout.set(self._MOONBOARD.MAPPING[t], color_top)
        #self._MOONBOARD.layout.set(self._MOONBOARD.MAPPING[ihold], color_1er_done)
        self._MOONBOARD.layout.push_to_driver()



    def _record_data(self, hostname="localhost",port=1883):
        logging.debug("Start recording data from mqtt to database")
        self._client= paho.Client("client-001")  # FIXME
        self._client.on_message=self._on_message
        self._client.connect(hostname,port,60)#connect

        # FIXME: subscribe to all?
        
        self._client.subscribe("moonboard/ble/problem")


        self._client.loop_forever()

# Main stuff

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='')

    parser.add_argument('--driver_type',
                        help='driver type, depends on leds and device controlling the led.',
                        choices=['PiWS281x', 'WS2801', 'SimPixel'],
                        default='PiWS281x')

    parser.add_argument('--brightness',  default=100, type=int)

    parser.add_argument('--led_mapping',
                        type=str,  
                        default='led_mapping.json', 
                        )

    parser.add_argument('--debug',  action = "store_true")

    args = parser.parse_args()
    argsd=vars(args)
    logger = logging.getLogger('run')
    logger.setLevel(logging.DEBUG)
    logger.addHandler(logging.StreamHandler())

    if args.debug:
        logger.setLevel(logging.DEBUG)
    else:
        logger.setLevel(logging.INFO)

    #problems
    led_layout = args.led_mapping
    driver_type = args.driver_type

    d = Database(driver_type=driver_type, led_layout=led_layout)
    d._record_data(hostname="raspi-moonboard")   

# -*- coding: utf-8 -*-
import argparse
from moonboard import MoonBoard
from gi.repository import GLib
import dbus
from dbus.mainloop.glib import DBusGMainLoop
from functools import partial
import json 
import RPi.GPIO as GPIO
import os
#import signal
import logging
import time



# external power LED and power button
LED_GPIO = 18
BUTTON_GPIO = 3


# Button function
def button_pressed_callback(channel):
    print("Button pressed") 
    MOONBOARD.clear()
    #print('Shutting down')
    #os.system("sudo shutdown -h now")


timeout_id = None

def turn_off_leds():
    global timeout_id
    logging.getLogger('run').info("Inactivity timeout: Turning off LEDs")
    MOONBOARD.clear()
    timeout_id = None
    return False

def new_problem_cb(mb,holds_string):
        global timeout_id
        holds = json.loads(holds_string)
        mb.show_problem(holds)
        logger.debug('new_problem: '+holds_string)

        if timeout_id is not None:
            GLib.source_remove(timeout_id)
        timeout_id = GLib.timeout_add_seconds(3600, turn_off_leds)

if __name__ == "__main__":
    logger = logging.getLogger('run')
    logger.setLevel(logging.DEBUG)
    logger.addHandler(logging.StreamHandler())

    try:
        # Comment out button stuff - yet...
        # # BUTTON + LED setup
        GPIO.setmode(GPIO.BCM)
        GPIO.setwarnings(False)
        GPIO.setup(LED_GPIO, GPIO.OUT)
        GPIO.output(LED_GPIO,1)
        # GPIO.setup(BUTTON_GPIO, GPIO.IN, pull_up_down=GPIO.PUD_UP)
        # # interupt handling for the power button
        # GPIO.add_event_detect(BUTTON_GPIO, GPIO.RISING,
        #     callback=button_pressed_callback, bouncetime=300)

        # #signal.signal(signal.SIGINT, signal_handler)
        # #signal.pause()

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

        if args.debug:
            logger.setLevel(logging.DEBUG)
        else:
            logger.setLevel(logging.INFO)

        MOONBOARD = MoonBoard(
            args.driver_type,
            args.led_mapping)

        print(f"Led mapping:{args.led_mapping}")
        print(f"Driver type:{args.driver_type}")

        print("Led Layout Test,")
        MOONBOARD.led_layout_test() 

        # Display the holdsets
        MOONBOARD.display_holdset('Moonboard2016', 'Hold Set A', 5)
        MOONBOARD.display_holdset('Moonboard2016', 'Hold Set B', 5)
        MOONBOARD.display_holdset('Moonboard2016', 'Original School Holds', 5)

        MOONBOARD.clear()

        # connect to dbus signal new problem
        dbml = DBusGMainLoop(set_as_default=True)

        bus = dbus.SystemBus()

        proxy = None
        while proxy is None:
            try:
                proxy = bus.get_object('com.moonboard','/com/moonboard')
            except dbus.DBusException:
                logger.info("Waiting for com.moonboard service...")
                time.sleep(2)

        proxy.connect_to_signal('new_problem', partial(new_problem_cb, MOONBOARD))
        loop = GLib.MainLoop()

        dbus.set_default_main_loop(dbml)

        # Run the loop
        loop.run()

    except KeyboardInterrupt:
        logger.info("keyboard interrupt received")
    except Exception as e:
        logger.error("Unexpected exception occurred: '{}'".format(str(e)), exc_info=True)
    finally:
        if 'loop' in locals() and loop.is_running():
            loop.quit()
        GPIO.cleanup()

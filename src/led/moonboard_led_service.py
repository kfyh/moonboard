# -*- coding: utf-8 -*-
import argparse
from moonboard import MoonBoard
from gi.repository import GLib
import dbus
from dbus.mainloop.glib import DBusGMainLoop
from functools import partial
import json
import os
import logging
import time
import requests

# external power LED and power button
LED_GPIO = 18
BUTTON_GPIO = 3

DBUS_CONNECT_TIMEOUT = 120  # seconds to wait for com.moonboard before giving up


def button_pressed_callback(channel):
    print("Button pressed")
    MOONBOARD.clear()


timeout_id = None

def turn_off_leds():
    global timeout_id
    logging.getLogger('run').info("Inactivity timeout: Turning off LEDs")
    MOONBOARD.clear()
    timeout_id = None
    return False

def new_problem_cb(mb, holds_string):
    global timeout_id
    holds = json.loads(holds_string)
    mb.show_problem(holds)
    response = requests.post("http://localhost:3001/api/holds", json=holds)
    if response.status_code == 200:
        logger.info("Holds data sent successfully")
    else:
        logger.error(f"Failed to send holds data: {response.status_code} - {response.text}")
    logger.debug('new_problem: ' + holds_string)
    if timeout_id is not None:
        GLib.source_remove(timeout_id)
    timeout_id = GLib.timeout_add_seconds(3600, turn_off_leds)


if __name__ == "__main__":
    logger = logging.getLogger('run')
    logger.setLevel(logging.DEBUG)
    logger.addHandler(logging.StreamHandler())

    gpio_enabled = False
    try:
        try:
            import RPi.GPIO as GPIO
            GPIO.setmode(GPIO.BCM)
            GPIO.setup(LED_GPIO, GPIO.OUT)
            GPIO.output(LED_GPIO, 1)
            gpio_enabled = True
        except (RuntimeError, ImportError) as e:
            logger.warning("Could not set up GPIO pins. Running without GPIO support. Error: %s", e)

        parser = argparse.ArgumentParser(description='')
        parser.add_argument('--driver_type',
                            choices=['PiWS281x', 'WS2801', 'SimPixel'],
                            default='PiWS281x')
        parser.add_argument('--brightness', default=100, type=int)
        parser.add_argument('--led_mapping', type=str, default='led_mapping.json')
        parser.add_argument('--debug', action="store_true")
        args = parser.parse_args()

        if args.debug:
            logger.setLevel(logging.DEBUG)
        else:
            logger.setLevel(logging.INFO)

        MOONBOARD = MoonBoard(args.driver_type, args.led_mapping)
        logger.info(f"Led mapping: {args.led_mapping}")
        logger.info(f"Driver type: {args.driver_type}")

        # NOTE: LED layout test and holdset display removed from startup.
        # They block boot and crash the service if hardware isn't ready.
        # Run manually for testing: python3 moonboard_led_service.py --debug

        MOONBOARD.clear()

        # Connect to dbus signal new_problem — with timeout so we don't hang forever
        dbml = DBusGMainLoop(set_as_default=True)
        bus = dbus.SystemBus()

        proxy = None
        deadline = time.time() + DBUS_CONNECT_TIMEOUT
        while proxy is None:
            if time.time() > deadline:
                logger.error(
                    "Timed out after %ds waiting for com.moonboard on D-Bus. "
                    "BLE service may not be running.", DBUS_CONNECT_TIMEOUT
                )
                raise SystemExit(1)
            try:
                proxy = bus.get_object('com.moonboard', '/com/moonboard')
                logger.info("Connected to com.moonboard on D-Bus.")
            except dbus.DBusException:
                logger.info("Waiting for com.moonboard service...")
                time.sleep(2)

        proxy.connect_to_signal('new_problem', partial(new_problem_cb, MOONBOARD))
        loop = GLib.MainLoop()
        dbus.set_default_main_loop(dbml)
        loop.run()

    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
    except SystemExit:
        raise
    except Exception as e:
        logger.error("Unexpected exception: '{}'".format(str(e)), exc_info=True)
        raise SystemExit(1)
    finally:
        if 'loop' in locals() and loop.is_running():
            loop.quit()
        if gpio_enabled:
            try:
                import RPi.GPIO as GPIO
                GPIO.cleanup()
            except Exception:
                pass
import sys
import dbus, dbus.mainloop.glib
from gi.repository import GLib
from gatt_base.gatt_lib_advertisement import Advertisement
from gatt_base.gatt_lib_characteristic import Characteristic
from gatt_base.gatt_lib_service import Service
import json
import logging
from moonboard_app_protocol import UnstuffSequence, decode_problem_string
 
BLUEZ_SERVICE_NAME =           'org.bluez'
DBUS_OM_IFACE =                'org.freedesktop.DBus.ObjectManager'
LE_ADVERTISING_MANAGER_IFACE = 'org.bluez.LEAdvertisingManager1'
GATT_MANAGER_IFACE =           'org.bluez.GattManager1'
GATT_CHRC_IFACE =              'org.bluez.GattCharacteristic1'
UART_SERVICE_UUID =            '6e400001-b5a3-f393-e0a9-e50e24dcca9e'
UART_RX_CHARACTERISTIC_UUID =  '6e400002-b5a3-f393-e0a9-e50e24dcca9e'
UART_TX_CHARACTERISTIC_UUID =  '6e400003-b5a3-f393-e0a9-e50e24dcca9e'
LOCAL_NAME =                   'Moonboard A'
SERVICE_NAME=                  'com.moonboard'
mainloop = None

class RxCharacteristic(Characteristic):
    def __init__(self, bus, index, service, process_rx):
        Characteristic.__init__(self, bus, index, UART_RX_CHARACTERISTIC_UUID,
                                ['write'], service)
        self.process_rx=process_rx

    def WriteValue(self, value, options):
        # The value is an array of bytes. process_rx expects a hex string.
        hex_string = ''.join(format(b, '02x') for b in value)
        self.process_rx(hex_string)

class UartService(Service):
    def __init__(self, bus,path, index, process_rx):
        Service.__init__(self, bus,path, index, UART_SERVICE_UUID, True)
        self.add_characteristic(RxCharacteristic(bus, 1, self, process_rx))       

class MoonAdvertisement(Advertisement):
    def __init__(self, bus, index):
        Advertisement.__init__(self, bus, index, 'peripheral')
        self.add_service_uuid(UART_SERVICE_UUID)
        self.add_local_name(LOCAL_NAME)
        self.include_tx_power = True

class MoonApplication(dbus.service.Object):
    IFACE = "com.moonboard.method"
    def __init__(self, bus, logger):
        self.path = '/com/moonboard'
        self.services = []
        self.logger=logger
        self.unstuffer= UnstuffSequence(self.logger)
        dbus.service.Object.__init__(self, bus, self.path)
        self.add_service(UartService(bus,self.get_path(), 0, self.process_rx)) 

    def process_rx(self,ba):
        new_problem_string= self.unstuffer.process_bytes(ba)
        flags = self.unstuffer.flags

        if new_problem_string is not None:
            problem= decode_problem_string(new_problem_string, flags)
            self.new_problem(json.dumps(problem))
            self.unstuffer.flags = ''

    @dbus.service.signal(dbus_interface="com.moonboard",
                            signature="s")
    def new_problem(self, problem):
        self.logger.info('Signal new problem: '+ str(problem))

    def get_path(self):
        return dbus.ObjectPath(self.path)

    def add_service(self, service):
        self.services.append(service)

    @dbus.service.method(DBUS_OM_IFACE, out_signature='a{oa{sa{sv}}}')
    def GetManagedObjects(self):
        response = {}
        for service in self.services:
            response[service.get_path()] = service.get_properties()
            chrcs = service.get_characteristics()
            for chrc in chrcs:
                response[chrc.get_path()] = chrc.get_properties()
        return response

def register_app_cb():
    print('GATT application registered')


def register_app_error_cb(error):
    print('Failed to register application: ' + str(error))
    mainloop.quit()

def register_ad_cb():
    print('Advertisement registered')

def register_ad_error_cb(error):
    print('Failed to register advertisement: ' + str(error))
    mainloop.quit()

def main(logger,adapter):
    global mainloop

    logger.info("Bluetooth adapter: "+ str(adapter))

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()

    try:
        bus_name = dbus.service.BusName(SERVICE_NAME,
                                        bus=bus,
                                        do_not_queue=True)
    except dbus.exceptions.NameExistsException:
        sys.exit(1)

    app = MoonApplication(bus_name,logger)    

    service_manager = dbus.Interface(
                                bus.get_object(BLUEZ_SERVICE_NAME, adapter),
                                GATT_MANAGER_IFACE)
    ad_manager = dbus.Interface(bus.get_object(BLUEZ_SERVICE_NAME, adapter),
                                LE_ADVERTISING_MANAGER_IFACE)

    mainloop = GLib.MainLoop()

    logger.info('app path: '+ app.get_path())

    service_manager.RegisterApplication(app.get_path(), {},
                                        reply_handler=register_app_cb,
                                        error_handler=register_app_error_cb)

    advertisement = MoonAdvertisement(bus, 0)
    ad_manager.RegisterAdvertisement(advertisement.get_path(), {},
                                     reply_handler=register_ad_cb,
                                     error_handler=register_ad_error_cb)

    # Run the loop
    try:
        mainloop.run()
    except KeyboardInterrupt:
        print("keyboard interrupt received")
    except Exception as e:
        print("Unexpected exception occurred: '{}'".format(str(e)))
    finally:
        mainloop.quit()

 
if __name__ == '__main__':
    
    import argparse
    parser = argparse.ArgumentParser(description='Moonboard bluetooth service')
    parser.add_argument('--debug',  action = "store_true")

    args = parser.parse_args()

    logger = logging.getLogger('moonboard.ble')
    logger.setLevel(logging.DEBUG)
    logger.addHandler(logging.StreamHandler())

    if args.debug:
        logger.setLevel(logging.DEBUG)
    else:
        logger.setLevel(logging.INFO)

    main(logger,adapter='/org/bluez/hci0')

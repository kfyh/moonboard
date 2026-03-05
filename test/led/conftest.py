import sys
from unittest.mock import MagicMock

# This file is automatically discovered by pytest.
# The code here sets up mocks for hardware/system-specific libraries
# before any of your application or test code is imported.

# --- Create mock modules ---
mock_dbus = MagicMock()
mock_dbus.mainloop = MagicMock()
mock_dbus.mainloop.glib = MagicMock()
mock_dbus.service = MagicMock()
mock_dbus.exceptions = MagicMock()

mock_gi = MagicMock()
mock_gi.repository = MagicMock()

# --- Assign mocks to sys.modules ---
# This intercepts imports for these modules and replaces them with our mocks.
sys.modules['dbus'] = mock_dbus
sys.modules['dbus.mainloop.glib'] = mock_dbus.mainloop.glib
sys.modules['dbus.service'] = mock_dbus.service
sys.modules['dbus.exceptions'] = mock_dbus.exceptions
sys.modules['gi'] = mock_gi
sys.modules['gi.repository'] = mock_gi.repository
sys.modules['gi.repository.GLib'] = mock_gi.repository.GLib

# --- Define mock behavior ---

# Mock GLib.MainLoop to prevent tests from blocking
mock_mainloop_instance = MagicMock()
mock_gi.repository.GLib.MainLoop.return_value = mock_mainloop_instance

# Mock dbus.mainloop.glib.DBusGMainLoop
mock_dbus.mainloop.glib.DBusGMainLoop.return_value = MagicMock()

# Mock dbus decorators (@dbus.service.method, @dbus.service.signal)
# These decorators should just return the original function without modification.
def dummy_decorator(*args, **kwargs):
    def decorator(f):
        return f
    return decorator

mock_dbus.service.method = dummy_decorator
mock_dbus.service.signal = dummy_decorator

# Mock dbus base classes so 'class MyClass(dbus.service.Object)' works
class MockDbusObject:
    def __init__(self, *args, **kwargs):
        pass
mock_dbus.service.Object = MockDbusObject
mock_dbus.ObjectPath = str
mock_dbus.exceptions.NameExistsException = type('NameExistsException', (Exception,), {})

# Mock dbus.SystemBus and the BlueZ interfaces
mock_bus_instance = MagicMock()
mock_dbus.SystemBus.return_value = mock_bus_instance

# --- Mock Bluez D-Bus Objects ---
GATT_MANAGER_IFACE = 'org.bluez.GattManager1'
DBUS_OM_IFACE = 'org.freedesktop.DBus.ObjectManager'
LE_ADVERTISING_MANAGER_IFACE = 'org.bluez.LEAdvertisingManager1'

# This simulates a bluetooth adapter being present on the system
mock_managed_objects = {
    '/org/bluez/hci0': {
        GATT_MANAGER_IFACE: {},
        LE_ADVERTISING_MANAGER_IFACE: {}
    }
}

mock_om_interface = MagicMock()
mock_om_interface.GetManagedObjects.return_value = mock_managed_objects

mock_gatt_manager_interface = MagicMock()
mock_ad_manager_interface = MagicMock()

# This function directs calls to dbus.Interface to the correct mock object
def get_interface(bus_obj, iface_name):
    if iface_name == DBUS_OM_IFACE:
        return mock_om_interface
    # Return a generic mock for other interfaces like GattManager1
    return MagicMock()

mock_dbus.Interface.side_effect = get_interface

# --- Mock Hardware Libraries (RPi.GPIO, rpi_ws281x) ---
mock_ws281x = MagicMock()
# PixelStrip is instantiated as a class, so we mock it to return a mock instance
mock_ws281x.PixelStrip.return_value = MagicMock()
mock_ws281x.Color = MagicMock(side_effect=lambda r, g, b: (r << 16) | (g << 8) | b)
sys.modules['rpi_ws281x'] = mock_ws281x

mock_gpio = MagicMock()
mock_gpio.BCM = 'BCM'
mock_gpio.OUT = 'OUT'
sys.modules['RPi'] = MagicMock()
sys.modules['RPi.GPIO'] = mock_gpio

mock_spidev = MagicMock()
sys.modules['spidev'] = mock_spidev
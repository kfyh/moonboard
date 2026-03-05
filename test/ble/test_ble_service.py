import logging
import pytest
from unittest.mock import patch

# Due to conftest.py, the following imports are now our mocked objects
import dbus
import dbus.mainloop.glib
from gi.repository import GLib

# Import the actual code we want to test
from src.ble.moonboard_BLE_service import main, find_adapter


def test_service_main_executes_without_error():
    """
    Tests if the main service function can be executed without raising unhandled exceptions.
    This relies on the mocks in conftest.py to simulate the D-Bus environment.
    """
    # 1. Arrange
    # Create a mock logger to pass into the main function
    mock_logger = logging.getLogger('test_ble_service')
    mock_logger.addHandler(logging.NullHandler())

    # The main loop's run() method is blocking. We get the instance from the
    # mock defined in conftest.py so we can control it.
    mock_mainloop_instance = GLib.MainLoop()

    # 2. Act & Assert
    try:
        # These first two calls would normally fail on a non-Pi machine
        dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
        bus = dbus.SystemBus()

        # Test the adapter-finding logic using our mocked D-Bus objects
        adapter = find_adapter(bus)
        assert adapter == '/org/bluez/hci0'

        # Run the main function. The test will fail if any unhandled exception occurs.
        # We use patch.object to prevent the blocking mainloop.run() from being called.
        with patch.object(mock_mainloop_instance, 'run') as mock_run:
            main(logger=mock_logger, bus=bus, adapter=adapter)

            # Verify that the service logic reached the point where it tries to start the loop
            mock_run.assert_called_once()

    except Exception as e:
        pytest.fail(f"moonboard_BLE_service.main() raised an unexpected exception: {e}", pytrace=True)
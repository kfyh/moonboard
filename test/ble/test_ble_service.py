import logging
import pytest
from unittest.mock import patch, MagicMock, call

# Due to conftest.py, the following imports are now our mocked objects
import dbus
import dbus.mainloop.glib
from gi.repository import GLib

# Import the actual code we want to test
from src.ble.moonboard_BLE_service import main, find_adapter, MoonApplication, decode_problem_string, RxCharacteristic, register_app_cb, register_app_error_cb, register_ad_cb, register_ad_error_cb

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

def test_moon_application_process_rx_and_dispatch():
    """
    Test that MoonApplication correctly processes received data and dispatches a D-Bus message.
    """
    # 1. Arrange
    mock_logger = logging.getLogger('test_ble_service')
    mock_logger.addHandler(logging.NullHandler())

    # Create a mock bus
    mock_bus = MagicMock()

    # Create a mock UnstuffSequence instance
    mock_unstuffer = MagicMock()
    mock_unstuffer.process_bytes.return_value = "test_problem_string"
    mock_unstuffer.flags = ""

    # Patch the UnstuffSequence class to return our mock
    with patch('src.ble.moonboard_BLE_service.UnstuffSequence', return_value=mock_unstuffer):
        # Create the MoonApplication instance
        app = MoonApplication(mock_bus, mock_logger)

        # Create a mock service
        mock_service = MagicMock()

        # Create the RxCharacteristic instance
        rx_char = RxCharacteristic(mock_bus, 1, mock_service, app.process_rx)

        # Mock the decode_problem_string function
        with patch('src.ble.moonboard_BLE_service.decode_problem_string') as mock_decode:
            mock_decode.return_value = {"problem": "test_problem"}

            # Mock the new_problem signal
            with patch.object(app, 'new_problem') as mock_new_problem:
                # 2. Act
                # Simulate receiving a Bluetooth message (array of bytes)
                test_message = [0x74, 0x65, 0x73, 0x74, 0x5f, 0x64, 0x61, 0x74, 0x61]  # "test_data" in bytes
                rx_char.WriteValue(test_message, {})

                # 3. Assert
                # Verify that process_bytes was called with the correct data
                mock_unstuffer.process_bytes.assert_called_once_with("746573745f64617461")

                # Verify that decode_problem_string was called with the correct arguments
                mock_decode.assert_called_once_with("test_problem_string", "")

                # Verify that the new_problem signal was emitted with the correct data
                mock_new_problem.assert_called_once_with('{"problem": "test_problem"}')

def test_moon_application_ping_method():
    """
    Test that the MoonApplication's Ping method returns the correct response.
    """
    # 1. Arrange
    mock_logger = logging.getLogger('test_ble_service')
    mock_logger.addHandler(logging.NullHandler())

    # Create a mock bus
    mock_bus = MagicMock()

    # Create the MoonApplication instance
    app = MoonApplication(mock_bus, mock_logger)

    # 2. Act
    # Call the Ping method
    response = app.Ping()

    # 3. Assert
    # Verify that the response is correct
    assert response == "Pong"

def test_moon_application_process_rx_with_incomplete_data():
    """
    Test that MoonApplication handles incomplete data correctly.
    """
    # 1. Arrange
    mock_logger = logging.getLogger('test_ble_service')
    mock_logger.addHandler(logging.NullHandler())

    # Create a mock bus
    mock_bus = MagicMock()

    # Create a mock UnstuffSequence instance
    mock_unstuffer = MagicMock()
    mock_unstuffer.process_bytes.return_value = None  # Simulate incomplete data
    mock_unstuffer.flags = ""

    # Patch the UnstuffSequence class to return our mock
    with patch('src.ble.moonboard_BLE_service.UnstuffSequence', return_value=mock_unstuffer):
        # Create the MoonApplication instance
        app = MoonApplication(mock_bus, mock_logger)

        # Create a mock service
        mock_service = MagicMock()

        # Create the RxCharacteristic instance
        rx_char = RxCharacteristic(mock_bus, 1, mock_service, app.process_rx)

        # Mock the decode_problem_string function
        with patch('src.ble.moonboard_BLE_service.decode_problem_string') as mock_decode:
            # Mock the new_problem signal
            with patch.object(app, 'new_problem') as mock_new_problem:
                # 2. Act
                # Simulate receiving a Bluetooth message (array of bytes)
                test_message = [0x74, 0x65, 0x73, 0x74, 0x5f, 0x64, 0x61, 0x74, 0x61]  # "test_data" in bytes
                rx_char.WriteValue(test_message, {})

                # 3. Assert
                # Verify that process_bytes was called with the correct data
                mock_unstuffer.process_bytes.assert_called_once_with("746573745f64617461")

                # Verify that decode_problem_string was not called
                mock_decode.assert_not_called()

                # Verify that the new_problem signal was not emitted
                mock_new_problem.assert_not_called()

def test_moon_application_process_rx_with_flags():
    """
    Test that MoonApplication correctly processes data with flags.
    """
    # 1. Arrange
    mock_logger = logging.getLogger('test_ble_service')
    mock_logger.addHandler(logging.NullHandler())

    # Create a mock bus
    mock_bus = MagicMock()

    # Create a mock UnstuffSequence instance
    mock_unstuffer = MagicMock()
    mock_unstuffer.process_bytes.return_value = "test_problem_string"
    mock_unstuffer.flags = "test_flags"

    # Patch the UnstuffSequence class to return our mock
    with patch('src.ble.moonboard_BLE_service.UnstuffSequence', return_value=mock_unstuffer):
        # Create the MoonApplication instance
        app = MoonApplication(mock_bus, mock_logger)

        # Create a mock service
        mock_service = MagicMock()

        # Create the RxCharacteristic instance
        rx_char = RxCharacteristic(mock_bus, 1, mock_service, app.process_rx)

        # Mock the decode_problem_string function
        with patch('src.ble.moonboard_BLE_service.decode_problem_string') as mock_decode:
            mock_decode.return_value = {"problem": "test_problem"}

            # Mock the new_problem signal
            with patch.object(app, 'new_problem') as mock_new_problem:
                # 2. Act
                # Simulate receiving a Bluetooth message (array of bytes)
                test_message = [0x74, 0x65, 0x73, 0x74, 0x5f, 0x64, 0x61, 0x74, 0x61]  # "test_data" in bytes
                rx_char.WriteValue(test_message, {})

                # 3. Assert
                # Verify that process_bytes was called with the correct data
                mock_unstuffer.process_bytes.assert_called_once_with("746573745f64617461")

                # Verify that decode_problem_string was called with the correct arguments
                mock_decode.assert_called_once_with("test_problem_string", "test_flags")

                # Verify that the new_problem signal was emitted with the correct data
                mock_new_problem.assert_called_once_with('{"problem": "test_problem"}')

                # Verify that the flags were reset
                assert app.unstuffer.flags == ''

def test_find_adapter_with_no_adapter():
    """
    Test that find_adapter returns None when no adapter is found.
    """
    # 1. Arrange
    # Create a mock bus
    mock_bus = MagicMock()
    # Create a mock for the object returned by dbus.Interface
    mock_interface_obj = MagicMock()
    mock_interface_obj.GetManagedObjects.return_value = {}  # No adapters found
    # Patch dbus.Interface to return our mock object
    with patch('src.ble.moonboard_BLE_service.dbus.Interface', return_value=mock_interface_obj):
        # 2. Act
        # Call find_adapter
        adapter = find_adapter(mock_bus)
        # 3. Assert
        # Verify that the adapter is None
        assert adapter is None



def test_main_with_existing_service_name():
    """
    Test that main exits gracefully when the service name already exists.
    """
    # 1. Arrange
    # Create a mock logger
    mock_logger = logging.getLogger('test_ble_service')
    mock_logger.addHandler(logging.NullHandler())

    # Create a mock bus
    mock_bus = MagicMock()

    # Patch dbus.service.BusName to raise NameExistsException
    with patch('src.ble.moonboard_BLE_service.dbus.service.BusName', side_effect=dbus.exceptions.NameExistsException):
        # 2. Act & Assert
        # Verify that sys.exit was called with 1
        with pytest.raises(SystemExit) as e:
            main(logger=mock_logger, bus=mock_bus, adapter='/org/bluez/hci0')
        assert e.value.code == 1

def test_moon_application_get_managed_objects():
    """
    Test that MoonApplication correctly returns managed objects.
    """
    # 1. Arrange
    mock_logger = logging.getLogger('test_ble_service')
    mock_logger.addHandler(logging.NullHandler())

    # Create a mock bus
    mock_bus = MagicMock()

    # Create the MoonApplication instance
    app = MoonApplication(mock_bus, mock_logger)

    # Create mock services and characteristics
    mock_service1 = MagicMock()
    mock_service1.get_path.return_value = '/service1'
    mock_service1.get_properties.return_value = {'prop1': 'value1'}
    mock_service1.get_characteristics.return_value = []

    mock_service2 = MagicMock()
    mock_service2.get_path.return_value = '/service2'
    mock_service2.get_properties.return_value = {'prop2': 'value2'}
    mock_chrc1 = MagicMock()
    mock_chrc1.get_path.return_value = '/chrc1'
    mock_chrc1.get_properties.return_value = {'prop3': 'value3'}
    mock_service2.get_characteristics.return_value = [mock_chrc1]

    # Add the mock services to the application
    app.services = [mock_service1, mock_service2]

    # 2. Act
    # Call GetManagedObjects
    managed_objects = app.GetManagedObjects()

    # 3. Assert
    # Verify that the managed objects are correct
    expected_objects = {
        '/service1': {'prop1': 'value1'},
        '/service2': {'prop2': 'value2'},
        '/chrc1': {'prop3': 'value3'}
    }
    assert managed_objects == expected_objects

def test_moon_application_registration_callbacks():
    """
    Test that MoonApplication correctly handles registration callbacks.
    """
    # 1. Arrange
    mock_logger = logging.getLogger('test_ble_service')
    mock_logger.addHandler(logging.NullHandler())

    # Create a mock bus
    mock_bus = MagicMock()

    # Create a mock adapter
    mock_adapter = MagicMock()

    # Create mock service and advertisement managers
    mock_service_manager = MagicMock()
    mock_ad_manager = MagicMock()

    # Simulate the D-Bus service calling the reply_handler
    def register_app_side_effect(path, options, reply_handler, error_handler):
        reply_handler()

    def register_ad_side_effect(path, options, reply_handler, error_handler):
        reply_handler()

    mock_service_manager.RegisterApplication.side_effect = register_app_side_effect
    mock_ad_manager.RegisterAdvertisement.side_effect = register_ad_side_effect

    # Patch the dbus.Interface to return our mock managers
    with patch('src.ble.moonboard_BLE_service.dbus.Interface') as mock_interface:
        mock_interface.side_effect = [mock_service_manager, mock_ad_manager]

        # Patch the mainloop to prevent it from running
        with patch('src.ble.moonboard_BLE_service.mainloop') as mock_mainloop:
            # Patch the print function to capture the output
            with patch('builtins.print') as mock_print:
                # 2. Act
                # Call main
                main(logger=mock_logger, bus=mock_bus, adapter=mock_adapter)

                # 3. Assert
                # Verify that the service manager was called with the correct arguments
                mock_service_manager.RegisterApplication.assert_called_once_with(
                    '/com/moonboard',
                    {},
                    reply_handler=register_app_cb,
                    error_handler=register_app_error_cb
                )

                # Verify that the advertisement manager was called with the correct arguments
                mock_ad_manager.RegisterAdvertisement.assert_called_once_with(
                    '/org/bluez/example/advertisement0',
                    {},
                    reply_handler=register_ad_cb,
                    error_handler=register_ad_error_cb
                )

                # Verify that the print function was called with the correct messages
                assert mock_print.call_args_list == [
                    call('GATT application registered'),
                    call('Advertisement registered')
                ]



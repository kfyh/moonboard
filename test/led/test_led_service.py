import os
import runpy
from unittest.mock import patch, MagicMock, ANY
import json


def test_led_service_integration():
    """
    Tests the LED service integration with dbus and moonboard.
    """
    script_path = os.path.join('src', 'led', 'moonboard_led_service.py')
    assert os.path.exists(script_path)

    # We need to patch many modules because the script will try to import them
    with patch('gi.repository.GLib.MainLoop') as MockMainLoop, \
         patch('gi.repository.GLib.timeout_add_seconds') as mock_timeout_add, \
         patch('gi.repository.GLib.source_remove') as mock_source_remove, \
         patch('dbus.SystemBus') as MockSystemBus, \
         patch('dbus.mainloop.glib.DBusGMainLoop'), \
         patch('moonboard.MoonBoard') as MockMoonBoard, \
         patch('sys.argv', [script_path, '--driver_type', 'SimPixel']), \
         patch('time.sleep'), \
         patch.dict('sys.modules', {'RPi': MagicMock(), 'RPi.GPIO': MagicMock()}):

        # Setup mock objects
        mock_loop = MockMainLoop.return_value
        mock_bus = MockSystemBus.return_value
        mock_proxy = MagicMock()
        mock_bus.get_object.return_value = mock_proxy
        mock_moonboard_instance = MockMoonBoard.return_value

        callback_container = {}
        def capture_callback(*args, **kwargs):
            callback_container['callback'] = args[1]

        mock_proxy.connect_to_signal.side_effect = capture_callback

        # run_path returns the module's globals, which we can use to inspect state
        module_globals = runpy.run_path(script_path, run_name='__main__')

        # --- Assertions ---
        MockMoonBoard.assert_called_once_with('SimPixel', 'led_mapping.json')

        mock_bus.get_object.assert_called_once_with('com.moonboard', '/com/moonboard')
        mock_proxy.connect_to_signal.assert_called_once()
        assert 'new_problem' in mock_proxy.connect_to_signal.call_args[0]

        mock_loop.run.assert_called_once()

        # --- Now, simulate a dbus signal ---
        assert 'callback' in callback_container
        dbus_callback = callback_container['callback']

        holds = {"p": [["1", "2"], ["3", "4"]]}
        holds_json = json.dumps(holds)
        
        # --- First signal ---
        mock_timeout_add.return_value = 54321
        dbus_callback(holds_json)

        # Check if moonboard was updated
        mock_moonboard_instance.show_problem.assert_called_once_with(holds)

        # Check if a timer was started.
        mock_timeout_add.assert_called_with(3600, module_globals['turn_off_leds'])

        # --- Simulate another signal to check if timer is reset ---
        holds2 = {"p": [["5", "6"]]}
        holds_json2 = json.dumps(holds2)
        
        mock_timeout_add.return_value = 12345
        
        dbus_callback(holds_json2)

        # Check that the old timer was removed (the one from the first call)
        mock_source_remove.assert_called_once_with(54321)
        mock_moonboard_instance.show_problem.assert_called_with(holds2)
        assert mock_timeout_add.call_count == 2
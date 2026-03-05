import os
import runpy
from unittest.mock import patch

def test_led_service_execution():
    """
    Tests that the LED service script executes correctly.
    Uses runpy to simulate script execution since the entry point
    might be under 'if __name__ == "__main__":' rather than a 'main()' function.
    """
    # Define the path to the service script
    script_path = os.path.join('src', 'led', 'moonboard_led_service.py')
    
    # Ensure the file exists before trying to run it
    assert os.path.exists(script_path), f"Service script not found at {script_path}"

    # Patch GLib.MainLoop to prevent blocking when the service starts
    # Patch sys.argv to prevent argument parsing errors
    with patch('gi.repository.GLib.MainLoop') as MockMainLoop, \
         patch('sys.argv', [script_path]):
        
        mock_loop = MockMainLoop.return_value
        
        # Execute the script
        runpy.run_path(script_path, run_name='__main__')
        
        # Verify the main loop was started
        mock_loop.run.assert_called_once()
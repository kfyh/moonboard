import pytest
from unittest.mock import patch, mock_open, MagicMock
import json
from src.led.moonboard import MoonBoard

def test_moonboard_initialization():
    """
    Smoke test for MoonBoard class initialization.
    Verifies that it loads the mapping and initializes the driver.
    """
    mock_mapping_json = json.dumps({
        "A1": 0,
        "B2": 1,
        "num_pixels": 50
    })

    # We mock 'open' to avoid needing a real file
    # We mock the drivers to avoid hardware interaction
    with patch("builtins.open", mock_open(read_data=mock_mapping_json)), \
         patch("src.led.moonboard.PiWS281X") as MockPiWS281X, \
         patch("src.led.moonboard.Strip") as MockStrip:
        
        # Act
        mb = MoonBoard(driver_type="PiWS281x", led_mapping="dummy_mapping.json")

        # Assert
        assert mb.MAPPING["A1"] == 0
        MockPiWS281X.assert_called_with(50) # num_pixels from mapping
        MockStrip.assert_called()
        
        # Verify cleanup and start were called
        mb.layout.cleanup_drivers.assert_called_once()
        mb.layout.start.assert_called_once()

def test_moonboard_show_problem():
    """
    Test showing a problem on the MoonBoard.
    """
    mock_mapping_json = json.dumps({
        "A1": 0,
        "K10": 1,
        "num_pixels": 50
    })

    with patch("builtins.open", mock_open(read_data=mock_mapping_json)), \
         patch("src.led.moonboard.PiWS281X"), \
         patch("src.led.moonboard.Strip"):
        
        mb = MoonBoard(driver_type="PiWS281x", led_mapping="dummy.json")
        
        # Setup a problem
        problem = {
            "START": ["A1"],
            "MOVES": [],
            "TOP": ["K10"]
        }
        
        # Act
        mb.show_problem(problem)
        
        # Assert
        # Check that push_to_driver was called, indicating an update occurred
        mb.layout.push_to_driver.assert_called()
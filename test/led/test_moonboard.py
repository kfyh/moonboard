import pytest
from unittest.mock import patch, mock_open, MagicMock, call
import json
from src.led.moonboard import MoonBoard
from bibliopixel.colors import COLORS

@pytest.fixture
def mock_open_valid_mapping():
    mock_mapping_json = json.dumps({
        "A1": 0, "B2": 1, "K10": 197,
        "num_pixels": 200
    })
    return mock_open(read_data=mock_mapping_json)

@pytest.fixture(autouse=True)
def mock_drivers():
    with patch("src.led.moonboard.PiWS281X") as MockPiWS281X, \
         patch("src.led.moonboard.WS2801") as MockWS2801, \
         patch("src.led.moonboard.SimPixel") as MockSimPixel, \
         patch("src.led.moonboard.DriverDummy") as MockDriverDummy, \
         patch("src.led.moonboard.Strip") as MockStrip:
        yield {
            "PiWS281X": MockPiWS281X,
            "WS2801": MockWS2801,
            "SimPixel": MockSimPixel,
            "DriverDummy": MockDriverDummy,
            "Strip": MockStrip,
        }

def test_moonboard_initialization(mock_open_valid_mapping, mock_drivers):
    with patch("builtins.open", mock_open_valid_mapping):
        mb = MoonBoard(driver_type="PiWS281x", led_mapping="dummy_mapping.json")

    assert mb.MAPPING["A1"] == 0
    mock_drivers["PiWS281X"].assert_called_with(200)
    mock_drivers["Strip"].assert_called()
    mb.layout.cleanup_drivers.assert_called_once()
    mb.layout.start.assert_called_once()

def test_init_invalid_json():
    with patch("builtins.open", mock_open(read_data="not a json")), \
         pytest.raises(json.JSONDecodeError):
        MoonBoard(driver_type="PiWS281x", led_mapping="dummy.json")

def test_init_no_num_pixels(mock_drivers):
    mock_mapping = {"A1": 0, "B2": 1, "C3": 10}
    m = mock_open(read_data=json.dumps(mock_mapping))
    with patch("builtins.open", m):
        MoonBoard(driver_type="PiWS281x", led_mapping="dummy.json")
    # max(values) + 1 = 10 + 1 = 11
    mock_drivers["PiWS281X"].assert_called_with(11)

@pytest.mark.parametrize("driver_type, mocked_driver_name", [
    ("WS2801", "WS2801"),
    ("SimPixel", "SimPixel"),
])
def test_init_other_drivers(mock_open_valid_mapping, mock_drivers, driver_type, mocked_driver_name):
    with patch("builtins.open", mock_open_valid_mapping):
        MoonBoard(driver_type=driver_type, led_mapping="dummy.json")
    
    mocked_driver_class = mock_drivers[mocked_driver_name]
    mocked_driver_class.assert_called()
    
    if driver_type == "SimPixel":
        mock_simpixel_instance = mocked_driver_class.return_value
        mock_simpixel_instance.open_browser.assert_called_once()

def test_init_driver_import_error(mock_open_valid_mapping, mock_drivers):
    mock_drivers["PiWS281X"].side_effect = ImportError("test error")
    with patch("builtins.open", mock_open_valid_mapping):
        MoonBoard(driver_type="PiWS281x", led_mapping="dummy.json")
    mock_drivers["DriverDummy"].assert_called()

def test_clear(mock_open_valid_mapping):
    with patch("builtins.open", mock_open_valid_mapping):
        mb = MoonBoard("PiWS281x")
        mb.animation = MagicMock()
        mb.clear()
    mb.animation.stop.assert_called_once()
    mb.layout.all_off.assert_called_once()
    mb.layout.push_to_driver.assert_called_once()

def test_set_hold(mock_open_valid_mapping):
    with patch("builtins.open", mock_open_valid_mapping):
        mb = MoonBoard("PiWS281x")
        mb.set_hold("A1", COLORS.red)
    mb.layout.set.assert_called_once_with(0, COLORS.red)

def test_show_hold(mock_open_valid_mapping):
    with patch("builtins.open", mock_open_valid_mapping):
        mb = MoonBoard("PiWS281x")
        with patch.object(mb, 'set_hold') as mock_set_hold:
            mb.show_hold("A1", COLORS.red)
            mock_set_hold.assert_called_once_with("A1", COLORS.red)
    mb.layout.push_to_driver.assert_called_once()


def test_moonboard_show_problem_colors(mock_open_valid_mapping):
    with patch("builtins.open", mock_open_valid_mapping):
        mb = MoonBoard("PiWS281x")
        problem = {"START": ["A1"], "MOVES": ["B2"], "TOP": ["K10"]}
        
        with patch.object(mb, 'set_hold') as mock_set_hold:
            mb.show_problem(problem)
            
    calls = [
        call("A1", COLORS.green),
        call("B2", COLORS.blue),
        call("K10", COLORS.red),
    ]
    mock_set_hold.assert_has_calls(calls, any_order=True)
    mb.layout.push_to_driver.assert_called()

def test_show_problem_custom_colors(mock_open_valid_mapping):
    with patch("builtins.open", mock_open_valid_mapping):
        mb = MoonBoard("PiWS281x")
        problem = {"START": ["A1"], "MOVES": [], "TOP": []}
        colors = {"START": COLORS.hotpink}
        
        with patch.object(mb, 'set_hold') as mock_set_hold:
            mb.show_problem(problem, hold_colors=colors)
            
    mock_set_hold.assert_called_once_with("A1", COLORS.hotpink)

@patch("time.sleep")
def test_led_layout_test(mock_sleep, mock_open_valid_mapping):
    mock_mapping = {"A" + str(i+1): i for i in range(18)}
    mock_mapping.update({"B" + str(i+1): i+18 for i in range(18)})
    mock_mapping_json = json.dumps(mock_mapping)
    
    # Use a mapping with fewer rows/cols for faster testing
    m = mock_open(read_data=mock_mapping_json)
    with patch("builtins.open", m):
        mb = MoonBoard("PiWS281x")
        mb.COLS = 2
        mb.ROWS = 18
        mb.led_layout_test(duration=0.01)

    assert mb.layout.set.call_count == 36 * 2 # 36 holds, 2 colors each
    assert mb.layout.push_to_driver.call_count == 36 * 2
    assert mock_sleep.call_count == 36 * 2


@patch("time.sleep")
def test_display_holdset(mock_sleep, mock_drivers):
    # Mock the two files that will be opened
    hold_setup_data = json.dumps({
        "Moonboard2016": {
            "A1": {"HoldSet": "Hold Set A"},
            "B2": {"HoldSet": "Hold Set B"},
        }
    })
    led_mapping_data = json.dumps({"A1": 0, "B2": 1, "num_pixels": 2})
    
    mock_open_files = {
        'led_mapping.json': mock_open(read_data=led_mapping_data).return_value,
        '../problems/HoldSetup.json': mock_open(read_data=hold_setup_data).return_value,
    }

    def mock_open_custom(file_path, *args, **kwargs):
        for key in mock_open_files:
            if key in file_path:
                return mock_open_files[key]
        raise FileNotFoundError(f"File not mocked: {file_path}")

    with patch("builtins.open", side_effect=mock_open_custom):
        mb = MoonBoard("PiWS281x", led_mapping='led_mapping.json')
        mb.display_holdset(setup="Moonboard2016", holdset="Hold Set A", duration=5)

    calls = [
        call(0, COLORS.green), # A1
        call(1, COLORS.black), # B2
    ]
    mb.layout.set.assert_has_calls(calls, any_order=True)
    
    # push_to_driver is called once in display_holdset and once in clear
    assert mb.layout.push_to_driver.call_count == 2
    mock_sleep.assert_called_once_with(5)
    
    # clear() calls all_off()
    mb.layout.all_off.assert_called_once()


def test_stop_animation(mock_open_valid_mapping):
    with patch("builtins.open", mock_open_valid_mapping):
        mb = MoonBoard("PiWS281x")
        mb.animation = None
        mb.stop_animation() # Should not raise error

        mb.animation = MagicMock()
        mb.stop_animation()
        mb.animation.stop.assert_called_once()
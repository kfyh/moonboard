import pytest
from unittest.mock import patch
from src.ble.moonboard_app_protocol import position_trans, decode_problem_string, UnstuffSequence
import logging

def test_position_trans():
    # Test with an even column (0)
    assert position_trans(0, 18) == "A1"
    assert position_trans(17, 18) == "A18"

    # Test with an odd column (1)
    assert position_trans(18, 18) == "B18"
    assert position_trans(35, 18) == "B1"

    # Test with 12 rows
    assert position_trans(0, 12) == "A1"
    assert position_trans(11, 12) == "A12"
    assert position_trans(12, 12) == "B12"
    assert position_trans(23, 12) == "B1"

def test_decode_problem_string():
    # Test with 18 rows (no 'M' flag)
    problem_string = "S0,P18,E35"
    decoded = decode_problem_string(problem_string, "")
    assert decoded['START'] == ["A1"]
    assert decoded['MOVES'] == ["B18"]
    assert decoded['TOP'] == ["B1"]
    assert decoded['FLAGS'] == [""]

    # Test with 12 rows ('M' flag)
    problem_string_mini = "S0,P12,E23"
    decoded_mini = decode_problem_string(problem_string_mini, "M")
    assert decoded_mini['START'] == ["A1"]
    assert decoded_mini['MOVES'] == ["B12"]
    assert decoded_mini['TOP'] == ["B1"]
    assert decoded_mini['FLAGS'] == ["M"]

    # Test with multiple holds of the same type
    problem_string_multiple = "S0,S1,P18,E35,E36"
    decoded_multiple = decode_problem_string(problem_string_multiple, "")
    assert decoded_multiple['START'] == ["A1", "A2"]
    assert decoded_multiple['MOVES'] == ["B18"]
    assert decoded_multiple['TOP'] == ["B1", "C1"]

    # Test with empty string
    assert decode_problem_string("", "") == {'START':[],'MOVES':[],'TOP':[], 'FLAGS':[""]}

def test_unstuff_sequence():
    logger = logging.getLogger('test_app_protocol')
    unstuffer = UnstuffSequence(logger)

    # Test complete sequence in one go
    complete_sequence = "l#S0,P18,E35#".encode().hex()
    assert unstuffer.process_bytes(complete_sequence) == "S0,P18,E35"

    # Test sequence in multiple parts
    part1 = "l#S0,P18".encode().hex()
    part2 = ",E35#".encode().hex()
    assert unstuffer.process_bytes(part1) is None
    assert unstuffer.s == "S0,P18"
    assert unstuffer.process_bytes(part2) == "S0,P18,E35"
    assert unstuffer.s == ""

    # Test flag processing
    flag_sequence = "~M*".encode().hex()
    assert unstuffer.process_bytes(flag_sequence) is None
    assert unstuffer.flags == "M"

    # Test another flag
    flag_sequence_d = "~D*".encode().hex()
    assert unstuffer.process_bytes(flag_sequence_d) is None
    assert unstuffer.flags == "D"

    # Test error: stop before start
    unstuffer.s = ""
    stop_sequence = "E35#".encode().hex()
    assert unstuffer.process_bytes(stop_sequence) is None
    assert unstuffer.s == ""

    # Test error: start before previous finished
    part1 = "l#S0".encode().hex()
    unstuffer.process_bytes(part1)
    assert unstuffer.s == "S0"
    part2 = "l#S1".encode().hex()
    unstuffer.process_bytes(part2)
    assert unstuffer.s == "" # error condition resets sequence

    # Test invalid byte sequence
    with patch.object(logger, 'error') as mock_error:
        unstuffer.process_bytes("invalidhex")
        mock_error.assert_called_once_with('Cannot process bytes: invalidhex')

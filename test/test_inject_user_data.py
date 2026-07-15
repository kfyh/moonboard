import os
import runpy
import sys
from unittest.mock import patch
import pytest

SCRIPT_PATH = os.path.join("install", "inject-user-data.py")

def test_missing_arguments():
    """Verify that script exits with code 1 if BOOTFS path is missing."""
    with patch("sys.argv", [SCRIPT_PATH]):
        with pytest.raises(SystemExit) as excinfo:
            runpy.run_path(SCRIPT_PATH, run_name="__main__")
        assert excinfo.value.code == 1

def test_new_bootfs_creation(tmp_path):
    """Verify cloud-init files are created on a new/fresh bootfs."""
    user_data_file = tmp_path / "user-data"
    meta_data_file = tmp_path / "meta-data"
    network_config_file = tmp_path / "network-config"

    with patch("sys.argv", [SCRIPT_PATH, str(tmp_path)]):
        runpy.run_path(SCRIPT_PATH, run_name="__main__")

    # Assert all files created
    assert user_data_file.exists()
    assert meta_data_file.exists()
    assert network_config_file.exists()

    # Verify user-data contents
    content = user_data_file.read_text()
    assert "#cloud-config" in content
    assert "runcmd:" in content
    assert "- [ /bin/bash, /boot/firmware/moonboard/install/automated-install.sh ]" in content

    # Verify other files comments
    assert "empty meta-data" in meta_data_file.read_text()
    assert "empty network-config" in network_config_file.read_text()

def test_existing_runcmd(tmp_path):
    """Verify injection appends to an existing runcmd block."""
    user_data_file = tmp_path / "user-data"
    user_data_file.write_text(
        "#cloud-config\n"
        "timezone: Europe/London\n"
        "runcmd:\n"
        "  - [ echo, 'hello' ]\n"
    )

    with patch("sys.argv", [SCRIPT_PATH, str(tmp_path)]):
        runpy.run_path(SCRIPT_PATH, run_name="__main__")

    content = user_data_file.read_text()
    assert "timezone: Europe/London" in content
    assert "runcmd:" in content
    assert "  - [ echo, 'hello' ]" in content
    assert "- [ /bin/bash, /boot/firmware/moonboard/install/automated-install.sh ]" in content

def test_existing_no_runcmd(tmp_path):
    """Verify injection creates runcmd block if user-data exists without it."""
    user_data_file = tmp_path / "user-data"
    user_data_file.write_text(
        "#cloud-config\n"
        "timezone: Europe/London\n"
    )

    with patch("sys.argv", [SCRIPT_PATH, str(tmp_path)]):
        runpy.run_path(SCRIPT_PATH, run_name="__main__")

    content = user_data_file.read_text()
    assert "timezone: Europe/London" in content
    assert "runcmd:" in content
    assert "- [ /bin/bash, /boot/firmware/moonboard/install/automated-install.sh ]" in content

def test_already_injected(tmp_path):
    """Verify injection is skipped if trigger is already present."""
    user_data_file = tmp_path / "user-data"
    original_content = (
        "#cloud-config\n"
        "runcmd:\n"
        "  - [ /boot/firmware/moonboard/install/automated-install.sh ]\n"
    )
    user_data_file.write_text(original_content)

    with patch("sys.argv", [SCRIPT_PATH, str(tmp_path)]):
        runpy.run_path(SCRIPT_PATH, run_name="__main__")

    content = user_data_file.read_text()
    assert content == original_content

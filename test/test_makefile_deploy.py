import os
import subprocess
import pytest

def test_makefile_deploy_target(tmp_path):
    """Verify that 'make deploy' correctly populates the BOOTFS layout."""
    # Run the make target with our temporary directory as BOOTFS
    # We must run it from the root directory where the Makefile lives
    bootfs_str = str(tmp_path)
    
    # We can pre-populate a cmdline.txt with an old hook to verify it gets cleaned
    cmdline_file = tmp_path / "cmdline.txt"
    cmdline_file.write_text("console=serial0,115200 console=tty1 root=PARTUUID=1234-5678 rootfstype=ext4 fsck.repair=yes rootwait init=/boot/firmware/firstrun.sh")

    result = subprocess.run(
        ["make", "deploy", f"BOOTFS={bootfs_str}"],
        capture_output=True,
        text=True
    )
    
    # Check if command was successful
    assert result.returncode == 0, f"make deploy failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"
    
    # Check directory structure
    moonboard_dir = tmp_path / "moonboard"
    assert moonboard_dir.exists()
    
    # Check key files/folders
    assert (moonboard_dir / "ble").is_dir()
    assert (moonboard_dir / "led").is_dir()
    assert (moonboard_dir / "install").is_dir()
    assert not (moonboard_dir / "web" / "dist").exists()
    assert (moonboard_dir / "web" / "src").is_dir()
    assert (moonboard_dir / "web" / "service").is_dir()
    assert (moonboard_dir / "web" / "package.json").is_file()
    
    # Check executables
    auto_install = moonboard_dir / "install" / "automated-install.sh"
    web_install = moonboard_dir / "install" / "web-install.sh"
    assert auto_install.is_file()
    assert web_install.is_file()
    
    # Check file permissions on unix
    if os.name != "nt":
        assert os.access(str(auto_install), os.X_OK)
        assert os.access(str(web_install), os.X_OK)
        
    # Check cloud-init injection
    assert (tmp_path / "user-data").is_file()
    assert (tmp_path / "meta-data").is_file()
    assert (tmp_path / "network-config").is_file()
    
    user_data_content = (tmp_path / "user-data").read_text()
    assert "#cloud-config" in user_data_content
    assert "runcmd:" in user_data_content
    assert "- [ /bin/bash, /boot/firmware/moonboard/install/automated-install.sh ]" in user_data_content

    # Verify cmdline.txt clean up
    cmdline_content = cmdline_file.read_text()
    assert "init=/boot/firmware/firstrun.sh" not in cmdline_content
    assert "console=serial0,115200" in cmdline_content

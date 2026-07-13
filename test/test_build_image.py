import os
import subprocess
import tempfile
import pytest

SCRIPT_PATH = os.path.join("install", "build-image.sh")

@pytest.fixture
def mock_env_dir():
    with tempfile.TemporaryDirectory() as tmpdir:
        yield tmpdir

def create_mock_tool(bin_dir, name, exit_code=0, stdout="", stderr=""):
    path = os.path.join(bin_dir, name)
    with open(path, "w") as f:
        f.write("#!/bin/bash\n")
        if name == "uname":
            f.write(f"echo '{stdout or 'Linux'}'\n")
        elif name == "id":
            f.write(f"echo '{stdout or '0'}'\n")
        else:
            if name == "tar":
                f.write("cat >/dev/null 2>/dev/null\n")
            f.write(f"echo '{stdout}'\n")
            if stderr:
                f.write(f"echo '{stderr}' >&2\n")
        f.write(f"exit {exit_code}\n")
    os.chmod(path, 0o755)

def setup_path_env(mock_env_dir, isolate=True):
    # Symlink bash into mock_env_dir to allow subprocess execution under isolation
    bash_path = None
    for p in ["/bin/bash", "/usr/bin/bash"]:
        if os.path.exists(p):
            bash_path = p
            break
    if bash_path:
        target = os.path.join(mock_env_dir, "bash")
        if not os.path.exists(target):
            os.symlink(bash_path, target)
            
    env = os.environ.copy()
    if isolate:
        env["PATH"] = mock_env_dir
    else:
        env["PATH"] = f"{mock_env_dir}:{env['PATH']}"
    return env

def test_checks_pass_with_valid_env(mock_env_dir):
    """Verify that --check-only passes when all environment checks are satisfied."""
    tools = ["mount", "unzip", "wget", "xz", "curl", "parted", "losetup", "qemu-arm-static"]
    for t in tools:
        create_mock_tool(mock_env_dir, t)
    
    create_mock_tool(mock_env_dir, "uname", stdout="Linux")
    create_mock_tool(mock_env_dir, "id", stdout="0")
    
    # Create dummy loop control file
    loop_control = os.path.join(mock_env_dir, "loop-control")
    with open(loop_control, "w") as f:
        f.write("")
        
    env = setup_path_env(mock_env_dir, isolate=True)
    env["MOCK_EUID"] = "0"
    env["MOCK_LOOP_CONTROL"] = loop_control
    
    res = subprocess.run(["bash", SCRIPT_PATH, "--check-only"], env=env, capture_output=True, text=True)
    assert res.returncode == 0
    assert "Environment check passed" in res.stdout

def test_checks_fail_non_linux(mock_env_dir):
    """Verify that the script fails if the OS is not Linux."""
    tools = ["mount", "unzip", "wget", "xz", "curl", "parted", "losetup", "qemu-arm-static"]
    for t in tools:
        create_mock_tool(mock_env_dir, t)
        
    create_mock_tool(mock_env_dir, "uname", stdout="Darwin")
    create_mock_tool(mock_env_dir, "id", stdout="0")
    
    loop_control = os.path.join(mock_env_dir, "loop-control")
    with open(loop_control, "w") as f:
        f.write("")
        
    env = setup_path_env(mock_env_dir, isolate=True)
    env["MOCK_EUID"] = "0"
    env["MOCK_LOOP_CONTROL"] = loop_control
    
    res = subprocess.run(["bash", SCRIPT_PATH, "--check-only"], env=env, capture_output=True, text=True)
    assert res.returncode != 0
    assert "Error: This script must be run on Linux." in res.stderr

def test_checks_fail_non_root(mock_env_dir):
    """Verify that the script fails if not run as root (non-zero UID)."""
    tools = ["mount", "unzip", "wget", "xz", "curl", "parted", "losetup", "qemu-arm-static"]
    for t in tools:
        create_mock_tool(mock_env_dir, t)
        
    create_mock_tool(mock_env_dir, "uname", stdout="Linux")
    create_mock_tool(mock_env_dir, "id", stdout="1000")
    
    loop_control = os.path.join(mock_env_dir, "loop-control")
    with open(loop_control, "w") as f:
        f.write("")
        
    env = setup_path_env(mock_env_dir, isolate=True)
    env["MOCK_EUID"] = "1000"
    env["MOCK_LOOP_CONTROL"] = loop_control
    
    res = subprocess.run(["bash", SCRIPT_PATH, "--check-only"], env=env, capture_output=True, text=True)
    assert res.returncode != 0
    assert "Error: This script must be run with root privileges (sudo)." in res.stderr

def test_checks_fail_missing_loop_control(mock_env_dir):
    """Verify that the script fails if the loop-control device is missing."""
    tools = ["mount", "unzip", "wget", "xz", "curl", "parted", "losetup", "qemu-arm-static"]
    for t in tools:
        create_mock_tool(mock_env_dir, t)
        
    create_mock_tool(mock_env_dir, "uname", stdout="Linux")
    create_mock_tool(mock_env_dir, "id", stdout="0")
    
    # Do NOT create loop-control file
    loop_control = os.path.join(mock_env_dir, "loop-control")
    
    env = setup_path_env(mock_env_dir, isolate=True)
    env["MOCK_EUID"] = "0"
    env["MOCK_LOOP_CONTROL"] = loop_control
    
    res = subprocess.run(["bash", SCRIPT_PATH, "--check-only"], env=env, capture_output=True, text=True)
    assert res.returncode != 0
    assert "Error: /dev/loop-control device not found." in res.stderr

def test_checks_fail_missing_required_tools(mock_env_dir):
    """Verify that the script fails if a required tool (e.g. wget) is missing."""
    # Exclude wget
    tools = ["mount", "unzip", "xz", "curl", "parted", "losetup", "qemu-arm-static"]
    for t in tools:
        create_mock_tool(mock_env_dir, t)
        
    create_mock_tool(mock_env_dir, "uname", stdout="Linux")
    create_mock_tool(mock_env_dir, "id", stdout="0")
    
    loop_control = os.path.join(mock_env_dir, "loop-control")
    with open(loop_control, "w") as f:
        f.write("")
        
    env = setup_path_env(mock_env_dir, isolate=True)
    env["MOCK_EUID"] = "0"
    env["MOCK_LOOP_CONTROL"] = loop_control
    
    res = subprocess.run(["bash", SCRIPT_PATH, "--check-only"], env=env, capture_output=True, text=True)
    assert res.returncode != 0
    assert "Error: Required tool 'wget' is not installed." in res.stderr

def test_checks_fail_missing_loop_tool(mock_env_dir):
    """Verify that the script fails if neither kpartx nor losetup is available."""
    # Exclude losetup/kpartx
    tools = ["mount", "unzip", "wget", "xz", "curl", "parted", "qemu-arm-static"]
    for t in tools:
        create_mock_tool(mock_env_dir, t)
        
    create_mock_tool(mock_env_dir, "uname", stdout="Linux")
    create_mock_tool(mock_env_dir, "id", stdout="0")
    
    loop_control = os.path.join(mock_env_dir, "loop-control")
    with open(loop_control, "w") as f:
        f.write("")
        
    env = setup_path_env(mock_env_dir, isolate=True)
    env["MOCK_EUID"] = "0"
    env["MOCK_LOOP_CONTROL"] = loop_control
    
    res = subprocess.run(["bash", SCRIPT_PATH, "--check-only"], env=env, capture_output=True, text=True)
    assert res.returncode != 0
    assert "Error: Neither 'kpartx' nor 'losetup' was found." in res.stderr

def test_checks_fail_missing_qemu_tool(mock_env_dir):
    """Verify that the script fails if neither qemu-arm-static nor qemu-aarch64-static is available."""
    # Exclude qemu-arm-static/qemu-aarch64-static
    tools = ["mount", "unzip", "wget", "xz", "curl", "parted", "losetup"]
    for t in tools:
        create_mock_tool(mock_env_dir, t)
        
    create_mock_tool(mock_env_dir, "uname", stdout="Linux")
    create_mock_tool(mock_env_dir, "id", stdout="0")
    
    loop_control = os.path.join(mock_env_dir, "loop-control")
    with open(loop_control, "w") as f:
        f.write("")
        
    env = setup_path_env(mock_env_dir, isolate=True)
    env["MOCK_EUID"] = "0"
    env["MOCK_LOOP_CONTROL"] = loop_control
    
    res = subprocess.run(["bash", SCRIPT_PATH, "--check-only"], env=env, capture_output=True, text=True)
    assert res.returncode != 0
    assert "Error: Neither 'qemu-arm-static' nor 'qemu-aarch64-static' was found." in res.stderr

def test_mock_full_execution(mock_env_dir):
    """Verify script executes successfully under fully mocked mounting, chroot, and download environment."""
    tools = ["mount", "unzip", "wget", "xz", "curl", "parted", "chroot", "kpartx", "tar", "truncate", "e2fsck", "resize2fs"]
    for t in tools:
        create_mock_tool(mock_env_dir, t)
        
    create_mock_tool(mock_env_dir, "uname", stdout="Linux")
    create_mock_tool(mock_env_dir, "id", stdout="0")
    
    # Mock losetup to return a path in mock_env_dir
    loop_dev_path = os.path.join(mock_env_dir, "loop99")
    path = os.path.join(mock_env_dir, "losetup")
    with open(path, "w") as f:
        f.write("#!/bin/bash\n")
        f.write("if [[ \"$*\" == *\"-fP\"* ]]; then\n")
        f.write(f"  echo '{loop_dev_path}'\n")
        f.write("fi\n")
        f.write("exit 0\n")
    os.chmod(path, 0o755)

    create_mock_tool(mock_env_dir, "qemu-arm-static")
    
    # Create dummy loop control
    loop_control = os.path.join(mock_env_dir, "loop-control")
    with open(loop_control, "w") as f:
        f.write("")
        
    # Create mock partitions in a temp directory (to pass -f check)
    dummy_boot_part = os.path.join(mock_env_dir, "loop99p1")
    dummy_root_part = os.path.join(mock_env_dir, "loop99p2")
    with open(dummy_boot_part, "w") as f:
        f.write("boot")
    with open(dummy_root_part, "w") as f:
        f.write("root")
        
    # Create dummy cache files
    cache_dir = os.path.join(mock_env_dir, "cache")
    os.makedirs(cache_dir, exist_ok=True)
    with open(os.path.join(cache_dir, "raspios_lite_latest.img"), "w") as f:
        f.write("mock_raw_image")
        
    env = setup_path_env(mock_env_dir, isolate=False)
    env["MOCK_EUID"] = "0"
    env["MOCK_LOOP_CONTROL"] = loop_control
    
    script_abs_path = os.path.abspath(SCRIPT_PATH)
    
    res = subprocess.run(["bash", script_abs_path], env=env, cwd=mock_env_dir, capture_output=True, text=True)
    assert res.returncode == 0
    assert "Success! Customized offline image is ready" in res.stdout

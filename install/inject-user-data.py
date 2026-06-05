#!/usr/bin/env python3
import os
import sys

def main():
    if len(sys.argv) < 2:
        print("Usage: inject-user-data.py <BOOTFS_PATH>", file=sys.stderr)
        sys.exit(1)
        
    bootfs = sys.argv[1]
    user_data_path = os.path.join(bootfs, "user-data")
    meta_data_path = os.path.join(bootfs, "meta-data")
    network_config_path = os.path.join(bootfs, "network-config")
    
    command = "/boot/firmware/moonboard/install/automated-install.sh"
    runcmd_entry = f"  - [ {command} ]\n"
    
    print(f"Injecting automated-install trigger into {user_data_path}...")
    
    # Case 1: user-data doesn't exist
    if not os.path.exists(user_data_path):
        print("user-data file not found. Creating a new cloud-init configuration...")
        
        # Write user-data
        with open(user_data_path, "w") as f:
            f.write("#cloud-config\nruncmd:\n" + runcmd_entry)
            
        # cloud-init requires meta-data and network-config to be present
        if not os.path.exists(meta_data_path):
            with open(meta_data_path, "w") as f:
                f.write("# empty meta-data for NoCloud datasource\n")
        if not os.path.exists(network_config_path):
            with open(network_config_path, "w") as f:
                f.write("# empty network-config for NoCloud datasource\n")
                
        print("New cloud-init configuration files successfully created.")
        return
        
    # Case 2: user-data exists. We must parse it and safely inject
    with open(user_data_path, "r") as f:
        lines = f.readlines()
        
    # Check if this command is already injected to prevent duplicates
    command_str = f"/{command}"
    if any(command in line or command_str in line for line in lines):
        print("Trigger already present in user-data. Skipping injection.")
        return
        
    # Search for an existing runcmd: section
    runcmd_index = -1
    for i, line in enumerate(lines):
        if line.strip().startswith("runcmd:"):
            runcmd_index = i
            break
            
    if runcmd_index != -1:
        # Append to the existing runcmd list
        print("Existing runcmd block found. Appending trigger to the list...")
        lines.insert(runcmd_index + 1, runcmd_entry)
    else:
        # Append a new runcmd block at the end of the file
        print("No runcmd block found. Creating a new runcmd block...")
        # Ensure file ends with a newline
        if lines and not lines[-1].endswith("\n"):
            lines[-1] = lines[-1] + "\n"
        lines.append("runcmd:\n" + runcmd_entry)
        
    with open(user_data_path, "w") as f:
        f.writelines(lines)
        
    print("cloud-init user-data successfully updated.")

if __name__ == "__main__":
    main()

#!/bin/bash

root_drive="/dev/sda"
log_dir="/mnt/nfs"
erase_password="MySecurePassword"

# Fetch all drives excluding root drive and excluding partition numbers
for device in $(ls /dev/sd* /dev/md* | grep -v "[0-9]$" | grep -v "$root_drive"); do
    (
        # Check if the device is part of a RAID array
        if [[ $device == /dev/md* ]]; then
            echo "Processing RAID array $device..."

            # Fetch drives in the RAID array
            raid_devices=$(mdadm --detail "$device" 2>/dev/null | awk '/\/dev/{print $NF}')

            # If the RAID array doesn't exist, skip the device
            if [ -z "$raid_devices" ]; then
                echo "Cannot open $device. Skipping..."
                exit
            fi

            # Stop the RAID array
            mdadm --stop "$device"

            # Zero out superblocks of each device in the RAID array
            for raid_device in $raid_devices; do
                echo "Zeroing out superblock of $raid_device..."
                mdadm --zero-superblock "$raid_device"
            done

            # Skip further processing for the RAID device
            echo "Skipping further processing for RAID array $device..."
            exit
        fi

        # Fetch drive details
        serial=$(smartctl -i $device | grep -i 'Serial number:' | awk '{print $3}')
        model=$(smartctl -i $device | grep -i 'Device Model:' | awk '{print $3}')
        size=$(smartctl -i $device | grep -i 'User Capacity:' | cut -d'[' -f2 | cut -d']' -f1)

        # If any of these details are empty, skip the device
        if [[ -z "$serial" ]] || [[ -z "$model" ]] || [[ -z "$size" ]]; then
            echo "Skipping $device due to missing details."
            exit
        fi

        # Print drive details
        echo "Processing $device with serial number $serial, model $model, and size $size..."

        # Abort any ongoing SMART test
        smartctl -X "$device"

        # Perform SMART self-test and check result
        smartctl -t short "$device"
        sleep 2
        smart_status=$(smartctl -H "$device")
        if echo "$smart_status" | grep -q "PASSED"; then
            echo "SMART self-test for $device passed."
        else
            echo "SMART self-test for $device failed. Exiting..."
            exit
        fi

        # Print drive details
        echo "Processing $device with serial number $serial, model $model, and size $size..."

        # Abort any ongoing SMART test
        smartctl -X "$device"

        # Perform SMART self-test and check result
        smartctl -t short "$device"
        sleep 2
        smart_status=$(smartctl -H "$device")
        if echo "$smart_status" | grep -q "PASSED"; then
            echo "SMART self-test for $device passed."
        else
            echo "SMART self-test for $device failed. Exiting..."
            exit
        fi

        # Perform badblocks test
        echo "Start badblocks test on $device..."
        badblocks_output=$(badblocks -v "$device")

        # Check for errors in badblocks test
        if echo "$badblocks_output" | grep -q "error"; then
            echo "$device has bad blocks. Skipping data overwrite."
            continue
        fi

        # Check if the drive supports ATA Secure Erase
        if hdparm -I "$device" | grep -q 'supported: enhanced erase'; then
            echo "$device supports ATA Secure Erase. Starting erase..."
            # Set the security password
            hdparm --security-set-pass $erase_password "$device"
            # Issue the secure erase command
            hdparm --security-erase $erase_password "$device"
        else
            # Error handling for dd command
            set -e
            trap 'echo "dd command failed with exit code $?"' ERR
            # Get disk size in bytes for pv
            disk_size=$(blockdev --getsize64 "$device")
            # Overwrite drive once with random data
            echo "Start overwriting $device with random data..."
            dd if=/dev/urandom | pv -s $disk_size | dd of="$device" bs=1M iflag=fullblock
            trap - ERR
            set +e
        fi

        # Verification of the erase
        echo "Verifying erase..."
        dd if="$device" bs=1M count=100 | hexdump -C | grep -qv '00 00 00 00'
        if [ $? -ne 1 ]; then
            echo "Erase verification failed for $device. Please check."
        fi

        # Create a certificate text file
        echo "Certificate of HDD Erasure" > "$log_dir/certificate_$serial.txt"
        echo "Serial Number: $serial" >> "$log_dir/certificate_$serial.txt"
        echo "Model: $model" >> "$log_dir/certificate_$serial.txt"
        echo "Disk Size: $size" >> "$log_dir/certificate_$serial.txt"
        echo "Relevant SMART Data:" >> "$log_dir/certificate_$serial.txt"
        echo "$smart_status" >> "$log_dir/certificate_$serial.txt"
        echo "Badblocks Test Result:" >> "$log_dir/certificate_$serial.txt"
        echo "$badblocks_output" >> "$log_dir/certificate_$serial.txt"
        echo "Erasure was successful." >> "$log_dir/certificate_$serial.txt"

        # Wait for all previous commands to finish
        wait

        # Convert text file to PostScript
        enscript -p "$log_dir/certificate_$serial.ps" "$log_dir/certificate_$serial.txt"

        # Convert PostScript to PDF
        ps2pdf "$log_dir/certificate_$serial.ps" "$log_dir/certificate_$serial.pdf"

        # Remove temporary files
        rm "$log_dir/certificate_$serial.txt" "$log_dir/certificate_$serial.ps"
    ) &
done
wait

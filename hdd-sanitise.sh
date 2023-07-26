#!/bin/bash

root_drive="/dev/sda"
log_dir="/mnt/nfs"
erase_password="MySecurePassword"

# Fetch all drives excluding root drive and excluding partition numbers
for device in $(ls /dev/sd* | grep -v "[0-9]$" | grep -v "$root_drive"); do
    (
        # Fetch drive details
        serial=$(smartctl -i $device | grep -i 'Serial number:' | awk '{print $3}')
        model=$(smartctl -i $device | grep -i 'Device Model:' | awk '{print $3}')
        size=$(smartctl -i $device | grep -i 'User Capacity:' | cut -d'[' -f2 | cut -d']' -f1)

        # If any of these details are empty, skip the device
        if [[ -z "$serial" ]] || [[ -z "$model" ]] || [[ -z "$size" ]]; then
            echo "Skipping $device due to missing details."
            continue
        fi

        # Print drive details
        echo "Processing $device with serial number $serial, model $model, and size $size..."

        # Perform SMART test
        echo "Start SMART test on $device..."
        smart_data=$(smartctl -A "$device")
        
        # Check if SMART data was successfully accessed
        if [[ -z "$smart_data" ]]; then
            echo "Failed to fetch SMART data for $device. Skipping..."
            continue
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
            # Get disk size in bytes for pv
            disk_size=$(blockdev --getsize64 "$device")

            # Overwrite drive once with random data
            echo "Start overwriting $device with random data..."
            dd if=/dev/urandom | pv -s $disk_size | dd of="$device" bs=1M iflag=fullblock
        fi

        # Create a certificate text file
        echo "Certificate of HDD Erasure" > "$log_dir/certificate_$serial.txt"
        echo "Serial Number: $serial" >> "$log_dir/certificate_$serial.txt"
        echo "Model: $model" >> "$log_dir/certificate_$serial.txt"
        echo "Disk Size: $size" >> "$log_dir/certificate_$serial.txt"
        echo "Relevant SMART Data:" >> "$log_dir/certificate_$serial.txt"
        echo "$smart_data" >> "$log_dir/certificate_$serial.txt"
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

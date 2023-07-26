# hdd-sanitise

A comprehensive HDD sanitization and reporting script for Unix-based systems.

## Description

`hdd-sanitise` is a bash script designed to automate the process of HDD sanitization. It not only wipes data but also runs SMART and badblocks tests, creates erasure certificates, and converts these certificates to PDF.

## Prerequisites

Ubuntu 22.04
Before running the script, you need to install some necessary tools. Run the following commands:

```
sudo apt-get update && sudo apt-get install smartmontools pv nfs-kernel-server enscript ghostscript hdparm
sudo mkdir -p /mnt/nfs
sudo chown nobody:nogroup /mnt/nfs
sudo chmod 777 /mnt/nfs
sudo nano /etc/exports
```

In the exports file, add the following lines:

```
/mnt/nfs 192.168.1.0/24(rw,sync,no_subtree_check) #enter correct subnet
/mnt/nfs 192.168.0.0/24(rw,sync,no_subtree_check) #enter correct subnet
```

Finally, run these commands:

```
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
sudo chmod +x hdd
```

## Usage

Once you have set up your environment, you can run the hdd_sanitise.sh script with root privileges.

## Note for Mac users

If you're using a Mac, you may need to mount NFS share with the following command:

```
sudo mount -o resvport -t nfs 192.168.0.80:/mnt/nfs /Users/User/Documents/NFS/
```

## License

Please modify this template to suit your specific needs, such as adding more details about what the script does, its output, how to use the script, and any prerequisites users need to know about.

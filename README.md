# ApptainerROS

Makefile to easy install and deploy any version of ros.
```bash
make build VERSION="noetic"
```
build to only create the apptainer of a ros version

deploy to create the container and set a setup at the same location that the normal install of ros to be easily used.

# Issue with remote session on Ubuntu 22.04 on LAAS Config:

if you can build the apptainer due to setuid issue on you session do this : 
```bash
sudo usermod -v 79750000-797599999 <username>
sudo usermod -w 79750000-797599999 <username>
```
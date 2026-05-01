#! /usr/bin/bash
service udev start &
sleep 1
# udevadm control --reload
udevadm trigger

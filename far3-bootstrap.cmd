@echo off
set "busybox=http://frippery.org/files/busybox/busybox.exe"
set "download=certutil -URLcache -split -f"
echo Downloading busybox.exe from '%busybox%'
%download% %busybox% busybox.exe
echo Executing far3-bootstrap.sh using busybox sh
busybox sh far3-bootstrap.sh

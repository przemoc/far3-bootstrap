$busybox = "http://frippery.org/files/busybox/busybox.exe"
"Downloading busybox.exe from $busybox"
Invoke-WebRequest -Uri $busybox -OutFile busybox.exe
"Executing far3-bootstrap.sh using busybox sh"
.\busybox sh far3-bootstrap.sh $args

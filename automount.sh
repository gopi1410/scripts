#!/bin/bash
#
# pbrisbin 2009, 2010
#
# http://pbrisbin.com:8080/bin/automount
#
# just moves a rules file about to change udev behavior regarding the
# automounting of usb devices. 
#
# see http://wiki.archlinux.org/index.php/Udev for details.
#
###

USECOLOR='YES'

# get those fun BUSY/DONE messages
. /etc/rc.d/functions

# if this file's present, automounting is 'on'
file='/etc/udev/rules.d/11-media-by-label-auto-mount.rules'

message() { echo 'usage: automount [ start | stop | restart ]'; exit 1; }

# find the number of in-use drives and get the next available letter
get_next_letter() {
  local alph n
  
  alph=( $(echo {a..z}) )
  n=$(ls /dev/sd? 2>/dev/null | wc -l)

  echo "${alph[n]}"
}

# mount as /media/<label> or fall back on usbhd-sdxy
write_file() {
  local a="$(get_next_letter)"

  [[ -z "$a" ]] && return 1

  # 7/10/2010 + rule updated
  cat > "$file" << EOF
KERNEL!="sd[$a-z][0-9]", GOTO="media_by_label_auto_mount_end"

# Import FS infos
IMPORT{program}="/sbin/blkid -o udev -p %N"

# Get a label if present, otherwise specify one
ENV{ID_FS_LABEL}!="", ENV{dir_name}="%E{ID_FS_LABEL}"
ENV{ID_FS_LABEL}=="", ENV{dir_name}="usbhd-%k"

# Global mount options
ACTION=="add", ENV{mount_options}="relatime,users"
# Filesystem-specific mount options
ACTION=="add", ENV{ID_FS_TYPE}=="vfat|ntfs", ENV{mount_options}="\$env{mount_options},utf8,gid=100,umask=002"

# Mount the device
ACTION=="add", RUN+="/bin/mkdir -p /media/%E{dir_name}", RUN+="/bin/mount -o \$env{mount_options} /dev/%k /media/%E{dir_name}"

# Clean up after removal
ACTION=="remove", ENV{dir_name}!="", RUN+="/bin/umount -l /media/%E{dir_name}", RUN+="/bin/rmdir /media/%E{dir_name}"

# Exit
LABEL="media_by_label_auto_mount_end"
EOF

}

# write out the file to enable automounting
turn_on() { 
  stat_busy 'Turning on automount'
  [[ -f "$file" ]] || write_file && stat_done || stat_fail
}

# remove the file to disable automounting
turn_off() { 
  stat_busy 'Turning off automount'
  [[ -f "$file" ]] && rm "$file" && stat_done || stat_fail
}

check_state() { [[ -f "$file" ]] && echo 'on' || echo 'off'; }

# no args will just print current state
[[ -z "$1" ]] && check_state

# must be root to change things
[[ $(id -u) -ne 0 ]] && exit 1

case "$1" in
  start)   turn_on           ;;
  stop)    turn_off          ;;
  restart) turn_off; turn_on ;;
  *)       message           ;;
esac

#!/bin/sh

case $1 in
  post)
    /sbin/modprobe -r psmouse && /sbin/modprobe psmouse 
  ;;
esac

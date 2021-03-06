#!/bin/bash
# Copyright (C) 2012 Anders Sundman <anders@4zm.org>
#
# This script is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# This script sets up an IP Proxy for testing how server and client 
# applications handle network deterioration. 
#
# [DST: Eg. DB Server] <-> [PROXY] <-> [Application]
#

# Default arg values
INTERFACE=eth0
LATENCY=200ms
LOSS=1.0%
CORRUPTION=

# Parse args
NO_ARGS=$#
while [ $# -gt 0 ] ; do
  case $1 in
    --dst)        DSTIP=$2      ; shift 2 ;;
    --interface)  INTERFACE=$2  ; shift 2 ;;
    --latency)    LATENCY=$2    ; shift 2 ;;
    --loss)       LOSS=$2       ; shift 2 ;; 
    --corruption) CORRUPTION=$2 ; shift 2 ;;
    --help)       HELP="yes"    ; shift 1 ;;
     *)                           shift 1 ;;
  esac
done

# Usage on missing args
if [ $NO_ARGS -eq 0 ] || [ "x$HELP" = "xyes" ]; then
  echo "Usage: $0 --dst xx.xx.xx.xx [--interface eth0] [--latency 200ms] [--loss 1.0%] [--corruption 0.1%]"
  exit 1
fi

# Root check
if [[ $EUID -ne 0 ]]; then
  echo "Only root can run this script"
  exit 1
fi

# Find the IP:addr of the specified interface.
PROXYIP=$(ifconfig $INTERFACE | sed -r -n "s/^.*inet addr:([0-9\.]+).*$/\1/p")

# Sanity checks
if ! [ "$DSTIP" ] || ! [ "$PROXYIP" ] ; then
  echo "Bad proxy ip"
  exit 1
fi

# Enable forwarding
echo "[+] Turning on ip forwarding for $INTERFACE"
echo 1 | tee /proc/sys/net/ipv4/conf/$INTERFACE/forwarding > /dev/null

# Setup the proxy
echo "[+] Seting up iptables to nat $DSTIP <-> $PROXYIP"
iptables -F
iptables -P FORWARD ACCEPT

iptables -F -t nat
iptables -A PREROUTING  -t nat -d $PROXYIP -j DNAT --to $DSTIP
iptables -A POSTROUTING -t nat -d $DSTIP -j SNAT --to $PROXYIP

TC_CMD="tc qdisc replace dev $INTERFACE root netem"

# Latency
if [ "$LATENCY" ] ; then
  echo "[+] Adding $LATENCY latency to $INTERFACE"
  TC_CMD="$TC_CMD delay $LATENCY"
fi

# Random package loss
if [ "$LOSS" ] ; then
  echo "[+] Adding $LOSS package loss to $INTERFACE"
  TC_CMD="$TC_CMD loss $LOSS"
fi

# Single bit corruption of packages
if [ "$CORRUPTION" ] ; then
  echo "[+] Adding $CORRUPTION package single bit corruption to $INTERFACE"
  TC_CMD="$TC_CMD corrupt $CORRUPTION"
fi

# Execute the tc cmd
$TC_CMD


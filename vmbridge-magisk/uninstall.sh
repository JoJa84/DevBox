#!/system/bin/sh
# Codefone vmbridge uninstall hook.
# Runs when Magisk removes the module. We revert the persistent TCP ADB flag
# and drop our firewall rule. adbkeys stay — removing them would brick the
# existing VM's bridge until it re-registered.

resetprop --delete persist.adb.tcp.port 2>/dev/null
setprop service.adb.tcp.port 0

iptables -D INPUT -p tcp --dport 5555 -j DROP 2>/dev/null
iptables -D INPUT -p tcp --dport 5555 -i avf_tap_fixed -j ACCEPT 2>/dev/null
iptables -D INPUT -p tcp --dport 5555 -i lo -j ACCEPT 2>/dev/null
ip6tables -D INPUT -p tcp --dport 5555 -j DROP 2>/dev/null

stop adbd
sleep 1
start adbd
exit 0

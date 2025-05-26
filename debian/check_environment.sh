#!/bin/bash

# Проверка: выполняется ли скрипт от имени root
if [ "$(id -u)" != "0" ]; then
    echo "Ошибка: этот скрипт требует прав root"
    exit 1
fi

# Проверка, установлен ли sing-box
if command -v sing-box &> /dev/null; then
    current_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
    echo "sing-box уже установлен, версия: $current_version"
else
    echo "sing-box не установлен"
fi

# Проверка включения IP-перенаправления для IPv4 и IPv6
ipv4_forward=$(sysctl net.ipv4.ip_forward | awk '{print $3}')
ipv6_forward=$(sysctl net.ipv6.conf.all.forwarding | awk '{print $3}')

if [ "$ipv4_forward" -eq 1 ] && [ "$ipv6_forward" -eq 1 ]; then
    echo "IP-перенаправление уже включено"
else
    echo "Включение IP-перенаправления..."
    sudo sed -i '/net.ipv4.ip_forward/s/^#//;/net.ipv6.conf.all.forwarding/s/^#//' /etc/sysctl.conf
    sudo sysctl -p
    echo "IP-перенаправление успешно включено"
fi

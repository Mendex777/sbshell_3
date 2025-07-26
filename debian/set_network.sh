#!/bin/bash

# Определение цветов
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # Без цвета

# Обработка сигнала Ctrl+C
trap 'echo -e "\n${RED}Операция отменена, возвращаемся в меню настройки сети.${NC}"; exit 1' SIGINT

# Получение текущего IP-адреса, шлюза и DNS сервера
CURRENT_IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}')
CURRENT_GATEWAY=$(ip route show default | awk '{print $3}')
CURRENT_DNS=$(grep 'nameserver' /etc/resolv.conf | awk '{print $2}')

echo -e "${YELLOW}Текущий IP-адрес: $CURRENT_IP${NC}"
echo -e "${YELLOW}Текущий адрес шлюза: $CURRENT_GATEWAY${NC}"
echo -e "${YELLOW}Текущий DNS сервер: $CURRENT_DNS${NC}"

# Получение имени сетевого интерфейса
INTERFACE=$(ip -br link show | awk '{print $1}' | grep -v "lo" | head -n 1)
[ -z "$INTERFACE" ] && { echo -e "${RED}Сетевой интерфейс не найден, выход из программы.${NC}"; exit 1; }

echo -e "${YELLOW}Обнаружен сетевой интерфейс: $INTERFACE${NC}"

# Определение системы управления сетью
if [ -d "/etc/netplan" ] && ls /etc/netplan/*.yaml >/dev/null 2>&1; then
    NETWORK_MANAGER="netplan"
    echo -e "${YELLOW}Обнаружена система netplan${NC}"
elif [ -f "/etc/network/interfaces" ]; then
    NETWORK_MANAGER="interfaces"
    echo -e "${YELLOW}Обнаружена система /etc/network/interfaces${NC}"
else
    echo -e "${RED}Не удалось определить систему управления сетью${NC}"
    exit 1
fi

while true; do
    # Запрос у пользователя статического IP, шлюза и DNS серверов
    read -rp "Введите статический IP-адрес: " IP_ADDRESS
    read -rp "Введите адрес шлюза: " GATEWAY
    read -rp "Введите адреса DNS серверов (несколько через пробел): " DNS_SERVERS

    echo -e "${YELLOW}Введённые данные конфигурации:${NC}"
    echo -e "IP-адрес: $IP_ADDRESS"
    echo -e "Адрес шлюза: $GATEWAY"
    echo -e "DNS серверы: $DNS_SERVERS"

    read -rp "Подтвердить введённые данные? (y/n): " confirm_choice
    if [[ "$confirm_choice" =~ ^[Yy]$ ]]; then
        if [ "$NETWORK_MANAGER" = "netplan" ]; then
            # Конфигурация для netplan
            NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
            
            # Создание конфигурации netplan
            cat > $NETPLAN_FILE <<EOL
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: false
      addresses:
        - $IP_ADDRESS/24
      gateway4: $GATEWAY
      nameservers:
        addresses: [$(echo $DNS_SERVERS | sed 's/ /, /g')]
EOL
            
            # Применение конфигурации netplan
            sudo netplan apply
            
        else
            # Конфигурация для /etc/network/interfaces
            INTERFACES_FILE="/etc/network/interfaces"
            RESOLV_CONF_FILE="/etc/resolv.conf"

            # Обновление сетевой конфигурации
            cat > $INTERFACES_FILE <<EOL
# Сетевой интерфейс loopback
auto lo
iface lo inet loopback

# Основной сетевой интерфейс
allow-hotplug $INTERFACE
iface $INTERFACE inet static
    address $IP_ADDRESS
    netmask 255.255.255.0
    gateway $GATEWAY
EOL

            # Обновление файла resolv.conf с DNS серверами
            echo > $RESOLV_CONF_FILE
            for dns in $DNS_SERVERS; do
                echo "nameserver $dns" >> $RESOLV_CONF_FILE
            done

            # Перезапуск сетевого сервиса
            sudo systemctl restart networking
        fi

        echo -e "${GREEN}Статический IP и DNS успешно настроены!${NC}"
        break
    else
        echo -e "${RED}Пожалуйста, введите данные заново.${NC}"
    fi
done

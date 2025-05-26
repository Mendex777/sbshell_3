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
        # Пути к конфигурационным файлам
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

        echo -e "${GREEN}Статический IP и DNS успешно настроены!${NC}"
        break
    else
        echo -e "${RED}Пожалуйста, введите данные заново.${NC}"
    fi
done

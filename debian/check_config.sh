#!/bin/bash

# Определение цветов
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

CONFIG_FILE="/etc/sing-box/config.json"

if [ -f "$CONFIG_FILE" ]; then
    echo -e "${CYAN}Проверка конфигурационного файла ${CONFIG_FILE}...${NC}"
    
    if sing-box check -c "$CONFIG_FILE"; then
        echo -e "${CYAN}Конфигурационный файл успешно прошёл проверку!${NC}"
    else
        echo -e "${RED}Проверка конфигурационного файла не удалась!${NC}"
        exit 1
    fi
else
    echo -e "${RED}Конфигурационный файл ${CONFIG_FILE} не существует!${NC}"
    exit 1
fi

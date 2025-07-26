#!/bin/bash

# Определение цветов
CYAN='\033[0;36m'
GREEN='\033[0;32m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Каталог для скриптов
SCRIPT_DIR="/etc/sing-box/scripts"

# Проверка текущего режима работы
check_mode() {
    echo "Режим TProxy"
}

# Применение правил файрвола
apply_firewall() {
    bash "$SCRIPT_DIR/configure_tproxy.sh"
}

# Запуск службы sing-box
start_singbox() {
    echo -e "${CYAN}Проверка, что сеть не через прокси...${NC}"
    STATUS_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "https://www.google.com")

    if [ "$STATUS_CODE" -eq 200 ]; then
        echo -e "${RED}Сеть сейчас через прокси. Для запуска sing-box требуется прямое подключение. Пожалуйста, настройте!${NC}"
        read -rp "Выполнить скрипт настройки сети (поддерживается только Debian)? (y/n/skip): " network_choice
        if [[ "$network_choice" =~ ^[Yy]$ ]]; then
            bash "$SCRIPT_DIR/set_network.sh"
            STATUS_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "https://www.google.com")
            if [ "$STATUS_CODE" -eq 200 ]; then
                echo -e "${RED}После изменений сеть все еще через прокси, проверьте настройки!${NC}"
                exit 1
            fi
        elif [[ "$network_choice" =~ ^[Ss]kip$ ]]; then
            echo -e "${CYAN}Пропускаем проверку сети, запускаем sing-box напрямую.${NC}"
        else
            echo -e "${RED}Пожалуйста, переключитесь на сеть без прокси перед запуском sing-box.${NC}"
            exit 1
        fi
    else
        echo -e "${CYAN}Сеть не через прокси, можно запускать sing-box.${NC}"
    fi

    sudo systemctl restart sing-box &>/dev/null
    
    apply_firewall

    if systemctl is-active --quiet sing-box; then
        echo -e "${GREEN}sing-box успешно запущен${NC}"
        mode=$(check_mode)
        echo -e "${MAGENTA}Текущий режим запуска: ${mode}${NC}"
    else
        echo -e "${RED}Не удалось запустить sing-box, проверьте логи${NC}"
    fi
}

# Запрос подтверждения запуска у пользователя
read -rp "Запустить sing-box? (y/n): " confirm_start
if [[ "$confirm_start" =~ ^[Yy]$ ]]; then
    start_singbox
else
    echo -e "${CYAN}Запуск sing-box отменён.${NC}"
    exit 0
fi

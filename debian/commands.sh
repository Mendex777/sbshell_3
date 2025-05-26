#!/bin/bash

# Определение цветов
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

function view_firewall_rules() {
    echo -e "${YELLOW}Просмотр правил брандмауэра...${NC}"
    sudo nft list ruleset
    read -rp "Нажмите Enter, чтобы вернуться в подменю..."
}

function view_logs() {
    echo -e "${YELLOW}Просмотр логов...${NC}"
    sudo journalctl -u sing-box --output cat -e
    read -rp "Нажмите Enter, чтобы вернуться в подменю..."
}

function live_logs() {
    echo -e "${YELLOW}Просмотр логов в реальном времени...${NC}"
    sudo journalctl -u sing-box -f --output=cat
    read -rp "Нажмите Enter, чтобы вернуться в подменю..."
}

function check_config() {
    echo -e "${YELLOW}Проверка конфигурационного файла...${NC}"
    bash /etc/sing-box/scripts/check_config.sh
    read -rp "Нажмите Enter, чтобы вернуться в подменю..."
}

function show_submenu() {
    echo -e "${CYAN}=========== Подменю ===========${NC}"
    echo -e "${MAGENTA}1. Просмотр правил брандмауэра${NC}"
    echo -e "${MAGENTA}2. Просмотр логов${NC}"
    echo -e "${MAGENTA}3. Просмотр логов в реальном времени${NC}"
    echo -e "${MAGENTA}4. Проверка конфигурационного файла${NC}"
    echo -e "${MAGENTA}0. Вернуться в главное меню${NC}"
    echo -e "${CYAN}==============================${NC}"
}

function handle_submenu_choice() {
    while true; do
        read -rp "Выберите действие: " choice
        case $choice in
            1) view_firewall_rules ;;
            2) view_logs ;;
            3) live_logs ;;
            4) check_config ;;
            0) return 0 ;;
            *) echo -e "${RED}Неверный выбор${NC}" ;;
        esac
        show_submenu
    done
    return 0
}

menu_active=true
while $menu_active; do
    show_submenu
    handle_submenu_choice
    choice_returned=$?
    if [[ $choice_returned -eq 0 ]]; then
        menu_active=false
    fi
done

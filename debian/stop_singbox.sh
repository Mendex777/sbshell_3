#!/bin/bash

# Определение цветов
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Каталог для скриптов
SCRIPT_DIR="/etc/sing-box/scripts"

# Остановка службы sing-box
stop_singbox() {
    sudo systemctl stop sing-box

    if ! systemctl is-active --quiet sing-box; then
        echo -e "${GREEN}sing-box остановлен${NC}"

        # Запрос подтверждения очистки правил файрвола
        read -rp "Очистить правила файрвола? (y/n): " confirm_cleanup
        if [[ "$confirm_cleanup" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}Выполняется очистка правил файрвола...${NC}"
            bash "$SCRIPT_DIR/clean_nft.sh"
            echo -e "${GREEN}Очистка правил файрвола завершена${NC}"
        else
            echo -e "${CYAN}Очистка правил файрвола отменена.${NC}"
        fi

    else
        echo -e "${RED}Не удалось остановить sing-box, проверьте логи${NC}"
    fi
}

# Запрос подтверждения остановки у пользователя
read -rp "Остановить sing-box? (y/n): " confirm_stop
if [[ "$confirm_stop" =~ ^[Yy]$ ]]; then
    stop_singbox
else
    echo -e "${CYAN}Остановка sing-box отменена.${NC}"
    exit 0
fi

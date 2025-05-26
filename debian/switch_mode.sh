#!/bin/bash

# Определение цветов
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Проверка, установлен ли sing-box
if ! command -v sing-box &> /dev/null; then
    echo "Пожалуйста, установите sing-box перед запуском."
    sudo bash /etc/sing-box/scripts/install_singbox.sh
    exit 1
fi

# Остановка службы sing-box
function stop_singbox() {
    sudo systemctl stop sing-box
    if ! systemctl is-active --quiet sing-box; then
        echo "sing-box остановлен" >/dev/null
    else
        exit 1
    fi
}

# Логика переключения режима
echo "Начинается переключение режима... Пожалуйста, следуйте инструкциям."

while true; do
    # Выбор режима
    read -rp "Выберите режим (1: режим TProxy, 2: режим TUN): " mode_choice

    case $mode_choice in
        1)
            stop_singbox
            echo "MODE=TProxy" | sudo tee /etc/sing-box/mode.conf > /dev/null
            echo -e "${GREEN}Текущий выбранный режим: режим TProxy${NC}"
            break
            ;;
        2)
            stop_singbox
            echo "MODE=TUN" | sudo tee /etc/sing-box/mode.conf > /dev/null
            echo -e "${GREEN}Текущий выбранный режим: режим TUN${NC}"
            break
            ;;
        *)
            echo -e "${RED}Неверный выбор, пожалуйста, введите снова.${NC}"
            ;;
    esac
done

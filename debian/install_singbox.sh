#!/bin/bash

# Определение цветов
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Проверка, установлен ли sing-box
if command -v sing-box &> /dev/null; then
    echo -e "${CYAN}sing-box уже установлен, пропускаем этап установки${NC}"
else
    # Добавление официального GPG ключа и репозитория
    sudo mkdir -p /etc/apt/keyrings
    sudo curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
    sudo chmod a+r /etc/apt/keyrings/sagernet.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" | sudo tee /etc/apt/sources.list.d/sagernet.list > /dev/null

    # Обновление списка пакетов
    echo "Обновляем список пакетов, пожалуйста, подождите..."
    sudo apt-get update -qq > /dev/null 2>&1

    # Выбор версии для установки: стабильная или бета
    while true; do
        read -rp "Выберите версию для установки (1: стабильная, 2: бета): " version_choice
        case $version_choice in
            1)
                echo "Устанавливаем стабильную версию..."
                sudo apt-get install sing-box -yq > /dev/null 2>&1
                echo "Установка завершена"
                break
                ;;
            2)
                echo "Устанавливаем бета-версию..."
                sudo apt-get install sing-box-beta -yq > /dev/null 2>&1
                echo "Установка завершена"
                break
                ;;
            *)
                echo -e "${RED}Неверный выбор, пожалуйста, введите 1 или 2.${NC}"
                ;;
        esac
    done

    # Проверка успешности установки
    if command -v sing-box &> /dev/null; then
        sing_box_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
        echo -e "${CYAN}sing-box успешно установлен, версия: ${NC} $sing_box_version"
    else
        echo -e "${RED}Установка sing-box не удалась, проверьте логи или настройки сети${NC}"
    fi
fi

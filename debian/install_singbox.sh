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

    # Установка стабильной версии
    echo "Устанавливаем стабильную версию..."
    sudo apt-get install sing-box -yq > /dev/null 2>&1
    echo "Установка завершена"

    # Проверка успешности установки
    if command -v sing-box &> /dev/null; then
        sing_box_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
        echo -e "${CYAN}sing-box успешно установлен, версия: ${NC} $sing_box_version"
    else
        echo -e "${RED}Установка sing-box не удалась, проверьте логи или настройки сети${NC}"
    fi
fi

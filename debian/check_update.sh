#!/bin/bash

# Определение цветов для вывода
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

echo "Проверка последней версии sing-box..."
sudo apt-get update -qq > /dev/null 2>&1

# Проверка, установлен ли sing-box
if command -v sing-box &> /dev/null; then
    current_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
    echo -e "${CYAN}Текущая установленная версия sing-box:${NC} $current_version"
    
    stable_version=$(apt-cache policy sing-box | grep Candidate | awk '{print $2}')
    beta_version=$(apt-cache policy sing-box-beta | grep Candidate | awk '{print $2}')
    
    echo -e "${CYAN}Последняя стабильная версия:${NC} $stable_version"
    echo -e "${CYAN}Последняя тестовая версия:${NC} $beta_version"
    
    while true; do
        read -rp "Хотите переключиться на другую версию? (1: стабильная, 2: тестовая) (текущая: $current_version, Enter — отмена): " switch_choice
        case $switch_choice in
            1)
                echo "Вы выбрали переключение на стабильную версию"
                sudo apt-get install sing-box -y
                break
                ;;
            2)
                echo "Вы выбрали переключение на тестовую версию"
                sudo apt-get install sing-box-beta -y
                break
                ;;
            '')
                echo "Отмена переключения версии"
                break
                ;;
            *)
                echo -e "${RED}Неверный выбор. Введите 1 или 2.${NC}"
                ;;
        esac
    done
else
    echo -e "${RED}sing-box не установлен${NC}"
fi

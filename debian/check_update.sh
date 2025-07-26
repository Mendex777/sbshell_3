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
    
    echo -e "${CYAN}Последняя стабильная версия:${NC} $stable_version"
    
    if [ "$current_version" != "$stable_version" ]; then
        echo "Обновляем до стабильной версии..."
        sudo apt-get install sing-box -y
    else
        echo "У вас уже установлена последняя стабильная версия"
    fi
else
    echo -e "${RED}sing-box не установлен${NC}"
fi

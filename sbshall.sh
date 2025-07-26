#!/bin/bash
# Определение URL для загрузки основного скрипта
MAIN_SCRIPT_URL="https://raw.githubusercontent.com/Mendex777/sbshell_3/refs/heads/main/debian/menu.sh"
 
# Каталог для загрузки скрипта
SCRIPT_DIR="/etc/sing-box/scripts"

# Определение цветов
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Проверка поддержки системы
if [[ "$(uname -s)" != "Linux" ]]; then
    echo -e "${RED}Текущая система не поддерживает выполнение этого скрипта.${NC}"
    exit 1
fi

# Проверка дистрибутива
if grep -qi 'debian\|ubuntu\|armbian' /etc/os-release; then
    echo -e "${GREEN}Обнаружена система Debian/Ubuntu/Armbian — поддерживается.${NC}"
    DEPENDENCIES=("wget" "nftables")

    # Проверка наличия sudo
    if ! command -v sudo &> /dev/null; then
        echo -e "${RED}sudo не установлен.${NC}"
        read -rp "Установить sudo? (y/n): " install_sudo
        if [[ "$install_sudo" =~ ^[Yy]$ ]]; then
            apt-get update
            apt-get install -y sudo
            if ! command -v sudo &> /dev/null; then
                echo -e "${RED}Не удалось установить sudo. Установите его вручную и перезапустите скрипт.${NC}"
                exit 1
            fi
            echo -e "${GREEN}sudo успешно установлен.${NC}"
        else
            echo -e "${RED}Без sudo скрипт не может продолжить работу.${NC}"
            exit 1
        fi
    fi

    # Проверка и установка недостающих зависимостей
    for DEP in "${DEPENDENCIES[@]}"; do
        if [ "$DEP" == "nftables" ]; then
            CHECK_CMD="nft --version"
        else
            CHECK_CMD="wget --version"
        fi

        if ! $CHECK_CMD &> /dev/null; then
            echo -e "${RED}$DEP не установлен.${NC}"
            read -rp "Установить $DEP? (y/n): " install_dep
            if [[ "$install_dep" =~ ^[Yy]$ ]]; then
                sudo apt-get update
                sudo apt-get install -y "$DEP"
                if ! $CHECK_CMD &> /dev/null; then
                    echo -e "${RED}Не удалось установить $DEP. Установите вручную и перезапустите скрипт.${NC}"
                    exit 1
                fi
                echo -e "${GREEN}$DEP успешно установлен.${NC}"
            else
                echo -e "${RED}Без $DEP скрипт не может продолжить работу.${NC}"
                exit 1
            fi
        fi
    done
else
    echo -e "${RED}Текущая система не является Debian/Ubuntu/Armbian — не поддерживается.${NC}"
    exit 1
fi

# Создание каталога скриптов и установка прав
sudo mkdir -p "$SCRIPT_DIR"
sudo chown "$(whoami)":"$(whoami)" "$SCRIPT_DIR"

# Загрузка и запуск основного скрипта
wget -q -O "$SCRIPT_DIR/menu.sh" "$MAIN_SCRIPT_URL"

echo -e "${GREEN}Скрипт загружается, пожалуйста, подождите...${NC}"
#echo -e "${YELLOW}Внимание: для установки или обновления sing-box рекомендуется использовать подключение через прокси, а для запуска — отключать его!${NC}"

if ! [ -f "$SCRIPT_DIR/menu.sh" ]; then
    echo -e "${RED}Не удалось загрузить основной скрипт. Проверьте сетевое подключение.${NC}"
    exit 1
fi

chmod +x "$SCRIPT_DIR/menu.sh"
bash "$SCRIPT_DIR/menu.sh"

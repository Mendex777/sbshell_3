#!/bin/bash

UI_DIR="/etc/sing-box/ui"                      # Папка с UI
BACKUP_DIR="/tmp/sing-box/ui_backup"           # Папка для бэкапов UI
TEMP_DIR="/tmp/sing-box-ui"                     # Временная папка для загрузки UI

# URL для загрузки разных UI-панелей
ZASHBOARD_URL="https://gh-proxy.com/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
METACUBEXD_URL="https://gh-proxy.com/https://github.com/MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip"
YACD_URL="https://gh-proxy.com/https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/gh-pages.zip"

# Создаем папки для бэкапов и временные папки
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_DIR"

# Проверка и установка зависимости busybox
check_and_install_dependencies() {
    if ! command -v busybox &> /dev/null; then
        echo -e "\e[31mbusybox не установлен, устанавливаю...\e[0m"
        sudo apt-get update
        sudo apt-get install -y busybox
        export PATH=$PATH:/bin/busybox
        sudo chmod +x /bin/busybox
    fi
}

# Распаковка архива через busybox
unzip_with_busybox() {
    busybox unzip "$1" -d "$2" > /dev/null 2>&1
}

# Получение URL загрузки UI из конфигурационного файла
get_download_url() {
    CONFIG_FILE="/etc/sing-box/config.json"
    DEFAULT_URL="https://gh-proxy.com/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
    
    if [ -f "$CONFIG_FILE" ]; then
        URL=$(grep -oP '(?<="external_ui_download_url": ")[^"]*' "$CONFIG_FILE")
        echo "${URL:-$DEFAULT_URL}"
    else
        echo "$DEFAULT_URL"
    fi
}

# Создаем бэкап текущей UI папки и удаляем её
backup_and_remove_ui() {
    if [ -d "$UI_DIR" ]; then
        echo -e "Делаю резервную копию текущей папки ui..."
        mv "$UI_DIR" "$BACKUP_DIR/$(date +%Y%m%d%H%M%S)_ui"
        echo -e "Резервная копия сохранена в $BACKUP_DIR"
    fi
}

# Загрузка и установка UI из архива
download_and_process_ui() {
    local url="$1"
    local temp_file="$TEMP_DIR/ui.zip"
    
    # Чистим временную папку
    rm -rf "${TEMP_DIR:?}"/*
    
    echo "Загрузка панели..."
    curl -L "$url" -o "$temp_file"
    if [ $? -ne 0 ]; then
        echo -e "\e[31mЗагрузка не удалась, восстанавливаю бэкап...\e[0m"
        [ -d "$BACKUP_DIR" ] && mv "$BACKUP_DIR/"* "$UI_DIR" 2>/dev/null
        return 1
    fi

    # Распаковка архива
    echo "Распаковка..."
    if unzip_with_busybox "$temp_file" "$TEMP_DIR"; then
        mkdir -p "$UI_DIR"
        rm -rf "${UI_DIR:?}"/*
        mv "$TEMP_DIR"/*/* "$UI_DIR"
        echo -e "\e[32mУстановка панели завершена\e[0m"
        return 0
    else
        echo -e "\e[31mРаспаковка не удалась, восстанавливаю бэкап...\e[0m"
        [ -d "$BACKUP_DIR" ] && mv "$BACKUP_DIR/"* "$UI_DIR" 2>/dev/null
        return 1
    fi
}

# Установка UI по умолчанию (из конфигурации)
install_default_ui() {
    echo "Установка UI по умолчанию..."
    DOWNLOAD_URL=$(get_download_url)
    backup_and_remove_ui
    download_and_process_ui "$DOWNLOAD_URL"
}

# Установка выбранного пользователем UI
install_selected_ui() {
    local url="$1"
    backup_and_remove_ui
    download_and_process_ui "$url"
}

# Проверка, установлен ли UI и не пустая ли папка
check_ui() {
    if [ -d "$UI_DIR" ] && [ "$(ls -A "$UI_DIR")" ]; then
        echo -e "\e[32mUI панель установлена\e[0m"
    else
        echo -e "\e[31mUI панель не установлена или папка пустая\e[0m"
    fi
}

# Настройка автоматического обновления UI через cron
setup_auto_update_ui() {
    local schedule_choice
    while true; do
        echo "Выберите частоту автоматического обновления:"
        echo "1. Каждый понедельник"
        echo "2. Первое число каждого месяца"
        read -rp "Введите опцию (1/2, по умолчанию 1): " schedule_choice
        schedule_choice=${schedule_choice:-1}

        if [[ "$schedule_choice" =~ ^[12]$ ]]; then
            break
        else
            echo -e "\e[31mНеверный ввод, введите 1 или 2.\e[0m"
        fi
    done

    if crontab -l 2>/dev/null | grep -q '/etc/sing-box/update-ui.sh'; then
        echo -e "\e[31mОбнаружена уже существующая задача авт обновления.\e[0m"
        read -rp "Перезаписать её? (y/n): " confirm_reset
        if [[ "$confirm_reset" =~ ^[Yy]$ ]]; then
            crontab -l 2>/dev/null | grep -v '/etc/sing-box/update-ui.sh' | crontab -
            echo "Старая задача удалена."
        else
            echo -e "\e[36mСохраняю текущую задачу. Возврат в меню.\e[0m"
            return
        fi
    fi

    # Создание скрипта для обновления UI
    cat > /etc/sing-box/update-ui.sh <<EOF
#!/bin/bash

CONFIG_FILE="/etc/sing-box/config.json"
DEFAULT_URL="https://gh-proxy.com/https://github.com/Zephyruso/zashboard/archive/refs/heads/gh-pages.zip"
URL=\$(grep -oP '(?<="external_ui_download_url": ")[^"]*' "\$CONFIG_FILE")
URL="\${URL:-\$DEFAULT_URL}"

TEMP_DIR="/tmp/sing-box-ui"
UI_DIR="/etc/sing-box/ui"
BACKUP_DIR="/tmp/sing-box/ui_backup"

mkdir -p "\$BACKUP_DIR"
mkdir -p "\$TEMP_DIR"

if [ -d "\$UI_DIR" ]; then
    mv "\$UI_DIR" "\$BACKUP_DIR/\$(date +%Y%m%d%H%M%S)_ui"
fi

curl -L "\$URL" -o "\$TEMP_DIR/ui.zip"
if busybox unzip "\$TEMP_DIR/ui.zip" -d "\$TEMP_DIR"; then
    mkdir -p "\$UI_DIR"
    rm -rf "\${UI_DIR:?}"/*
    mv "\$TEMP_DIR"/*/* "\$UI_DIR"
else
    echo "Распаковка не удалась, восстанавливаю бэкап..."
    [ -d "\$BACKUP_DIR" ] && mv "\$BACKUP_DIR/"* "\$UI_DIR" 2>/dev/null
fi

EOF

    chmod a+x /etc/sing-box/update-ui.sh

    if [ "$schedule_choice" -eq 1 ]; then
        (crontab -l 2>/dev/null; echo "0 0 * * 1 /etc/sing-box/update-ui.sh") | crontab -
        echo -e "\e[32mЗадача автоматического обновления установлена, выполняется по понедельникам\e[0m"
    else
        (crontab -l 2>/dev/null; echo "0 0 1 * * /etc/sing-box/update-ui.sh") | crontab -
        echo -e "\e[32mЗадача автоматического обновления установлена, выполняется 1-го числа каждого месяца\e[0m"
    fi

    systemctl restart cron
}

# Главное меню для управления UI
update_ui() {
    check_and_install_dependencies  # Проверка и установка зависимостей
    while true; do
        echo "Выберите действие:"
        echo "1. Установить UI по умолчанию (из конфигурации)"
        echo "2. Установить/обновить выбранный UI"
        echo "3. Проверить наличие UI панели"
        echo "4. Настроить автоматическое обновление UI"
        read -r -p "Введите опцию (1/2/3/4) или нажмите Enter для выхода: " choice

        if [ -z "$choice" ]; then
            echo "Выход из программы."
            exit 0
        fi

        case "$choice" in
            1)
                install_default_ui
                exit 0
                ;;
            2)
                echo "Выберите панель для установки:"
                echo "1. Zashboard"
                echo "2. Metacubexd"
                echo "3. Yacd"
                read -r -p "Введите опцию (1/2/3): " ui_choice

                case "$ui_choice" in
                    1)
                        install_selected_ui "$ZASHBOARD_URL"
                        ;;
                    2)
                        install_selected_ui "$METACUBEXD_URL"
                        ;;
                    3)
                        install_selected_ui "$YACD_URL"
                        ;;
                    *)
                        echo -e "\e[31mНеверный выбор, возвращаюсь в меню.\e[0m"
                        ;;
                esac
                exit 0
                ;;
            3)
                check_ui
                ;;
            4)
                setup_auto_update_ui
                ;;
            *)
                echo -e "\e[31mНеверный выбор, возвращаюсь в главное меню\e[0m"
                ;;
        esac
    done
}

update_ui

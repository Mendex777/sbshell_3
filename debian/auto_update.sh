#!/bin/bash

# Определение цветов
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Файл конфигурации, вводимый вручную
MANUAL_FILE="/etc/sing-box/manual.conf"

# Создание скрипта для автоматического обновления
cat > /etc/sing-box/update-singbox.sh <<EOF
#!/bin/bash

# Чтение параметров конфигурации, введённых вручную
BACKEND_URL=\$(grep BACKEND_URL $MANUAL_FILE | cut -d'=' -f2-)
SUBSCRIPTION_URL=\$(grep SUBSCRIPTION_URL $MANUAL_FILE | cut -d'=' -f2-)
TEMPLATE_URL=\$(grep TEMPLATE_URL $MANUAL_FILE | cut -d'=' -f2-)

# Формирование полного URL для конфигурационного файла
FULL_URL="\${BACKEND_URL}/config/\${SUBSCRIPTION_URL}&file=\${TEMPLATE_URL}"

# Резервное копирование существующего конфигурационного файла
[ -f "/etc/sing-box/config.json" ] && cp /etc/sing-box/config.json /etc/sing-box/config.json.backup

# Загрузка и проверка нового конфигурационного файла
if curl -L --connect-timeout 10 --max-time 30 "\$FULL_URL" -o /etc/sing-box/config.json; then
    if ! sing-box check -c /etc/sing-box/config.json; then
        echo "Проверка нового конфигурационного файла не пройдена, восстановление из резервной копии..."
        [ -f "/etc/sing-box/config.json.backup" ] && cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
    fi
else
    echo "Не удалось загрузить конфигурационный файл, восстановление из резервной копии..."
    [ -f "/etc/sing-box/config.json.backup" ] && cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
fi

# Перезапуск службы sing-box
systemctl restart sing-box
EOF

chmod a+x /etc/sing-box/update-singbox.sh

while true; do
    echo -e "${CYAN}Пожалуйста, выберите действие:${NC}"
    echo "1. Установить интервал автоматического обновления"
    echo "2. Отменить автоматическое обновление"
    read -rp "Введите выбор (1 или 2, по умолчанию 1): " menu_choice
    menu_choice=${menu_choice:-1}

    if [[ "$menu_choice" == "1" ]]; then
        while true; do
            read -rp "Введите интервал обновления в часах (от 1 до 23, по умолчанию 12 часов): " interval_choice
            interval_choice=${interval_choice:-12}

            if [[ "$interval_choice" =~ ^[1-9]$|^1[0-9]$|^2[0-3]$ ]]; then
                break
            else
                echo -e "${RED}Недопустимый ввод, введите число от 1 до 23.${NC}"
            fi
        done

        # Проверка на наличие существующего задания на обновление
        if crontab -l 2>/dev/null | grep -q '/etc/sing-box/update-singbox.sh'; then
            echo -e "${RED}Обнаружено существующее задание на автоматическое обновление.${NC}"
            read -rp "Перенастроить автоматическое обновление? (y/n): " confirm_reset
            if [[ "$confirm_reset" =~ ^[Yy]$ ]]; then
                crontab -l 2>/dev/null | grep -v '/etc/sing-box/update-singbox.sh' | crontab -
                echo "Старое задание на обновление удалено."
            else
                echo -e "${CYAN}Существующее задание на обновление оставлено без изменений. Возврат в меню.${NC}"
                exit 0
            fi
        fi

        # Добавление нового задания в cron
        (crontab -l 2>/dev/null; echo "0 */$interval_choice * * * /etc/sing-box/update-singbox.sh") | crontab -
        systemctl restart cron

        echo "Задание на периодическое обновление установлено, будет выполняться каждые $interval_choice часов"
        break

    elif [[ "$menu_choice" == "2" ]]; then
        # Отмена автоматического обновления
        if crontab -l 2>/dev/null | grep -q '/etc/sing-box/update-singbox.sh'; then
            crontab -l 2>/dev/null | grep -v '/etc/sing-box/update-singbox.sh' | crontab -
            systemctl restart cron
            echo -e "${CYAN}Автоматическое обновление отменено.${NC}"
        else
            echo -e "${CYAN}Задание на автоматическое обновление не найдено.${NC}"
        fi
        break

    else
        echo -e "${RED}Неверный ввод, пожалуйста, введите 1 или 2.${NC}"
    fi
done

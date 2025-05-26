#!/bin/bash

# Определение цветов
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Файл для ручного ввода конфигурации
MANUAL_FILE="/etc/sing-box/manual.conf"
DEFAULTS_FILE="/etc/sing-box/defaults.conf"

# Получение текущего режима
MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)


prompt_user_input() {
    while true; do
        read -rp "Введите адрес бекенда (оставьте пустым для значения по умолчанию): " BACKEND_URL
        if [ -z "$BACKEND_URL" ]; then
            BACKEND_URL=$(grep BACKEND_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
            if [ -z "$BACKEND_URL" ]; then
                echo -e "${RED}Значение по умолчанию не установлено, пожалуйста, настройте в меню!${NC}"
                continue
            fi
            echo -e "${CYAN}Используется адрес бекенда по умолчанию: $BACKEND_URL${NC}"
        fi
        break
    done

    while true; do
        read -rp "Введите адрес подписки (оставьте пустым для значения по умолчанию): " SUBSCRIPTION_URL
        if [ -z "$SUBSCRIPTION_URL" ]; then
            SUBSCRIPTION_URL=$(grep SUBSCRIPTION_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
            if [ -z "$SUBSCRIPTION_URL" ]; then
                echo -e "${RED}Значение по умолчанию не установлено, пожалуйста, настройте в меню!${NC}"
                continue
            fi
            echo -e "${CYAN}Используется адрес подписки по умолчанию: $SUBSCRIPTION_URL${NC}"
        fi
        break
    done

    while true; do
        read -rp "Введите адрес конфигурационного файла (оставьте пустым для значения по умолчанию): " TEMPLATE_URL
        if [ -z "$TEMPLATE_URL" ]; then
            if [ "$MODE" = "TProxy" ]; then
                TEMPLATE_URL=$(grep TPROXY_TEMPLATE_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
                if [ -z "$TEMPLATE_URL" ]; then
                    echo -e "${RED}Значение по умолчанию не установлено, пожалуйста, настройте в меню!${NC}"
                    continue
                fi
                echo -e "${CYAN}Используется адрес конфигурации TProxy по умолчанию: $TEMPLATE_URL${NC}"
            elif [ "$MODE" = "TUN" ]; then
                TEMPLATE_URL=$(grep TUN_TEMPLATE_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
                if [ -z "$TEMPLATE_URL" ]; then
                    echo -e "${RED}Значение по умолчанию не установлено, пожалуйста, настройте в меню!${NC}"
                    continue
                fi
                echo -e "${CYAN}Используется адрес конфигурации TUN по умолчанию: $TEMPLATE_URL${NC}"
            else
                echo -e "${RED}Неизвестный режим: $MODE${NC}"
                exit 1
            fi
        fi
        break
    done
}


read -rp "Хотите изменить адрес подписки? (y/n): " change_subscription
if [[ "$change_subscription" =~ ^[Yy]$ ]]; then
    # Выполнение ручного ввода параметров
    while true; do
        prompt_user_input

        echo -e "${CYAN}Введённые вами параметры конфигурации:${NC}"
        echo "Адрес бекенда: $BACKEND_URL"
        echo "Адрес подписки: $SUBSCRIPTION_URL"
        echo "Адрес конфигурационного файла: $TEMPLATE_URL"

        read -rp "Подтвердить введённые параметры? (y/n): " confirm_choice
        if [[ "$confirm_choice" =~ ^[Yy]$ ]]; then
           
            cat > "$MANUAL_FILE" <<EOF
BACKEND_URL=$BACKEND_URL
SUBSCRIPTION_URL=$SUBSCRIPTION_URL
TEMPLATE_URL=$TEMPLATE_URL
EOF

            echo "Ручная конфигурация обновлена"
            break
        else
            echo -e "${RED}Пожалуйста, введите параметры заново.${NC}"
        fi
    done
else
    if [ ! -f "$MANUAL_FILE" ]; then
        echo -e "${RED}Адрес подписки пуст, пожалуйста, настройте его!${NC}"
        exit 1
    fi

    # Использование существующих параметров и вывод отладочной информации
    BACKEND_URL=$(grep BACKEND_URL "$MANUAL_FILE" 2>/dev/null | cut -d'=' -f2-)
    SUBSCRIPTION_URL=$(grep SUBSCRIPTION_URL "$MANUAL_FILE" 2>/dev/null | cut -d'=' -f2-)
    TEMPLATE_URL=$(grep TEMPLATE_URL "$MANUAL_FILE" 2>/dev/null | cut -d'=' -f2-)

    if [ -z "$BACKEND_URL" ] || [ -z "$SUBSCRIPTION_URL" ] || [ -z "$TEMPLATE_URL" ]; then
        echo -e "${RED}Адрес подписки пуст, пожалуйста, настройте его!${NC}"
        exit 1
    fi

    echo -e "${CYAN}Текущая конфигурация:${NC}"
    echo "Адрес бекенда: $BACKEND_URL"
    echo "Адрес подписки: $SUBSCRIPTION_URL"
    echo "Адрес конфигурационного файла: $TEMPLATE_URL"
fi

# Формирование полного URL конфигурационного файла
FULL_URL="${BACKEND_URL}/config/${SUBSCRIPTION_URL}&file=${TEMPLATE_URL}"
echo "Сформирован полный URL подписки: $FULL_URL"

# Резервное копирование текущего конфигурационного файла
[ -f "/etc/sing-box/config.json" ] && cp /etc/sing-box/config.json /etc/sing-box/config.json.backup

if curl -L --connect-timeout 10 --max-time 30 "$FULL_URL" -o /etc/sing-box/config.json; then
    echo -e "${GREEN}Обновление конфигурационного файла прошло успешно!${NC}"
    if ! sing-box check -c /etc/sing-box/config.json; then
        echo -e "${RED}Проверка конфигурационного файла не пройдена, восстанавливаем резервную копию...${NC}"
        [ -f "/etc/sing-box/config.json.backup" ] && cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
    fi
else
    echo -e "${RED}Не удалось скачать конфигурационный файл, восстанавливаем резервную копию...${NC}"
    [ -f "/etc/sing-box/config.json.backup" ] && cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
fi

# Перезапуск sing-box и проверка статуса
sudo systemctl restart sing-box

if systemctl is-active --quiet sing-box; then
    echo -e "${GREEN}sing-box успешно запущен${NC}"
else
    echo -e "${RED}Не удалось запустить sing-box${NC}"
fi

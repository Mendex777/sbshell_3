#!/bin/bash

# Определение цветов
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

# Файл для ручного ввода конфигурации
MANUAL_FILE="/etc/sing-box/manual.conf"
DEFAULTS_FILE="/etc/sing-box/defaults.conf"

# Режим по умолчанию - TProxy
MODE="TProxy"

# Функция для запроса параметров у пользователя
prompt_user_input() {
    read -rp "Введите адрес бекенда (нажмите Enter для значения по умолчанию, можно оставить пустым): " BACKEND_URL
    if [ -z "$BACKEND_URL" ]; then
        BACKEND_URL=$(grep BACKEND_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
        echo -e "${CYAN}Используется адрес бекенда по умолчанию: $BACKEND_URL${NC}"
    fi

    read -rp "Введите адрес подписки (нажмите Enter для значения по умолчанию, можно оставить пустым): " SUBSCRIPTION_URL
    if [ -z "$SUBSCRIPTION_URL" ]; then
        SUBSCRIPTION_URL=$(grep SUBSCRIPTION_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
        echo -e "${CYAN}Используется адрес подписки по умолчанию: $SUBSCRIPTION_URL${NC}"
    fi

    read -rp "Введите адрес конфигурационного файла (нажмите Enter для значения по умолчанию, можно оставить пустым): " TEMPLATE_URL
    if [ -z "$TEMPLATE_URL" ]; then
        TEMPLATE_URL=$(grep TPROXY_TEMPLATE_URL "$DEFAULTS_FILE" 2>/dev/null | cut -d'=' -f2-)
        echo -e "${CYAN}Используется адрес конфигурации TProxy по умолчанию: $TEMPLATE_URL${NC}"
    fi
}

while true; do
    prompt_user_input

    # Вывод введённых пользователем данных
    echo -e "${CYAN}Введённые вами параметры конфигурации:${NC}"
    echo "Адрес бекенда: $BACKEND_URL"
    echo "Адрес подписки: $SUBSCRIPTION_URL"
    echo "Адрес конфигурационного файла: $TEMPLATE_URL"

    read -rp "Подтверждаете введённые параметры? (y/n): " confirm_choice
    if [[ "$confirm_choice" =~ ^[Yy]$ ]]; then
        # Обновление файла с ручным вводом конфигурации
        cat > "$MANUAL_FILE" <<EOF
BACKEND_URL=$BACKEND_URL
SUBSCRIPTION_URL=$SUBSCRIPTION_URL
TEMPLATE_URL=$TEMPLATE_URL
EOF

        echo "Ручная конфигурация обновлена."

        # Формирование полного URL для загрузки конфигурации
        if [ -n "$BACKEND_URL" ] && [ -n "$SUBSCRIPTION_URL" ]; then
            FULL_URL="${BACKEND_URL}/config/${SUBSCRIPTION_URL}&file=${TEMPLATE_URL}"
        else
            FULL_URL="${TEMPLATE_URL}"
        fi
        echo "Сформирован полный URL подписки: $FULL_URL"

        while true; do
            # Скачивание и проверка конфигурационного файла
            if curl -L --connect-timeout 10 --max-time 30 "$FULL_URL" -o /etc/sing-box/config.json; then
                echo "Загрузка конфигурационного файла завершена успешно!"
                if ! sing-box check -c /etc/sing-box/config.json; then
                    echo "Проверка конфигурационного файла не пройдена"
                    exit 1
                fi
                break
            else
                echo "Загрузка конфигурационного файла не удалась"
                read -rp "Повторить попытку загрузки? (y/n): " retry_choice
                if [[ "$retry_choice" =~ ^[Nn]$ ]]; then
                    exit 1
                fi
            fi
        done

        break
    else
        echo -e "${RED}Пожалуйста, введите параметры заново.${NC}"
    fi
done

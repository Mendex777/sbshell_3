#!/bin/bash

DEFAULTS_FILE="/etc/sing-box/defaults.conf"

# Запрашиваем у пользователя ввод параметров, если введено пусто — используем значения по умолчанию из файла
read -rp "Введите адрес backend: " BACKEND_URL
BACKEND_URL=${BACKEND_URL:-$(grep BACKEND_URL $DEFAULTS_FILE | cut -d '=' -f2)}

read -rp "Введите адрес подписки: " SUBSCRIPTION_URL
SUBSCRIPTION_URL=${SUBSCRIPTION_URL:-$(grep SUBSCRIPTION_URL $DEFAULTS_FILE | cut -d '=' -f2)}

read -rp "Введите адрес шаблона конфигурации TProxy: " TPROXY_TEMPLATE_URL
TPROXY_TEMPLATE_URL=${TPROXY_TEMPLATE_URL:-$(grep TPROXY_TEMPLATE_URL $DEFAULTS_FILE | cut -d '=' -f2)}

read -rp "Введите адрес шаблона конфигурации TUN: " TUN_TEMPLATE_URL
TUN_TEMPLATE_URL=${TUN_TEMPLATE_URL:-$(grep TUN_TEMPLATE_URL $DEFAULTS_FILE | cut -d '=' -f2)}

# Обновляем файл с конфигурацией по умолчанию
cat > $DEFAULTS_FILE <<EOF
BACKEND_URL=$BACKEND_URL
SUBSCRIPTION_URL=$SUBSCRIPTION_URL
TPROXY_TEMPLATE_URL=$TPROXY_TEMPLATE_URL
TUN_TEMPLATE_URL=$TUN_TEMPLATE_URL
EOF

echo "Конфигурация по умолчанию обновлена"

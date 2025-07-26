#!/bin/bash

# Определение цветов
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # Без цвета

echo -e "${GREEN}Настройка автозапуска при старте системы...${NC}"
echo "Выберите действие (1: Включить автозапуск, 2: Отключить автозапуск)"
read -rp "(1/2): " autostart_choice

apply_firewall() {
    echo "Применение правил файервола для режима TProxy..."
    bash /etc/sing-box/scripts/configure_tproxy.sh
}

case $autostart_choice in
    1)
        # Проверка, включён ли уже автозапуск
        if systemctl is-enabled sing-box.service >/dev/null 2>&1 && systemctl is-enabled nftables-singbox.service >/dev/null 2>&1; then
            echo -e "${GREEN}Автозапуск уже включён, никаких действий не требуется.${NC}"
            exit 0
        fi

        echo -e "${GREEN}Включаем автозапуск...${NC}"

        # Удаляем старый файл сервиса, чтобы избежать дублирования
        sudo rm -f /etc/systemd/system/nftables-singbox.service

        # Создаём сервис nftables-singbox.service
        sudo bash -c 'cat > /etc/systemd/system/nftables-singbox.service <<EOF
[Unit]
Description=Применение правил nftables для Sing-Box
After=network.target

[Service]
ExecStart=/etc/sing-box/scripts/manage_autostart.sh apply_firewall
Type=oneshot
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF'

        # Вносим изменения в sing-box.service, чтобы он зависел от nftables-singbox.service
        sudo bash -c "sed -i '/After=network.target nss-lookup.target network-online.target/a After=nftables-singbox.service' /usr/lib/systemd/system/sing-box.service"
        sudo bash -c "sed -i '/^Requires=/d' /usr/lib/systemd/system/sing-box.service"
        sudo bash -c "sed -i '/\[Unit\]/a Requires=nftables-singbox.service' /usr/lib/systemd/system/sing-box.service"

        # Перезагружаем конфигурацию systemd и включаем сервисы
        sudo systemctl daemon-reload
        sudo systemctl enable nftables-singbox.service sing-box.service
        sudo systemctl start nftables-singbox.service sing-box.service
        cmd_status=$?

        if [ "$cmd_status" -eq 0 ]; then
            echo -e "${GREEN}Автозапуск успешно включён.${NC}"
        else
            echo -e "${RED}Ошибка при включении автозапуска.${NC}"
        fi
        ;;
    2)
        # Проверяем, отключён ли уже автозапуск
        if ! systemctl is-enabled sing-box.service >/dev/null 2>&1 && ! systemctl is-enabled nftables-singbox.service >/dev/null 2>&1; then
            echo -e "${GREEN}Автозапуск уже отключён, никаких действий не требуется.${NC}"
            exit 0
        fi

        echo -e "${RED}Отключаем автозапуск...${NC}"

        # Отключаем и останавливаем сервисы
        sudo systemctl disable sing-box.service
        sudo systemctl disable nftables-singbox.service
        sudo systemctl stop sing-box.service
        sudo systemctl stop nftables-singbox.service

        # Удаляем сервис nftables-singbox.service
        sudo rm -f /etc/systemd/system/nftables-singbox.service

        # Восстанавливаем sing-box.service
        sudo bash -c "sed -i '/After=nftables-singbox.service/d' /usr/lib/systemd/system/sing-box.service"
        sudo bash -c "sed -i '/Requires=nftables-singbox.service/d' /usr/lib/systemd/system/sing-box.service"

        # Перезагружаем конфигурацию systemd
        sudo systemctl daemon-reload
        cmd_status=$?

        if [ "$cmd_status" -eq 0 ]; then
            echo -e "${GREEN}Автозапуск успешно отключён.${NC}"
        else
            echo -e "${RED}Ошибка при отключении автозапуска.${NC}"
        fi
        ;;
    *)
        echo -e "${RED}Неверный выбор.${NC}"
        ;;
esac

# Если скрипт вызван с параметром apply_firewall, вызываем функцию применения правил
if [ "$1" = "apply_firewall" ]; then
    apply_firewall
fi

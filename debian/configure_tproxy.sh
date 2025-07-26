#!/bin/sh

# Параметры конфигурации
TPROXY_PORT=7895           # Должен совпадать с настройками sing-box
ROUTING_MARK=666          # Должен совпадать с настройками sing-box
PROXY_FWMARK=1
PROXY_ROUTE_TABLE=100
INTERFACE=$(ip route show default | awk '/default/ {print $5; exit}')  # Получаем интерфейс по умолчанию

# Набор зарезервированных IP-адресов
ReservedIP4='{ 127.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.0.2.0/24, 198.51.100.0/24, 192.88.99.0/24, 192.168.0.0/16, 203.0.113.0/24, 224.0.0.0/4, 240.0.0.0/4, 255.255.255.255/32 }'
CustomBypassIP='{ 192.168.0.0/16, 10.0.0.0/8 }'  # Пользовательский список IP для обхода

# Считываем текущий режим работы sing-box
MODE=$(grep -oP '(?<=^MODE=).*' /etc/sing-box/mode.conf)

# Проверка существования таблицы маршрутизации
check_route_exists() {
    ip route show table "$1" >/dev/null 2>&1
    return $?
}

# Создание таблицы маршрутизации, если её нет
create_route_table_if_not_exists() {
    if ! check_route_exists "$PROXY_ROUTE_TABLE"; then
        echo "Таблица маршрутизации не найдена, создаём..."
        ip route add local default dev "$INTERFACE" table "$PROXY_ROUTE_TABLE" || { echo "Ошибка при создании таблицы маршрутизации"; exit 1; }
    fi
}

# Ожидание загрузки таблицы маршрутизации (FIB)
wait_for_fib_table() {
    i=1
    while [ $i -le 10 ]; do
        if ip route show table "$PROXY_ROUTE_TABLE" >/dev/null 2>&1; then
            return 0
        fi
        echo "Ожидание загрузки таблицы FIB, ждём $i секунд..."
        i=$((i + 1))
        sleep 1
    done
    echo "Не удалось загрузить таблицу FIB, превышено максимальное число попыток"
    return 1
}

# Очистка правил firewall sing-box
clearSingboxRules() {
    nft list table inet sing-box >/dev/null 2>&1 && nft delete table inet sing-box
    ip rule del fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE 2>/dev/null
    ip route del local default dev "${INTERFACE}" table $PROXY_ROUTE_TABLE 2>/dev/null
    echo "Очистка правил firewall sing-box завершена"
}

# Применяем правила firewall только в режиме TProxy
if [ "$MODE" = "TProxy" ]; then
    echo "Применяем правила firewall для режима TProxy..."

    # Создаём таблицу маршрутизации, если отсутствует
    create_route_table_if_not_exists

    # Ждём готовности таблицы маршрутизации
    if ! wait_for_fib_table; then
        echo "Таблица FIB не готова, выход из скрипта."
        exit 1
    fi

    # Очистка старых правил
    clearSingboxRules

    # Добавляем правила IP и маршруты
    ip -f inet rule add fwmark $PROXY_FWMARK lookup $PROXY_ROUTE_TABLE
    ip -f inet route add local default dev "${INTERFACE}" table $PROXY_ROUTE_TABLE
    sysctl -w net.ipv4.ip_forward=1 > /dev/null

    # Создаём каталог для правил nftables, если его нет
    sudo mkdir -p /etc/sing-box/nft

    # Записываем правила nftables в файл
    cat > /etc/sing-box/nft/nftables.conf <<EOF
table inet sing-box {
    set RESERVED_IPSET {
        type ipv4_addr
        flags interval
        auto-merge
        elements = $ReservedIP4
    }

    chain prerouting_tproxy {
        type filter hook prerouting priority mangle; policy accept;

        # Перенаправление DNS запросов на локальный порт TProxy
        meta l4proto { tcp, udp } th dport 53 tproxy to :$TPROXY_PORT accept

        # Обход пользовательских IP
        ip daddr $CustomBypassIP accept

        # Запрет доступа к локальному порту TProxy
        fib daddr type local meta l4proto { tcp, udp } th dport $TPROXY_PORT reject with icmpx type host-unreachable

        # Обход локальных адресов
        fib daddr type local accept

        # Обход зарезервированных IP
        ip daddr @RESERVED_IPSET accept

        # Оптимизация для установленных TCP-соединений
        meta l4proto tcp socket transparent 1 meta mark set $PROXY_FWMARK accept

        # Перенаправление остального трафика на TProxy с установкой метки
        meta l4proto { tcp, udp } tproxy to :$TPROXY_PORT meta mark set $PROXY_FWMARK
    }

    chain output_tproxy {
        type route hook output priority mangle; policy accept;

        # Пропуск трафика локального loopback
        meta oifname "lo" accept

        # Обход трафика, исходящего от sing-box
        meta mark $ROUTING_MARK accept

        # Маркировка DNS трафика
        meta l4proto { tcp, udp } th dport 53 meta mark set $PROXY_FWMARK

        # Обход NBNS трафика
        udp dport { netbios-ns, netbios-dgm, netbios-ssn } accept

        # Обход пользовательских IP
        ip daddr $CustomBypassIP accept

        # Обход локальных адресов
        fib daddr type local accept

        # Обход зарезервированных IP
        ip daddr @RESERVED_IPSET accept

        # Маркировка и перенаправление остального трафика
        meta l4proto { tcp, udp } meta mark set $PROXY_FWMARK
    }
}
EOF

    # Применяем правила firewall
    nft -f /etc/sing-box/nft/nftables.conf

    # Сохраняем правила для постоянного использования
    nft list ruleset > /etc/nftables.conf

    echo "Правила firewall для режима TProxy успешно применены."
else
    # Применяем правила только для режима TProxy
    echo "Текущий режим не TProxy, правила firewall не применяются." >/dev/null 2>&1
fi

#!/bin/bash

#################################################
# Описание: Скрипт проверки состояния системы sing-box
# Версия: 1.0.0
#################################################

# Определение цветов для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
GRAY='\033[0;37m'
BOLD='\033[1m'
NC='\033[0m' # Без цвета

# Символы для статуса
CHECK_MARK="●"
CROSS_MARK="●"
WARNING_MARK="●"
INFO_MARK="●"

# Функция для вывода заголовка
print_header() {
    echo -e "${BOLD}${CYAN}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${CYAN}│                 СТАТУС СИСТЕМЫ SING-BOX                │${NC}"
    echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────────┘${NC}"
}

# Функция для вывода статуса с цветом
print_status() {
    local status="$1"
    local message="$2"
    local details="$3"
    
    case $status in
        "OK")
            local dots_count=$((50 - ${#message}))
            local dots=$(printf "%*s" $dots_count "" | tr ' ' '.')
            if [ -n "$details" ]; then
                printf "${GREEN}${CHECK_MARK}${NC} %s${GRAY}%s${NC} ${GREEN}[OK]${NC} ${GRAY}%s${NC}\n" "$message" "$dots" "$details"
            else
                printf "${GREEN}${CHECK_MARK}${NC} %s${GRAY}%s${NC} ${GREEN}[OK]${NC}\n" "$message" "$dots"
            fi
            ;;
        "ERROR")
            if [ -n "$details" ]; then
                printf "${RED}${CROSS_MARK}${NC} %-35s ${RED}[FAIL]${NC} ${GRAY}%s${NC}\n" "$message" "$details"
            else
                printf "${RED}${CROSS_MARK}${NC} %-35s ${RED}[FAIL]${NC}\n" "$message"
            fi
            ;;
        "WARNING")
            if [ -n "$details" ]; then
                printf "${YELLOW}${WARNING_MARK}${NC} %-35s ${YELLOW}[WARN]${NC} ${GRAY}%s${NC}\n" "$message" "$details"
            else
                printf "${YELLOW}${WARNING_MARK}${NC} %-35s ${YELLOW}[WARN]${NC}\n" "$message"
            fi
            ;;
        "INFO")
            if [ -n "$details" ]; then
                printf "${BLUE}${INFO_MARK}${NC} %-35s ${BLUE}[INFO]${NC} ${GRAY}%s${NC}\n" "$message" "$details"
            else
                printf "${BLUE}${INFO_MARK}${NC} %-35s ${BLUE}[INFO]${NC}\n" "$message"
            fi
            ;;
    esac
}

# Функция для вывода секции (убрана)
# print_section() {
#     local title="$1"
#     echo -e "${BOLD}${MAGENTA}▶ $title${NC}"
# }

# Проверка статуса службы sing-box
check_singbox_service() {
    if command -v sing-box &> /dev/null; then
        if systemctl is-active --quiet sing-box; then
            print_status "OK" "Статус службы sing-box" "Запущена"
        else
            print_status "ERROR" "Статус службы sing-box" "Остановлена"
        fi
        
        if systemctl is-enabled --quiet sing-box; then
            print_status "OK" "Автозапуск службы sing-box" "Включен"
        else
            print_status "WARNING" "Автозапуск службы sing-box" "Отключен"
        fi
    else
        print_status "ERROR" "Установка sing-box" "sing-box не найден"
    fi
}

# Проверка версии и обновлений
check_version_updates() {
    if command -v sing-box &> /dev/null; then
        local current_version=$(sing-box version 2>/dev/null | grep 'sing-box version' | awk '{print $3}')
        
        # Проверка доступных обновлений
        apt list --upgradable 2>/dev/null | grep -q sing-box
        if [ $? -eq 0 ]; then
            local available_version=$(apt list --upgradable 2>/dev/null | grep sing-box | awk -F'[' '{print $2}' | awk -F']' '{print $1}')
            print_status "WARNING" "Версия sing-box $current_version" "Доступна версия $available_version"
        else
            print_status "OK" "Версия sing-box $current_version" "Актуальная версия"
        fi
    else
        print_status "ERROR" "Версия sing-box" "sing-box не установлен"
    fi
}

# Проверка IP-перенаправления
check_ip_forwarding() {
    local ipv4_forward=$(sysctl net.ipv4.ip_forward 2>/dev/null | awk '{print $3}')
    local ipv6_forward=$(sysctl net.ipv6.conf.all.forwarding 2>/dev/null | awk '{print $3}')
    
    if [ "$ipv4_forward" = "1" ]; then
        print_status "OK" "IPv4 forwarding" "Включено"
    else
        print_status "ERROR" "IPv4 forwarding" "Отключено"
    fi
    
    if [ "$ipv6_forward" = "1" ]; then
        print_status "OK" "IPv6 forwarding" "Включено"
    else
        print_status "ERROR" "IPv6 forwarding" "Отключено"
    fi
}

# Проверка правил файрвола nftables
check_firewall_rules() {
    if command -v nft &> /dev/null; then
        # Проверка наличия таблицы sing-box
        if nft list tables 2>/dev/null | grep -q "inet sing-box"; then
            print_status "OK" "Таблица nftables sing-box" "найдена"
            
            # Проверка правил TProxy
            local tproxy_rules=$(nft list table inet sing-box 2>/dev/null | grep -c "tproxy")
            if [ "$tproxy_rules" -gt 0 ]; then
                print_status "OK" "Правила TProxy" "$tproxy_rules правил активно"
            else
                print_status "WARNING" "Правила TProxy" "Не найдены"
            fi
        else
            print_status "ERROR" "Таблица nftables sing-box" "не найдена"
        fi
    else
        print_status "ERROR" "Система nftables" "Не установлена"
    fi
}

# Проверка конфигурационных файлов
check_config_files() {
    # Проверка основного конфига
    if [ -f "/etc/sing-box/config.json" ]; then
        if sing-box check -c /etc/sing-box/config.json &>/dev/null; then
            print_status "OK" "Конфигурация sing-box" "Валидна"
        else
            print_status "ERROR" "Конфигурация sing-box" "Содержит ошибки"
        fi
    else
        print_status "ERROR" "Конфигурация sing-box" "config.json не найден"
    fi
    
    # Проверка файла режима
    if [ -f "/etc/sing-box/mode.conf" ]; then
        local mode=$(cat /etc/sing-box/mode.conf | grep MODE | cut -d'=' -f2)
        print_status "OK" "Режим работы sing-box" "$mode"
    else
        print_status "WARNING" "Режим работы sing-box" "mode.conf не найден"
    fi
    
    # Проверка файла настроек по умолчанию
    if [ -f "/etc/sing-box/defaults.conf" ]; then
        print_status "OK" "Настройки по умолчанию sing-box" "найдены"
    else
        print_status "WARNING" "Настройки по умолчанию sing-box" "не найдены"
    fi
}

# Проверка сетевого подключения
check_network_connectivity() {
    # Проверка прямого подключения
    if curl -s --max-time 5 "https://www.google.com" >/dev/null 2>&1; then
        print_status "OK" "Интернет соединение" "Доступно"
    else
        print_status "ERROR" "Интернет соединение" "Недоступно"
    fi
    
    # Проверка DNS
    if nslookup google.com >/dev/null 2>&1; then
        print_status "OK" "DNS разрешение" "Работает"
    else
        print_status "ERROR" "DNS разрешение" "Не работает"
    fi
}

# Проверка системных ресурсов
check_system_resources() {
    # Проверка использования CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')
    if (( $(echo "$cpu_usage < 80" | bc -l) )); then
        print_status "OK" "Использование CPU" "${cpu_usage}%"
    else
        print_status "WARNING" "Использование CPU" "${cpu_usage}% (высокая нагрузка)"
    fi
    
    # Проверка использования памяти
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    if (( $(echo "$mem_usage < 80" | bc -l) )); then
        print_status "OK" "Использование памяти" "${mem_usage}%"
    else
        print_status "WARNING" "Использование памяти" "${mem_usage}% (высокое использование)"
    fi
    
    # Проверка свободного места на диске
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 80 ]; then
        print_status "OK" "Использование диска" "${disk_usage}%"
    else
        print_status "WARNING" "Использование диска" "${disk_usage}% (мало места)"
    fi
}

# Проверка API панели управления
check_api_panel() {
    # Проверка службы singbox-file-api
    if systemctl list-unit-files | grep -q "singbox-file-api.service"; then
        if systemctl is-active --quiet singbox-file-api; then
            print_status "OK" "Служба API панели" "Запущена"
        else
            print_status "ERROR" "Служба API панели" "Остановлена"
        fi
        
        if systemctl is-enabled --quiet singbox-file-api; then
            print_status "OK" "Автозапуск API панели" "Включен"
        else
            print_status "WARNING" "Автозапуск API панели" "Отключен"
        fi
    else
        print_status "WARNING" "Служба API панели" "Не найдена"
    fi
    
    # Проверка доступности HTTP API на порту 8000
    if curl -s --max-time 5 "http://0.0.0.0:8000" >/dev/null 2>&1; then
        print_status "OK" "HTTP API панель :8000" "Доступна"
    else
        print_status "ERROR" "HTTP API панель :8000" "Недоступна"
    fi
}

# Проверка логов на ошибки
check_logs() {
    if systemctl is-active --quiet sing-box; then
        local error_count=$(journalctl -u sing-box --since "1 hour ago" | grep -i error | wc -l)
        if [ "$error_count" -eq 0 ]; then
            print_status "OK" "Логи sing-box за час" "Без ошибок"
        else
            print_status "WARNING" "Логи sing-box за час" "$error_count ошибок"
        fi
    else
        print_status "INFO" "Логи sing-box за час" "Служба не запущена"
    fi
    
    # Проверка логов API панели
    if systemctl is-active --quiet singbox-file-api; then
        local api_error_count=$(journalctl -u singbox-file-api --since "1 hour ago" | grep -i error | wc -l)
        if [ "$api_error_count" -eq 0 ]; then
            print_status "OK" "Логи API панели за час" "Без ошибок"
        else
            print_status "WARNING" "Логи API панели за час" "$api_error_count ошибок"
        fi
    fi
}

# Основная функция
main() {
    # Проверка прав root
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}Ошибка: этот скрипт требует прав root${NC}"
        exit 1
    fi
    
    print_header
    
    check_singbox_service
    check_version_updates
    check_ip_forwarding
    check_firewall_rules
    check_config_files
    check_network_connectivity
    check_system_resources
    check_api_panel
    check_logs
    
    echo -e "${BOLD}${CYAN}└─────────────────────────────────────────────────────────┘${NC}"
}

# Запуск основной функции
main "$@"
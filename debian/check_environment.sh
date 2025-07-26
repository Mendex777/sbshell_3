#!/bin/bash

# Проверка: выполняется ли скрипт от имени root
if [ "$(id -u)" != "0" ]; then
    echo "Ошибка: этот скрипт требует прав root"
    exit 1
fi

# Проверка, установлен ли sing-box
if command -v sing-box &> /dev/null; then
    current_version=$(sing-box version | grep 'sing-box version' | awk '{print $3}')
    echo "sing-box уже установлен, версия: $current_version"
else
    echo "sing-box не установлен"
fi

# Проверка включения IP-перенаправления для IPv4 и IPv6
ipv4_forward=$(sysctl net.ipv4.ip_forward | awk '{print $3}')
ipv6_forward=$(sysctl net.ipv6.conf.all.forwarding | awk '{print $3}')

if [ "$ipv4_forward" -eq 1 ] && [ "$ipv6_forward" -eq 1 ]; then
    echo "IP-перенаправление уже включено"
else
    echo "Включение IP-перенаправления..."
    sudo sed -i '/net.ipv4.ip_forward/s/^#//;/net.ipv6.conf.all.forwarding/s/^#//' /etc/sysctl.conf
    sudo sysctl -p
    echo "IP-перенаправление успешно включено"
fi

# Создание директории rules и файла custom_list.json
echo "Проверка и создание файла custom_list.json..."
sudo mkdir -p /etc/sing-box/rules

if [ ! -f "/etc/sing-box/rules/custom_list.json" ]; then
    echo "Создание файла custom_list.json..."
    sudo tee /etc/sing-box/rules/custom_list.json > /dev/null <<'EOF'
{
  "version": 1,
  "rules": [
    {
      "domain_suffix": [
//Прочая фигня
        "mozilla.org",
        "veeam.com",
        "kino.pub",
        "anilibria.tv",
        "rutor.org",
        "zona.media",
        "skvalex.dev",

//play market
        "googleplay.com",
        "play-fe.googleapis.com",
        "play-games.googleusercontent.com",
        "play-lh.googleusercontent.com",
        "play.google.com",
        "play.googleapis.com",
        "xn--ngstr-lra8j.com",

//hashicorp.com
        "hashicorp.com",

//bitwarden.com
        "bitwarden.com",

//repack.me
        "repack.me",

//nzxt.com
        "nzxt.com",

//Lampac
        "cub.red",
//        "cookielaw.org",
//        "onetrust.com",
//        "gravatar.com",
//        "doubleclick.net",
//        "googletagmanager.com",
//        "kurwa-bober.ninja",

//trae.ai
        "byteintlapi.com",
        "byteoversea.com",
        "bytednsdoc.com",
        "bytelemon.com",
        "exp-tas.com",
        "trae.ai",
        "trae.com.cn",

//copilot
        "copilot.microsoft.com",

//Проверка ip на 2ip.ru
        "2ip.ru"
      ]
    },
    {
      "domain": "tmdb-image-prod.b-cdn.net",
      "domain_suffix": [
        "themoviedb.org",
        "tmdb.org"
      ]
    }
  ]
}
EOF
    echo "Файл custom_list.json успешно создан"
else
    echo "Файл custom_list.json уже существует"
fi

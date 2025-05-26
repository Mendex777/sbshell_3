#!/bin/bash

# Очистка правил брандмауэра и остановка сервиса
sudo systemctl stop sing-box
nft flush ruleset

echo "Служба sing-box остановлена, правила брандмауэра очищены."

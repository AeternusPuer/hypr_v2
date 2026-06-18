#!/bin/bash
# Требует прав root для выполнения
mem_total=$(free -m | awk '/^Mem:/{print $2}')
SWAPFILE="/swapfile"
if [ "$mem_total" -lt 8192 ]; then
    SWAP_SIZE=$mem_total"M"
else
    SWAP_SIZE="8192M"
fi
echo "=== Начало создания файла подкачки ==="
# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "Ошибка: скрипт должен быть запущен с правами root"
    echo "Используйте: sudo ./create_swap.sh"
    exit 1
fi
# Проверка существующего swap
echo "Проверка текущего состояния swap..."
if swapon --show | grep -q .; then
    echo "Обнаружена активная подкачка:"
    swapon --show
    echo "Рекомендуется отключить существующий swap перед созданием нового."
    exit 1
fi
# Создание файла подкачки
echo "Создание файла подкачки размером $SWAP_SIZE..."
if command -v fallocate >/dev/null 2>&1; then
    fallocate -l "$SWAP_SIZE" "$SWAPFILE"
else
    echo "fallocate не найден, используется dd (это может занять время)..."
    dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((1024)) status=progress
fi
# Проверка успешности создания файла
if [ ! -f "$SWAPFILE" ]; then
    echo "Ошибка: не удалось создать файл $SWAPFILE"
    exit 1
fi
# Установка правильных прав
echo "Настройка прав доступа..."
chmod 600 "$SWAPFILE"
# Форматирование в swap
echo "Форматирование файла в swap..."
mkswap "$SWAPFILE"
# Активация swap
echo "Активация файла подкачки..."
swapon "$SWAPFILE"
# Добавление в fstab для автозагрузки
echo "Добавление в /etc/fstab для автоматической загрузки при старте системы..."
if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo -e "\n#swapfile" >> /etc/fstab
    echo -e "$SWAPFILE\tnone\tswap\tdefaults\t0\t0" >> /etc/fstab
    echo "Запись добавлена в /etc/fstab"
else
    echo "Запись для $SWAPFILE уже существует в /etc/fstab"
fi
# Проверка результата
echo "=== Проверка результата ==="
swapon --show
echo ""
free -h

echo "=== Файл подкачки успешно создан и активирован ==="
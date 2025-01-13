#!/bin/bash

# Удаляем предыдущий архив резервной копии
rm -rf /tmp/backup-marzban.tar.gz

# Учетные данные для MySQL/MariaDB и контейнер
MYSQL_USER="marzban"
MYSQL_PASSWORD="NRrnbx4Psu"
MYSQL_CONTAINER_NAME="marzban-mariadb-1"

# Информация для отправки в Telegram
TG_BOT_TOKEN="bot6474207875:AAGYG69RGggzYhpRGd3jlAZjrHQ3najXJU0"
TG_CHAT_ID="-1001990887300"

# Получаем список баз данных
databases_marzban=$(docker exec $MYSQL_CONTAINER_NAME mariadb -h 127.0.0.1 --user=$MYSQL_USER --password=$MYSQL_PASSWORD -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)
databases_shop=$(docker exec marzban-shop-db-1 mariadb -h 127.0.0.1 --user=$MYSQL_USER --password=$MYSQL_PASSWORD -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)

# Делаем дамп только для баз данных marzban и shop, исключая системные базы
for db in $databases_marzban; do
    if [[ "$db" == "marzban" ]]; then
        echo "Dumping database: $db from $MYSQL_CONTAINER_NAME"
        docker exec $MYSQL_CONTAINER_NAME mariadb-dump -h 127.0.0.1 --force --opt --user=$MYSQL_USER --password=$MYSQL_PASSWORD --databases $db > /var/lib/marzban/mysql/db-backup/$db.sql
    fi
done

for db in $databases_shop; do
    if [[ "$db" == "shop" ]]; then
        echo "Dumping database: $db from marzban-shop-db-1"
        docker exec marzban-shop-db-1 mariadb-dump -h 127.0.0.1 --force --opt --user=$MYSQL_USER --password=$MYSQL_PASSWORD --databases $db > /var/lib/marzban/mysql/db-backup/$db.sql
    fi
done

# Создаем архив резервной копии и добавляем дампы баз данных
tar --exclude='/var/lib/marzban/mysql/*' --exclude='/var/lib/marzban/logs/*' \
    --exclude='/var/lib/marzban/access.log*' \
    --exclude='/var/lib/marzban/error.log*' \
    --exclude='/var/lib/marzban/xray-core/*' \
    -cf /tmp/backup-marzban.tar \
    -C / \
    /opt/marzban/.env \
    /opt/marzban/ \
    /var/lib/marzban/
tar -rf /tmp/backup-marzban.tar -C / /var/lib/marzban/mysql/db-backup/*
gzip /tmp/backup-marzban.tar

# Отправляем архив в Telegram и очищаем временные файлы
curl -F chat_id="$TG_CHAT_ID" \
     -F caption=$'Main\n\nMarzban and Shop backup\n<code>188.245.93.215</code>\nhttps://dash.wetset.xyz/dashboard' \
     -F parse_mode="HTML" \
     -F document=@"/tmp/backup-marzban.tar.gz" \
     https://api.telegram.org/$TG_BOT_TOKEN/sendDocument \
&& rm -rf /var/lib/marzban/mysql/db-backup/*

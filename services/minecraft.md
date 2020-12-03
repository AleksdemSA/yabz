# Сервер Minecraft

Задача: поднять сервер Майнкрафт на CentOS7.

Решение достаточно просто: нужно попасть в каталог с ПО (предварительно настроенным) и запустить как сервис. В идеале ещё автозапуск в случае выключения и рестарт в случае падения сервиса. Вот пример Unit для SystemD. Пользователя root и путь меняем на то, где это лежит у вас.

```
cat /etc/systemd/system/minecraft.service
```

```
[Unit]
Description=Minecraft Server

[Service]
User=root
Type=simple
Restart=always
RestartSec=5
WorkingDirectory=/opt/
ExecStart=/usr/bin/java -Xmx2048M -jar server.jar nogui SuccessExitStatus=143
ExecStop=/bin/kill -TERM

[Install]
WantedBy=multi-user.target
```

Автозарузка, запуск и журнал...

```
systemctl enable minecraft
systemctl restart minecraft
journalctl -u minecraft -f
```
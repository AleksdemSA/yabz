# Добавление сертификатов для Cockpit

Одна из проблем Cockpit в том, что после установки в него зайти бывает проблематично. Браузеры иногда наотрез отказываются заходить на невалидные, с их точки зрения, ресурсы. Решается это очень просто.
<!--more-->

Копируем сертификаты

```sh
cp /certfolder/* /etc/cockpit/ws-certs.d/
```

Перегружаем сервис

```sh
systemctl restart cockpit
```

Проверяем всё ли в порядке

```sh
/usr/libexec/cockpit-certificate-ensure --check
```

#cockpit #service

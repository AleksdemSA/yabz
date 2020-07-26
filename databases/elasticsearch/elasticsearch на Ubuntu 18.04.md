# Установка ElasticSearch 7 на Ubuntu 18.04

На самом деле, установка ElasticSearch очень проста. Можно как добавить хранилище, так и просто скопировать нужный deb-пакет с сайта. Давайте добавим хранилищем...

#### Установка

Для начала скачаем и добавим ключ

```
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
```

Далее добавляем хранилище

```
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list
```

Обновляем список пакетов

```
sudo apt update
```
И устанавливаем сам эластик

```
sudo apt install elasticsearch
```


#### Настройка

Редактируем файл настройки. Дело в том, что авторизации по-умолчанию тут нет и зарубежные хостеры могут начинать сыпать гневные письма на тему "закройте или закроем", что достаточно правильно.

```
vim /etc/elasticsearch/elasticsearch.yml
```

Прявязываем к localhost что бы не возникало несанкционированных посещений.
```
network.host: localhost
```
Далее рекомендую посмотреть настройки Java, хотя бы на уровне "сколько ему выделить памяти".

```
vim /etc/elasticsearch/jvm.options
```

И после редактирования запуск и автозагрузка.

```
systemctl start elasticsearch
systemctl enable elasticsearch
```


#### Проверка

Смотрим состояние эластика

```
curl -X GET 'http://localhost:9200'
```

И его ноды....

```
curl -XGET 'http://localhost:9200/_nodes?pretty'
```


### Простейшая кластеризация

Если нужно сделать простой кластер ElasticSearch, поправим 2 строчки на каждом сервере

```
vim /etc/elasticsearch/elasticsearch.yml
```

где открываем эластик "наружу" и пишем все адреса серверов
```
network.host: 0.0.0.0
discovery.zen.ping.unicast.hosts: ["192.168.0.100", "192.168.0.101","192.168.0.102"]
```

После этого перегружаем эластик на всех нодах

```
systemctl restart elasticsearch
```
И проверяем

```
curl -XGET 'http://localhost:9200/_nodes?pretty'
```

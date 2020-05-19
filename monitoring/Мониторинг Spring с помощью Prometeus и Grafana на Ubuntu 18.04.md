У вас есть проект на Spring Boot, вы добавили actuator и micrometer-registry-prometheus и теперь есть возможность собирать данные по различным аспектам: от скорости ответа и до потребления памяти Java.

Что будет нужно:
```
apt install -y docker.io
```

### Prometeus

Для начала, добавим контейнер с Prometeus

```
docker pull prom/prometheus
```

И проверим, что он есть:

```
docker images
```

Далее создаём файл prometheus.yml следующего содержания:

```
global:
  scrape_interval:     15s
  evaluation_interval: 15s

rule_files:

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
    - targets: ['127.0.0.1:9090']

  - job_name: 'spring-actuator'
    metrics_path: '/actuator/prometheus'
    scrape_interval: 5s
    static_configs:
    - targets: ['HOST_IP:8080']
```
Где HOST_IP:8080 - это адрес вашего актуатора

И запускаем:
```
docker run -d --name=prometheus -p 59090:9090 -v /root/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus --config.file=/etc/prometheus/prometheus.yml
```

Разумеется, это совсем небезопасно, вариант забиндить прометеус на 127.0.0.1 и уже по авторизации сделать к нему доступ. Как проксировать запросы в NginX и сделать в нём же Basic Authorisation - тема другой статьи.


### Grafana

Для удобного отображения данных из прометеуса запускаем в другом контейрене Grafana:
```
docker run -d --name=grafana -p 3000:3000 grafana/grafana
```
Логин и пароль будет admin и он же предложет его сменить. Далее уже добавляете нужные графики себе на dashboard и наблюдайте нужные вам тенденции.

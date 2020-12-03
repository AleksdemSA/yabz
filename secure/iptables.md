# Немного про IPTables

### QoS для Linux, кто использует торрент-клиенты
Итак, задача: чтобы торрент качал как надо и в то же время можно было достаточно комфортно сёрфить страницы. Для этого мы отделим приоритеты для портов до 1024 и после. Те порты, которые будут до 1024-го, будут более значимы. Таким образом канал будет использоваться наиболее полно, нежели просто ограничивать торрент-клиент на время. Итак, список правил:

```
iptables -A PREROUTING -t mangle -p tcp --sport 0:1024 -j TOS --set-tos Minimize-Delay
iptables -A PREROUTING -t mangle -p tcp --sport 1025:65535 -j TOS --set-tos Maximize-Throughput
iptables -A OUTPUT -t mangle -p tcp --dport 0:1024 -j TOS --set-tos Minimize-Delay
iptables -A OUTPUT -t mangle -p tcp --dport 1025:65535 -j TOS --set-tos Maximize-Throughput
```

### Как удалить в iptables правило по номеру

```
iptables -L INPUT --line-numbers
iptables -D INPUT номер

iptables -t nat -L POSTROUTING --line-numbers
iptables -t nat -D POSTROUTING номер
```

### Сбрасываем старые данные и правила

```
/sbin/iptables -F
/sbin/iptables -F -t nat
/sbin/iptables -F -t mangle
/sbin/iptables -X
/sbin/iptables -X -t nat
/sbin/iptables -X -t mangle
```


### Маскарадинг

```
/sbin/iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -j MASQUERADE
```
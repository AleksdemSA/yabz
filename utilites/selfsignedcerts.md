# Центр сертификации и генерация сертификатов для тестовых серверов

Создаём место под ЦА

```
mkdir /opt/cert_center
cd /opt/cert_center/
```

Делаем корневой сертификат

```
openssl genrsa -out rootCA.key 4096
openssl req -x509 -new -key rootCA.key -days 3650 -out rootCA.crt
cp rootCA.crt /КУДА/НАДО/ЧТОБЫ/ВСЕ/СКАЧАЛИ
```

Делаем серт для нужного сервера. По сути первые шаги выполняются только 1 раз, а дальше нужны только эти 3 команды.

```
openssl genrsa -out DOMAIN.key 4096
openssl req -new -key DOMAIN.key -out DOMAIN.csr
openssl x509 -req -in DOMAIN.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out DOMAIN.crt -days 3650
```

Как убунте прописать в системе корневой сертификат

```
sudo mkdir /usr/share/ca-certificates/extra
sudo cp rootCA.crt /usr/share/ca-certificates/extra/rootCA.crt
sudo dpkg-reconfigure ca-certificates
sudo update-ca-certificates
```
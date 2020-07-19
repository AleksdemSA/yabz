Установка Maven 3.6.3 на CentOS

К сожалению, по-умолчанию версия Maven достаточно старая, поэтому обновляем его с официального сайта.

Скачивание нужного пакета:
```
wget https://downloads.apache.org/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz -P /tmp
```

Распаковка:
```
tar xf /tmp/apache-maven-3.6.3-bin.tar.gz -C /opt
ln -s /opt/apache-maven-3.6.3 /opt/maven
```

Удаляем старую версию
```
dnf remove -y maven*
```

Создаём линк на бинарник и смотрим версию.
```
ln -s /opt/maven/bin/mvn /usr/bin/mvn
mvn -v
```

В итоге видим примерно это:
```
Apache Maven 3.6.3 (cecedd343002696d0abb50b32b541b8a6ba2883f)
Maven home: /opt/maven
```

Привет всем! Итак, у нас есть достаточно мощный сервер, который предназначен для разработки. В целях автоматизации, ускорения процессов и просто уменьшения нагрузки на инженеров, выбираем для него OpenShift. Сейчас мы рассмотрим вариант установки OpenShift с помощью метода "oc cluster up" буквально в 12 комманд.

## Начальная работа

Итак, на чистый сервер с CentOS 8 ставим привычные для нас пакеты. Кроме wget и tar остальные опциональны.
```
yum install -y epel-release
yum update -y
yum install -y wget tar htop lost mc
```

## OpenShift CLI

Теперь нам нужны oc и kubectl, которые можно взять с GitHub. На сегодня это последнее версия, в дальнейшем лучше посмотреть, не вышло ли что-то новее.
```
wget -c "https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz"
tar xvf openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz
cp -v openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit/kubectl /usr/bin/
cp -v openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit/oc /usr/bin/
```

## Docker on CentOS 8

Теперь Docker, куда же без него в наши дни. Можно заменить на Podman/Buildah, но это уже для другой статьи тема.
```
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce docker-ce-cli containerd.io --nobest
systemctl start docker
systemctl enable docker
```

## OC Cluster UP

И теперь уже создание сервера OpenShift. Первой командой создадим конфиги (чтобы после перезапуска сервера ничего не потерялось), второй уже проходим саму установку. SERVERNAME замените на полное название своего сервера. Иначе в браузере зайти будет чуть сложнее, придется что-то в hosts вносить и т.д.
```
oc cluster up --skip-registry-check=false --public-hostname=SERVERNAME --routing-suffix SERVERNAME --loglevel=5 --base-dir='/opt/oc' --write-config=true
oc cluster up --skip-registry-check=false --public-hostname=SERVERNAME --routing-suffix SERVERNAME --loglevel=5 --base-dir='/opt/oc'
```

Всё, в конце будет показано куда зайти и под каким пользователем. Если сервер в офисе и для себя, можно сразу озаботится работой с Registry, если же сервер виден из сети Интернет - заводим админа с паролем, деактивируем ненужные учётки и многое другое. Тут есть над чем поработать. :)

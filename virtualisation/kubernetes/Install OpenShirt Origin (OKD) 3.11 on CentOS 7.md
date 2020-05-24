Установка OpenShift Origin (OKD) 3.11
-------------------------------------
Инструкция позволяет развернуть свой кластер OpenShift. Минимальная установка требует три виртуалки на CentOS - мастер и две рабочих ноды. Перед установкой обязательно необходимо убедиться, что системы соответствуют необходимым требованиям.

---
### Requirments

Master - 16G памяти, 4 ядра и 40G на жестком диске

Worker -  8G памяти, 1 ядро и 15G на жестком диске

Я пытался запустить деплой кластера на меньших параметрах памяти и процессора - неудачно. Так что, как говорится, если вы хотите сварить куриный суп, но у вас нет курицы, то... ничего у вас не выйдет! Также следует понимать, что выделяемая память - виртуальная, и если на гипервизоре недостаточно физической памяти, всё равно стоит попробовать сделать некоторый overbooking по памяти, может и прокатит.

Я запускал в конфигурации: Master - 16/6/50, Worker - 8/4/50.

Кому будет интересно, можете поэкспериментировать с разными вариантами конфигураций и настроек, но у меня любое отклонение от этой инструкции приводило к проблемам на разных этапах установки. Поэтому, для первого раза, лучше всё сделать в точности, как когда идёшь по болоту - след в след.

Кроме того я нашел несколько неочевидных требований, но без них процесс установки прерывался:

* Должен быть включен SELinux.
* Должен быть включен Firewall (хотя во время работы плейбука он и отключается).
* Подключение по SSH должно быть доступно на стандартном порту.
* Хосты должны резолвится по dns, добавление только в файл hosts - недостаточно.
* Если вы создаёте виртуалки клонированием, не забывайте делать `sysprep`, иначе также возможны сложности в дальнейшем.
* Необходимо будет добавить пару строк в настройку сетевого интерфейса каждого хоста. Это необходимо для возможности настройки сети средствами NetworkManager во время работы плейбука
* Также нужно иметь стабильное подключение к интернету, так как в процессе установки будут установленны необходимые пакеты.
* В процессе установки нужно будет сделать даунгрейд ансибла.
* Может потребоваться учетная запись RedHat.

---
### Подготовка

##### SELinux
Убедитесь, что в файле `/etc/selinux/config` установлены правильные значения `SELINUX=enforcing` и `SELINUXTYPE=targeted`.

Файл должен выглядеть примерно так:
```
# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#     enforcing - SELinux security policy is enforced.
#     permissive - SELinux prints warnings instead of enforcing.
#     disabled - No SELinux policy is loaded.
SELINUX=enforcing
# SELINUXTYPE= can take one of these three values:
#     targeted - Targeted processes are protected,
#     minimum - Modification of targeted policy. Only selected processes are protected.
#     mls - Multi Level Security protection.
SELINUXTYPE=targeted
```
##### DNS
Кластер требует под себя DNS-сервер. В официальной документации сказано, что желательно иметь его на отдельно стоящей машине. В процессе установки, может быть и можно без него обойтись, но он будет необходим для дальнейшего использования кластера. У меня для этих целей использовался свой DNS-сервер, на котором я сделал A-записи для хостов:

```
master       IN      A       10.1.1.13
node1        IN      A       10.1.1.14
node2        IN      A       10.1.1.15
```
Все хосты входят в сеть vpn 10.1.1.0/24.

Tакже на всех хостах сделана запись в файл `/etc/hosts` такого вида:

```
192.168.111.22        master.<your.domain>
192.168.111.33        node1.<your.domain>
192.168.111.44        node2.<your.domain>
```
Эти адреса принадлежат сети `kvm` на которой крутятся виртуалки. Вероятно, можно было прописать и адреса из сети `vpn`, но по внутренней сети будет быстрее.

В процессе установки на ноды будет установлен `dnsmasq`. Это необходимо для правильного функционирования подов, поэтому на нодах не должно быть установленно никаких других DNS-сервисов, использующих 53 порт.

После настройки `/etc/hosts` нужно внести небольшие правки в скрипт настройки сети на каждой ноде. У меня сетевой интерфейс настраивается в файле `ifcfg-eth0`, у вас может быть иначе. Открываем файл на редактирование
```
vim /etc/sysconfig/network-scripts/ifcfg-eth0
```

и добавляем в конец файла
```
NM_CONTROLLED="yes"
PEERDNS="yes"
```

Убедитесь, что все ваши хосты резолвятся через DNS-серверы указанные в файле `/etc/resolf.conf` выполнив команду

```
dig <node_hostname> @<IP_address> +short
```
где `@<ID_address>` - это адрес через который резолвится хост.

В моём случае - адрес своего DNS-сервера из `vpn`-сети:

```
[root@master ~]# dig node1.<your.domain> @10.1.1.1 +short
10.1.1.14

```

---
### Установка

##### Предварительная настройка

На каждой ноде нужно:
* создать пользователя, под которым впоследствии будет производиться установка ансиблом, и дать ему root-права:
```
[root@master ~]# useradd origin
[root@master ~]# passwd origin
[root@master ~]# echo -e 'Defaults:origin !requiretty\norigin ALL = (root) NOPASSWD:ALL' | tee /etc/sudoers.d/openshift
[root@master ~]# chmod 440 /etc/sudoers.d/openshift
```
* разрешить SSH в Firewalld:
```
[root@master ~]# firewall-cmd --add-service=ssh --permanent
[root@master ~]# firewall-cmd --reload
```
* установить необходимые пакеты
```
[root@master ~]# yum -y install centos-release-openshift-origin311 epel-release docker git pyOpenSSL
```
* и включить Docker
```
[root@master ~]# systemctl start docker
[root@master ~]# systemctl enable docker
```

После этого, зайти на мастер-ноду только что созданным пользователем и
* создать ssh-ключ без изспользования парольной фразы:
```
[origin@master ~]$ ssh-keygen -q -N ""
Enter file in which to save the key (/home/origin/.ssh/id_rsa):
```
* отредактировать файл конфигурации:
```
vim ~/.ssh/config
```
```
Host master
    Hostname master.<your.domain>
    User origin
Host node1
    Hostname node1.<your.domain>
    User origin
Host node2
    Hostname node2.<your.domain>
    User origin
```
* и поправить на нём права:
```
[origin@master ~]$ chmod 600 ~/.ssh/config
```
* теперь прокидываем ssh-ключ на все ноды, включая самого себя:
```
[origin@master ~]$ ssh-copy-id node1
origin@node1.<your.domain>'s password:
Number of key(s) added: 1
Now try logging into the machine, with:   "ssh 'node1'"
and check to make sure that only the key(s) you wanted were added.
[origin@master ~]$ ssh-copy-id node2
[origin@master ~]$ ssh-copy-id master
```
Настоятельно рекомендую зайти по очереди на каждый сервер (`ssh 'node1'` и две других ноды) и убедиться что всё нормально.

##### Установка и предварительная настройка Ansible

Зайти на мастер-ноду созданным пользователем и установить Ansible и необходимые плейбуки (всё в одном пакете):
```
[origin@master ~]$ sudo yum -y install openshift-ansible
```
После чего нужно сделать даунгрейд Ansible, так как версия, устанавливающаяся из команды выше, на момент написания инструкции (май, 2020) имела номер 2.9.7 и при запуске плейбука деплоя кластера она являлась причиной того, что Docker не мог настроить свои стораджи. Путём гугления обнаружилось, что всё нормально работает на Ansible версиий 2.6 или 2.7. Но эксперимент показал, что лучше всё-таки 2.6, на 2.7 не взлетело. Кстати, Docker тоже должен быть версии 1.13. Для даунгрейда запускаем:
```
[origin@master ~]$ sudo yum install python-pip python-devel python -y
[origin@master ~]$ sudo pip install pip --upgrade
[origin@master ~]$ sudo pip install ansible==2.6
```

Проверим версию Ansible:
```
[origin@master ~]$ ansible --version
ansible 2.6.0
  config file = /etc/ansible/ansible.cfg
  configured module search path = [u'/home/origin/.ansible/plugins/modules', u'/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python2.7/site-packages/ansible
  executable location = /bin/ansible
  python version = 2.7.5 (default, Apr  2 2020, 13:16:51) [GCC 4.8.5 20150623 (Red Hat 4.8.5-39)]
```
и Docker:
```
[origin@master ~]$ docker --version
Docker version 1.13.1, build 64e9980/1.13.1
```
Подготовим файл `/etc/ansible/hosts`

```
[origin@master ~]$ sudo vim /etc/ansible/hosts
```
И заменим его содержимое на следующий текст:
```
[OSEv3:children]
masters
nodes
etcd

[OSEv3:vars]
#admin user created in previous section
ansible_ssh_user=origin
ansible_become=true
openshift_deployment_type=origin

# use HTPasswd for authentication
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider'}]
# define default sub-domain for Master node
openshift_master_default_subdomain=apps.<your.domain>
# allow unencrypted connection within cluster
openshift_docker_insecure_registries=172.30.0.0/16

[masters]
master.<your.domain> openshift_schedulable=true containerized=false

[etcd]
os-master.<your.domain>

[nodes]
# defined values for [openshift_node_group_name] in the file below
# [/usr/share/ansible/openshift-ansible/roles/openshift_facts/defaults/main.yml]
master.<your.domain> openshift_node_group_name='node-config-master-infra'
node1.<your.domain> openshift_node_group_name='node-config-compute'
node2.<your.domain> openshift_node_group_name='node-config-compute'
```
Вообще в инструкции, которую я взял за основу предлагается дописать этот текст в конец файла, но я для удобочитаемости оставил только свою информацию, остальное там всё равно было закомментировано. Не забывайте подставлять свой домен вместо <your.domain>.

В этом месте я ребутнул виртуалки, но указаний на то, что это обязательно, я нигде не нашел.

##### Запуск предварительного плейбука
```
[origin@master ~]$ ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml


................
................

PLAY RECAP *********************************************************************
master.<your.domain>       : ok=83   changed=22   unreachable=0    failed=0
localhost                  : ok=11   changed=0    unreachable=0    failed=0
node1.<your.domain>        : ok=58   changed=21   unreachable=0    failed=0
node2.<your.domain>        : ok=58   changed=21   unreachable=0    failed=0


INSTALLER STATUS ***************************************************************
Initialization  : Complete (0:01:18)
```
Время работы плейбука около пяти минут.

Этот плейбук сделает предварительную инициализацию кластера и проверит, что все необходимые условия для деплоя кластера соблюдены. После чего можно запускать основной плейбук.

##### Деплой кластера OpenShift
```
[origin@master ~]$ ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml


................
................

PLAY RECAP *********************************************************************
master.<your.domain>       : ok=711  changed=322  unreachable=0    failed=0
localhost                  : ok=11   changed=0    unreachable=0    failed=0
node1.<your.domain>        : ok=119  changed=63   unreachable=0    failed=0
node2.<your.domain>        : ok=119  changed=63   unreachable=0    failed=0


INSTALLER STATUS ***************************************************************
Initialization               : Complete (0:00:39)
Health Check                 : Complete (0:00:56)
Node Bootstrap Preparation   : Complete (0:03:47)
etcd Install                 : Complete (0:01:42)
Master Install               : Complete (0:07:06)
Master Additional Install    : Complete (0:01:04)
Node Join                    : Complete (0:00:20)
Hosted Install               : Complete (0:01:27)
Cluster Monitoring Operator  : Complete (0:01:25)
Web Console Install          : Complete (0:00:41)
Console Install              : Complete (0:00:30)
metrics-server Install       : Complete (0:00:01)
Service Catalog Install      : Complete (0:02:40)
```
Плейбук работает около 25-30 минут.

##### Если возникли проблемы
Я разворачивал кластер по этой инструкции не меньше десятка раз и вот перед тем как поделиться ей с общественностью на последнем прогоне я столкнулся со следующей ошибкой:
```
Hosts:    master.<your.domain>
     Play:     OpenShift Health Checks
     Task:     Run health checks (install) - EL
     Message:  One or more checks failed
     Details:  check "docker_image_availability":
               One or more required container images are not available:
                   registry.redhat.io/openshift3/ose-control-plane:v3.11.43,
                   registry.redhat.io/openshift3/ose-deployer:v3.11.43,
                   registry.redhat.io/openshift3/ose-docker-registry:v3.11.43,
                   registry.redhat.io/openshift3/ose-haproxy-router:v3.11.43,
                   registry.redhat.io/openshift3/registry-console:v3.11.43
               Checked with: skopeo inspect [--tls-verify=false] [--creds=<user>:<pass>] docker://<registry>/<image>
```
Суть в том, что плейбук жалуется, что не может получить очень нужные ему образы контейнеров. Образы могут быть другими, это не важно. В официальной документации есть следующее решение.

Для начала, нужно залогиниться в реестр RedHat (нужно будет зарегистрироваться там для этого), находясь на мастер-ноде (лучше проверить на всех нодах):
```
[root@master ~]# docker login https://registry.redhat.io
```
После удачной авторизации, попробуем стянуть нужный образ:
```
[root@master ~]# docker pull registry.redhat.io/openshift3/ose-control-plane:v3.11.43
```
И если получаем удачный ответ, типа такого:
```
Trying to pull repository registry.redhat.io/openshift3/ose-control-plane ...
v3.11.43: Pulling from registry.redhat.io/openshift3/ose-control-plane
9a1bea865f79: Pull complete
602125c154e3: Pull complete
12f4e4c20da2: Pull complete
b598aebf1511: Pull complete
899256dd9531: Pull complete
Digest: sha256:adf53b055e13699154b6e084603b84e0ae7df8c33454e43e9530fd3eb5533977
Status: Downloaded newer image for registry.redhat.io/openshift3/ose-control-plane:v3.11.43
```
считаем, что у нас всё в порядке и можно отключить проверку доступности образов, добавив в файл `/etc/ansible/hosts` в секцию `[OSEv3:vars]` строчку:
```
openshift_disable_check="docker_image_availability"
```
После этого запускам заново деплой кластера.

Если в какой-то момент показалось что всё встало, надо немного подождать.

У меня на моменте `Install node, clients, and conntrack packages` всё замерло минут на 10, уже собирался останавливать плейбук и перезапускать.

Второй раз всё подвисло в момент `Install the base package for admin tooling`.

Дальше появлялись ошибки такого плана:
```
TASK [openshift_control_plane : Wait for all control plane pods to become ready] **********************************************
FAILED - RETRYING: Wait for all control plane pods to become ready (60 retries left).
FAILED - RETRYING: Wait for all control plane pods to become ready (59 retries left).
FAILED - RETRYING: Wait for all control plane pods to become ready (58 retries left).
```
Подозреваю, что всё это связано с сетью.

Со всеми задержками последний деплой занял около часа. Так что запаситесь попкорном. ;)

---
##### Смотрим что получилось
```
[origin@master ~]$ oc get nodes

NAME                  STATUS    ROLES          AGE       VERSION
master.<your.domain>  Ready     infra,master   15m       v1.11.0+d4cacc0
node1.<your.domain>   Ready     compute        10m       v1.11.0+d4cacc0
node2.<your.domain>   Ready     compute        10m       v1.11.0+d4cacc0
```
и тоже самое в расширенном режиме, с метками:
```
[origin@master ~]$ oc get nodes --show-labels=true

NAME                  STATUS    ROLES          AGE       VERSION           LABELS
master.<your.domain>  Ready     infra,master   15m       v1.11.0+d4cacc0   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=master.<your.domain>,node-role.kubernetes.io/infra=true,node-role.kubernetes.io/master=true
node1.<your.domain>   Ready     compute        10m       v1.11.0+d4cacc0   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=node1.<your.domain>,node-role.kubernetes.io/compute=true
node2.<your.domain>   Ready     compute        10m       v1.11.0+d4cacc0   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/hostname=node2.<your.domain>,node-role.kubernetes.io/compute=true
```

---
##### Создание пользователя
Для работы в кластере нам нужен пользователь. Сделаем его.

На мастер-ноде создаем пользователя `cent`:

```
[origin@master ~]$ sudo htpasswd /etc/origin/master/htpasswd cent
New password:          # введите пароль для нового пользователя
Re-type new password:  # и повторите его
Adding password for user cent
```
Теперь можно авторизоваться в кластере используя регистрационные данные только что созданного пользователя через HTPasswd.
```
[origin@master ~]$ oc login
```
```
Server [https://localhost:8443]: https://master.<your.domain>:8443
The server uses a certificate signed by an unknown authority.
You can bypass the certificate check, but any data you send to the server could be intercepted by others.
Use insecure connections? (y/n): y

Authentication required for https://master.<your.domain>:8443 (openshift)
Username: cent
Password:
Login successful.

You don't have any projects. You can try to create a new project, by running

    oc new-project <projectname>

Welcome! See 'oc help' to get started.
```
Можно узнать кто мы:
```
[origin@master ~]$ oc whoami
cent
```
Для выхода:
```
[origin@master ~]$ oc logout
Logged "cent" out on "https://master.<your.domain>:8443"
```

##### Доступ к кластеру OpenShift через WebUI
В браузере пишем
```
https://master.<your.domain>:8443/console
```
вводим логин и пароль того самого пользователя `cent` и на этом всё!

Если будут проблемы с доступом в Web-консоль, можно прописать в `/etc/hosts` строчку
```
10.1.1.13     master.<your.domain>
```

---
### Полезные ссылки
* Официальный сайт
https://docs.okd.io/3.11/welcome/index.html
* Инструкция, взятая за основу
https://www.server-world.info/en/note?os=CentOS_7&p=openshift311&f=1
* Решение проблемы `OpenShift Installation Fails with "One or more required container images are not available"` (нужны креды к RedHat, без них не покажет)
https://access.redhat.com/solutions/3774971

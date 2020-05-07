Разворачиваем Heketi на отдельном сервере
-----------------------------------------
Существуют разные варианты установки Heketi. Сервис может быть развёрнут традиционным способом, как контейнер докера, как под в кластере Kubernetes или OpenShift.
В интернете преобладают как раз последние варианты. Но мне, для понимания что откуда растёт, захотелось попробовать настроить именно отдельный сервер, без привязки к куберу или шифту.

По этой инструкции можно развернуть Heketi как отдельный сервис на любом свободном сервере. То есть сервис будет физически отеделён от хранилища, хотя ничто не мешает его развернуть на любой из нод кластера GlusterFS. Доступ к сервису можно будет иметь из любой удобной точки.

После этого я покажу, как использовать доступ к сервису из кластера Kubernetes и как получить доступ к данным смонтировав том в файловую систему.

Я не буду касаться вопросов безопасности. Это мой домашний стенд для опытов, здесь всё максимально открыто и отключено всё, что могло бы мешать моим творческим экспериментам.

---
### Что такое Heketi? Зачем нам это?
Heketi – это открытый проект, предоставляющий RESTful API другим приложениям, управляя жизненным циклом дисков в GlusterFS. Heketi используется OpenStack, Kubernetes и OpenShift для гибкого предоставления дисковых ресурсов GlusterFS с любым поддерживаемым GlusterFS режимом надежности. Heketi также поддерживает любое количество кластеров GlusterFS, позволяя облачным сервисам использовать дисковые ресурсы без привязки к единственному типу стораджа.

Вобщем, это стильно, модно, молодёжно и плюс ко всему добавляет некоторый слой абстракции в хранении данных и доступа к ним.

---
### Requirements

Для работы нам понадобится:
1. Работающий кластер GlusterFS. Желательно не менее, чем с тремя нодами.
2. На каждой ноде кластера нужен один свободный диск, который полностью уйдёт под нужды Heketi. Не нужно никак его размечать, Heketi всё сделает сам.
3. Обязательно нужен доступ по ssh между всеми серверами (ноды GlusterFS; сервер, где будет развернут Heketi; сервер, с которого будет вестись управление). Настоятельно рекомендую после проброса ssh-ключей удостовериться что всё нормально. Я потратил много времени на поиск причин отказа, пока не обнаружил, что не все ключи прокинулись так, как нужно.
4. Работающий кластер Kubernetes. Исключительно для демонстрации примера настройки постоянного тома.
5. Установленный на всех нодах кластера Kubernetes пакет `glusterfs-client`.

В моём случае, все работы велись на серверах, работающих под CentOS 7.

---
### Часть I. Ставим Heketi
Как я уже написал выше, устанавливать сам сервис можно на любой сервер, который имеет доступ к кластеру хранилища. В том числе это может быть любая из нод. В этом случае нужно только доустановить `heketi` и `heketi-client`.
```
# yum install -y centos-release-gluster6
# yum install -y glusterfs
# yum install heketi
# yum install heketi-client
```
Пакет `glusterfs` вроде как и не нужен, но я его использовал для своих целей в будущем. Клиент тоже здесь не совсем обязателен, но с ним проще проверить работу после установки. Вообще это просто бинарник, который можно скачать отдельно с сайта разработчика в виде архива, разархивировать и положить в папку `/usr/local/bin`.

---
### Часть II. Запускаем сервер

Перед запуском нужно настроить сервер. Все настройки лежат в двух файлах. Плюс, надо будет создать ssh-ключ для пользователя `heketi`.
##### Конфиг
Основой файл конфигурации находится тут: `/etc/heketi/heketi.json`

В эту же папку `/etc/heketi/` желательно положить и остальные файлы, участвующие в настройке, чтобы потом мучительно не вспоминать где и что лежит. В моём случае - это файл топологии, а также закрытый и открытый ключ. Файл базы данных самого Heketi лежит отдельно.

Само описание параметров настройки есть ниже по ссылке. Здесь я приведу пример готового файла. В принципе, сам файл довольно неплохо закомментирован, но на паре мест я остановлюсь подробнее, так как не понимая их потерял довольно много времени.

```
{
  "_port_comment": "Heketi Server Port Number",
  "port": "8080",

  "_use_auth": "Enable JWT authorization. Please enable for deployment",
  "use_auth": false,

  "_jwt": "Private keys for access",
  "jwt": {
    "_admin": "Admin has access to all APIs",
    "admin": {
      "key": "<ваш ключ админа>"
    },
    "_user": "User only has access to /volumes endpoint",
    "user": {
      "key": "<ваш ключ пользователя>"
    }
  },

  "_glusterfs_comment": "GlusterFS Configuration",
  "glusterfs": {
    "_executor_comment": [
      "Execute plugin. Possible choices: mock, ssh",
      "mock: This setting is used for testing and development.",
      "      It will not send commands to any node.",
      "ssh:  This setting will notify Heketi to ssh to the nodes.",
      "      It will need the values in sshexec to be configured.",
      "kubernetes: Communicate with GlusterFS containers over",
      "            Kubernetes exec api."
    ],
    "executor": "ssh",

    "_sshexec_comment": "SSH username and private key file information",
    "sshexec": {
      "keyfile": "/etc/heketi/heketi_key",
      "user": "root",
      "port": "<ваш ssh-порт>",
      "fstab": "/etc/fstab"
    },

    "_kubeexec_comment": "Kubernetes configuration",
    "kubeexec": {
      "host" :"https://kubernetes.host:8443",
      "cert" : "/path/to/crt.file",
      "insecure": false,
      "user": "kubernetes username",
      "password": "password for kubernetes user",
      "namespace": "OpenShift project or Kubernetes namespace",
      "fstab": "Optional: Specify fstab file on node.  Default is /etc/fstab"
    },

    "_db_comment": "Database file name",
    "db": "<путь/до/файла/>heketi.db",

    "_loglevel_comment": [
      "Set log level. Choices are:",
      "  none, critical, error, warning, info, debug",
      "Default is warning"
    ],
    "loglevel" : "debug"
  }
}

```
##### Итак, нюансы:
* `port` - я его не трогал, оставил дефолтный, также как и следующий параметр аутентификации
* в секции `jwt` нужно прописать ключи для админа и пользователя; ключ будет нужен в дальнейшем, когда будем прикручивать Heketi к Kubernetes.
* в секции `glusterfs` нужно определить параметр `executor`. По дефолту стоит `mock`, нужно поменять на `ssh`. Если бы мы планировали запускать Heketi как поды Kubernetes, тогда, естественно нужно было бы выбрать значение `kubernetes`.

Это был один из моментов на котором я потерял время.

Дело в том, что вроде и написано, что в режиме `mock` нодам не отдаются никакие команды, но смутила первая строка, в которой написано, что этот режим чудесно подходит для тестов и разработки. Действительно, всё работает, тома создаются, можно получить любую информацию о состоянии кластера, его нодах, созданных томах. Только на самом деле вся эта информация живёт исключительно в воображении Heketi, в его базе данных.

Я заподозрил что что-то не так, когда первый раз создал в Kubernetes `StorageClass`, а из него `PersistentVolumeClaim`, вот только под никак не хотел стартовать с вновь созданным томом. Когда я наконец долез до хранилища GlusterFS и решил поискать на дисках свой только что созданный том, я был несколько озадачен, что по команде `lsblk` я обнаружил диск девственно чистым. Я не нашел там никаких разделов `lvm`, которые Heketi должен был создать самостоятельно. Долго пытался понять что я сделал не так, пока, наконец, не решился сменить значение на `ssh` и... залип ещё на день в настройке следующей секции.

* секция `sshexec` на самом деле кажется простой и понятной. Укажите путь к ssh-ключу, пользователя, под которым будет происходить ssh-соединение, порт, и за каким-то хреном путь к `fstab`, но это не совсем так

Затык случился по нескольким причинам.

Первая. Вроде бы можно использовать ключ `root`-пользователя, но бродя по просторам интернета наткнулся на совет создать отдельный ключ и положить его в папку `/etc/heketi`. Причём речь идёт именно о приватном, а не об открытом ключе. И тут встаёт вопрос безопасности. Либо городить огород с предоставлением прав пользователю `heketi`, от которого работает служба, к закрытому ключу `root`, либо всё-таки создать отдельного пользователя.

Вторая. Вытекает из первой. Было очень неочевидно, под каким именно пользователем всё-таки нужно устанавливать ssh-соединение. Так как сама служба работает от пользователя `heketi`, который создаётся при установке, и наличие рекомендации по созданию отдельного ключа, казалось, что и сюда надо прописывать его же. В официальной документации я не нашел явного указания как это должно быть. У себя оставил рута, позже нашел вариант с абсолютно посторонним пользователем.

Таким образом, в моем случае получаем: пользователь - `root`, приватный ключ - отдельно созданный. Не забываем добавить открытый ключ по всем участвующим в процессе серверам. Я разложил его и в кластер Kubernetes, и кластер GlusterFS. Не уверен, что была необходимость в предоставлении доступа к куберу, но так как меня уже начал утомлять процесс проб и ошибок, я добавил его везде. Повторюсь, это мой тестовый стенд и вопросы безопасности меня интересуют в данный момент не сильно.

Третья. Здесь я опять потерял уйму времени.

Пока я игрался с разными вариантами конфигурации, я открыл в соседнем окне ещё один терминал и запустил команду
```
journalctl -f -u heketi
```
дабы отслеживать ошибки и довольно быстро получил такой вывод:

```
[root@server1 ~]# journalctl -f -u heketi
-- Logs begin at Ср 2020-05-06 10:07:58 MSK. --
май 06 10:11:33 server1 systemd[1]: Started Heketi Server.
май 06 10:11:34 server1 systemd[1]: heketi.service: main process exited, code=exited, status=1/FAILURE
май 06 10:11:34 server1 systemd[1]: Unit heketi.service entered failed state.
май 06 10:11:34 server1 systemd[1]: heketi.service failed.
май 06 10:11:34 server1 systemd[1]: heketi.service holdoff time over, scheduling restart.
май 06 10:11:34 server1 systemd[1]: Stopped Heketi Server.
май 06 10:11:34 server1 systemd[1]: start request repeated too quickly for heketi.service
май 06 10:11:34 server1 systemd[1]: Failed to start Heketi Server.
май 06 10:11:34 server1 systemd[1]: Unit heketi.service entered failed state.
май 06 10:11:34 server1 systemd[1]: heketi.service failed.
```
В двух словах, тут говорится о том, что сервис пытается рестартовать слишком часто и ему надо бы малость остыть. Так я познакомился с командой
```
# systemctl reset-failed heketi.service
```
которая позволяет сбрасывать счётчик неудачных попыток старта за отведённый промежуток времени. Можно продолжать ломать.

А причиной такого поведения сервиса оказалась проста до невозможности. Устав смотреть на унылый вывод лога сервиса `heketi` я включил полный лог
```
journalctl -f
```
и он малость отличался от предыдущего

```
[root@server1 ~]# journalctl -f
-- Logs begin at Ср 2020-05-06 10:07:58 MSK. --
май 06 12:22:13 server1 systemd[1]: heketi.service holdoff time over, scheduling restart.
май 06 12:22:13 server1 systemd[1]: Stopped Heketi Server.
май 06 12:22:13 server1 systemd[1]: start request repeated too quickly for heketi.service
май 06 12:22:13 server1 systemd[1]: Failed to start Heketi Server.
май 06 12:22:13 server1 systemd[1]: Unit heketi.service entered failed state.
май 06 12:22:13 server1 systemd[1]: heketi.service failed.
май 06 12:22:59 server1 systemd[1]: Started Heketi Server.
май 06 12:22:59 server1 heketi[4232]: Heketi 8.0.0
май 06 12:22:59 server1 heketi[4232]: ERROR: Unable to parse configuration: invalid character '#' looking for beginning of object key string
май 06 12:22:59 server1 systemd[1]: heketi.service: main process exited, code=exited, status=1/FAILURE
май 06 12:22:59 server1 systemd[1]: Unit heketi.service entered failed state.
май 06 12:22:59 server1 systemd[1]: heketi.service failed.
```

На четвёртой снизу строке крупненько написно `ERROR` и даже указана причина.

Играясь с настройками сервера я, в силу природной лени, делал копии некоторых строк и просто комментировал и раскомментировал их для изменения значений полей и долго удивлялся, почему поведение сервера не меняется.

После того, как я убрал все комментарии из файла настроек, сервер сразу стартанул.

* секцию `kubeexec` я также не трогал, т.к. в данном случае просто не наш вариант
* `db` - здесь всё просто - нужно указать пусть где будет лежать база данных самого Heketi. По дефолту она лежит в `/var/lib/heketi/heketi.db`, но я, после настройки сервиса переложил её в отдельный том GlusterFS.
* `loglevel` - вроде всё понятно

Также рекомендуется сменить владельцев папок
```
sudo chown -R heketi:heketi /var/lib/heketi /var/log/heketi /etc/heketi
```
Папку `/var/log/heketi` было предложенно сделать в одной из инструкций. У меня её нет, но пусть останется упоминание о том, что лог `heketi` можно хранить отдельно, вдруг кому пригодится.

Модуль сервиса выглядит примерно так, на случай, если кто решит его подшаманить под себя:
```
# vim /etc/systemd/system/heketi.service
[Unit]
Description=Heketi Server

[Service]
Type=simple
WorkingDirectory=/var/lib/heketi
EnvironmentFile=-/etc/heketi/heketi.env
User=heketi
ExecStart=/usr/local/bin/heketi --config=/etc/heketi/heketi.json
Restart=on-failure
StandardOutput=syslog
StandardError=syslog

[Install]
WantedBy=multi-user.target
```

##### Стартуем
```
# systemctl enable heketi
# systemctl start heketi
# systemctl status heketi
```
```
[root@server1 heketi]# systemctl status heketi
● heketi.service - Heketi Server
   Loaded: loaded (/usr/lib/systemd/system/heketi.service; disabled; vendor preset: disabled)
   Active: active (running) since Ср 2020-05-06 16:45:02 MSK; 3s ago
 Main PID: 4338 (heketi)
   CGroup: /system.slice/heketi.service
           └─4338 /usr/bin/heketi --config=/etc/heketi/heketi.json

май 06 16:45:02 server1 systemd[1]: Started Heketi Server.
май 06 16:45:02 server1 heketi[4338]: Heketi 8.0.0
май 06 16:45:02 server1 heketi[4338]: [heketi] INFO 2020/05/06 16:45:02 Loaded ssh executor
май 06 16:45:02 server1 heketi[4338]: [heketi] INFO 2020/05/06 16:45:02 GlusterFS Application Loaded
май 06 16:45:02 server1 heketi[4338]: [heketi] INFO 2020/05/06 16:45:02 Started Node Health Cache Monitor
май 06 16:45:02 server1 heketi[4338]: Listening on port 8080

```
На этом этапе можно проверить жив ли пациент:

```
curl http://<server:port>/hello
```
В ответ должны получить:

```
Hello from Heketi
```

---
### Часть III. Загружаем топологию хранилища
На этом этапе мы могли бы перейти на любой другой компьютер, откуда будет в дальнейшем вестись управление Heketi, так как с помощью утилиты `heketi-cli` можно управлять любым доступным сервером используя ключ `-s http://<heketi server>:<port>`, но для удобства, мы закончим настройку там же, где и начали.

В официальной инструкции есть пару абзацев о разнесении серверов по зонам исходя из их физического расположения, скорости дисков, подведённого питания, но я с этим заморачиваться не стал и все свои виртуалки мирно живущие на соседних пластинах харда поместил в одну зону.
Итак, создаем файл `topology.json` всё в той же папке `/etc/heketi/`
```
{
"clusters": [
    {
      "nodes": [
        {
          "node": {
            "hostnames": {
              "manage": [
                "<ip node1 GlusterFS>"
              ],
              "storage": [
                "<ip node1 GlusterFS>"
              ]
            },
            "zone": 1
          },
          "devices": [
            "/dev/XXX"
          ]
        },
        {
          "node": {
            "hostnames": {
              "manage": [
                "<ip node2 GlusterFS>"
              ],
              "storage": [
                "<ip node2 GlusterFS>"
              ]
            },
            "zone": 1
          },
          "devices": [
            "/dev/XXX"
          ]
        },
        {
          "node": {
            "hostnames": {
              "manage": [
                "<ip node3 GlusterFS>"
              ],
              "storage": [
                "<ip node3 GlusterFS>"
              ]
            },
            "zone": 1
          },
          "devices": [
            "/dev/XXX"
          ]
        }
      ]
    }
]
}
```
Структура файла проста и понятна. Поочередно описываются ноды кластера GlusterFS.

Чего я не смог понять, так это зачем отдельно описывать для каждой ноды адреса управления и хранилища, причём адрес управления разработчик предлагает описывать в текстовой форме, как он записан в `hosts`, а адрес хранилища - цифрами. Под адресом управления понимается адрес, по которому будет устанавливаться ssh-соединение с нодой. Я в обоих случаях писал ip-адрес ноды - всё работает. Если мне кто-нибудь объяснит в чём тут разница, буду премного благодарен.

Также в каждом блоке описываются девайсы для хранения данных, как они отображаются на самих виртуалках. В моём примере всего по одному диску, но реально их может быть много больше.

##### Загружаем топологию в Heketi
Сначала нам нужно экспортировать переменную
```
export HEKETI_CLI_SERVER=http://<heketi server>:<port>
```
Теперь загружаем
```
heketi-cli topology load --json=topology.json
````
Должны увидеть примерно такое:
```
[root@server1 ~]# heketi-cli topology load --json=topology.json
Creating cluster ... ID: cff9cbc71751bace90ac429e865f6e22
	Allowing file volumes on cluster.
	Allowing block volumes on cluster.
	Creating node 192.168.1.11 ... ID: 2cb0ba3adbef669bd7986a8557e0b2a6
		Adding device /dev/vdc ... OK
	Creating node 192.168.1.12 ... ID: 6c95df802f750c30671413622b4202fd
		Adding device /dev/vdc ... OK
	Creating node 192.168.1.13 ... ID: fd6661b263a13ed871ab97dbefbc0c0f
		Adding device /dev/vdc ... OK
```
На этом установка закончена, можно создавать тома.

---
### Часть IV. Создание тома данных
Тома данных можно создавать как утилитой командной строки, так и с помощью Kubernetes или OpenShift. В любом случае, это лишь инструменты доступа к API GlusterFS.

Чтоб было проще и меньше писать я сделал на компьютере с которого будет вестись управление алиас (заодно и выглядит команда в стиле `k` или `oc`):
```
alias hc='heketi-cli -s http://<heketi server>:<port>'
```
Теперь просто пишем:
```
hc volume create --size=1
```
и получаем том размером 1 гигабайт.

По воле разработчиков - это минимально возможный размер тома данных и все они должны быть кратны 1 гигабайту.

Давайте проверим, что получилось. Посмотрим информацию по кластеру
```
[root@server1 ~]# hc cluster list
Clusters:
Id:cff9cbc71751bace90ac429e865f6e22 [file][block]
```
У нас есть один кластер. На самом деле их может быть больше, чем один.
```
[root@server1 ~]# hc cluster info cff9cbc71751bace90ac429e865f6e22
Cluster id: cff9cbc71751bace90ac429e865f6e22
Nodes:
2cb0ba3adbef669bd7986a8557e0b2a6
6c95df802f750c30671413622b4202fd
fd6661b263a13ed871ab97dbefbc0c0f
Volumes:
619804001c50bb2eb9490b5d9a775350
Block: true

File: true
```
В нашем кластере есть три ноды и только что созданный том данных.

Также можно посмотреть информацию по нодам, девайсам, и самим томам.
```
[root@server1 ~]# hc volume info 619804001c50bb2eb9490b5d9a775350
Name: vol_619804001c50bb2eb9490b5d9a775350
Size: 1
Volume Id: 619804001c50bb2eb9490b5d9a775350
Cluster Id: cff9cbc71751bace90ac429e865f6e22
Mount: 192.168.1.11:vol_619804001c50bb2eb9490b5d9a775350
Mount Options: backup-volfile-servers=192.168.1.12,192.168.1.13
Block: false
Free Size: 0
Reserved Size: 0
Block Hosting Restriction: (none)
Block Volumes: []
Durability Type: replicate
Distribute Count: 1
Replica Count: 3
```
А теперь ещё интересный момент. Если на любой ноде гластера выполнить команду
```
[root@gluster-01 ~]# gluster volume list
gv0
gv1
vol_619804001c50bb2eb9490b5d9a775350
```
то мы увидим в списке ещё два волюма. Они были созданы без участия Heketi, при помощи утилиты `gluster` и на других дисках, не участвующих в образовании хранилища Heketi.

Один из них я планирую использовать для хранения базы данных самого Heketi.

Для этого я изменю стандартный путь в файле `/etc/heketi/heketi.json`
```
  "db": "/var/lib/heketi/heketi.db",
```
на
```
  "db": "/mnt/heketi-db/heketi.db",
```
создам этот каталог и скопирую туда файл базы данных `heketi.db`

Также я добавлю строку в '/etc/fstab' на сервере, где развёрнут Heketi, чтобы каталог монтировался автоматически при запуске сервера.

У меня эта строка выглядит так (`g1` - так прописана в `hosts` первая нода кластера GlusterFS):
```
g1:/gv0                 /mnt/heketi-db          glusterfs       defaults,_netdev        0 0
```
После чего
```
# mount -a
# systemctl restart heketi
```
Вот нам и пригодился заранее установленный пакет `glusterfs`.

Теперь база данных самого Heketi хранится в файловой системе GlusterFS.

Можно пробовать создавать постоянные тома Kubernetes.

---
### Часть V. Создание постоянного тома Kubernetes
##### Создаём StorageClass
Идём туда, откуда мы управляем кубером и пишем файл `heketi-sc.yml`
```
kind: StorageClass
apiVersion: storage.k8s.io/v1beta1
metadata:
  name: heketi
provisioner: kubernetes.io/glusterfs
parameters:
  resturl: "http://<heketi server>:<port>"
  clusterid: "cff9cbc71751bace90ac429e865f6e22"      
  restauthenabled: "false"
  restuser: "admin"
  restuserkey: "<ваш ключ админа>"
```
По параметрам вроде всё очевидно, `clusterid` мы недавно получали утилитой `heketi-cli`, а значения `restuser` и `restuserkey` сами задавали в файле `heketi.json`.

Запускаем:
```
k apply -f heketi-sc.yml
```
Я для примера использования постоянного тома создам в Kubernetes под частного реестра докера в котором буду хранить свои образы. Постоянный том я буду использовать чтобы при пересоздании пода с реестром не убивались данные.

##### Создаём PersistentVolumeClaim
Пишем файл `registry-pvc.yml`
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-pvc
spec:
  accessModes:
    - ReadWriteMany
  volumeMode: Filesystem
  storageClassName: heketi
  resources:
    requests:
      storage: 3Gi
```
Запускаем:
```
k apply -f registry-pvc.yml
```
Теперь можно создать под, который будет использовать постоянный том.
##### Создаём ReplicationController
Пишем `registry.yml`
```
apiVersion: v1
kind: ReplicationController
metadata:
  name: registry
spec:
  replicas: 1
  selector:
    app: registry
  template:
    metadata:
      name: registry
      labels:
        app: registry
    spec:
      containers:
      - name: registry
        image: registry:2
        ports:
        - containerPort: 5000
        volumeMounts:
        - mountPath: "/var/lib/registry"
          name: heketi-vol
      volumes:
      - name: heketi-vol
        persistentVolumeClaim:
          claimName: registry-pvc
          readOnly: false
```
Всё, что будет находится внутри папки `/var/lib/registry` контейнера, физически теперь будет располагаться в нашем постоянном томе.

Почему именно ReplicationController c значением реплики единица, а не просто под, честно скажу - не знаю, скопипастил откуда то.

Запускаем:
```
k apply -f registry.yml
```

##### Создаём службу
Для доступа по постоянному адресу, создадим службу. Пишем `registry-svc.yml`
```
apiVersion: v1
kind: Service
metadata:
  name: registry-svc
spec:
  ports:
  - port: 5000
    targetPort: 5000
  type: NodePort
  selector:
    app: registry
```
Запускаем:
```
k apply -f registry-svc.yml
```

##### Проверяем, что из всего этого получилось
```
[centos@kube-master ~]$ k get sc
NAME                PROVISIONER               RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
gluster (default)   kubernetes.io/glusterfs   Delete          Immediate           false                  7d17h
heketi              kubernetes.io/glusterfs   Delete          Immediate           false                  2m
```
Видим два сторадж-класса. Верхний был создан раньше.
```
[centos@kube-master ~]$ k get pvc
NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
registry-pvc   Bound    pvc-4dca7417-b764-45b2-af8f-dd2b44f2aacf   3Gi        RWX            heketi         2m
```
Видим наш `PersistentVolumeClaim`
```
[centos@kube-master ~]$ k get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   REASON   AGE
pvc-4dca7417-b764-45b2-af8f-dd2b44f2aacf   3Gi        RWX            Delete           Bound    default/registry-pvc   heketi                  2m
```
Видим `PersistentVolume`. Он был создан автоматически.
```
[centos@kube-master ~]$ k get rc
NAME        DESIRED   CURRENT   READY   AGE
registry    1         1         1       2m
```
А это наш контроллер репликации, к которому можно обратиться через службу
```
[centos@kube-master ~]$ k get svc
NAME                                                     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
glusterfs-cluster                                        ClusterIP   10.101.17.223    <none>        1/TCP            7d17h
glusterfs-dynamic-4dca7417-b764-45b2-af8f-dd2b44f2aacf   ClusterIP   10.97.190.50     <none>        1/TCP            2m
kubernetes                                               ClusterIP   10.96.0.1        <none>        443/TCP          10d
registry-svc                                             NodePort    10.98.72.128     <none>        5000:32390/TCP   2m
```
И, наконец, наш под
```
[centos@kube-master ~]$ k get po
NAME                       READY   STATUS    RESTARTS   AGE
glusterfs                  1/1     Running   11         7d16h
registry-xl7qk             1/1     Running   1          2m
```
Я запушил в `registry` дефолтный образ `nginx`, скачанный с официального сайта.
Можно посмотреть, есть ли он там, обратившись к службе. Так как она работает с типом доступа `NodePort`, это позволяет нам обратиться к ней по адресу любой рабочей ноды кластера Kubernetes и соответствующему порту.
```
[centos@kube-master ~]$ curl http://10.244.1.1:32390/v2/_catalog
{"repositories":["nginx"]}
```
Тоже самое можно увидеть, зайдя в контейнер `registry` например, через WebUI Dashboard

Мы видим структуру каталогов `/docker/registry/v2/repositories/`, созданную внутри каталога `/var/lib/registry/`.

Надеюсь, позже мы увидим её же отдельно от кубера.
```
/ # ls
bin            home           proc           srv            var
dev            lib            root           sys
entrypoint.sh  media          run            tmp
etc            mnt            sbin           usr
/ # ls /var/lib/registry/docker/registry/v2/repositories/
nginx
```
Ну, и наконец, мы можем просто примонтировать наш постоянный том как папку. Для этого смотрим описание тома `k desribe pv ...`

Я сокращу лишний вывод, а то и так уже инструкция на полстранички превратилась в отдельную книгу.
```
[centos@kube-master ~]$ k describe pv pvc-4dca7417-b764-45b2-af8f-dd2b44f2aacf
Name:            pvc-4dca7417-b764-45b2-af8f-dd2b44f2aacf
...
Source:
    Type:                Glusterfs (a Glusterfs mount on the host that shares a pod's lifetime)
    EndpointsName:       glusterfs-dynamic-4dca7417-b764-45b2-af8f-dd2b44f2aacf
    EndpointsNamespace:  default
    Path:                vol_619804001c50bb2eb9490b5d9a775350
    ReadOnly:            false
Events:                  <none>
```
Отюда нам нужно значение `Path`. Его мы используем, когда нам будет нужно найти точку монтирования. Это сейчас у нас один постоянный том, когда их будет много, поиск нужного будет не так очевиден.

Получив путь к тому, смотрим список доступных томов `hc volume list`
```
[root@server1 ~]# hc volume list
Id:619804001c50bb2eb9490b5d9a775350    Cluster:cff9cbc71751bace90ac429e865f6e22    Name:vol_619804001c50bb2eb9490b5d9a775350
```
и получаем описание тома `hc volume info ...`
```
[root@server1 ~]# hc volume info 619804001c50bb2eb9490b5d9a775350
Name: vol_619804001c50bb2eb9490b5d9a775350
Size: 1
Volume Id: 619804001c50bb2eb9490b5d9a775350
Cluster Id: cff9cbc71751bace90ac429e865f6e22
Mount: 192.168.1.11:vol_619804001c50bb2eb9490b5d9a775350
...
```
Я уже делал это раньше, поэтому также сокращу вывод. Отсюда нам нужно поле `Mount`.

Создаем каталог, куда будем монтировать наш том
```
# mkdir /mnt/registry
```
и монтируем
```
[root@kube-master ~]# mount -t glusterfs 192.168.1.11:vol_619804001c50bb2eb9490b5d9a775350 /mnt/registry
```
и смотрим что там есть

```
[root@kube-master ~]# tree -d /mnt/registry
/mht/registry/
└── docker
    └── registry
        └── v2
            ├── blobs
            │   └── sha256
            │       ├── 12
........
            │       └── fa
            │           └── fa7cb2d4347b7646d95c0c03c61b4090c5d5120e8913f9d440acd89ade8a83b3
            └── repositories
                └── nginx
                    ├── _layers
                    │   └── sha256
                    │       ├── a4db9bb2f0712cd0d5219f3f2c6012d0b79515be68e0626db3ea30e904851b1c
........
                    │       └── e55d2d0a2a924fb29ba2055bd7ac181cd4f2e1bdf632437995da5048ec7d01b0
                    ├── _manifests
                    │   ├── revisions
                    │   │   └── sha256
                    │   │       └── daeb130595a78c79abff9578e494daa4edb55d43bce129108cfa8c7d55932923
                    │   └── tags
                    │       └── latest
                    │           ├── current
                    │           └── index
                    │               └── sha256
                    │                   └── daeb130595a78c79abff9578e494daa4edb55d43bce129108cfa8c7d55932923
                    └── _uploads
```
Как раз всё то, что находится в каталоге `/var/lib/registry/` контейнера `registry`.

Мы можем убить под в Kubernetes. Он автоматически восстановится средствами самого Kubernetes и все запушенные образы будут доступны.

---
### Итог
1. Мы развернули сервис Heketi на сервере, не входящем в состав нод кластера GlusterFS, используемый сервисом для хранения данных.
2. Мы создали постоянный том в кластере Kubernetes, используя сервис Heketi для автоматического выделения для него места в хранилище кластера GlusterFS.
3. Мы смогли убедиться в доступности наших данных просто смонтировав том как каталог файловой системы за пределами кластера GlusterFS, в которой этот том находится физически.

---
### Полезные ссылки
Установка Heketi:
https://github.com/heketi/heketi/tree/master/docs/admin

Дистрибутивы:
https://github.com/heketi/heketi/releases

Описание файла конфигурации 'heketi.json':
https://github.com/heketi/heketi/blob/master/docs/admin/server.md

Описание файла топологии 'topology.json': https://github.com/heketi/heketi/blob/master/docs/admin/topology.md

Одна из наиболее понятных инструкции по настройке 'heketi.json': https://computingforgeeks.com/setup-glusterfs-storage-with-heketi-on-centos-server/

По этой статье я ориентировался, настраивая связь между Heketi, GlusterFS и Kubernetes: https://delfer.ru/2017/10/20/kubernetes-%D0%B8-glusterfs/

Статья от КРОКа. Не мой случай, так как в ней Heketi интегрируется в контейнеры Kubernetes, но для понимания процесса настройки подойдёт: https://cloud.croc.ru/blog/byt-v-teme/kubernetes-postoyannye-diski-na-glusterfs-i-heketi/

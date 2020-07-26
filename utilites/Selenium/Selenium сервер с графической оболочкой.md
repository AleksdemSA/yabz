Задача: на сервере с CentOS7 развернуть графику и сервер Selenium, чтобы можно было подключать удалённые автоматические тесты. В дальнейшем мы добавим это в CI/CD процесс.

Для начала ставим все необходимые и удобные для работы пакеты:

```
yum install -y epel-release
yum install -y git lsof wget htop unzip vim tigervnc-server java-1.8.0-openjdk
yum groupinstall -y "Окружение GNOME"
```

Теперь копируем нужный selenium-server-standalone и закидываем его в /opt
```
wget -c https://selenium-release.storage.googleapis.com/3.141/selenium-server-standalone-3.141.59.jar
mv selenium-server-standalone-3.141.59.jar /opt/
```

Не забываем скопировать rpm пакет с Chrome и устанавливаем этот браузер.
```
yum localinstall -y /home/vistest/Downloads/google-chrome-stable_current_x86_64.rpm
```

Так как тестировать будем на Chrome, попутно скачиваем и этот драйвер.
```
wget -c https://chromedriver.storage.googleapis.com/83.0.4103.39/chromedriver_linux64.zip
unzip chromedriver_linux64.zip
mv chromedriver /usr/local/bin/
```

Теперь создаём пользователя vistest для работы в браузере. Запуск графики и браузера от root не уверен что возможен, слишком много будет ограничений. :)
```
useradd -m vistest
```

Зайдем под пользователя, зададим vnc пароль и запустим сервер VNC.

```
su - vistest
vncpasswd
vncserver :10 -geometry 1600x1200 -depth 24
```

А теперь сделаем сервис selenium с нужными параметрами. Запускать его в фоне на современных дистрибутивах таким образом очень даже удобно.

```
vim /etc/systemd/system/selenium.service
```

```
[Unit]
Description=Selenium Service
After=syslog.target network.target

[Service]
User=vistest
Type=simple
Environment="DISPLAY=:10"
WorkingDirectory=/opt
Restart=always
RestartSec=3
ExecStart=/usr/bin/java -jar -Dwebdriver.chrome.driver=/usr/local/bin/chromedriver /opt/selenium-server-standalone-3.141.59.jar -host 10.100.0.15
ExecStop=/bin/kill -TERM

[Install]
WantedBy=multi-user.target
```

host здесь - это ip сервера внутри локальной сети. Selenium не требует авторизации, поэтому выставлять его в интернет не стоит. Теперь запускаем сам сервис:

```
systemctl restart selenium
systemctl enable selenium
```

Журнал можно посмотреть так:

```
journalctl -f -u selenium
```

Ну и пример команды для запуска ранее созданного с помощью Selenium IDE файла release.side.

```
selenium-side-runner -c "browserName=chrome" --server http://10.100.0.15:4444/wd/hub release.side
```

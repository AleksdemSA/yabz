Первоначальная настройка кластера после установки
-------------------------------------------------

В конце инструкции по установке мы создали пользователя, для того, чтобы можно было подключиться к кластеру. Но если мы попробуем получить какую-нибудь информацию о кластере из под этого пользователя, то получим от ворот поворот.

### Делаем нашего пользователя админом кластера
```
$ oc get nodes
No resources found.
Error from server (Forbidden): nodes is forbidden: User "cent" cannot list nodes at the cluster scope: no RBAC policy matched
```
У него очень ограниченные права. Надо их слегка расширить.
Сразу предположим, что это будет не единственный админ кластера, поэтому создадим новую `new` группу админов `okd-admins` и добавим туда пользователя `cent`:
```
oc adm groups new okd-admins cent
```
Посмотрим, какие у нас есть пользователи
```
# oc get users
NAME      UID                                    FULL NAME   IDENTITIES
cent      6919942b-96b2-11ea-b8e2-52540063ffcb               htpasswd_auth:cent
```
и в каких они группах
```
# oc get groups
NAME         USERS
okd-admins   cent
```
Теперь добавим роль кластера `cluster-admins` группе `okd-admins`:
```
# oc adm policy add-cluster-role-to-group cluster-admin okd-admins
cluster role "cluster-admin" added: "okd-admins"
```
Если теперь заново авторизоваться в кластере, то мы увидим, что список проектов, где мы можем порулить слегка расширился:
```
Login successful.

You have access to the following projects and can switch between them with 'oc project <projectname>':

  * default
    kube-public
    kube-service-catalog
    kube-system
    management-infra
    openshift
    openshift-ansible-service-broker
    openshift-console
    openshift-infra
    openshift-logging
    openshift-monitoring
    openshift-node
    openshift-sdn
    openshift-template-service-broker
    openshift-web-console

Using project "default".
```
И если сейчас опять запросить информацию о нодах, то всё получится:
```
[origin@master ~]$ oc get nodes
NAME                     STATUS    ROLES          AGE       VERSION
master.<your.domain>   Ready     infra,master   3d        v1.11.0+d4cacc0
node1.<your.domain>    Ready     compute        3d        v1.11.0+d4cacc0
node2.<your.domain>    Ready     compute        3d        v1.11.0+d4cacc
```

Теперь мы можем авторизоваться в кластере с правами администратора с любого компьютера, где есть утилита `oc` с учётными данными пользователя `cent`.
```
$ oc login https://master.<your.domain>:<port>
Authentication required for https://master.<your.domain>:<port> (openshift)
Username: cent
Password:
Login successful.
```
Для удобства добавьте утилиту `oc` в каталог `/usr/bin`.

---
### Добавляем Wildcard в DNS
Чтобы к нашим приложениям, которые будем деплоить в кластер можно было иметь доступ и не прописывать его для каждого случая, нужно добавить запись в файл зоны на нашем DNS-сервере
```
*.apps          IN      A       10.1.1.13 ; это адрес мастер-ноды
```
Если кто забыл, то `apps` это наш субдомен, который был определен в переменной Ansible перед запуском плейбука развёртывания кластера:
`openshift_master_default_subdomain=apps.<your.domain>`

---
### Чиним registry-console
После того, как мы авторизовались в кластере и посмотрели наличие нод и подов, мы могли заметить, что под registry-console не стартует. Это связано с тем, что образ для этого контейнера отсутствует по дефолтному адресу и теперь находится в реестре RedHat, а не DockerHub. Дело поправимое.

* Сначала логинимся в реестр RedHat (да, опять нужны креды к нему):
```
# docker login https://registry.redhat.io
```
* Тянем образ к себе:
```
# docker pull registry.redhat.io/openshift3/registry-console
```
* Смотрим, на каком адресе и порту у нас доступен реестр Docker в контейнере OpenShift:
```
$ oc get svc
NAME               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                   AGE
docker-registry    ClusterIP   172.30.68.17    <none>        5000/TCP                  3d
```
Сейчас служба доступна по ClusterIP и вероятно поменяет его, если пересоздать саму службу. В будущем можно сменить тип на NodePort, например, но пока нам это не важно, пока нам нужент только адрес и порт.

* Тегируем:
```
# docker tag registry.redhat.io/openshift3/registry-console 172.30.68.17:5000/openshift/registry-console
```
* И пушим в наш реестр:
```
# docker push 172.30.68.17:5000/openshift/registry-console
```
* Осталось отредактировать DeploymentConig `registry-console`:
```
$ oc edit dc registry-console
```
найдём там строчку, указывающую на местоположение образа и поправим её:
```
.....
spec:
  containers:
  - env:
.....
    - name: REGISTRY_ONLY
      value: "true"
    - name: REGISTRY_HOST
      value: docker-registry-default.apps.<your.domain>
    image: 172.30.68.17:5000/openshift/registry-console
    imagePullPolicy: Always
.....    
```
а строчкой выше указан путь, по которому можно заглянуть в содержимое этой службы через браузер.
* Смотрим, чего получилось:
```
$ oc get po
NAME                        READY     STATUS             RESTARTS   AGE
docker-registry-1-2hfqx     1/1       Running            0          3d
registry-console-5-djxxm    1/1       Running            0          2m
```
---
### Выносим хранилище registry на постоянный том
Как видно выше, после дефолтной установки у нас есть свой реестр Docker, где будут храниться наши образы. Но есть проблема - если мы уничтожим контейнер с реестром, то все образы будут утеряны. Чтобы этого не произошло, нужно вынести хранилище на постоянный том. Я рассмотрю вариант использования кластера GlusterFS и Heketi для динамического предоставления тома.

Итак, в моём случае я имею развёрнутый отдельно от кластера OpenShift кластер GlusterFS. Также на одной из нод кластера GlusterFS развёрнута служба Heketi.

Изначально она была отделена от GlusterFS и находилась на мастер-ноде моего другого проекта - кластера Kubernetes, но после того, как кубер и шифт стали использовать одно хранилище, я отделил мух от котлет и переместил службу для автоматического предоставления томов данных туда, где ей и положено было быть - на кластер GlusterFS. Так как её база данных лежала в томе GlusterFS, то перенос прошел безболезненно: в одном месте выключил, в другом - включил. Единственный минус - я не разобрался, можно ли отредактировать уже существующие тома в кластере Kubernetes. Ничего особо ценного у меня там не было, а самих томов было не много. Я решил не терять время на решение этой проблемы и просто пересоздал StorageClass в кластере Kubernetes, создал там новые тома данных, потом скопировал в них данные из старых томов и удалил всё, что ссылалось на старый сервер Heketi. Всё прошло быстро и в пути ничего не потерялось.

Ну, а дальше всё почти также, как в Kubernetes. Сначала логинимся в кластер OpenShift и создаем там StorageClass:
```
$ vim heketi-sc.yaml
```
содержимое файла:
```
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: heketi-sc
provisioner: kubernetes.io/glusterfs
parameters:
  resturl: "http://<ip-адрес серевера Heketi>:<port>"
  restauthenabled: "false"
```
создаём класс:
```
$ oc create -f heketi-sc.yaml
storageclass.storage.k8s.io/heketi-sc created
```
проверяем:
```
$ oc get sc
NAME        PROVISIONER               AGE
heketi-sc   kubernetes.io/glusterfs   6s
```
Теперь создаём заявку на постоянный том:
```
$ vim registry-pvc.yaml
```
содержимое файла:
```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: heketi-sc
```
создаём заявку:
```
$ oc create -f registry-pvc.yaml
persistentvolumeclaim/registry created
```
проверяем:
```
$ oc get pvc
NAME       STATUS    VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
registry   Bound     pvc-bd22266c-9a93-11ea-8632-52540063ffcb   10Gi       RWX            heketi-sc      8с
```
Перед переключением хранилища на внешний постоянный том, нам нужно убедиться что служба `docker-registry` запущена:
```
$ oc get svc
NAME                                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                   AGE
docker-registry                           ClusterIP   172.30.68.17     <none>        5000/TCP                  4d
```
Теперь присоединяем постоянный том:
```
$ oc set volume deploymentconfigs/docker-registry --add --name=registry-storage -t pvc --claim-name=registry --overwrite
deploymentconfig.apps.openshift.io/docker-registry volume updated
```
Всё!!! После этого OpenShift сам пересоздаст под реестра Docker с новым расположением хранилища. Единственный минус - оно пустое. Поэтому свежезапушенного образа `registry-console` там больше нет. Но если мы запушим его туда снова, то после этого можем примонтировать том GlusterFS который теперь привязан к поду с реестром на любом хосте и убедиться, что всё на месте.
```
$ oc describe pv pvc-bd22266c-9a93-11ea-8632-52540063ffcb
Name:            pvc-bd22266c-9a93-11ea-8632-52540063ffcb
Labels:          <none>
Annotations:     Description=Gluster-Internal: Dynamically provisioned PV
....
Finalizers:      [kubernetes.io/pv-protection]
StorageClass:    heketi-sc
Status:          Bound
Claim:           default/registry
Reclaim Policy:  Delete
Access Modes:    RWX
Capacity:        10Gi
Node Affinity:   <none>
Message:         
Source:
    Type:           Glusterfs (a Glusterfs mount on the host that shares a pod's lifetime)
    EndpointsName:  glusterfs-dynamic-bd22266c-9a93-11ea-8632-52540063ffcb
    Path:           vol_b1436d1cbd568a61c5cb49ee49829817
    ReadOnly:       false
Events:             <none>

```
Отсюда нам нужно значение поля `path`, которое мы вставим в следующую команду:
```
# mount -t glusterfs <ip-адрес.любой.ноды.GlusterFS>:vol_b1436d1cbd568a61c5cb49ee49829817 /mnt/
```
Отличия от Kubernetes на этом этапе заключаются в том, что создать заявку на постоянный том и добавить хранилище к деплойменту можно из WebUI, что само по себе нагляднее, быстрее и удобнее.

На этом пока всё. Реестр Docker в надёжном месте, у пользователя `cent` достаточно прав, чтобы уронить что угодно. Можно, наконец, задеплоить что-нибудь полезное.

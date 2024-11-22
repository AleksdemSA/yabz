# Deploy в Kubernetes с помощью Ansible на примере Metabase

Есть такая замечательная система аналитики - Metabase. В первую очередь меня она подкупила интуитивно понятным интерфейсом. И, чтобы использовать данное ПО, я его разворачивал в Kubernetes. Не просто манифестами, а с помощью Ansible. Давайте посмотрим как это делается...

<!--more-->

Для начала - дерево файлов. Посмотрим, где что лежит.

```sh
roles
└── metabase
    ├── application.yml
    ├── defaults
    │   └── main.yml
    ├── tasks
    │   └── main.yml
    └── templates
        ├── appdeploy.yml.j2
        ├── appingress.yml.j2
        ├── appservice.yml.j2
        ├── database.yml.j2
        ├── dbpvc.yml.j2
        └── namespace.yml.j2
```

И начнём с application.yml, лежащего в корне роли. Именно этот файл я запускаю для раскатки плейбука. Пример самого запуска:

```sh
ansible-playbook role/metabase/application.yml
```

Содержимое файла самое что ни есть простейшее. Это специально сделано так, чтобы при тиражировании роли для других проектов переписывать как можно меньше. Чем проще - тем меньше шансов где-то ошибиться.


```yml
---
- name: Install Metabase
  hosts: localhost
  roles:
    - ..
```

Здесь в имени можно убрать Metabase, заменив на что-то нейтральное (Applacation?), чтобы файл не трогать в дальнейшем вообще. Роль выполняется локально, а значит, доступ на деплой у вас должен быть. Если запуск в Jenkins, то блок кода может выглядеть примерно так:


```groovy
withCredentials([file(credentialsId: 'kuber', variable: 'KUBECONFIG')]) {
  sh """
    ansible-galaxy collection install kubernetes.core
    ansible-playbook role/metabase/application.yml \
      --extra-vars "namespace=${NS}"
  """
}
```

Попутно я оставил и extra-vars, чтобы показать, что часть переменных можно будет позже задавать в ходе деплоя. Конфиги, версия образа и тд - что угодно!

А в этом нам поможет defaults/main.yml с подобным содержимым:

```yml
---
NAMESPACE: "{{ meta.NAMESPACE | default('metabase') }}"
EMAIL: "devops@example.org"
IMAGE: "metabase/metabase:v0.46.8"
POSTGRES_PASSWORD: "metabase"
POSTGRES_USER: "metabase"
POSTGRES_DB: "metabase"
DBSIZE: "1Gi"
APPCPU: "1"
APPMEM: "2Gi"
DBCPU: "1"
DBMEM: "500Mi"
DOMAIN: "{{ meta.DOMAIN | default('metabase.example.org') }}"
IPWHITELIST: "0.0.0.0/0"
```

Строки, содержащие default, нужны для того, чтобы в случае пропуска переменной, выставлялось значение по-умолчанию. Иногда это очень даже удобно. Например, на всех тестовых namespace можно указать небольшой значение для CPU, а для уже более нагруженных стендов - по потребностям.

Разумеется, параметры вы выставляете самостоятельно, на свой вкус. Уж пароль точно стоит сменить и спрятать в Vault или что-то поодобное.

А теперь рассмотрим сам процесс запуска манифестов в Kubernetes, который описан в tasks/main.yml

```yml
---
- name: Create NS
  kubernetes.core.k8s:
    state: present
    template:
      - namespace.yml.j2

- name: Create database pvc
  kubernetes.core.k8s:
    state: present
    template:
      - dbpvc.yml.j2

- name: Create database
  kubernetes.core.k8s:
    state: present
    template:
      - database.yml.j2

- name: Create application deploy
  kubernetes.core.k8s:
    state: present
    template:
      - appdeploy.yml.j2

- name: Create application service
  kubernetes.core.k8s:
    state: present
    template:
      - appservice.yml.j2

- name: Create application ingress
  kubernetes.core.k8s:
    state: present
    template:
      - appingress.yml.j2
```

Проще и обезличеннее уже сложно написать. К тому же с чётко описанной последовательностью. Остаётся разве только темплейты собрать в один файл, но тогда вопрос с дебагом будет стоять чуть острее. Можно не усложнять себе жизнь. ;)

И для примера посмотрим один из манифестов. Остальные выложены на github (ссылка в конце) и можно посмотреть в любое время, поэтому не будем терять время:

```yml
---
apiVersion: v1
kind: Service
metadata:
  name: metabase
  namespace: {{ NAMESPACE }}
  labels:
    app: metabase
spec:
  ports:
    - port: 3000
      protocol: TCP
      targetPort: 3000
  selector:
    app: metabase
```

Как вы видите, любой темплейт, это, по сути, просто манифест. К тому же с переменными. Это поможет сделать деплой приложений в кластер в любой namespace с любыми параметрами простым и очень быстрым. Даже достаточно любимый многими Helm смотрится чуть сложнее, чем этот вариант. И по скорости Ansible в данном случае не уступает последнему.

Обещанная ссылка на GitHub: [AleksdemSA/metabaseDeploy]( https://github.com/AleksdemSA/metabaseDeploy).

#kubernetes #ansible

# Gitea в Docker Swarm

В качестве теста нужно было развернуть хранилище для интеграции с Jenkins, где я мог бы разместить свои pipelines на groovy. Выбор пал на Gitea - это замечательный, легкий, быстрый и очень функциаональный вариант для организации своего git-хранилища. Описание проекта делать нет смысла, оно есть и на официальном сайте. В моём случае рядом был кластер Docker Swarm, где и можно было развернуть Gitea.

*Маленькое отступление: зачем нужна статья ради одной-двух команд? Всё просто: я хочу показать, что создавать сервисы гораздо проще, чем кажется!*

Итак, для данных мне нужно было хранилище:

```
docker volume create gitea
```
и теперь уже запуск самого сервиса

```
docker service create -d -p 80:3000 -p 22:22 --mount type=volume,source=gitea,destination=/data --network internal --name gitea --replicas=1  gitea/gitea:latest
```

В данном случае сервис будет отвечать на стандартном 80 порту (http) и на 22 отдавать хранилища по SSH. Базы данных я не подключал, так как Gitea может прекрасно работать и с sqlite. Как показала практика, для команды в 2-5 человек разницы просто не видно, а дальше настроить базу данных (MySQL или PostgreSQL) не составит большого труда. Так же в кластере Docker Swarm, например.

Пожалуйста, если есть уточнения илвопросы, задавайте их в Issue, мы найдем время на ответ. :)
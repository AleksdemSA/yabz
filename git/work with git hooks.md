## Примеры работы с git hook


#### Выполняем команду перед push в зависимости от ветки.

Необходимо было при отправке изменений сразу выполнять и нужную команду. При этом учитывать название ветки. Ну и попутно почему бы не настроить уведомление у нужный мессенджер?

Задача решена созданием файла .git/hooks/pre-push следующего содержания:

```
#!/bin/bash
LC_ALL=C

local_branch="$(git rev-parse --abbrev-ref HEAD)"


#### ls, please ####

if [ $local_branch = ls ] ; then
  ls -lah *

  sending_text="DNS changed"

fi

#### make scheme in graphviz ####

if [ $local_branch == graphviz ] ; then
  echo "make renessans net"
  dot -Tsvg docs/scheme_net.gv -o docs/net.svg

  sending_text="scheme of net rebuilded"

fi

#### master branch ####

if [ $local_branch == master ] ; then
  sending_text="master branch changed"
fi

#### telegram sender ####

if [ $# -gt 0 ]
  then
      text="[$2] :  $sending_text"
      url="https://api.telegram.org/bot***:***/sendMessage"

      curl \
        --data-urlencode "chat_id=***" \
        --data-urlencode "text=$text" \
        --connect-timeout 10 \
        --max-time 10 \
        $url > /dev/null 2>&1
      else
        echo "Text is empty"
  fi
```

Файл нужно сделать исполняемым:
```
chmod u+x .git/hooks/pre-push
```

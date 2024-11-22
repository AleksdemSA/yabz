# Библиотека в Jenkins для получения секретов из Hashicorp Vault

Традиционная уже задачка на тему получения секретов из Vault. На самом деле буквально один запрос, но из-за JsonSlurperClassic конвейер всегда будет считаться небезопасным. Если же вынести это в SharedLibrary, вопросов не возникает.
<!--more-->

Итак, делаем библиотеку, добавляем импорт JsonSlurperClassic и пишем функцию:

```sh
import groovy.json.JsonSlurperClassic
...
Map get(String name) {
  ResponseContentSupplier httpResponse = jenkins.httpRequest consoleLogResponseBody: true, \
    customHeaders: [[maskValue: true, name: 'X-Vault-Token', \
    value: 'yourToken' ]], \
    url: "yourVaultURL/${name}", \
    validResponseCodes: '100:299', wrapAsMultipart: false

  Map secrets = new JsonSlurperClassic().parseText(httpResponse.getContent())
  return secrets.data.data
}
```

В return специально указана data.data, чтобы это не повторялось при использовании. Проще один раз указать тут, чем в конвейерах это везде повторять.

Использование в конвейерах данной функции будет достаточно простое.

```sh
@Library('yourLib')
import yourLib.Vault
...
Vault vault = new Vault(this)
...
secrets = vault.get('Internal/TestSecrets')
println(secrets.MySecretKey)
```

В println нет data.data, так как мы это уже указали в return.

Обращение к любому ключу в секрете становится очень простым. Достаточно указать secrets.нужныйКлюч и получено значение.

#jenkins #sharedlibrary

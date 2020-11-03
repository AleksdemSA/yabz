Итак, у нас есть связка Vault и Jenkins. Нам нужно, имея в credentionals логин и пасс для Vault, получить токен для дальнейшей работы. Я использовал такой вариант для этой операции. Из условий: в Jenkins должен быть плагин HTTP Request Plugin

```
import groovy.json.JsonSlurper;

// передаём логин и пароль и получаем токен Vault
public def vaultGetToken() {
    def response
    def VaultAuthUrl='https://127.0.0.1/v1/auth/userpass/login/'

    withCredentials([usernamePassword(credentialsId: 'vaultUserPassword', passwordVariable: 'vaultPass', usernameVariable: 'vaultUser')]) {
    
    // пытаемся получить токен по логину-паролю
    try {
        response = httpRequest acceptType: 'TEXT_PLAIN', 
                    consoleLogResponseBody: false, 
                    contentType: 'APPLICATION_JSON', 
                    httpMode: 'POST', 
                    requestBody: '{"password": "'+vaultPass+'"}',
                    validResponseCodes: '200,404',
                    url: VaultAuthUrl+vaultUser

 
    // парсим JSON-массив и возвращаем токен
    def jsonSlurperAuth = new JsonSlurper().parseText(response.getContent())
    return (jsonSlurperAuth.auth.client_token)
    
    // если не получаем токен, показать ошибку и завершить сборку
    } catch(all) {
        println(all)
        currentBuild.result = 'FAILURE'
    }
```

Разумеется, это не самый простой способ, возможно есть и удобнее варианты, буду рад их увидеть.
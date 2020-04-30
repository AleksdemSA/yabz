Быстро правим параметры виртуалки из консоли
--------------------------------------------
Имеем виртуалку с 4 гигами памяти и 1 процем
```
[root@localhost ~]# free -h
              total        used        free      shared  buff/cache   available
Mem:           3.9G         85M        3.7G         16M         82M        3.6G
Swap:          2.0G          0B        2.0G
```
```
[root@localhost ~]# lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                1
```
Хотим добавить мощи, сделав 8 гигов памяти и 2 проца. Легко!

Открываем работающую или выключенную виртуалку на редактирование:
```
# virsh edit <vm name>
```
Так выглядит начальный кусок её xml-файла:
```
<domain type='kvm'>
  <name>test-3</name>
  <uuid>f5dc3171-b568-4947-96d4-adddec7aebf8</uuid>
  <memory unit='KiB'>4194304</memory>
  <currentMemory unit='KiB'>4194304</currentMemory>
  <vcpu placement='static'>1</vcpu>
  <os>
    <type arch='x86_64' machine='pc-i440fx-rhel7.0.0'>hvm</type>
    <boot dev='hd'/>
  </os>
```
Берём калькулятор, считаем и вписываем нужные параметры в строки 'memory unit', 'currentMemory unit' и 'cpu placement'.
Если без калькулятора, меняем килобайты на мегабайты ('MiB') или гигабайты ('GiB').
После этого виртуалку надо обязательно выключить и включить, т.к. простая перезагрузка почему-то не применяет новые параметры.
```
# virsh shutdown <vm name>
```
Если хотим убедиться, что виртуалка выключилась:
```
# virsh list --all
```
Тогда в списке будут не только работающие.

Запускаем виртуалку.
```
# virsh start <vm name>
```
Ждём пока загрузится. Смотрим что получилось.
```
[root@localhost ~]# free -h
              total        used        free      shared  buff/cache   available
Mem:           7.8G        130M        7.6G         16M         97M        7.5G
Swap:          2.0G          0B        2.0G
```
```
[root@localhost ~]# lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                2
```
Делаем ещё раз 'virsh edit ...' и видим, что объём памяти и количество процессоров поменялись, но параметры памяти так и остались в килобайтах. Зато можно было обойтись без калькулятора на этапе редактирования.
```
<domain type='kvm'>
  <name>test-3</name>
  <uuid>f5dc3171-b568-4947-96d4-adddec7aebf8</uuid>
  <memory unit='KiB'>8388608</memory>
  <currentMemory unit='KiB'>8388608</currentMemory>
  <vcpu placement='static'>2</vcpu>
  <os>
    <type arch='x86_64' machine='pc-i440fx-rhel7.0.0'>hvm</type>
    <boot dev='hd'/>
  </os>
```

Я потратил больше времени на написание этой инструкции, чем в дальнейшем потребует её использование. ;)

# MikrotikBackup
## Сценарий резервного копирования настроек и журнала устройства с автоматическим определением местоположения хранилища

  Имею в хозяйстве разношёрстные устройства от Mikrotik и каждое из них обладает своими особенностями хранения данных: где-то используется внешний USB-накопитель, где-то встроенный flash-диск устройства. На части устройств встроенный диск по умолчанию называется 'flash', а на другой части никак не называется :)
  Захотелось изобразить один универсальный бэкап-скрипт, который будет одинаково хорошо сохранять все настройки и журналы на любом из этих устройств.
Задумка простая: нужно запустить скрипт на устройстве, а скрипт сам разбирётся что и куда он будет сохранять...
По умолчанию в настройках скрипта задана глубина архива =180 дней. Глубина архива автоматически уменьшается при нехватке свободного места на накопителе.
При запуске скрипта в терминале, можно наблюдать отчёт о его работе.
Скрипт работает по алгоритму:
 - определяется место для хранения данных. Приоритеты в порядке убывания: внешний накопитель, встроенный накопитель.
 - генерится имя для будущих файлов по шаблону: 'Диск\ИмяРоутера_ТекущаяДата'
 - удаляются все файлы, старше глубины архива и подходящие под шаблон: 'Диск\ИмяРоутера_'
 - удаляются файлы, младше глубины архива, но при условии, что свободного места на диске не менее 4%.
 - сохраняются бэкап-файл, экспорт-файл, файл журнала со сгенеренными в п.2 именами.

  В скрипте предусмотрена возможность отключения автоопределения места хранения данных, для этого переменной 'autoDiskSelection' нужно задать значение 'false', а в переменной 'diskName' потребуется указать актуальное имя накопителя (по умолчанию задано имя "flash").
В рабочем варианте скрипт запускается по шедулеру один раз в сутки.

https://forummikrotik.ru/viewtopic.php?p=91135#p91135

# MikrotikBackup
## Script for backup of device settings and log with automatic storage location detection

I have a variety of Mikrotik devices in my household, each of which has its own data storage features: somewhere an external USB drive is used, somewhere a built-in flash drive of the device. On some devices, the built-in drive is named 'flash' by default, while on others it has no name. :)

I wanted to create one universal backup script that will save all the settings and logs of any of these devices equally well on the currently available drive.

The script must be run on the device, and then it will figure out what, how and where to save it... By default, the archive depth = 180 days is set in the script settings, which automatically decreases when there is not enough free space on the available drive. Along the way, when you run the script in the terminal window, you can see a report on its operation.

The algorithm of the script:
- the data storage location is being determined. Priorities in descending order: 1. External storage, 2. Built-in storage
- a new file name is generated using the template: 'Path/Router name_Current-Date_Current-Time'
- all files older than the archive depth and suitable for the template are deleted: 'Path/Router name'
- in the case when less than 4% of free space is left on the drive: files younger than the archive depth and suitable for the template: 'Path/Router name' are deleted
- the following files are created and saved on the drive:
  - device settings in the format '.backup
  - 'device configuration in '.rsc' format device
  - log in '.txt'
  - format The configuration of 'The Dude' in '.rsc' format
  - The database of 'The Dude' in '.db' format

The script has the option to manually configure the path to the directory where backups are stored. To do this, disable automatic backup location detection in the script settings by setting the 'autoDskSel' variable to 'false' and specifying the full path to the target directory using the "/" characters in the 'backupPath' variable.

**Please note, this is important!!!** In the file system of the router, you must MANUALLY create a directory in ADVANCE where the script will save backups. Windows users can do this by creating a folder in Explorer and dragging it to the desired location in the Files window in Winbox.

The typical scheduled script launch period is once a day.

https://forummikrotik.ru/viewtopic.php?p=91135#p91135

Features:
- automatically determines the data storage location,
- allows you to set the archive depth in days,
- looks after free space on the drive,
- saves backup file, settings file, log file, base and settings "The Dude",
- file names is based on the device ID, date and time,
- works on RouterOS 6.xx and 7.xx
- no dependencies on other software modules

**If you use a script, mark it with an asterisk, it's not difficult for you, but it's nice for me!**
_____________________________________________________

## Скрипт резервного копирования настроек и журнала устройства с автоопределением расположения хранилища

  Имею в хозяйстве разношёрстные устройства Mikrotik, каждое из которых обладает своими особенностями хранения данных: где-то используется внешний USB-накопитель, где-то встроенный flash-диск устройства. На некоторых устройствах встроенный диск по умолчанию называется 'flash', а на других никак не называется :)
  
  Захотелось изобразить один универсальный бэкап-скрипт, который одинаково хорошо сохранит все настройки и журналы любого из этих устройств на доступном в текущий момент накопителе.
  
  Скрипт необходимо запустить на устройстве, а далее он сам разберётся что, как и куда нужно сохранять...
По умолчанию в настройках скрипта задана глубина архива =180 дней, которая автоматически снижается при нехватке свободного места на доступном накопителе.
Попутно, при запуске скрипта в окне терминала можно наблюдать отчёт о его работе.

Алгоритм работы скрипта:
 - определяется место для хранения данных. Приоритеты в порядке убывания: 1. внешний накопитель, 2. встроенный накопитель
 - генерится новое имя файлов по шаблону: 'Путь/ИмяРоутера_Текущая-Дата_Текущее-Время'
 - удаляются все файлы, **старше глубины архива** и подходящие под шаблон: 'Путь/ИмяРоутера_'
 - в случае, когда на накопителе осталось менее 4% свободного места: удаляются файлы **младше глубины архива** и подходящие под шаблон: 'Путь/ИмяРоутера_'
 - создаются и сохраняются следующие файлы на накопителе:
   - настройки устройства в формате '.backup'
   - конфигурация устройства в формате '.rsc'
   - журнал устройства в формате '.txt'
   - конфигурация 'The Dude' в формате '.rsc'
   - база данных 'The Dude' в формате '.db'

  В скрипте имеется возможность ручной настройки пути к каталогу, где хранятся бэкапы. Для этого в настройках скрипта следует отключить автоопределение места хранения бэкапов путём присвоения переменной 'autoDskSel' значения 'false' и указания полного пути к целевому каталогу через символы "/" в переменной 'backupPath'.
  
  **Обратите внимание, это важно!!!** В файловой системе маршрутизатора необходимо **ЗАРАНЕЕ ВРУЧНУЮ** создать каталог, куда скрипт будет сохранять бэкапы. Пользователи Windows могут это сделать путём создания папки в Проводнике и перетаскивания её в нужное место в окно Files в Winbox.

Типовая настройка периода запуска скрипта по расписанию - один раз в сутки.

https://forummikrotik.ru/viewtopic.php?p=91135#p91135

Особенности работы:
- автоматически определяет место хранения данных,
- позволяет установить глубину архива в днях,
- заботится о свободном месте на накопителе,
- сохраняет резервную копию, файл настроек, лог, базу и настройки «The Dude»,
- имена файлов основаны на идентификаторе устройства, дате и времени,
- работает на RouterOS 6.xx и 7.xx
- никаких зависимостей от других программных модулей

**Используете скрипт - отметьте это звездочкой, Вам не сложно, а мне приятно!**

# automation utils


## Скрипт обновления зависимостей в проекте

[Source code](./update_dependencies.ps1)

Входящие параметры

|Имя параметра        |Коммент                                             | Обязательно |
|---------------------|----------------------------------------------------|-------------|
|workingFolder        |Путь к папке в которой будут созданы временные файлы| да |
|repoAddress          |Url удаленного репозитория проекта, над которые небоходимо провести манипуляции | да |
|includingPackages    |имена пакетов для обновления                        | нет |
|testBranchPrefix     |Префикс бранчи                                      | нет |

### Описание

Скрипт работает примерно следующим образом:

1. Клонирует бранчу в workingFolder
1. Переключается на бранчу к которой будет делать Merge requert
1. Проверяет, есть ли обновления по пакетам
    - если обнов нет - завершает выполнение и удаляет временные файлы и репу
1. Обновляет только патч версии пакетов
    - пытается обновить пакеты, котоыре указаны через "Directory.Build.props"(костыль :( )
    - пытается обновить остальные пакеты
1. Запускает тесты солюшена
    - если тесты падают - завершает выполнение
1. Коммитит все изменения, пушит из в репу, создает merge request
1. Удаляет верменные файлы и репу
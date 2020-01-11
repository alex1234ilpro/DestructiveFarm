Сервер фермы
============

<p align="center">
    <img src="https://github.com/borzunov/DestructiveFarm/blob/master/docs/images/farm_server_screenshot.png" width="700">
</p>

**Сервер фермы** &mdash; это утилита, которая собирает флаги от клиентов фермы, следит за использованием квот, централизованно отправляет флаги в проверяющую систему и показывает статистику по принятым и некорректным флагам. Настраивается и запускается админом команды в начале соревнования. Во время соревнования члены команды могут воспользоваться веб-интерфейсом сервера (см. скриншот выше), чтобы следить за результатами работы эксплоитов и статистикой отправляемых флагов.

Сервер представляет собой веб-сервис (на Flask) из папки [server](../../server) в данном репозитории.

## Установка и запуск

Для работы сервера требуется Python 3 и ОС Linux или macOS. Сервер зависит от нескольких библиотек, но не требует установки на компьютер дополнительного ПО (такого как MySQL или Redis).

Установить сервер можно командами:

```bash
git clone https://github.com/borzunov/DestructiveFarm
cd DestructiveFarm/server
python3 -m pip install -r requirements.txt
```

Перед каждым соревнованием следует:

1. Удалить старую БД с флагами (файл `flags.sqlite`).

2. Указать правильные настройки в файле [config.py](../../server/config.py) (список команд, формат флага, протокол отправки флагов, квоты в проверяющей системе).

    Стандартно поддерживаются протоколы отправки флагов, используемые на соревнованиях RuCTFE, RuCTF и VolgaCTF (система Themis), но вы можете добавить и поддержку других протоколов (см. папку [protocols](../../server/protocols)).

3. Если у других команд на соревновании будет доступ к подсети вашей команды, обязательно смените пароль к веб-интерфейсу сервера (иначе соперники увидят ваши флаги).

Запустить сервер можно командой:

```bash
./start_server.sh
```

## База данных флагов

Сервер хранит все флаги, когда-либо присланные клиентами, в файле `flags.sqlite`. Если клиент присылает флаг, который уже есть в базе, этот флаг игнорируется. Флаги также можно добавлять вручную с помощью формы &laquo;Add Flags Manually&raquo;.

Веб-интерфейс позволяет просматривать и фильтровать флаги по ряду параметров (см. скриншот выше):

- Название файла с эксплоитом, с помощью которого был получен флаг
- Команда, в результате атаки которой был получен флаг
- Сам флаг
- Время его первого добавления в базу сервера фермы
- Статус (см. ниже)
- Результат отправки флага в проверяющую систему (сообщение об ошибке или вердикт системы)

Каждый флаг может иметь один из следующих *статусов*:

- **QUEUED** &mdash; флаг находится в очереди на отправку в проверяющую систему.

    Это значит, что сервер либо ещё не отправлял этот флаг в проверяющую систему, либо не получил от неё ясного ответа (например, проверяющая система в этот момент упала или сообщила об израсходованной квоте). В последнем случае поле &laquo;Checksystem Response&raquo; будет непусто, а флаг будет отправлен ещё раз.

- **ACCEPTED** &mdash; проверяющая система зачла флаг как корректный.

- **REJECTED** &mdash; проверяющая система зачла флаг как некорректный.

- **SKIPPED** &mdash; ферма не получила от проверяющей системы ясного ответа относительно этого флага за период, равный времени его жизни. Ещё раз отправлять флаг бессмысленно, поэтому он был исключён из очереди на отправку.

    Это значит, что сервер либо не успел отправить флаг за нужный период из-за установленных квот на отправку, либо многократно отправлял флаг в проверяющую систему, каждый раз получая ошибку или неизвестный вердикт. В последнем случае поле &laquo;Checksystem Response&raquo; будет непусто.

    Чтобы реализовать поддержку ранее неизвестного вердикта проверяющей системы, его можно добавить в описание используемого протокола в папке [protocols](../../server/protocols).

Обратите внимание, что при фильтрации сервер также выводит общее количество флагов, удовлетворяющих заданным условиям. Например, это позволяет проверять гипотезы о том, что эксплоит в один период времени работал лучше, чем в другой период времени.

## Алгоритм работы

Веб-приложение в составе сервера предоставляет веб-интерфейс и HTTP API для клиентов фермы.

В отдельном потоке работает цикл отправки флагов. Каждые `SUBMIT_PERIOD` секунд сервер сначала загружает новые настройки из файла [config.py](../../server/config.py) (если он изменился и новая версия выполняется без ошибок), после чего отправляет не более, чем `SUBMIT_FLAG_LIMIT` флагов из очереди на отправку. Флаги в очереди, добавленные более, чем `FLAG_LIFETIME` секунд назад, удаляются из очереди (им присваивается статус *SKIPPED*).

## Защита от спама флагами

**Спам флагами** &mdash; это ситуация, когда одна из команд размещает в сервисе (своём или чужом) большое количество ложных флагов (случайных строк, удовлетворяющих формату флага). Ложные флаги часто не влияют на работоспособность сервиса, но могут затруднить его атаку, если получение флага является длительным процессом или если проверяющая система устанавливает квоту на отправку флагов.

В последнем случае команда противника не может проверить все флаги в сервисе и отправляет их случайное подмножество (большой процент которого может оказаться ложными флагами). В то же время, команда, добавившая ложные флаги, может исключить их из выборки и отправлять только корректные флаги, получая больше очков.

На многих соревнованиях спам флагами явно не запрещён. Начиная с 2017 года, жюри реализует различные подходы для защиты от спама:

- На RuCTF отменили квоты на отправку флагов
- На VolgaCTF флаги подписываются электронной подписью, которую ферма может проверить перед отправкой флага

Чтобы уменьшить пагубный эффект от спама флагами в остальных случаях, сервер фермы реализует следующий алгоритм. Флаги делятся на группы, каждая из которых соответствует паре *(эксплоит, команда)*. После этого в проверяющую систему отправляются флаги, выбранные равномерно из данных групп. Так, даже если один из сервисов (у одной команды или у всех) содержит большое количество ложных флагов, они не смогут израсходовать непропорционально большую часть квоты.
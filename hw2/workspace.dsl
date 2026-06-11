
workspace {

    model {
        #  АКТОРЫ 
        buhgalter  person "Бухгалтер" "Основной пользователь системы. Вводит первичную документацию, проводит платежи, формирует отчетность."
        sotrudnik  person "Сотрудник/Преподаватель" "Подает заявки на расходы, командировки, гранты."
        zav_kaf  person "Заведующий кафедрой" "Утверждает заявки сотрудников своей кафедры. Часто работает удаленно."
        prezident  person "Президент колледжа" "Утверждает глобальные бюджеты, просматривает сводные дашборды."
        auditor  person "Аудитор/ИБ-специалист" "Проверяет журналы аудита, расследует инциденты. Только чтение."

        #  ВНЕШНИЕ СИСТЕМЫ 
        bank  softwareSystem "Банк-клиент" "Проведение платежей и выписок. Внешняя система."
        nalog  softwareSystem "ФНС (Электронная отчетность)" "Прием бухгалтерской и налоговой отчетности."
        kadry  softwareSystem "1С:ЗУП" "Кадровый учет и расчет заработной платы. Legacy-система колледжа."
        ldap  softwareSystem "Корпоративный LDAP/AD" "Хранилище учетных записей сотрудников колледжа."

        #  НАША СИСТЕМА 
        accountingSystem  softwareSystem "Бухгалтерская система колледжа" "Учет расходов, управление workflow, ведение неизменяемого аудиторского следа. Соответствие требованиям ФСТЭК и 152-ФЗ." {
            
            #  КОНТЕЙНЕРЫ (Клиенты) 
            desktopApp  container "Desktop Client" "Qt/C#" "Основной интерфейс для бухгалтерии и локальных сотрудников. Поддержка оффлайн-режима."
            mobileApp  container "Mobile App" "Flutter" "Интерфейс для согласования заявок и просмотра отчетов. iOS/Android/Aurora."

            #  КОНТЕЙНЕРЫ (Канал / Точка входа) 
            apiGateway  container "API Gateway / Reverse Proxy" "NGINX + WAF" "Точка входа. Терминация TLS/ГОСТ, Rate Limiting, маршрутизация, защита от OWASP Top 10."

            #  КОНТЕЙНЕРЫ (Компоненты / Бэкенд) 
            backend  container "Core Backend" "Go/Java" "Модульный монолит. Бизнес-логика, финансы, Workflow Engine (State Machine)."
            authService  container "Auth & Audit Service" "Go" "Аутентификация (интеграция с LDAP), генерация токенов, запись в неизменяемый журнал аудита."
            docService  container "Document Service" "Go" "Обработка файлов: загрузка, антивирусная проверка, OCR, генерация печатных форм."
            notificationService  container "Notification Service" "Go" "Отправка Push, Email, SMS-уведомлений."

            #  КОНТЕЙНЕРЫ (Кладовые / Хранилища) 
            postgresPrimary  container "PostgreSQL Primary" "Postgres Pro" "Основная БД. ACID-транзакции, финансовая отчетность, workflow. Single-Leader."
            postgresReplica  container "PostgreSQL Hot Standby" "Postgres Pro" "Реплика для чтения и формирования тяжелых отчетов. Streaming replication."
            auditDb  container "Audit Database" "Postgres Pro" "Append-only БД для журналов аудита. Партиционирование по месяцам. Хэширование цепочки по ГОСТ."
            redis  container "Redis Cluster" "Redis" "Inline/Sidecar кэш. Сессии, токены, справочники кафедр. Паттерн Cache-aside, TTL 5-10 мин, вытеснение LRU."
            minio  container "Object Storage" "MinIO (S3)" "Хранение сканов, чеков, актов, печатных форм. On-Premise, сертификат ФСТЭК."

            #  КОНТЕЙНЕРЫ (Асинхронный канал / Брокер) 
            rabbitmq  container "Message Broker" "RabbitMQ" "Очередь задач для Document Service и Notification Service. Гарантированная доставка."
        }
    }

    views {
        #  VIEW 1: SYSTEM CONTEXT 
        systemContext accountingSystem "SystemContext" "Контекст бухгалтерской системы колледжа" {
            include *
            
            rel buhgalter, accountingSystem "Вводит документы, проводит платежи", "Desktop-клиент, LAN"
            rel sotrudnik, accountingSystem "Подает заявки на расходы", "Desktop-клиент (LAN) или Mobile (VPN)"
            rel zav_kaf, accountingSystem "Утверждает заявки, настраивает workflow кафедры", "Mobile-приложение, VPN"
            rel prezident, accountingSystem "Просматривает дашборды, утверждает бюджеты", "Mobile-приложение, VPN"
            rel auditor, accountingSystem "Выгружает и анализирует журналы аудита", "Desktop-клиент, LAN"
            
            rel accountingSystem, bank "Отправляет платежные поручения, получает выписки", "HTTPS/API, ГОСТ-шифры"
            rel accountingSystem, nalog "Отправляет электронную отчетность", "HTTPS/API, ФНС-протокол"
            rel accountingSystem, kadry "Синхронизация кадровых данных и начислений", "REST API"
            rel accountingSystem, ldap "Аутентификация пользователей, получение ролей", "LDAPS"
            
            autoLayout lr
        }

        #  VIEW 2: CONTAINER 
        container accountingSystem "Containers" "Контейнерная диаграмма — технологические компоненты системы" {
            include *
            
            # Отношения акторов к клиентам
            rel buhgalter, desktopApp "Использует", "LAN"
            rel sotrudnik, desktopApp "Использует", "LAN"
            rel sotrudnik, mobileApp "Использует", "VPN"
            rel zav_kaf, mobileApp "Утверждает", "VPN"
            rel prezident, mobileApp "Просматривает", "VPN"
            rel auditor, desktopApp "Использует", "LAN"
            
            # Отношения клиентов к API Gateway
            rel desktopApp, apiGateway "HTTPS/mTLS", "REST/JSON"
            rel mobileApp, apiGateway "HTTPS/mTLS", "REST/JSON"
            
            # Отношения API Gateway к бэкенду
            rel apiGateway, backend "gRPC", "Внутренний API"
            rel apiGateway, authService "gRPC", "Проверка токенов"
            
            # Отношения бэкенда к хранилищам
            rel backend, postgresPrimary "SQL", "Основная БД (ACID)"
            rel backend, redis "TCP", "Кэш справочников и сессий"
            rel backend, rabbitmq "AMQP", "Асинхронные задачи"
            
            # Отношения Auth Service
            rel authService, auditDb "SQL (Append-only)", "Журнал аудита"
            rel authService, ldap "LDAPS", "Аутентификация"
            
            # Отношения Document Service
            rel backend, docService "gRPC", "Синхронные вызовы"
            rel docService, rabbitmq "AMQP", "Получает задачи"
            rel docService, minio "S3 API", "Хранение файлов"
            
            # Отношения Notification Service
            rel notificationService, rabbitmq "AMQP", "Получает задачи"
            
            # Репликация БД
            rel postgresPrimary, postgresReplica "Streaming Replication", "Синхронная репликация"
            
            # Внешние интеграции
            rel backend, bank "HTTPS", "API банка"
            rel backend, nalog "HTTPS", "Отчетность"
            rel backend, kadry "REST", "Кадровые данные"
            
            autoLayout lr
        }
    }
}
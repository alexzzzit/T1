workspace {

    model {
        # Акторы
        buhgalter = person "Бухгалтер" "Вводит документы, проводит платежи"
        sotrudnik = person "Сотрудник" "Подает заявки на расходы"
        zav_kaf = person "Зав. кафедрой" "Утверждает заявки удаленно"
        auditor = person "Аудитор ИБ" "Проверяет журналы аудита"

        # Внешние системы
        bank = softwareSystem "Банк-клиент" "Проведение платежей"
        nalog = softwareSystem "ФНС" "Электронная отчетность"
        ldap = softwareSystem "Корпоративный LDAP" "Хранилище учетных записей"

        # Наша система
        accountingSystem = softwareSystem "Бухгалтерская система колледжа" "Учет расходов, workflow, неизменяемый аудит. ФСТЭК." {
            
            # Клиенты
            desktopApp = container "Desktop Client" "Qt/C#" "Основной интерфейс в LAN. Поддержка оффлайн."
            mobileApp = container "Mobile App" "Flutter" "Согласование заявок через VPN."

            # Канал / Точка входа
            apiGateway = container "API Gateway" "NGINX + WAF" "Терминация TLS, Rate Limiting, маршрутизация."

            # Компоненты
            backend = container "Core Backend" "Go/Java" "Модульный монолит: финансы, Workflow Engine."
            authService = container "Auth & Audit" "Go" "Аутентификация (LDAP), запись в неизменяемый журнал."
            docService = container "Document Service" "Go" "Обработка файлов: антивирус, OCR, PDF."

            # Кладовые
            postgresPrimary = container "PostgreSQL Primary" "Postgres Pro" "Основная БД (ACID). Single-Leader."
            postgresReplica = container "PostgreSQL Standby" "Postgres Pro" "Hot Standby для чтения и тяжелых отчетов."
            auditDb = container "Audit Database" "Postgres Pro" "Append-only логи. Партиционирование по датам."
            redis = container "Redis" "Redis" "Кэш справочников и сессий (Cache-aside, LRU)."
            minio = container "MinIO" "S3" "Хранилище сканов и бэкапов."

            # Брокер
            rabbitmq = container "RabbitMQ" "RabbitMQ" "Очередь задач для Document Service."
        }
    }

    views {
        # System Context
        systemContext accountingSystem "SystemContext" "Контекст системы" {
            include *
            rel buhgalter, accountingSystem "Вводит документы", "Desktop, LAN"
            rel sotrudnik, accountingSystem "Подает заявки", "Desktop/Mobile"
            rel zav_kaf, accountingSystem "Утверждает", "Mobile, VPN"
            rel auditor, accountingSystem "Проверяет логи", "Desktop"
            rel accountingSystem, bank "Платежные поручения", "HTTPS/API"
            rel accountingSystem, nalog "Отчетность", "HTTPS/API"
            rel accountingSystem, ldap "Аутентификация", "LDAPS"
            autoLayout lr
        }

        # Container Diagram
        container accountingSystem "Containers" "Технологические компоненты" {
            include *
            
            # Клиенты -> Шлюз
            rel buhgalter, desktopApp "Использует", "LAN"
            rel sotrudnik, mobileApp "Использует", "VPN"
            rel zav_kaf, mobileApp "Утверждает", "VPN"
            rel auditor, desktopApp "Использует", "LAN"
            
            rel desktopApp, apiGateway "HTTPS", "REST/JSON"
            rel mobileApp, apiGateway "HTTPS", "REST/JSON"
            
            # Шлюз -> Бэкенд
            rel apiGateway, backend "gRPC", "Внутренний API"
            rel apiGateway, authService "gRPC", "Проверка токенов"
            
            # Бэкенд -> Хранилища и Брокер
            rel backend, postgresPrimary "SQL", "Основная БД (ACID)"
            rel backend, redis "TCP", "Кэш справочников"
            rel backend, rabbitmq "AMQP", "Асинхронные задачи"
            
            # Аудит и Документы
            rel authService, auditDb "SQL", "Append-only журнал"
            rel authService, ldap "LDAPS", "Аутентификация"
            
            rel backend, docService "gRPC", "Синхронные вызовы"
            rel docService, rabbitmq "AMQP", "Получает задачи"
            rel docService, minio "S3 API", "Хранение файлов"
            
            # Репликация
            rel postgresPrimary, postgresReplica "Streaming Replication", "Синхронная репликация"
            
            autoLayout lr
        }
    }
}


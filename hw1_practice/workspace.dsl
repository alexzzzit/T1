workspace {
    model {
        user = person "Пользователь" "Виртуальный пользователь (k6), создающий и просматривающий заказы"
        
        demoApp = softwareSystem "Demo App 1" "Веб-приложение для управления заказами" {
            
            # Клиент (Модель 4К)
            client = container "HTTP Client" "k6 / Браузер" "Генерирует нагрузку (RPS)"
            
            # Канал (Модель 4К)
            nginx = container "NGINX" "Reverse Proxy / Load Balancer" "Терминация соединений, Rate Limiting, балансировка (алгоритм Leastconn)"
            
            # Компонент (Модель 4К)
            backend = container "Backend API" "Go / Python / Node.js" "Бизнес-логика, обработка POST/GET запросов. Stateless."
            
            # Кладовая (Модель 4К) - Оптимизированная
            db = container "PostgreSQL" "Реляционная БД" "Хранение заказов. Оптимизирован пул коннектов."
            cache = container "Redis" "In-Memory KV" "Sidecar-кэш для GET-запросов (паттерн Cache-aside). Снижает нагрузку на БД."
            queue = container "RabbitMQ" "Message Queue" "Буферизация тяжелых POST-запросов (асинхронная интеграция)."
            worker = container "Background Worker" "Go / Python" "Асинхронно разбирает очередь и пишет в БД с комфортным TPS."
        }
        
        # Отношения
        user -> client "Инициирует запросы" "HTTP/HTTPS"
        client -> nginx "Создает соединения" "HTTP"
        
        nginx -> backend "Проксирует запросы" "HTTP/gRPC (Round Robin / Leastconn)"
        nginx ..> client "Отдает 429 при превышении лимита" "Rate Limiting"
        
        backend -> cache "Читает кэш (GET)" "TCP"
        backend -> db "Пишет/Читает напрямую (если нет в кэше)" "SQL (TCP)"
        backend -> queue "Отправляет задачи на создание заказа" "AMQP (Асинхронно)"
        
        worker -> queue "Забирает задачи" "AMQP"
        worker -> db "Сохраняет заказ в БД" "SQL (TCP)"
    }

    views {
        container demoApp "Containers" "Контейнерная диаграмма Demo App 1 с учетом решений по масштабированию и кэшированию" {
            include *
            autoLayout lr
        }
    }
}
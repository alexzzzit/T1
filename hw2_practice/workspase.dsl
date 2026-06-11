
workspace {
    model {
        app = person "Приложение" "traffic-generator.py, генерирует нагрузку"
        
        haCluster = softwareSystem "PostgreSQL HA Cluster" "Кластер высокой доступности БД" {
            haproxy = container "HAProxy" "L4/L7 Load Balancer" "Маршрутизация RW/RO трафика, проверка health"
            
            patroni1 = container "Patroni Node 1" "PostgreSQL + Patroni" "Участник кластера, может быть Leader или Replica"
            patroni2 = container "Patroni Node 2" "PostgreSQL + Patroni" "Участник кластера, может быть Leader или Replica"
            patroni3 = container "Patroni Node 3" "PostgreSQL + Patroni" "Участник кластера, может быть Leader или Replica"
            
            etcd1 = container "etcd Node 1" "DCS (Raft)" "Хранит Leader Key и состояние кластера"
            etcd2 = container "etcd Node 2" "DCS (Raft)" "Хранит Leader Key и состояние кластера"
            etcd3 = container "etcd Node 3" "DCS (Raft)" "Хранит Leader Key и состояние кластера"
        }
        
        app -> haproxy "SQL запросы" "TCP (порты 5001/5002)"
        
        haproxy -> patroni1 "Проксирование трафика" "TCP"
        haproxy -> patroni2 "Проксирование трафика" "TCP"
        haproxy -> patroni3 "Проксирование трафика" "TCP"
        
        patroni1 -> etcd1 "Leader election, health check" "HTTP (REST API)"
        patroni1 -> etcd2 "Leader election, health check" "HTTP (REST API)"
        patroni1 -> etcd3 "Leader election, health check" "HTTP (REST API)"
        
        patroni2 -> etcd1 "Leader election, health check" "HTTP (REST API)"
        patroni2 -> etcd2 "Leader election, health check" "HTTP (REST API)"
        patroni2 -> etcd3 "Leader election, health check" "HTTP (REST API)"
        
        patroni3 -> etcd1 "Leader election, health check" "HTTP (REST API)"
        patroni3 -> etcd2 "Leader election, health check" "HTTP (REST API)"
        patroni3 -> etcd3 "Leader election, health check" "HTTP (REST API)"
        
        patroni1 -> patroni2 "Streaming Replication" "WAL (Write-Ahead Log)"
        patroni1 -> patroni3 "Streaming Replication" "WAL (Write-Ahead Log)"
    }
    
    views {
        container haCluster "HA_Cluster_Diagram" "Архитектура кластера Patroni + etcd + HAProxy" {
            include *
            autoLayout lr
        }
    }
}
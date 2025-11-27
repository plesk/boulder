# Расширенная конфигурация Consul с продвинутыми настройками DNS
# Этот файл демонстрирует все возможности интеграции Consul с внешним DNS

client_addr = "0.0.0.0"
bind_addr   = "10.77.77.10"
log_level   = "INFO"

# ============================================================================
# DNS RECURSORS - Внешние DNS серверы для запросов вне Consul
# ============================================================================

# Список внешних DNS серверов, на которые Consul будет перенаправлять запросы,
# которые он не может разрешить самостоятельно (не *.consul домены)
recursors = [
  "8.8.8.8",      # Google Public DNS Primary
  "8.8.4.4",      # Google Public DNS Secondary
  "1.1.1.1",      # Cloudflare DNS Primary
  "1.0.0.1"       # Cloudflare DNS Secondary
]

# ============================================================================
# DNS CONFIGURATION - Детальная настройка DNS поведения
# ============================================================================

dns_config {
  # -------------------------------------------------------------------------
  # КЭШИРОВАНИЕ И ПРОИЗВОДИТЕЛЬНОСТЬ
  # -------------------------------------------------------------------------

  # Разрешить использование устаревших (stale) данных из кэша.
  # Это значительно повышает производительность и доступность DNS,
  # позволяя отвечать на запросы даже если leader недоступен.
  allow_stale = true

  # Максимальное время, в течение которого могут использоваться устаревшие данные
  # 87600h = 10 лет (практически безлимитно для dev окружения)
  # Для production рекомендуется: "5m" - "1h"
  max_stale = "87600h"

  # -------------------------------------------------------------------------
  # TTL (TIME TO LIVE) НАСТРОЙКИ
  # -------------------------------------------------------------------------

  # TTL для записей узлов (node records)
  # 0 = без кэширования, клиенты всегда будут запрашивать свежие данные
  # Для production: "30s" - "5m"
  node_ttl = "0s"

  # TTL для записей сервисов - можно настроить индивидуально для каждого сервиса
  service_ttl = {
    # Дефолтное значение для всех сервисов
    "*" = "5s"

    # Критичные сервисы с частыми изменениями - короткий TTL
    "sa" = "3s"
    "ra" = "3s"
    "va" = "3s"

    # Стабильные сервисы - более длинный TTL
    "redis" = "30s"
    "redisratelimits" = "30s"

    # Инфраструктурные сервисы
    "dns" = "60s"
    "consul" = "60s"
  }

  # -------------------------------------------------------------------------
  # RECURSOR НАСТРОЙКИ
  # -------------------------------------------------------------------------

  # Таймаут для запросов к внешним DNS серверам (recursors)
  # Если внешний DNS не отвечает за это время, Consul попробует следующий
  recursor_timeout = "2s"

  # Стратегия выбора recursor из списка:
  # - "sequential" - по порядку (fallback)
  # - "random" - случайный выбор (load balancing)
  recursor_strategy = "random"

  # -------------------------------------------------------------------------
  # ФИЛЬТРАЦИЯ И БЕЗОПАСНОСТЬ
  # -------------------------------------------------------------------------

  # Возвращать только сервисы с passing health checks
  # false - вернет все сервисы, включая failing (полезно для debug)
  # true - только healthy сервисы (для production)
  only_passing = false

  # Включить DNS64 (IPv6 to IPv4 translation) - экспериментально
  # enable_dns64 = false

  # -------------------------------------------------------------------------
  # ОПТИМИЗАЦИЯ РАЗМЕРА ОТВЕТОВ
  # -------------------------------------------------------------------------

  # Включить флаг TC (truncated) в DNS ответах, превышающих размер UDP пакета
  # Клиент должен будет повторить запрос через TCP для получения полного ответа
  enable_truncate = false

  # Максимальное количество записей в UDP ответе (для предотвращения truncation)
  # 0 = без ограничений
  # Для множества инстансов сервиса рекомендуется 3-5
  udp_answer_limit = 3

  # Максимальное количество A/AAAA записей в ответе
  # 0 = без ограничений
  # Ограничение помогает избежать больших UDP пакетов
  a_record_limit = 5

  # Отключить DNS компрессию (обычно не требуется)
  disable_compression = false

  # -------------------------------------------------------------------------
  # ДОПОЛНИТЕЛЬНЫЕ НАСТРОЙКИ
  # -------------------------------------------------------------------------

  # Использовать альтернативный домен вместо .consul
  # domain = "consul"

  # Разрешить PTR запросы для обратного разрешения IP -> имя
  # enable_ptr = true

  # Порядок предпочтения записей в DNS ответах
  # - "name" - алфавитный порядок
  # - "random" - случайный порядок (load balancing)
  # node_meta_txt = ["*"]

  # Использовать RFC 2782 стиль для SRV записей
  # soa {
  #   expire  = 86400
  #   min_ttl = 0
  #   refresh = 3600
  #   retry   = 600
  # }
}

# ============================================================================
# PORTS CONFIGURATION
# ============================================================================

ports {
  # DNS порт - стандартный порт 53
  # Можно использовать альтернативный порт, например 8600 (по умолчанию для Consul)
  dns      = 53

  # HTTP API порт
  http     = 8500

  # gRPC порт с TLS
  grpc_tls = 8503

  # Serf LAN порт (для communication между агентами)
  # serf_lan = 8301

  # Serf WAN порт (для communication между datacenters)
  # serf_wan = 8302

  # Server RPC порт
  # server   = 8300
}

# ============================================================================
# TLS CONFIGURATION
# ============================================================================

# Использовать TLS для health checks (требуется для Boulder)
enable_agent_tls_for_checks = true

tls {
  defaults {
    ca_file         = "test/certs/ipki/minica.pem"
    ca_path         = "test/certs/ipki/minica-key.pem"
    cert_file       = "test/certs/ipki/consul.boulder/cert.pem"
    key_file        = "test/certs/ipki/consul.boulder/key.pem"
    verify_incoming = false
    verify_outgoing = true

    # Минимальная версия TLS
    tls_min_version = "TLSv1_2"

    # Разрешенные cipher suites
    # tls_cipher_suites = "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
  }
}

# ============================================================================
# UI CONFIGURATION
# ============================================================================

ui_config {
  enabled = true

  # Дополнительные метрики в UI
  metrics_provider = "prometheus"
  # metrics_proxy {
  #   base_url = "http://prometheus:9090"
  # }
}

# ============================================================================
# PERFORMANCE TUNING
# ============================================================================

performance {
  # Количество одновременных RPC запросов
  # raft_multiplier = 1

  # Настройки для DNS
  # leave_drain_time = "5s"
  # rpc_hold_timeout = "7s"
}

# ============================================================================
# TELEMETRY
# ============================================================================

telemetry {
  # Отключить hostname prefix в метриках
  disable_hostname = false

  # Prometheus метрики
  prometheus_retention_time = "60s"

  # Dogstatsd
  # dogstatsd_addr = "localhost:8125"
  # dogstatsd_tags = ["environment:dev"]

  # Statsd
  # statsd_address = "localhost:8125"
}

# ============================================================================
# LOGGING
# ============================================================================

# Уровень логирования: TRACE, DEBUG, INFO, WARN, ERROR
log_level = "INFO"

# Формат логов: "standard" или "json"
# log_json = false

# Файл для логов (опционально)
# log_file = "/var/log/consul/consul.log"

# Ротация логов
# log_rotate_duration = "24h"
# log_rotate_max_files = 7

# ============================================================================
# SERVICES CONFIGURATION
# ============================================================================

# Примеры сервисов с health checks и DNS-specific настройками

services {
  id      = "sa-a"
  name    = "sa"
  address = "10.77.77.77"
  port    = 9395
  tags    = ["tcp", "primary", "datacenter-1"]

  # Метаданные для фильтрации и routing
  meta = {
    version = "v1"
    region  = "us-west"
  }

  # Health checks с разными методами
  checks = [
    {
      id              = "sa-a-grpc"
      name            = "sa-a-grpc"
      grpc            = "10.77.77.77:9395"
      grpc_use_tls    = true
      tls_server_name = "sa.boulder"
      tls_skip_verify = false
      interval        = "10s"
      timeout         = "5s"
    },
    {
      id              = "sa-a-grpc-sa"
      name            = "sa-a-grpc-sa"
      grpc            = "10.77.77.77:9395/sa.StorageAuthority"
      grpc_use_tls    = true
      tls_server_name = "sa.boulder"
      tls_skip_verify = false
      interval        = "10s"
      timeout         = "5s"
    }
  ]

  # DNS-specific TTL для этого конкретного инстанса
  # service_ttl = "5s"
}

# ============================================================================
# ДОПОЛНИТЕЛЬНЫЕ ОПЦИИ
# ============================================================================

# Datacenter имя (по умолчанию: dc1)
# datacenter = "dc1"

# Node имя (по умолчанию: hostname)
# node_name = "consul-server-1"

# Включить локальный script checks (security risk!)
# enable_local_script_checks = false

# Включить удаленные script checks через HTTP API (security risk!)
# enable_script_checks = false

# Автоматически покинуть кластер при остановке
# leave_on_terminate = true

# Rejoin кластер после рестарта
# rejoin_after_leave = true

# Disable update check
# disable_update_check = true

# ============================================================================
# ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ
# ============================================================================

# После применения этой конфигурации:
#
# 1. Запросы Consul сервисов (автоматическое разрешение):
#    dig @10.77.77.10 sa.service.consul
#    dig @10.77.77.10 -t SRV _sa._tcp.service.consul
#
# 2. Запросы внешних доменов (через recursors):
#    dig @10.77.77.10 google.com
#    dig @10.77.77.10 -t MX gmail.com
#
# 3. Фильтрация по тегам:
#    dig @10.77.77.10 primary.sa.service.consul
#
# 4. Проверка конфигурации:
#    consul validate /test/consul/config-advanced-dns.hcl
#    curl http://10.77.77.10:8500/v1/agent/self | jq .DebugConfig.DNSRecursors
#
# 5. Мониторинг DNS метрик:
#    curl http://10.77.77.10:8500/v1/agent/metrics?format=prometheus

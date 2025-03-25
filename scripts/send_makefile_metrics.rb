#!/usr/bin/env ruby
require 'net/http'
require 'uri'

# Метрики из Makefile
metrics_data = <<-EOF
# HELP test_metric Тестовая метрика для демонстрации
# TYPE test_metric gauge
test_metric{service="api",endpoint="/users"} 42
test_metric{service="api",endpoint="/orders"} 53
test_metric{service="api",endpoint="/products"} 76

# HELP api_response_time Время ответа API в миллисекундах
# TYPE api_response_time gauge
api_response_time{service="api",endpoint="/users"} 120
api_response_time{service="api",endpoint="/orders"} 350
api_response_time{service="api",endpoint="/products"} 240

# HELP api_request_count Количество запросов к API
# TYPE api_request_count counter
api_request_count{service="api",endpoint="/users"} 2435
api_request_count{service="api",endpoint="/orders"} 1578
api_request_count{service="api",endpoint="/products"} 4291

# HELP api_errors_count Количество ошибок API
# TYPE api_errors_count counter
api_errors_count{service="api",endpoint="/users"} 23
api_errors_count{service="api",endpoint="/orders"} 45
api_errors_count{service="api",endpoint="/products"} 12

# HELP database_connections Количество активных подключений к базе данных
# TYPE database_connections gauge
database_connections{database="users"} 15
database_connections{database="products"} 8
database_connections{database="orders"} 12
EOF

# Отправляем данные в Pushgateway
def push_to_gateway(data)
  uri = URI.parse('http://localhost:9091/metrics/job/test_job')
  request = Net::HTTP::Post.new(uri)
  request.body = data
  request["Content-Type"] = "text/plain"
  
  response = Net::HTTP.start(uri.hostname, uri.port) do |http|
    http.request(request)
  end
  
  if response.code.to_i >= 200 && response.code.to_i < 300
    puts "Metrics successfully pushed to gateway!"
  else
    puts "Failed to push metrics. Response: #{response.code} #{response.message}"
    puts response.body
  end
end

# Выполняем отправку
push_to_gateway(metrics_data) 
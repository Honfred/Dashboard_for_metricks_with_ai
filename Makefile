.PHONY: start stop build rebuild restart restart-web restart-sidekiq generate-test-data

start:
	docker compose up -d

stop:
	docker compose down

build:
	docker compose build

rebuild: down build up

restart:
	docker compose restart

restart-web:
	docker compose restart web

restart-sidekiq:
	docker compose restart sidekiq

generate-test-data:
	docker compose exec web rails runner 'MetricsGenerator.generate_test_data'
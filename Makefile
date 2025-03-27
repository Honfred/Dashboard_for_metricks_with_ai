.PHONY: start stop build rebuild restart restart-web restart-sidekiq generate-test-data setup-db chown

start:
	docker compose up -d

stop:
	docker compose down

build:
	docker compose build

rebuild: stop build start

restart:
	docker compose restart

restart-web:
	docker compose restart web

restart-sidekiq:
	docker compose restart sidekiq

setup-db:
	docker compose exec web rails db:migrate

generate-test-data: setup-db
	docker compose exec web rails runner 'MetricsGenerator.generate_test_data'

chown:
	sudo chown -R $$(whoami) ./*
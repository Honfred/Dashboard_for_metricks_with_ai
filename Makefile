.PHONY: start stop build rebuild restart restart-web restart-sidekiq

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
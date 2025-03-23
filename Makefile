build:
	docker compose build --no-cache

start:
	docker compose up -d

stop:
	docker compose down

restart: stop start

docker:
	docker compose run --rm web ash

c:
	docker compose run --rm web rails c

chown:
	sudo chown -R $$(whoami) ./*
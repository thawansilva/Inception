COMPOSE_FILE=srcs/docker-compose.yml

all: up

up:
	docker compose -f $(COMPOSE_FILE) up -d

down:
	docker compose -f $(COMPOSE_FILE) down

clean: down
	docker volume prune -a -f

fclean: clean
	docker image prune -a -f

re: fclean all

.PHONY: all down clean fclean re

.PHONY: help setup start stop test cluster-check logs
# Makefile for Nexus Poncho: The Distributed Financial Monolith

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Install deps and setup infrastructure (First time only)
	docker compose up -d postgres
	sleep 10
	# event_store.create is intentionally omitted: ledger_dev is created by Docker (POSTGRES_DB),
	# and the event_store schema is pre-seeded by infra/postgres/init.sql. Running
	# event_store.create would fail — the ledger user lacks CREATEDB privilege.
	docker compose run --rm node1 sh -c "cd nexus && mix deps.get && mix do event_store.init, ecto.create, ecto.migrate"
	docker compose run --rm web sh -c "cd nexus_web && mix deps.get"
	docker compose up -d

start: ## Start the entire distributed cluster
	docker compose up -d

stop: ## Stop all services
	docker compose down

logs: ## Tail all container logs
	docker compose logs -f

cluster-check: ## Verify distributed node connectivity (The Batteries Check)
	@docker exec nexus_poncho-web-1 iex --name tester@$$(hostname -i | awk '{print $$1}') --cookie nexus --eval "IO.inspect(Node.list())"

test: ## Run all tests across the soul and web layers
	docker compose run --rm node1 sh -c "cd nexus && mix test"
	docker compose run --rm web sh -c "cd nexus_web && mix test"

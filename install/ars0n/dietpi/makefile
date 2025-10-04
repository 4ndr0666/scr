# ==============================================================================
# Ars0n Sentinel - Makefile v2.0
# A simple Makefile for managing the ars0n-framework Docker stack.
# Assumes execution from the framework directory (/opt/ars0n-framework).
# ==============================================================================

.PHONY: up down logs ps clean restart

# Build and start all services in detached mode
up:
	@echo "Bringing up the Ars0n Sentinel stack in detached mode..."
	docker compose up -d --build

# Stop and remove all services
down:
	@echo "Taking down the Ars0n Sentinel stack..."
	docker compose down

# Follow live logs from all services
logs:
	@echo "Following live logs for all services... (Press CTRL+C to exit)"
	docker compose logs -f

# List the status of all running services
ps:
	@echo "Checking status of Ars0n Sentinel containers..."
	docker compose ps

# Restart all services in the stack
restart: down up

# Prune unused Docker resources to save space
clean:
	@echo "Cleaning up unused Docker resources (containers, networks, images)..."
	docker system prune -af

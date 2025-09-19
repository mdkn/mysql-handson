# MySQL Query Tuning Training Environment
# Make-based Docker setup for hands-on MySQL learning

# Colors for better output
RED    := \033[31m
GREEN  := \033[32m
YELLOW := \033[33m
BLUE   := \033[34m
RESET  := \033[0m

# Docker configuration
CONTAINER_NAME := mysql-training
DB_NAME := training_db
DB_USER := trainee
DB_PASS := traineepass
ROOT_PASS := rootpassword

.PHONY: help setup connect connect-root logs slow-logs general-logs status stop clean restart

# Default target
help: ## Show this help message
	@echo "$(BLUE)MySQL Query Tuning Training Environment$(RESET)"
	@echo "$(YELLOW)Available commands:$(RESET)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(RESET) %s\n", $$1, $$2}'

setup: ## Start MySQL container and initialize database
	@echo "$(BLUE)Setting up MySQL training environment...$(RESET)"
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "$(RED)✗ Docker is not installed or not in PATH$(RESET)"; \
		exit 1; \
	elif ! docker info >/dev/null 2>&1; then \
		echo "$(RED)✗ Docker daemon is not running$(RESET)"; \
		echo "$(YELLOW)Please start Docker first$(RESET)"; \
		exit 1; \
	fi
	@mkdir -p logs
	@docker-compose up -d
	@echo "$(YELLOW)Waiting for MySQL to be ready...$(RESET)"
	@while ! docker exec $(CONTAINER_NAME) mysqladmin ping -h localhost --silent; do \
		echo "$(YELLOW).$(RESET)"; \
		sleep 2; \
	done
	@echo ""
	@echo "$(GREEN)✓ MySQL is ready!$(RESET)"
	@echo "$(BLUE)Database: $(DB_NAME)$(RESET)"
	@echo "$(BLUE)User: $(DB_USER) / Password: $(DB_PASS)$(RESET)"
	@echo "$(BLUE)Root Password: $(ROOT_PASS)$(RESET)"
	@echo ""
	@echo "$(YELLOW)Use 'make connect' to start learning!$(RESET)"

connect: ## Connect to MySQL as trainee user
	@if ! docker ps | grep -q $(CONTAINER_NAME); then \
		echo "$(RED)MySQL container is not running. Run 'make setup' first.$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Connecting to MySQL as $(DB_USER)...$(RESET)"
	@docker exec -it $(CONTAINER_NAME) mysql -u$(DB_USER) -p$(DB_PASS) $(DB_NAME)

connect-root: ## Connect to MySQL as root user
	@if ! docker ps | grep -q $(CONTAINER_NAME); then \
		echo "$(RED)MySQL container is not running. Run 'make setup' first.$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Connecting to MySQL as root...$(RESET)"
	@docker exec -it $(CONTAINER_NAME) mysql -uroot -p$(ROOT_PASS)

logs: ## View MySQL container logs
	@echo "$(BLUE)MySQL container logs:$(RESET)"
	@docker logs $(CONTAINER_NAME) --tail=50 -f

slow-logs: ## View slow query logs
	@if ! docker ps | grep -q $(CONTAINER_NAME); then \
		echo "$(RED)MySQL container is not running.$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Slow query logs:$(RESET)"
	@if [ -f ./logs/slow.log ]; then \
		tail -f ./logs/slow.log; \
	else \
		echo "$(YELLOW)No slow query log found yet. Generate some slow queries first!$(RESET)"; \
	fi

general-logs: ## View general query logs
	@if ! docker ps | grep -q $(CONTAINER_NAME); then \
		echo "$(RED)MySQL container is not running.$(RESET)"; \
		exit 1; \
	fi
	@echo "$(BLUE)General query logs:$(RESET)"
	@if [ -f ./logs/general.log ]; then \
		tail -f ./logs/general.log; \
	else \
		echo "$(YELLOW)No general log found yet.$(RESET)"; \
	fi

status: ## Check MySQL container status
	@echo "$(BLUE)Container status:$(RESET)"
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "$(RED)✗ Docker is not installed or not in PATH$(RESET)"; \
		exit 1; \
	elif ! docker info >/dev/null 2>&1; then \
		echo "$(RED)✗ Docker daemon is not running$(RESET)"; \
		echo "$(YELLOW)Please start Docker first$(RESET)"; \
		exit 1; \
	elif docker ps 2>/dev/null | grep -q $(CONTAINER_NAME); then \
		echo "$(GREEN)✓ MySQL container is running$(RESET)"; \
		docker ps | grep $(CONTAINER_NAME); \
		echo ""; \
		echo "$(BLUE)MySQL process status:$(RESET)"; \
		docker exec $(CONTAINER_NAME) mysqladmin -uroot -p$(ROOT_PASS) status; \
	elif docker ps -a 2>/dev/null | grep -q $(CONTAINER_NAME); then \
		echo "$(YELLOW)⚠ MySQL container exists but is not running$(RESET)"; \
		echo "$(YELLOW)Run 'make setup' to start it$(RESET)"; \
	else \
		echo "$(RED)✗ MySQL container does not exist$(RESET)"; \
		echo "$(YELLOW)Run 'make setup' to create and start it$(RESET)"; \
	fi

stop: ## Stop MySQL container
	@echo "$(YELLOW)Stopping MySQL container...$(RESET)"
	@docker-compose stop
	@echo "$(GREEN)✓ MySQL container stopped$(RESET)"

clean: ## Stop and remove container and volumes
	@echo "$(RED)Cleaning up MySQL environment...$(RESET)"
	@docker-compose down -v
	@echo "$(GREEN)✓ All containers and volumes removed$(RESET)"
	@echo "$(YELLOW)Run 'make setup' to recreate the environment$(RESET)"

restart: ## Restart MySQL container
	@echo "$(YELLOW)Restarting MySQL container...$(RESET)"
	@docker-compose restart
	@echo "$(YELLOW)Waiting for MySQL to be ready...$(RESET)"
	@while ! docker exec $(CONTAINER_NAME) mysqladmin ping -h localhost --silent; do \
		echo "$(YELLOW).$(RESET)"; \
		sleep 2; \
	done
	@echo ""
	@echo "$(GREEN)✓ MySQL restarted and ready!$(RESET)"

# Quick access commands
shell: ## Open bash shell in MySQL container
	@docker exec -it $(CONTAINER_NAME) bash

ps: ## Show running containers
	@docker ps | grep -E "(CONTAINER|mysql)"

# Development helpers
test-connection: ## Test database connection
	@echo "$(BLUE)Testing database connection...$(RESET)"
	@docker exec $(CONTAINER_NAME) mysql -u$(DB_USER) -p$(DB_PASS) -e "SELECT 'Connection successful!' as status, NOW() as timestamp;" $(DB_NAME)

show-tables: ## Show all tables in training database
	@echo "$(BLUE)Tables in $(DB_NAME):$(RESET)"
	@docker exec $(CONTAINER_NAME) mysql -u$(DB_USER) -p$(DB_PASS) -e "SHOW TABLES;" $(DB_NAME)

sample-query: ## Run a sample query to generate some activity
	@echo "$(BLUE)Running sample queries...$(RESET)"
	@docker exec $(CONTAINER_NAME) mysql -u$(DB_USER) -p$(DB_PASS) -e "\
		SELECT 'Sample query executed' as message; \
		SELECT COUNT(*) as user_count FROM users; \
		SELECT COUNT(*) as product_count FROM products; \
		SELECT COUNT(*) as order_count FROM orders;" $(DB_NAME)
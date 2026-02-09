.PHONY: help install build up down logs clean build-image push-ecr login-ecr

# Configuration
AWS_REGION ?= us-west-2
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text)
ECR_REPO ?= quantmove-uptime-production
IMAGE_TAG ?= latest
IMAGE_NAME = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(ECR_REPO):$(IMAGE_TAG)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# =============================================================================
# Local Development
# =============================================================================

install: ## Install dependencies
	npm install

build: ## Build frontend (creates dist/)
	npm run build

up: install build ## Start local development with Docker Compose
	docker compose -f docker-compose.local.yml up --build

up-detach: build ## Start local development in background
	docker compose -f docker-compose.local.yml up --build -d

down: ## Stop local development
	docker compose -f docker-compose.local.yml down

logs: ## View container logs
	docker compose -f docker-compose.local.yml logs -f

clean: ## Clean dist and node_modules
	rm -rf dist node_modules

# =============================================================================
# Docker Image
# =============================================================================

build-image: build ## Build Docker image for production (linux/amd64)
	docker build -f docker/dockerfile --platform linux/amd64 --target release -t $(ECR_REPO):$(IMAGE_TAG) .

build-image-local: build ## Build Docker image with local tag
	docker build -f docker/dockerfile --target release -t $(ECR_REPO):local .

# =============================================================================
# AWS ECR
# =============================================================================

login-ecr: ## Login to AWS ECR
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

push-ecr: build-image login-ecr ## Build and push image to ECR
	docker tag $(ECR_REPO):$(IMAGE_TAG) $(IMAGE_NAME)
	docker push $(IMAGE_NAME)
	@echo "Pushed: $(IMAGE_NAME)"

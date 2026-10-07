IMAGE_NAME = terraform
TAG        = latest
PLATFORM   = linux/amd64

# 圧縮率を上げるために gzip で圧縮する
FILE_NAME  = $(IMAGE_NAME)-$(TAG).tar.gz

.PHONY: build save load clean

all:
	@$(MAKE) build
	@$(MAKE) save

build:
	@echo "Building $(IMAGE_NAME):$(TAG)..."
	docker build --pull --platform $(PLATFORM) -t $(IMAGE_NAME):$(TAG) .

save:
	@echo "Saving $(IMAGE_NAME):$(TAG)..."
	docker save $(IMAGE_NAME):$(TAG) | gzip > $(FILE_NAME)

load:
	@echo "Loading $(FILE_NAME)..."
	docker load -i $(FILE_NAME)

clean:
	@echo "Cleaning up..."
	@rm -f $(FILE_NAME)

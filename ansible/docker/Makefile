IMAGE_NAME = ansible
TAG        = latest
PLATFORM   = linux/amd64

# 圧縮率を上げるために gzip で圧縮する
FILE_NAME  = $(IMAGE_NAME)-$(TAG).tar.gz

.PHONY: build save load clean

build:
	@echo "Building $(IMAGE_NAME):$(TAG)..."
	podman build --platform $(PLATFORM) -f Dockerfile -t $(IMAGE_NAME):$(TAG) ..

save:
	@echo "Saving $(IMAGE_NAME):$(TAG)..."
	podman save $(IMAGE_NAME):$(TAG) | gzip > $(FILE_NAME)

load:
	@echo "Loading $(FILE_NAME)..."
	podman load -i $(FILE_NAME)

all:
	@$(MAKE) build
	@$(MAKE) save

clean:
	@echo "Cleaning up..."
	@rm -f $(FILE_NAME)

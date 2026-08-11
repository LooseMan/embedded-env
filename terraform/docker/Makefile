IMAGE_NAME = terraform
TAG        = latest

# デフォルトのターゲット名（空にしておけば指定なしで全体ビルド）
TARGET     = terraform

# 圧縮率を上げるために gzip で圧縮する
FILE_NAME  = $(IMAGE_NAME)_$(TARGET)_$(TAG).tar.gz

.PHONY: build save load clean

all:
	@$(MAKE) build
	@$(MAKE) save

build:
	@echo "Building $(IMAGE_NAME):$(TAG) $(if $(TARGET),with target $(TARGET))..."
	podman build $(if $(TARGET),--target $(TARGET)) -t $(IMAGE_NAME):$(TAG) .

save:
	@echo "Saving $(IMAGE_NAME):$(TAG)..."
	podman save $(IMAGE_NAME):$(TAG) | gzip > $(FILE_NAME)

load:
	@echo "Loading $(FILE_NAME)..."
	podman load -i $(FILE_NAME)

clean:
	@echo "Cleaning up..."
	@rm -f $(FILE_NAME)

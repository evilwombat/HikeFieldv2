APP_NAME := HikeFieldv2
TARGET := venu3

BIN_DIR  = bin/$(TARGET)
OUT_FILE = $(BIN_DIR)/$(APP_NAME).prg
REL_FILE = $(BIN_DIR)/$(TARGET)/$(APP_NAME)-release.prg
SDK_PATH := $$(cat $$HOME/.Garmin/ConnectIQ/current-sdk.cfg)
DEV_KEY = ~/garmin/developer_key
SIM_TEMP_DIR := /tmp/com.garmin.connectiq/GARMIN/Settings/
SIM_SETTINGS_FILE := $(SIM_TEMP_DIR)/$$(echo $(APP_NAME) | tr [:lower:] [:upper:])-settings.json

JUNGLE_FILE = monkey.jungle
JAVA_OPTIONS = -Xms1g -Dfile.encoding=UTF-8 -Dapple.awt.UIElement=true

SOURCES = source/HikeField.mc \
		  source/SunCalc.mc \
		  source/SunCalcEnum.mc \
		  resources/resources.xml \
		  constants \
		  Makefile \
		  monkey.jungle

.PHONY: all install run release sim clean

all: $(OUT_FILE)

release: $(REL_FILE)

$(OUT_FILE): $(SOURCES)
	$(SDK_PATH)/bin/monkeyc -o $(OUT_FILE) -f $(JUNGLE_FILE) -y $(DEV_KEY) -d $(TARGET)_sim -w -r

run: $(OUT_FILE)
	cp $(BIN_DIR)/$(APP_NAME)-settings.json $(SIM_SETTINGS_FILE)
	$(SDK_PATH)/bin/monkeydo $(OUT_FILE) $(TARGET)

$(REL_FILE): $(SOURCES)
	$(SDK_PATH)/bin/monkeyc -o $(REL_FILE) -f $(JUNGLE_FILE) -y $(DEV_KEY) -d $(TARGET) -w -r

sim:
	$(SDK_PATH)/bin/connectiq

clean:
	rm -rf bin/

install: $(REL_FILE)
	gio copy $(REL_FILE) $$(gio mount -l | grep -o 'mtp://[^ ]*' | head -n 1)Internal\ Storage/GARMIN/Apps

format:
	clang-format-10 -i source/HikeField.mc

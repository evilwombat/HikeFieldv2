APP_NAME := HikeFieldv2

OUT_FILE = bin/$(APP_NAME).prg
REL_FILE = bin/$(APP_NAME)-release-venu3.prg
SDK_PATH := $$(cat $$HOME/.Garmin/ConnectIQ/current-sdk.cfg)
DEV_KEY = ~/garmin/developer_key
SIM_TEMP_DIR := /tmp/com.garmin.connectiq/GARMIN/Settings/
SIM_SETTINGS_FILE := $(SIM_TEMP_DIR)/$$(echo $(APP_NAME) | tr [:lower:] [:upper:])-settings.json

JUNGLE_FILE = monkey.jungle
JAVA_OPTIONS = -Xms1g -Dfile.encoding=UTF-8 -Dapple.awt.UIElement=true
TARGET = venu3

SOURCES = source/HikeField.mc \
		  source/SunCalc.mc \
		  source/SunCalcEnum.mc \
		  resources/resources.xml \
		  resources/strings.xml

.PHONY: all install run release sim clean

all: $(OUT_FILE)

release: $(REL_FILE)

$(OUT_FILE): $(SOURCES)
	$(SDK_PATH)/bin/monkeyc -o $(OUT_FILE) -f $(JUNGLE_FILE) -y $(DEV_KEY) -d $(TARGET)_sim -w

run: $(OUT_FILE)
	cp bin/$(APP_NAME)-settings.json $(SIM_SETTINGS_FILE)
	$(SDK_PATH)/bin/monkeydo $(OUT_FILE) venu3

$(REL_FILE): $(SOURCES)
	$(SDK_PATH)/bin/monkeyc -o $(REL_FILE) -f $(JUNGLE_FILE) -y $(DEV_KEY) -d $(TARGET) -w -r

sim:
	$(SDK_PATH)/bin/connectiq

clean:
	rm -f $(OUT_FILE) $(REL_FILE)

install: $(REL_FILE)
	gio copy $(REL_FILE) $$(gio mount -l | grep -o 'mtp://[^ ]*' | head -n 1)Internal\ Storage/GARMIN/Apps

format:
	clang-format-10 -i source/HikeField.mc

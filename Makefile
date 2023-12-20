OUT_FILE = bin/HikeField.prg
REL_FILE = bin/HikeField-release-venu3.prg

SDK_PATH := $$(cat $$HOME/.Garmin/ConnectIQ/current-sdk.cfg)
DEV_KEY = ~/garmin/developer_key

JUNGLE_FILE = monkey.jungle
JAVA_OPTIONS = -Xms1g -Dfile.encoding=UTF-8 -Dapple.awt.UIElement=true
TARGET = venu3

SOURCES = source/HikeField.mc resources/resources.xml resources/strings.xml

.PHONY: all install run release sim clean

all: $(OUT_FILE)

release: $(REL_FILE)

$(OUT_FILE): $(SOURCES)
	$(SDK_PATH)/bin/monkeyc -o $(OUT_FILE) -f $(JUNGLE_FILE) -y $(DEV_KEY) -d $(TARGET)_sim -w

run: $(OUT_FILE)
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

OUT_FILE = bin/HikeField.prg
REL_FILE = bin/HikeField-release-venu3.prg

SDK_PATH = ~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-6.4.1-2023-11-27-6cafd260d
DEV_KEY = ~/garmin/developer_key

JUNGLE_FILE = monkey.jungle
JAVA_OPTIONS = -Xms1g -Dfile.encoding=UTF-8 -Dapple.awt.UIElement=true
TARGET = venu3

SOURCES = source/HikeField.mc resources/resources.xml resources/strings.xml

.PHONY: all install run release sim clean

all: $(OUT_FILE)

release: $(REL_FILE)

$(OUT_FILE): $(SOURCES)
	java $(JAVA_OPTIONS) -jar $(SDK_PATH)/bin/monkeybrains.jar -o $(OUT_FILE) -f $(JUNGLE_FILE) -y $(DEV_KEY) -d $(TARGET)_sim -w

run: $(OUT_FILE)
	$(SDK_PATH)/bin/monkeydo $(OUT_FILE) venu3


$(REL_FILE): $(SOURCES)
	java $(JAVA_OPTIONS) -jar $(SDK_PATH)/bin/monkeybrains.jar -o $(REL_FILE) -f $(JUNGLE_FILE) -y $(DEV_KEY) -d $(TARGET) -w -r

sim:
	$(SDK_PATH)/bin/simulator

clean:
	rm -f $(OUT_FILE) $(REL_FILE)

install: $(REL_FILE)
	gio copy $(REL_FILE) $$(gio mount -l | grep -o 'mtp://[^ ]*' | head -n 1)Internal\ Storage/GARMIN/Apps
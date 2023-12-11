OUT_FILE = bin/HikeField.prg
JUNGLE_FILE = monkey.jungle
SDK_PATH = ~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-6.4.1-2023-11-27-6cafd260d
DEV_KEY = ~/garmin/developer_key
TARGET = venu3_sim

SOURCES = source/HikeField.mc resources/resources.xml resources/strings.xml

.PHONY: all build run sim clean

all: build

build: $(OUT_FILE)

$(OUT_FILE): $(SOURCES)
	java -Xms1g -Dfile.encoding=UTF-8 -Dapple.awt.UIElement=true -jar $(SDK_PATH)/bin/monkeybrains.jar -o $(OUT_FILE) -f $(JUNGLE_FILE) -y $(DEV_KEY) -d $(TARGET) -w

run: $(OUT_FILE)
	$(SDK_PATH)/bin/monkeydo $(OUT_FILE) venu3

sim:
	$(SDK_PATH)/bin/simulator

clean:
	rm -f $(OUT_FILE)
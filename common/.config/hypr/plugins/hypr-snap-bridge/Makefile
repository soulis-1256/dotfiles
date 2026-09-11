CXX ?= g++
CXXFLAGS ?= -shared -fPIC --std=c++26 -O2
INCLUDES = $(shell pkg-config --cflags hyprland)
TARGET = hypr-snap-bridge-v3.so
INSTALL_DIR = $(HOME)/.local/lib/hyprland

all: $(TARGET)

$(TARGET): main.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) $< -o $@

install: $(TARGET)
	mkdir -p $(INSTALL_DIR)
	install -m 755 $(TARGET) $(INSTALL_DIR)/$(TARGET)

clean:
	rm -f $(TARGET)

.PHONY: all install clean

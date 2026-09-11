# Else exist specifically for clang
ifeq ($(CXX),g++)
    EXTRA_FLAGS = --no-gnu-unique
else
    EXTRA_FLAGS =
endif

CXXFLAGS ?= -O2
CXXFLAGS += -shared -fPIC -std=c++2b -Wno-c++11-narrowing
INCLUDES = `pkg-config --cflags pixman-1 libdrm hyprland libinput libudev wayland-server xkbcommon fontconfig pangocairo`
LIBS = `pkg-config --libs fontconfig pangocairo`

SRC = main.cpp barDeco.cpp BarPassElement.cpp
TARGET = hyprbars.so

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $(EXTRA_FLAGS) $(INCLUDES) $^ $> -o $@ $(LIBS)

install: $(TARGET)
	mkdir -p $(HOME)/.local/lib/hyprland
	install -m 755 $(TARGET) $(HOME)/.local/lib/hyprland/$(TARGET)

clean:
	rm -f ./$(TARGET)

meson-build:
	mkdir -p build
	cd build && meson .. && ninja

.PHONY: all install meson-build clean

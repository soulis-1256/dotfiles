#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/managers/EventManager.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/target/Target.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/pointer/PointerManager.hpp>
#include <hyprland/src/layout/supplementary/DragController.hpp>
#include <hyprland/src/managers/KeybindManager.hpp>
#include <format>
#include <algorithm>

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

static HANDLE PHANDLE = nullptr;
static bool wasDragging = false;
static Vector2D dragStartMousePos = {0, 0};
static Vector2D dragStartWinPos = {0, 0};
static Vector2D dragStartWinSize = {0, 0};
static Vector2D dragGrabOffset = {0, 0};
static bool dragGrabReady = false;
static bool dragReanchored = false;
static CHyprSignalListener mouseMoveListener;
static CHyprSignalListener mouseButtonListener;
static CHyprSignalListener windowActiveListener;

// Proportional X: grab 30% from the left of a maxed window stays 30% from
// the left after restore. Y is the original titlebar offset (can be negative
// when grabbing a hyprbar above the window).
static double followGrabX(double grabX, double oldW, double newW) {
    if (newW <= 1.0)
        return 0.0;
    double ratio = (oldW > 1.0) ? (grabX / oldW) : 0.5;
    ratio = std::clamp(ratio, 0.05, 0.95);
    return newW * ratio;
}

static void captureDragGrab(SP<Layout::ITarget> target, const Vector2D& mouse) {
    if (!target)
        return;
    dragStartWinPos = target->position().pos();
    dragStartWinSize = target->position().size();
    dragStartMousePos = mouse;
    dragGrabOffset = Vector2D{mouse.x - dragStartWinPos.x, mouse.y - dragStartWinPos.y};
    dragGrabReady = true;
    dragReanchored = false;
}

void checkDragState(const Vector2D* mousePos = nullptr) {
    if (!g_layoutManager)
        return;
    const auto& drag = g_layoutManager->dragController();
    bool isDragging = drag && drag->mode() == MBIND_MOVE;
    if (isDragging) {
        auto target = drag->target();
        if (!target) {
            isDragging = false;
        } else {
            auto win = target->window();
            if (!win || !win->m_isFloating || drag->draggingTiled() || target->wasTiling()) {
                isDragging = false;
            }
        }
    }
    if (isDragging != wasDragging) {
        wasDragging = isDragging;
        if (isDragging) {
            std::string addr = "";
            auto target = drag->target();
            if (target) {
                auto win = target->window();
                if (win)
                    addr = std::format("0x{:x}", (uintptr_t)win.get());
                Vector2D mouse = {0, 0};
                if (mousePos)
                    mouse = *mousePos;
                else if (g_pInputManager)
                    mouse = g_pInputManager->getMouseCoordsInternal();
                captureDragGrab(target, mouse);
            }
            g_pEventManager->postEvent(SHyprIPCEvent{"dragstart", addr});
        } else {
            dragGrabReady = false;
            g_pEventManager->postEvent(SHyprIPCEvent{"dragstop", ""});
        }
    }
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    mouseMoveListener = Event::bus()->m_events.input.mouse.move.listen([](Vector2D pos, Event::SCallbackInfo& info) {
        checkDragState(&pos);
        if (wasDragging && g_layoutManager) {
            const auto& drag = g_layoutManager->dragController();
            if (drag) {
                auto target = drag->target();
                if (target) {
                    if (!dragGrabReady)
                        captureDragGrab(target, pos);
                    if (!dragReanchored) {
                        Vector2D curSize = target->position().size();
                        if (curSize.x > 0 && dragStartWinSize.x > 0 &&
                            (std::abs(curSize.x - dragStartWinSize.x) > 50 || std::abs(curSize.y - dragStartWinSize.y) > 50)) {
                            dragReanchored = true;
                            double newX = pos.x - followGrabX(dragGrabOffset.x, dragStartWinSize.x, curSize.x);
                            double newY = pos.y - dragGrabOffset.y;
                            CBox newBox{newX, newY, curSize.x, curSize.y};
                            g_layoutManager->setTargetGeom(newBox, target);
                            target->warpPositionSize();
                            target->recalc();

                            drag->dragEnd();
                            drag->dragBegin(target, MBIND_MOVE);
                        }
                    }
                }
            }
            g_pEventManager->postEvent(SHyprIPCEvent{"dragpos", std::format("{},{}", (int)pos.x, (int)pos.y)});
        }
    });

    mouseButtonListener = Event::bus()->m_events.input.mouse.button.listen([](const IPointer::SButtonEvent& e, Event::SCallbackInfo& info) {
        if (e.state == WL_POINTER_BUTTON_STATE_RELEASED) {
            if (wasDragging) {
                wasDragging = false;
                g_pEventManager->postEvent(SHyprIPCEvent{"dragstop", ""});
            }
            if (g_pKeybindManager && g_layoutManager) {
                const auto& drag = g_layoutManager->dragController();
                if (drag && drag->mode() == MBIND_MOVE) {
                    g_pKeybindManager->changeMouseBindMode(MBIND_INVALID);
                }
            }
        } else {
            checkDragState(nullptr);
        }
    });

    windowActiveListener = Event::bus()->m_events.window.active.listen([](PHLWINDOW win, Desktop::eFocusReason reason) {
        if (win && win->m_isFloating && g_layoutManager && win->m_target) {
            g_layoutManager->bringTargetToTop(win->m_target);
        }
    });

    return {"hypr-snap-bridge", "Drag event bridge for snap layouts", "soulis", "1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    mouseMoveListener.reset();
    mouseButtonListener.reset();
    windowActiveListener.reset();
}

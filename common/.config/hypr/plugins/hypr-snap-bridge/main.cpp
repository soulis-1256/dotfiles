#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/managers/EventManager.hpp>
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
static double dragClickRatio = 0.5;
static bool dragReanchored = false;
static CHyprSignalListener mouseMoveListener;
static CHyprSignalListener mouseButtonListener;
static CHyprSignalListener windowActiveListener;

void checkDragState() {
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
                dragStartWinPos = target->position().pos();
                dragStartWinSize = target->position().size();
                dragStartMousePos = {0, 0};
                dragClickRatio = 0.5;
                dragReanchored = false;
            }
            g_pEventManager->postEvent(SHyprIPCEvent{"dragstart", addr});
        } else {
            g_pEventManager->postEvent(SHyprIPCEvent{"dragstop", ""});
        }
    }
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    mouseMoveListener = Event::bus()->m_events.input.mouse.move.listen([](Vector2D pos, Event::SCallbackInfo& info) {
        checkDragState();
        if (wasDragging && g_layoutManager) {
            const auto& drag = g_layoutManager->dragController();
            if (drag) {
                auto target = drag->target();
                if (target) {
                    if (dragStartMousePos.x == 0 && dragStartMousePos.y == 0) {
                        dragStartMousePos = pos;
                        if (dragStartWinSize.x > 0)
                            dragClickRatio = std::clamp((pos.x - dragStartWinPos.x) / dragStartWinSize.x, 0.05, 0.95);
                    }
                    if (!dragReanchored) {
                        Vector2D curSize = target->position().size();
                        if (curSize.x > 0 && dragStartWinSize.x > 0 && std::abs(curSize.x - dragStartWinSize.x) > 50) {
                            dragReanchored = true;
                            double newX = pos.x - (curSize.x * dragClickRatio);
                            double newY = std::max(10.0, pos.y - 18.0);
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
            checkDragState();
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

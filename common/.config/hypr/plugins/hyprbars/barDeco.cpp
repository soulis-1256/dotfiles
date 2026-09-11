#include "barDeco.hpp"

#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/state/LayerState.hpp>
#include <hyprland/src/desktop/state/ViewHitTester.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/desktop/view/LayerSurface.hpp>
#include <hyprland/src/helpers/MiscFunctions.hpp>
#include <hyprland/src/managers/SeatManager.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/render/Renderer.hpp>
#include <hyprland/src/config/ConfigManager.hpp>
#include <hyprland/src/config/ConfigValue.hpp>
#include <hyprland/src/config/shared/animation/AnimationTree.hpp>
#include <hyprland/src/config/shared/parserUtils/ParserUtils.hpp>
#include <hyprland/src/config/supplementary/executor/Executor.hpp>
#include <hyprland/src/config/shared/actions/ConfigActions.hpp>
#include <hyprland/src/animation/AnimationManager.hpp>
#include <hyprland/src/protocols/LayerShell.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/pointer/cursor/CursorShapeOverrideController.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/config/lua/ConfigManager.hpp>
#include <hyprland/src/render/OpenGL.hpp>
#include <hyprland/src/state/MonitorState.hpp>

#include "globals.hpp"
#include "BarPassElement.hpp"

#include <climits>

using namespace Render::GL;

static CHyprColor configColor(Config::INTEGER color) {
    return CHyprColor{static_cast<uint64_t>(color)};
}

CHyprBar::CHyprBar(PHLWINDOW pWindow) : IHyprWindowDecoration(pWindow) {
    m_pWindow = pWindow;

    const auto PMONITOR         = pWindow->m_monitor.lock();
    PMONITOR->m_scheduledRecalc = true;

    // button events
    m_pMouseButtonCallback = Event::bus()->m_events.input.mouse.button.listen([&](IPointer::SButtonEvent e, Event::SCallbackInfo& info) { onMouseButton(info, e); });
    m_pTouchDownCallback   = Event::bus()->m_events.input.touch.down.listen([&](ITouch::SDownEvent e, Event::SCallbackInfo& info) { onTouchDown(info, e); });
    m_pTouchUpCallback     = Event::bus()->m_events.input.touch.up.listen([&](ITouch::SUpEvent e, Event::SCallbackInfo& info) { onTouchUp(info, e); });

    // move events
    m_pTouchMoveCallback = Event::bus()->m_events.input.touch.motion.listen([&](ITouch::SMotionEvent e, Event::SCallbackInfo& info) { onTouchMove(info, e); });
    m_pMouseMoveCallback = Event::bus()->m_events.input.mouse.move.listen([&](Vector2D c, Event::SCallbackInfo& info) { onMouseMove(c); });

    Animation::mgr()->createAnimation(configColor(g_pGlobalState->config.barColor->value()), m_cRealBarColor, Config::animationTree()->getAnimationPropertyConfig("border"),
                                      pWindow, AVARDAMAGE_NONE);
    m_cRealBarColor->setUpdateCallback([&](auto) { damageEntire(); });
}

CHyprBar::~CHyprBar() {
    if (m_bBorderHoverActive) {
        Pointer::Cursor::overrideController->unsetOverride(Pointer::Cursor::CURSOR_OVERRIDE_SPECIAL_ACTION);
        m_bBorderHoverActive = false;
    }
    std::erase(g_pGlobalState->bars, m_self);
}

SDecorationPositioningInfo CHyprBar::getPositioningInfo() {
    const auto                 HEIGHT     = g_pGlobalState->config.barHeight->value();
    const auto                 ENABLED    = g_pGlobalState->config.enabled->value();
    const auto                 PRECEDENCE = g_pGlobalState->config.barPrecedenceOverBorder->value();

    SDecorationPositioningInfo info;
    info.policy         = m_hidden ? DECORATION_POSITION_ABSOLUTE : DECORATION_POSITION_STICKY;
    info.edges          = DECORATION_EDGE_TOP;
    info.priority       = PRECEDENCE ? 10005 : 5000;
    info.reserved       = true;
    info.desiredExtents = {{0, m_hidden || !ENABLED ? 0 : HEIGHT}, {0, 0}};
    return info;
}

void CHyprBar::onPositioningReply(const SDecorationPositioningReply& reply) {
    if (reply.assignedGeometry.size() != m_bAssignedBox.size())
        m_bWindowSizeChanged = true;

    m_bAssignedBox = reply.assignedGeometry;
}

std::string CHyprBar::getDisplayName() {
    return "Hyprbar";
}

bool CHyprBar::inputIsValid() {
    if (m_hidden)
        return false;

    if (g_pSeatManager->m_seatGrab && !g_pSeatManager->m_seatGrab->accepts(m_pWindow->wlSurface()->resource()))
        return false;

    const auto MOUSE    = g_pInputManager->getMouseCoordsInternal();
    auto       PMONITOR = Desktop::focusState()->monitor();

    if (!PMONITOR)
        return false;

    Desktop::CViewHitTester hitTester{*Desktop::viewState()};

    const auto              WINDOWATCURSOR = hitTester.windowAt(MOUSE, Desktop::View::RESERVED_EXTENTS | Desktop::View::INPUT_EXTENTS | Desktop::View::ALLOW_FLOATING);

    auto                    focusState = Desktop::focusState();
    auto                    window     = focusState->window();

    if (WINDOWATCURSOR != m_pWindow && m_pWindow != window)
        return false;

    PHLLS    foundSurface = nullptr;
    Vector2D surfaceCoords;

    // Check Top Layer
    hitTester.layerSurfaceAt(MOUSE, &PMONITOR->m_layerSurfaceLayers[ZWLR_LAYER_SHELL_V1_LAYER_TOP], &surfaceCoords, &foundSurface);
    if (foundSurface)
        return false;

    // Check Overlay Layer
    hitTester.layerSurfaceAt(MOUSE, &PMONITOR->m_layerSurfaceLayers[ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY], &surfaceCoords, &foundSurface);
    if (foundSurface)
        return false;

    return true;
}

void CHyprBar::onMouseButton(Event::SCallbackInfo& info, IPointer::SButtonEvent e) {
    if (!inputIsValid())
        return;

    if (e.state != WL_POINTER_BUTTON_STATE_PRESSED) {
        handleUpEvent(info);
        return;
    }

    handleDownEvent(info, std::nullopt);
}

void CHyprBar::onTouchDown(Event::SCallbackInfo& info, ITouch::SDownEvent e) {
    // Don't do anything if you're already grabbed a window with another finger
    if (!inputIsValid() || e.touchID != 0)
        return;

    handleDownEvent(info, e);
}

void CHyprBar::onTouchUp(Event::SCallbackInfo& info, ITouch::SUpEvent e) {
    if (!m_bDragPending || !m_bTouchEv || e.touchID != m_touchId)
        return;

    handleUpEvent(info);
}

bool CHyprBar::isOverButton(const Vector2D& COORDS) {
    const auto barHeight        = g_pGlobalState->config.barHeight->value();
    const auto barPadding       = g_pGlobalState->config.barPadding->value();
    const auto barButtonPadding = g_pGlobalState->config.barButtonPadding->value();
    const auto alignButtons     = g_pGlobalState->config.barButtonsAlignment->value();
    const bool buttonsRight     = alignButtons != "left";
    const auto barW             = assignedBoxGlobal().w;

    float offset = barPadding;
    for (auto& b : g_pGlobalState->buttons) {
        const float bWidth  = (b.width > 0) ? b.width : b.size;
        const float bHeight = (b.height > 0) ? b.height : (b.width > 0 ? (float)barHeight : b.size);
        const auto  BARBUF  = Vector2D{(int)barW, (int)barHeight};
        Vector2D    currentPos =
            Vector2D{(buttonsRight ? BARBUF.x - barButtonPadding - bWidth - offset : offset), (BARBUF.y - bHeight) / 2.0}.floor();

        if (VECINRECT(COORDS, currentPos.x, currentPos.y, currentPos.x + bWidth, currentPos.y + bHeight))
            return true;

        offset += barButtonPadding + bWidth;
    }
    return false;
}

bool CHyprBar::isWindowMaximized() {
    if (!validMapped(m_pWindow))
        return false;
    const auto PWIN = m_pWindow.lock();
    if (!PWIN)
        return false;

    if (Fullscreen::controller()->isFullscreen(PWIN))
        return true;

    if (PWIN->m_isFloating && PWIN->getRealBorderSize() <= 0)
        return true;

    const auto PMONITOR = PWIN->m_monitor.lock();
    if (PMONITOR) {
        const auto WINPOS  = PWIN->position(Desktop::View::IGeometric::GEOMETRIC_GOAL);
        const auto WINSIZE = PWIN->size(Desktop::View::IGeometric::GEOMETRIC_GOAL);
        const auto monBox  = PMONITOR->logicalBox();
        if (std::abs(WINPOS.x - monBox.x) <= 4 && std::abs(WINSIZE.x - monBox.w) <= 4) {
            if (std::abs(WINPOS.y - monBox.y) <= 35)
                return true;
        }
    }

    return false;
}

void CHyprBar::toggleMaximize() {
    const auto PWIN = m_pWindow.lock();
    if (!PWIN)
        return;

    Desktop::focusState()->fullWindowFocus(PWIN, Desktop::FOCUS_REASON_CLICK);

    if (Config::mgr()->type() == Config::CONFIG_LUA) {
        auto luaMgr = dynamicPointerCast<Config::Lua::CConfigManager>(WP<Config::IConfigManager>(Config::mgr()));
        if (luaMgr) {
            std::string code = std::format(
                "if _G.win11_toggle_maximize then "
                "    _G.win11_toggle_maximize('0x{:x}') "
                "else "
                "    hl.dispatch(hl.dsp.window.fullscreen({{ mode = 'maximized', action = 'toggle' }})) "
                "end",
                (uintptr_t)PWIN.get());
            luaMgr->eval(code);
            return;
        }
    }

    g_pKeybindManager->m_dispatchers["fullscreen"]("1");
}

std::optional<Layout::eRectCorner> CHyprBar::getResizeCorner(const Vector2D& mouseCoords) {
    if (!validMapped(m_pWindow) || m_hidden)
        return std::nullopt;

    const auto PWIN = m_pWindow.lock();
    if (!PWIN)
        return std::nullopt;

    if (isWindowMaximized())
        return std::nullopt;

    static auto PRESIZEONBORDER   = CConfigValue<Config::INTEGER>("general:resize_on_border");
    static auto PBORDERSIZE       = CConfigValue<Config::INTEGER>("general:border_size");
    static auto PBORDERGRABEXTEND = CConfigValue<Config::INTEGER>("general:extend_border_grab_area");

    if (!*PRESIZEONBORDER)
        return std::nullopt;

    const int BORDERSIZE   = PWIN->getRealBorderSize();
    if (BORDERSIZE <= 0)
        return std::nullopt;

    const int GRAB_EXTEND  = *PBORDERGRABEXTEND;
    const int BORDER_GRAB  = BORDERSIZE + GRAB_EXTEND;
    const int ROUNDING     = PWIN->rounding();
    const int CORNER       = std::max(ROUNDING + BORDERSIZE + 10, 20);
    const int HEIGHT       = g_pGlobalState->config.barHeight->value();

    const CBox barBox = assignedBoxGlobal();
    if (barBox.w <= 0 || barBox.h <= 0)
        return std::nullopt;

    const Vector2D COORDS   = mouseCoords - barBox.pos();
    const int      TOP_ZONE = std::max((int)BORDERSIZE, 4);

    // Outside the extended grab zone around the bar
    if (COORDS.x < -BORDER_GRAB || COORDS.x > barBox.w + BORDER_GRAB ||
        COORDS.y < -BORDER_GRAB || COORDS.y > HEIGHT + BORDER_GRAB)
        return std::nullopt;

    // Caption button priority: if within bar height and below TOP_ZONE, buttons take precedence
    if (COORDS.y >= TOP_ZONE && COORDS.y < HEIGHT && COORDS.x >= 0 && COORDS.x <= barBox.w) {
        if (isOverButton(COORDS))
            return std::nullopt;
    }

    // Top edge & top corners (above the bar in the grab area and along the top border strip)
    if (COORDS.y < TOP_ZONE) {
        if (COORDS.x < CORNER)
            return Layout::CORNER_TOPLEFT;
        if (COORDS.x > barBox.w - CORNER)
            return Layout::CORNER_TOPRIGHT;
        return Layout::CORNER_TOP;
    }

    // Left edge of the bar
    if (COORDS.x < TOP_ZONE) {
        if (COORDS.y < CORNER)
            return Layout::CORNER_TOPLEFT;
        return Layout::CORNER_LEFT;
    }

    // Right edge of the bar
    if (COORDS.x > barBox.w - TOP_ZONE) {
        if (COORDS.y < CORNER)
            return Layout::CORNER_TOPRIGHT;
        return Layout::CORNER_RIGHT;
    }

    return std::nullopt;
}

void CHyprBar::onMouseMove(Vector2D coords) {
    // ensure proper redraws of button icons on hover when using hardware cursors
    if (g_pGlobalState->config.iconOnHover->value())
        damageOnButtonHover();

    if (m_bDragPending && !m_bTouchEv && validMapped(m_pWindow) && m_touchId == 0) {
        m_bDragPending = false;
        handleMovement();
        return;
    }

    if (!validMapped(m_pWindow) || isWindowMaximized()) {
        if (m_bBorderHoverActive) {
            Pointer::Cursor::overrideController->unsetOverride(Pointer::Cursor::CURSOR_OVERRIDE_SPECIAL_ACTION);
            m_szCurrentCursorOverride.clear();
            m_bBorderHoverActive = false;
        }
        return;
    }

    // If an active drag / resize operation is running, don't interfere with the active drag cursor
    if (g_layoutManager && g_layoutManager->dragController() && g_layoutManager->dragController()->target()) {
        if (m_bBorderHoverActive) {
            Pointer::Cursor::overrideController->unsetOverride(Pointer::Cursor::CURSOR_OVERRIDE_SPECIAL_ACTION);
            m_szCurrentCursorOverride.clear();
            m_bBorderHoverActive = false;
        }
        return;
    }

    // Hit test: only the window under cursor should display border hover
    Desktop::CViewHitTester hitTester{*Desktop::viewState()};
    const auto              WINDOWATCURSOR = hitTester.windowAt(coords, Desktop::View::RESERVED_EXTENTS | Desktop::View::INPUT_EXTENTS | Desktop::View::ALLOW_FLOATING);

    if (WINDOWATCURSOR != m_pWindow) {
        if (m_bBorderHoverActive) {
            Pointer::Cursor::overrideController->unsetOverride(Pointer::Cursor::CURSOR_OVERRIDE_SPECIAL_ACTION);
            m_szCurrentCursorOverride.clear();
            m_bBorderHoverActive = false;
        }
        return;
    }

    const auto resizeCorner = getResizeCorner(coords);
    if (resizeCorner.has_value()) {
        static auto PHOVERICON = CConfigValue<Config::INTEGER>("general:hover_icon_on_border");
        if (*PHOVERICON) {
            std::string shape = "top_side";
            if (*resizeCorner == Layout::CORNER_TOPLEFT)
                shape = "top_left_corner";
            else if (*resizeCorner == Layout::CORNER_TOPRIGHT)
                shape = "top_right_corner";
            else if (*resizeCorner == Layout::CORNER_LEFT)
                shape = "left_side";
            else if (*resizeCorner == Layout::CORNER_RIGHT)
                shape = "right_side";

            if (m_szCurrentCursorOverride != shape) {
                Pointer::Cursor::overrideController->setOverride(shape, Pointer::Cursor::CURSOR_OVERRIDE_SPECIAL_ACTION);
                m_szCurrentCursorOverride = shape;
            }
            m_bBorderHoverActive = true;
        }
    } else if (m_bBorderHoverActive) {
        Pointer::Cursor::overrideController->unsetOverride(Pointer::Cursor::CURSOR_OVERRIDE_SPECIAL_ACTION);
        m_szCurrentCursorOverride.clear();
        m_bBorderHoverActive = false;
    }
}

void CHyprBar::onTouchMove(Event::SCallbackInfo& info, ITouch::SMotionEvent e) {
    if (!m_bDragPending || !m_bTouchEv || !validMapped(m_pWindow) || e.touchID != m_touchId)
        return;

    auto PMONITOR     = m_pWindow->m_monitor.lock();
    PMONITOR          = PMONITOR ? PMONITOR : Desktop::focusState()->monitor();
    const auto COORDS = Vector2D(PMONITOR->m_position.x + e.pos.x * PMONITOR->m_size.x, PMONITOR->m_position.y + e.pos.y * PMONITOR->m_size.y);

    if (!m_bDraggingThis) {
        // Initial setup for dragging a window.
        g_pKeybindManager->m_dispatchers["setfloating"]("activewindow");
        g_pKeybindManager->m_dispatchers["resizewindowpixel"]("exact 50% 50%,activewindow");
        // pin it so you can change workspaces while dragging a window
        g_pKeybindManager->m_dispatchers["pin"]("activewindow");
    }
    g_pKeybindManager->m_dispatchers["movewindowpixel"](std::format("exact {} {},activewindow", (int)(COORDS.x - (assignedBoxGlobal().w / 2)), (int)COORDS.y));
    m_bDraggingThis = true;
}

void CHyprBar::handleDownEvent(Event::SCallbackInfo& info, std::optional<ITouch::SDownEvent> touchEvent) {
    m_bTouchEv = touchEvent.has_value();
    if (m_bTouchEv)
        m_touchId = touchEvent.value().touchID;

    const auto PWINDOW = m_pWindow.lock();
    if (!PWINDOW)
        return;

    // Check border resize first (mouse only, not touch)
    if (!m_bTouchEv) {
        const auto mousePos     = g_pInputManager->getMouseCoordsInternal();
        const auto resizeCorner = getResizeCorner(mousePos);
        if (resizeCorner.has_value()) {
            if (Desktop::focusState()->window() != PWINDOW)
                Desktop::focusState()->fullWindowFocus(PWINDOW, Desktop::FOCUS_REASON_CLICK);

            if (PWINDOW->m_isFloating)
                Desktop::windowState()->raise(PWINDOW);

            info.cancelled   = true;
            m_bCancelledDown = true;
            m_bResizingThis  = true;
            m_bDragPending   = false;
            m_bDraggingThis  = false;

            g_layoutManager->beginDragTarget(PWINDOW->layoutTarget(), MBIND_RESIZE, *resizeCorner);
            Log::logger->log(Log::DEBUG, "[hyprbars] Border resize initiated on {:x} with corner {}", (uintptr_t)PWINDOW.get(), (int)*resizeCorner);
            return;
        }
    }

    auto COORDS = cursorRelativeToBar();
    if (m_bTouchEv) {
        ITouch::SDownEvent e        = touchEvent.value();
        PHLMONITOR         PMONITOR = nullptr;
        for (auto& m : State::monitorState()->monitors()) {
            if (m->m_name == (!e.device->m_boundOutput.empty() ? e.device->m_boundOutput : "")) {
                PMONITOR = m;
                break;
            }
        }
        PMONITOR = PMONITOR ? PMONITOR : Desktop::focusState()->monitor();
        COORDS   = Vector2D(PMONITOR->m_position.x + e.pos.x * PMONITOR->m_size.x, PMONITOR->m_position.y + e.pos.y * PMONITOR->m_size.y) - assignedBoxGlobal().pos();
    }

    const auto HEIGHT           = g_pGlobalState->config.barHeight->value();
    const auto BARBUTTONPADDING = g_pGlobalState->config.barButtonPadding->value();
    const auto BARPADDING       = g_pGlobalState->config.barPadding->value();
    const auto ALIGNBUTTONS     = g_pGlobalState->config.barButtonsAlignment->value();
    const auto ON_DOUBLE_CLICK  = g_pGlobalState->config.onDoubleClick->value();

    const bool BUTTONSRIGHT = ALIGNBUTTONS != "left";

    if (!VECINRECT(COORDS, 0, 0, assignedBoxGlobal().w, HEIGHT - 1)) {

        if (m_bDraggingThis) {
            if (m_bTouchEv)
                g_pKeybindManager->m_dispatchers["settiled"]("activewindow");
            g_pKeybindManager->m_dispatchers["mouse"]("0movewindow");
            Log::logger->log(Log::DEBUG, "[hyprbars] Dragging ended on {:x}", (uintptr_t)PWINDOW.get());
        }

        m_bDraggingThis = false;
        m_bDragPending  = false;
        m_bTouchEv      = false;
        return;
    }

    if (Desktop::focusState()->window() != PWINDOW)
        Desktop::focusState()->fullWindowFocus(PWINDOW, Desktop::FOCUS_REASON_CLICK);

    if (PWINDOW->m_isFloating)
        Desktop::windowState()->raise(PWINDOW);

    info.cancelled   = true;
    m_bCancelledDown = true;

    if (doButtonPress(BARPADDING, BARBUTTONPADDING, HEIGHT, COORDS, BUTTONSRIGHT))
        return;

    if (!ON_DOUBLE_CLICK.empty() &&
        std::chrono::duration_cast<std::chrono::milliseconds>(Time::steadyNow() - m_lastMouseDown).count() < 400 /* Arbitrary delay I found suitable */) {
        if (ON_DOUBLE_CLICK == "hyprctl dispatch fullscreen 1" || ON_DOUBLE_CLICK == "fullscreen 1" || ON_DOUBLE_CLICK == "maximize") {
            toggleMaximize();
        } else {
            Config::Supplementary::executor()->spawn(ON_DOUBLE_CLICK);
        }
        m_bDragPending = false;
    } else {
        m_lastMouseDown = Time::steadyNow();
        m_bDragPending  = true;
    }
}

void CHyprBar::handleUpEvent(Event::SCallbackInfo& info) {
    if (m_bResizingThis) {
        g_layoutManager->endDragTarget();
        m_bResizingThis = false;
        if (m_bBorderHoverActive) {
            Pointer::Cursor::overrideController->unsetOverride(Pointer::Cursor::CURSOR_OVERRIDE_SPECIAL_ACTION);
            m_szCurrentCursorOverride.clear();
            m_bBorderHoverActive = false;
        }
        Log::logger->log(Log::DEBUG, "[hyprbars] Border resize ended on {:x}", (uintptr_t)m_pWindow.lock().get());
    }

    if (m_bDraggingThis) {
        g_pKeybindManager->changeMouseBindMode(MBIND_INVALID);
        m_bDraggingThis = false;
        if (m_bTouchEv)
            (void)Config::Actions::floatWindow(Config::Actions::eTogglableAction::TOGGLE_ACTION_DISABLE);

        Log::logger->log(Log::DEBUG, "[hyprbars] Dragging ended on {:x}", (uintptr_t)m_pWindow.lock().get());
    }

    if (m_bCancelledDown)
        info.cancelled = true;

    m_bCancelledDown = false;
    m_bDragPending = false;
    m_bTouchEv     = false;
    m_touchId      = 0;
}

void CHyprBar::handleMovement() {
    g_pKeybindManager->changeMouseBindMode(MBIND_MOVE);
    m_bDraggingThis = true;
    Log::logger->log(Log::DEBUG, "[hyprbars] Dragging initiated on {:x}", (uintptr_t)m_pWindow.lock().get());
    return;
}

bool CHyprBar::doButtonPress(Config::INTEGER barPadding, Config::INTEGER barButtonPadding, Config::INTEGER barHeight, Vector2D COORDS, const bool BUTTONSRIGHT) {
    float offset = barPadding;
    const auto PWIN = m_pWindow.lock();

    for (auto& b : g_pGlobalState->buttons) {
        const float bWidth = (b.width > 0) ? b.width : b.size;
        const float bHeight = (b.height > 0) ? b.height : (b.width > 0 ? (float)barHeight : b.size);
        const auto BARBUF     = Vector2D{(int)assignedBoxGlobal().w, (int)barHeight};
        Vector2D   currentPos = Vector2D{(BUTTONSRIGHT ? BARBUF.x - barButtonPadding - bWidth - offset : offset), (BARBUF.y - bHeight) / 2.0}.floor();

        if (VECINRECT(COORDS, currentPos.x, currentPos.y, currentPos.x + bWidth, currentPos.y + bHeight)) {
            if (b.cmd == "close" || b.cmd.find("killactive") != std::string::npos || b.cmd.find("close") != std::string::npos) {
                if (PWIN)
                    PWIN->sendClose();
                return true;
            }

            if (b.cmd == "fullscreen" || b.cmd == "maximize" || b.cmd.find("fullscreen") != std::string::npos) {
                toggleMaximize();
                return true;
            }

            if (b.cmd == "togglefloating" || b.cmd == "minimize" || b.cmd.find("togglefloating") != std::string::npos) {
                if (PWIN) {
                    Desktop::focusState()->fullWindowFocus(PWIN, Desktop::FOCUS_REASON_CLICK);
                    g_pKeybindManager->m_dispatchers["togglefloating"]("");
                }
                return true;
            }

            if (g_pKeybindManager->m_dispatchers.contains(b.cmd))
                g_pKeybindManager->m_dispatchers[b.cmd]("");
            else
                Config::Supplementary::executor()->spawn(b.cmd);
            return true;
        }

        offset += barButtonPadding + bWidth;
    }
    return false;
}

void CHyprBar::renderBarTitle(const Vector2D& bufferSize, const float scale) {
    const auto COLORVAL         = g_pGlobalState->config.textColor->value();
    const auto SIZE             = g_pGlobalState->config.barTextSize->value();
    const auto WEIGHT           = g_pGlobalState->config.barTextWeight->value();
    const auto FONT             = g_pGlobalState->config.barTextFont->value();
    const auto ALIGN            = g_pGlobalState->config.barTextAlign->value();
    const auto BARPADDING       = g_pGlobalState->config.barPadding->value();
    const auto BARBUTTONPADDING = g_pGlobalState->config.barButtonPadding->value();

    float      buttonSizes = BARBUTTONPADDING;
    for (auto& b : g_pGlobalState->buttons) {
        const float bWidth = (b.width > 0) ? b.width : b.size;
        buttonSizes += bWidth + BARBUTTONPADDING;
    }

    const auto TITLEPADDING     = g_pGlobalState->config.barTitlePadding->value();
    const auto effectiveTitlePad = (TITLEPADDING >= 0 ? TITLEPADDING : (BARPADDING > 0 ? BARPADDING : 14));
    const int  scaledSize        = std::round(SIZE * scale);
    const auto scaledButtonsSize = buttonSizes * scale;
    const auto scaledBarPadding  = BARPADDING * scale;
    const auto scaledTitlePadding= effectiveTitlePad * scale;
    const int  paddingTotal      = scaledTitlePadding + scaledBarPadding + scaledButtonsSize + (ALIGN != "left" ? scaledButtonsSize : 0);
    const int  maxWidth          = std::clamp(static_cast<int>(bufferSize.x - paddingTotal), 0, INT_MAX);

    if (m_szLastTitle.empty() || maxWidth < 1) {
        m_pTextTex = nullptr;
        return;
    }

    const CHyprColor COLOR = m_bForcedTitleColor.value_or(configColor(COLORVAL));
    m_pTextTex             = g_pHyprRenderer->renderText(m_szLastTitle, COLOR, scaledSize, false, FONT, maxWidth, WEIGHT.m_value);
}

size_t CHyprBar::getVisibleButtonCount(Config::INTEGER barButtonPadding, Config::INTEGER barPadding, const Vector2D& bufferSize, const float scale) {
    float  availableSpace = bufferSize.x - barPadding * scale * 2;
    size_t count          = 0;

    for (const auto& button : g_pGlobalState->buttons) {
        const float bWidth = (button.width > 0) ? button.width : button.size;
        const float buttonSpace = (bWidth + barButtonPadding) * scale;
        if (availableSpace >= buttonSpace) {
            count++;
            availableSpace -= buttonSpace;
        } else
            break;
    }

    return count;
}

void CHyprBar::renderBarButtons(CBox* barBox, const float scale, const float a) {
    const auto BARBUTTONPADDING = g_pGlobalState->config.barButtonPadding->value();
    const auto BARPADDING       = g_pGlobalState->config.barPadding->value();
    const auto ALIGNBUTTONS     = g_pGlobalState->config.barButtonsAlignment->value();
    const auto INACTIVECOLOR    = g_pGlobalState->config.inactiveButtonColor->value();

    const bool BUTTONSRIGHT    = ALIGNBUTTONS != "left";
    const auto visibleCount    = getVisibleButtonCount(BARBUTTONPADDING, BARPADDING, Vector2D{barBox->w, barBox->h}, scale);
    const bool INVALIDATEICONS = m_bButtonsDirty || m_bWindowSizeChanged;

    int        offset = BARPADDING * scale;
    for (size_t i = 0; i < visibleCount; ++i) {
        auto&      button           = g_pGlobalState->buttons[i];
        const float bWidth          = ((button.width > 0) ? button.width : button.size) * scale;
        const float bHeight         = ((button.height > 0) ? button.height : (button.width > 0 ? (barBox->h / scale) : button.size)) * scale;
        const auto scaledButtonsPad = BARBUTTONPADDING * scale;

        auto color = button.bgcol;
        bool hovered = (m_iButtonHoverState & (1 << i)) != 0;

        if (button.bgcol.a <= 0.01f) {
            if (hovered) {
                if (i == 0 || button.cmd.find("killactive") != std::string::npos)
                    color = CHyprColor(0.91f, 0.07f, 0.14f, 0.95f);
                else
                    color = CHyprColor(1.0f, 1.0f, 1.0f, 0.14f);
            } else {
                color = CHyprColor(0.0f, 0.0f, 0.0f, 0.0f);
            }
        } else if (hovered) {
            color.r = std::min(1.0f, static_cast<float>(color.r * 1.3f + 0.1f));
            color.g = std::min(1.0f, static_cast<float>(color.g * 1.3f + 0.1f));
            color.b = std::min(1.0f, static_cast<float>(color.b * 1.3f + 0.1f));
        } else if (INACTIVECOLOR > 0) {
            color = m_bWindowHasFocus ? color : configColor(INACTIVECOLOR);
            if (INVALIDATEICONS && button.userfg && button.iconTex)
                button.iconTex = nullptr;
        }

        color.a *= a;

        CBox buttonBox = {barBox->x + (BUTTONSRIGHT ? barBox->w - offset - bWidth : offset), barBox->y + (barBox->h - bHeight) / 2.0, bWidth,
                          bHeight};
        buttonBox.round();

        int roundRadius = 0;
        if (button.round >= 0) {
            roundRadius = (button.round >= 50) ? static_cast<int>(std::round(std::min(bWidth, bHeight) / 2.0)) :
                                                 static_cast<int>(std::round(button.round * scale));
        } else if (button.width > 0) {
            roundRadius = 0;
        } else if (button.bgcol.a <= 0.01f) {
            roundRadius = static_cast<int>(std::round(4 * scale));
        } else {
            roundRadius = static_cast<int>(std::round(std::min(bWidth, bHeight) / 2.0));
        }

        g_pHyprOpenGL->renderRect(buttonBox, color, {.round = roundRadius, .roundingPower = 2.F});

        offset += scaledButtonsPad + bWidth;
    }
}

void CHyprBar::renderBarButtonsText(CBox* barBox, const float scale, const float a) {
    const auto HEIGHT           = g_pGlobalState->config.barHeight->value();
    const auto BARBUTTONPADDING = g_pGlobalState->config.barButtonPadding->value();
    const auto BARPADDING       = g_pGlobalState->config.barPadding->value();
    const auto ALIGNBUTTONS     = g_pGlobalState->config.barButtonsAlignment->value();
    const auto ICONONHOVER      = g_pGlobalState->config.iconOnHover->value();

    const bool BUTTONSRIGHT = ALIGNBUTTONS != "left";
    const auto visibleCount = getVisibleButtonCount(BARBUTTONPADDING, BARPADDING, Vector2D{barBox->w, barBox->h}, scale);
    const auto COORDS       = cursorRelativeToBar();

    int        offset        = BARPADDING * scale;
    float      noScaleOffset = BARPADDING;

    for (size_t i = 0; i < visibleCount; ++i) {
        auto&      button           = g_pGlobalState->buttons[i];
        const float bWidth          = ((button.width > 0) ? button.width : button.size) * scale;
        const float bHeight         = ((button.height > 0) ? button.height : (button.width > 0 ? (barBox->h / scale) : button.size)) * scale;
        const auto scaledButtonsPad = BARBUTTONPADDING * scale;

        const auto BARBUF        = Vector2D{(int)assignedBoxGlobal().w, (int)HEIGHT};
        const float noScaleWidth = (button.width > 0) ? button.width : button.size;
        const float noScaleHeight= (button.height > 0) ? button.height : (button.width > 0 ? (float)HEIGHT : button.size);
        Vector2D   currentPos    = Vector2D{(BUTTONSRIGHT ? BARBUF.x - BARBUTTONPADDING - noScaleWidth - noScaleOffset : noScaleOffset), (BARBUF.y - noScaleHeight) / 2.0}.floor();
        bool       hovering      = VECINRECT(COORDS, currentPos.x, currentPos.y, currentPos.x + noScaleWidth, currentPos.y + noScaleHeight);
        noScaleOffset += BARBUTTONPADDING + noScaleWidth;

        if ((!button.iconTex || button.iconTex->m_texID == 0) && !button.icon.empty()) {
            auto fgcol = button.userfg ? button.fgcol : (button.bgcol.r + button.bgcol.g + button.bgcol.b < 1) ? CHyprColor(0xFFFFFFFF) : CHyprColor(0xFF000000);

            const std::string fontName = button.font.empty() ? "lucide" : button.font;
            const int targetFontSize = (button.icon_size > 0) ?
                std::round(button.icon_size * scale) :
                std::round(std::max(14.0f, button.size * 0.9f) * scale);

            button.iconTex = g_pHyprRenderer->renderText(button.icon, fgcol, targetFontSize, false, fontName, 0);
        }

        if (!button.iconTex || button.iconTex->m_texID == 0)
            continue;

        const double btnCenterX = barBox->x + (BUTTONSRIGHT ? barBox->width - offset - bWidth / 2.0 : offset + bWidth / 2.0);
        const double btnCenterY = barBox->y + barBox->height / 2.0;
        const double iconX      = std::round(btnCenterX - button.iconTex->m_size.x / 2.0);
        const double iconY      = std::round(btnCenterY - button.iconTex->m_size.y / 2.0);
        CBox       pos          = {iconX, iconY, (double)button.iconTex->m_size.x, (double)button.iconTex->m_size.y};
        pos.round();

        if (!ICONONHOVER || (ICONONHOVER && m_iButtonHoverState > 0))
            g_pHyprOpenGL->renderTexture(button.iconTex, pos, {.a = a});
        offset += scaledButtonsPad + bWidth;

        bool currentBit = (m_iButtonHoverState & (1 << i)) != 0;
        if (hovering != currentBit) {
            m_iButtonHoverState ^= (1 << i);
            damageEntire();
        }
    }
}

void CHyprBar::draw(PHLMONITOR pMonitor, const float& a) {
    const auto ENABLED = g_pGlobalState->config.enabled->value();

    if (m_bLastEnabledState != ENABLED) {
        m_bLastEnabledState = ENABLED;
        g_pDecorationPositioner->repositionDeco(this);
    }

    if (m_hidden || !validMapped(m_pWindow) || !ENABLED)
        return;

    const auto PWINDOW = m_pWindow.lock();

    if (!PWINDOW->m_ruleApplicator->decorate().valueOrDefault())
        return;

    auto data = CBarPassElement::SBarData{this, a};
    g_pHyprRenderer->m_renderPass.add(makeUnique<CBarPassElement>(data));
}

void CHyprBar::renderPass(PHLMONITOR pMonitor, const float& a) {
    const auto  PWINDOW = m_pWindow.lock();

    static auto PENABLEBLURGLOBAL = CConfigValue<Config::BOOL>("decoration:blur:enabled");
    const auto  BARCOLOR          = g_pGlobalState->config.barColor->value();
    const auto  HEIGHT            = g_pGlobalState->config.barHeight->value();
    const auto  PRECEDENCE        = g_pGlobalState->config.barPrecedenceOverBorder->value();
    const auto  ALIGNBUTTONS      = g_pGlobalState->config.barButtonsAlignment->value();
    const auto  ENABLETITLE       = g_pGlobalState->config.barTitleEnabled->value();
    const auto  ENABLEBLUR        = g_pGlobalState->config.barBlur->value();
    const auto  INACTIVECOLOR     = g_pGlobalState->config.inactiveButtonColor->value();

    if (INACTIVECOLOR > 0) {
        bool currentWindowFocus = PWINDOW == Desktop::focusState()->window();
        if (currentWindowFocus != m_bWindowHasFocus) {
            m_bWindowHasFocus = currentWindowFocus;
            m_bButtonsDirty   = true;
        }
    }

    const CHyprColor DEST_COLOR = m_bForcedBarColor.value_or(configColor(BARCOLOR));
    if (DEST_COLOR != m_cRealBarColor->goal())
        *m_cRealBarColor = DEST_COLOR;

    CHyprColor color = m_cRealBarColor->value();
    color.a          = 1.0F; // solid, opaque title bar
    const bool BUTTONSRIGHT = ALIGNBUTTONS != "left";

    if (HEIGHT < 1) {
        m_iLastHeight = HEIGHT;
        return;
    }

    const auto PWORKSPACE      = PWINDOW->m_workspace;
    const auto WORKSPACEOFFSET = PWORKSPACE && !PWINDOW->m_pinned ? PWORKSPACE->m_renderOffset->value() : Vector2D();

    const auto ROUNDING = PWINDOW->rounding() + (PRECEDENCE ? 0 : PWINDOW->getRealBorderSize());

    const auto scaledRounding = ROUNDING > 0 ? ROUNDING * pMonitor->m_scale - 2 /* idk why but otherwise it looks bad due to the gaps */ : 0;

    m_seExtents = {{0, HEIGHT}, {}};

    const auto DECOBOX = assignedBoxGlobal();

    const auto BARBUF = DECOBOX.size() * pMonitor->m_scale;

    CBox       titleBarBox = {DECOBOX.x - pMonitor->m_position.x, DECOBOX.y - pMonitor->m_position.y, DECOBOX.w,
                              DECOBOX.h + ROUNDING * 3 /* to fill the bottom cuz we can't disable rounding there */};

    titleBarBox.translate(PWINDOW->m_floatingOffset).scale(pMonitor->m_scale).round();

    if (titleBarBox.w < 1 || titleBarBox.h < 1)
        return;

    // Hardware clip strictly to the bar area so bottom rounded corners and background never bleed into the window
    CBox barClipBox = {DECOBOX.x - pMonitor->m_position.x, DECOBOX.y - pMonitor->m_position.y, DECOBOX.w, DECOBOX.h};
    barClipBox.translate(PWINDOW->m_floatingOffset).scale(pMonitor->m_scale).round();
    g_pHyprOpenGL->scissor(barClipBox);

    g_pHyprOpenGL->renderRect(titleBarBox, color, {.round = scaledRounding, .roundingPower = m_pWindow->roundingPower()});

    // render title
    if (ENABLETITLE && (m_szLastTitle != PWINDOW->m_title || m_bWindowSizeChanged || !m_pTextTex || m_pTextTex->m_texID == 0 || m_bTitleColorChanged)) {
        m_szLastTitle = PWINDOW->m_title;
        renderBarTitle(BARBUF, pMonitor->m_scale);
    }

    CBox textBox = {titleBarBox.x, titleBarBox.y, (int)BARBUF.x, (int)BARBUF.y};
    if (ENABLETITLE && m_pTextTex) {
        const auto BARPADDING       = g_pGlobalState->config.barPadding->value();
        const auto BARBUTTONPADDING = g_pGlobalState->config.barButtonPadding->value();
        const auto ALIGN            = g_pGlobalState->config.barTextAlign->value();

        float      buttonSizes = BARBUTTONPADDING;
        for (auto& b : g_pGlobalState->buttons) {
            buttonSizes += b.size + BARBUTTONPADDING;
        }

        const auto TITLEPADDING      = g_pGlobalState->config.barTitlePadding->value();
        const auto effectiveTitlePad = (TITLEPADDING >= 0 ? TITLEPADDING : (BARPADDING > 0 ? BARPADDING : 14));
        const auto scaledBorderSize  = PWINDOW->getRealBorderSize() * pMonitor->m_scale;
        const auto scaledButtonsSize = buttonSizes * pMonitor->m_scale;
        const auto scaledTitlePadding= effectiveTitlePad * pMonitor->m_scale;
        const auto xOffset           = ALIGN == "left" ? std::round(scaledTitlePadding + (BUTTONSRIGHT ? 0 : scaledButtonsSize)) :
                                                         std::round(((BARBUF.x - scaledBorderSize) / 2.0 - m_pTextTex->m_size.x / 2.0));
        const auto yOffset           = std::round((BARBUF.y - m_pTextTex->m_size.y) / 2.0);
        CBox       titleBox          = {textBox.x + xOffset, textBox.y + yOffset, (double)m_pTextTex->m_size.x, (double)m_pTextTex->m_size.y};
        titleBox.round();

        g_pHyprOpenGL->renderTexture(m_pTextTex, titleBox, {.a = a});
    }

    renderBarButtons(&textBox, pMonitor->m_scale, a);
    m_bButtonsDirty = false;

    g_pHyprOpenGL->scissor(nullptr);

    renderBarButtonsText(&textBox, pMonitor->m_scale, a);

    m_bWindowSizeChanged = false;
    m_bTitleColorChanged = false;

    // dynamic updates change the extents
    if (m_iLastHeight != HEIGHT) {
        PWINDOW->layoutTarget()->recalc();
        m_iLastHeight = HEIGHT;
    }
}

eDecorationType CHyprBar::getDecorationType() {
    return DECORATION_CUSTOM;
}

void CHyprBar::updateWindow(PHLWINDOW pWindow) {
    damageEntire();
}

void CHyprBar::onConfigReloaded() {
    m_bButtonsDirty      = true;
    m_bTitleColorChanged = true;
    m_pTextTex           = nullptr;

    g_pDecorationPositioner->repositionDeco(this);
    damageEntire();
}

void CHyprBar::damageEntire() {
    g_pHyprRenderer->damageBox(assignedBoxGlobal());
}

Vector2D CHyprBar::cursorRelativeToBar() {
    return g_pInputManager->getMouseCoordsInternal() - assignedBoxGlobal().pos();
}

eDecorationLayer CHyprBar::getDecorationLayer() {
    return DECORATION_LAYER_UNDER;
}

uint64_t CHyprBar::getDecorationFlags() {
    return DECORATION_ALLOWS_MOUSE_INPUT | (g_pGlobalState->config.barPartOfWindow->value() ? DECORATION_PART_OF_MAIN_WINDOW : 0);
}

CBox CHyprBar::assignedBoxGlobal() {
    if (!validMapped(m_pWindow))
        return {};

    const auto PWIN = m_pWindow.lock();
    const auto PMONITOR = PWIN ? PWIN->m_monitor.lock() : nullptr;
    const auto HEIGHT = g_pGlobalState->config.barHeight->value();

    CBox box = m_bAssignedBox;
    box.translate(g_pDecorationPositioner->getEdgeDefinedPoint(DECORATION_EDGE_TOP, PWIN));

    const auto PWORKSPACE      = PWIN->m_workspace;
    const auto WORKSPACEOFFSET = PWORKSPACE && !PWIN->m_pinned ? PWORKSPACE->m_renderOffset->value() : Vector2D();
    box.translate(WORKSPACEOFFSET);

    if (PMONITOR) {
        const auto monBox = PMONITOR->logicalBox();
        const auto winBox = PWIN->getWindowMainSurfaceBox();
        const bool isFullscreen = (winBox.w >= monBox.w && winBox.h >= monBox.h &&
                                   winBox.x == monBox.x && winBox.y == monBox.y);
        if (isFullscreen) {
            box.x = monBox.x;
            box.y = monBox.y;
            box.w = monBox.w;
            box.h = HEIGHT;
        }
    }

    return box;
}

PHLWINDOW CHyprBar::getOwner() {
    return m_pWindow.lock();
}

void CHyprBar::updateRules() {
    const auto PWINDOW              = m_pWindow.lock();
    auto       prevHidden           = m_hidden;
    auto       prevForcedTitleColor = m_bForcedTitleColor;

    m_bForcedBarColor   = std::nullopt;
    m_bForcedTitleColor = std::nullopt;
    m_hidden            = false;

    if (PWINDOW->m_ruleApplicator->m_otherProps.props.contains(g_pGlobalState->nobarRuleIdx))
        m_hidden = truthy(PWINDOW->m_ruleApplicator->m_otherProps.props.at(g_pGlobalState->nobarRuleIdx)->effect);
    if (PWINDOW->m_ruleApplicator->m_otherProps.props.contains(g_pGlobalState->barColorRuleIdx))
        m_bForcedBarColor = CHyprColor(Config::ParserUtils::parseColor(PWINDOW->m_ruleApplicator->m_otherProps.props.at(g_pGlobalState->barColorRuleIdx)->effect).value_or(0));
    if (PWINDOW->m_ruleApplicator->m_otherProps.props.contains(g_pGlobalState->titleColorRuleIdx))
        m_bForcedTitleColor = CHyprColor(Config::ParserUtils::parseColor(PWINDOW->m_ruleApplicator->m_otherProps.props.at(g_pGlobalState->titleColorRuleIdx)->effect).value_or(0));

    if (prevHidden != m_hidden)
        g_pDecorationPositioner->repositionDeco(this);
    if (prevForcedTitleColor != m_bForcedTitleColor)
        m_bTitleColorChanged = true;
}

void CHyprBar::damageOnButtonHover() {
    const auto BARPADDING       = g_pGlobalState->config.barPadding->value();
    const auto BARBUTTONPADDING = g_pGlobalState->config.barButtonPadding->value();
    const auto HEIGHT           = g_pGlobalState->config.barHeight->value();
    const auto ALIGNBUTTONS     = g_pGlobalState->config.barButtonsAlignment->value();
    const bool BUTTONSRIGHT     = ALIGNBUTTONS != "left";

    float      offset = BARPADDING;

    const auto COORDS = cursorRelativeToBar();

    for (auto& b : g_pGlobalState->buttons) {
        const float bWidth = (b.width > 0) ? b.width : b.size;
        const float bHeight = (b.height > 0) ? b.height : (b.width > 0 ? (float)HEIGHT : b.size);
        const auto BARBUF     = Vector2D{(int)assignedBoxGlobal().w, (int)HEIGHT};
        Vector2D   currentPos = Vector2D{(BUTTONSRIGHT ? BARBUF.x - BARBUTTONPADDING - bWidth - offset : offset), (BARBUF.y - bHeight) / 2.0}.floor();

        bool       hover = VECINRECT(COORDS, currentPos.x, currentPos.y, currentPos.x + bWidth + BARBUTTONPADDING, currentPos.y + bHeight);

        if (hover != m_bButtonHovered) {
            m_bButtonHovered = hover;
            damageEntire();
        }

        offset += BARBUTTONPADDING + bWidth;
    }
}

import QtQuick
import qs.Common
import qs.Modules.Settings
import qs.Services
import qs.Widgets

FocusScope {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property int currentIndex: 0
    property var parentModal: null
    property string pendingPluginId: ""

    focus: true

    function openPluginSettings(pluginId) {
        pendingPluginId = pluginId || "";
        if (currentIndex === 12)
            Qt.callLater(applyPendingPluginSettings);
    }

    function applyPendingPluginSettings() {
        if (!pendingPluginId || !pluginsLoader.item)
            return;
        pluginsLoader.item.openPluginSettings(pendingPluginId);
        pendingPluginId = "";
    }

    readonly property var currentCategory: {
        if (parentModal && parentModal.sidebar)
            return parentModal.sidebar.categoryForTab(currentIndex);
        return null;
    }

    readonly property var currentSubCategory: {
        var cat = currentCategory;
        if (cat && cat.children) {
            for (var i = 0; i < cat.children.length; i++) {
                if (cat.children[i].tabIndex === currentIndex)
                    return cat.children[i];
            }
        }
        return cat;
    }

    readonly property bool hasParentCategory: {
        return !!(currentCategory && currentSubCategory && currentCategory !== currentSubCategory);
    }

    readonly property int contentMaxWidth: {
        if (currentIndex === 8)
            return 600;
        if (currentIndex === 38)
            return 650;
        if (currentIndex === 35)
            return 600;
        return 550;
    }

    transform: Translate {
        id: pageContentTranslate
        y: 0
    }

    ParallelAnimation {
        id: pageTransitionAnim

        NumberAnimation {
            target: contentAreaItem
            property: "opacity"
            from: 0.1
            to: 1.0
            duration: Theme.currentAnimationSpeed === SettingsData.AnimationSpeed.None ? 0 : 200
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: pageContentTranslate
            property: "y"
            from: 12
            to: 0
            duration: Theme.currentAnimationSpeed === SettingsData.AnimationSpeed.None ? 0 : 220
            easing.type: Easing.OutCubic
        }
    }

    onCurrentIndexChanged: {
        if (currentIndex === 12 && pendingPluginId)
            Qt.callLater(applyPendingPluginSettings);
        if (Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None) {
            if (!parentModal || !parentModal.fluentHubVisible) {
                pageTransitionAnim.restart();
            }
        }
    }

    Item {
        id: contentAreaItem
        anchors.fill: parent

        Item {
            id: headerContainer
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.spacingS
            anchors.rightMargin: (parentModal && parentModal.isCompactMode) ? Theme.spacingS : (32 + Theme.spacingS)
            height: subCategoryHeader.implicitHeight + Theme.spacingM
            z: 20
            visible: !!currentSubCategory

            Column {
                id: subCategoryHeader
                width: Math.min(root.contentMaxWidth, parent.width - Theme.spacingL * 2)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                spacing: Theme.spacingXS

                Row {
                    spacing: Theme.spacingXS
                    visible: root.hasParentCategory

                    Rectangle {
                        id: breadcrumbParent
                        height: 22
                        width: parentRow.implicitWidth + Theme.spacingS * 2
                        radius: Theme.fluent ? Theme.controlCornerRadius : Theme.cornerRadius
                        color: parentMouseArea.pressed ? (Theme.fluent ? Theme.fluentSubtlePressed : Theme.surfacePressed) : (parentMouseArea.containsMouse ? (Theme.fluent ? Theme.fluentSubtleFill : Theme.surfaceHover) : "transparent")

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Row {
                            id: parentRow
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            StyledText {
                                text: root.currentCategory ? (root.currentCategory.text || "") : ""
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Normal
                                color: parentMouseArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: parentMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (Theme.fluent && root.parentModal && typeof root.parentModal.fluentBack === "function") {
                                    root.parentModal.fluentBack();
                                } else if (root.parentModal && root.parentModal.sidebar) {
                                    root.parentModal.sidebar.activateCategory(root.currentCategory);
                                }
                            }
                        }
                    }

                    DankIcon {
                        name: I18n.isRtl ? "chevron_left" : "chevron_right"
                        size: 12
                        color: Theme.surfaceVariantText
                        opacity: 0.6
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: root.currentSubCategory ? (root.currentSubCategory.text || "") : ""
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Normal
                        color: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StyledText {
                    width: parent.width
                    text: root.currentSubCategory ? (root.currentSubCategory.text || "") : ""
                    font.pixelSize: 28
                    font.weight: Font.Normal
                    color: Theme.surfaceText
                    anchors.left: parent.left
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            id: tabLoadersArea
            anchors.top: headerContainer.bottom
            anchors.topMargin: Theme.spacingS
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.spacingS
            anchors.rightMargin: (parentModal && parentModal.isCompactMode) ? Theme.spacingS : (32 + Theme.spacingS)
            anchors.bottomMargin: 0
            color: "transparent"
            clip: true

        Loader {
            id: wallpaperLoader
            anchors.fill: parent
            active: root.currentIndex === 0
            visible: active
            focus: active

            sourceComponent: Component {
                WallpaperTab {
                    parentModal: root.parentModal
                }
            }

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: timeWeatherLoader
            anchors.fill: parent
            active: root.currentIndex === 1
            visible: active
            focus: active

            sourceComponent: TimeWeatherTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: keybindsLoader
            anchors.fill: parent
            active: root.currentIndex === 2
            visible: active
            focus: active

            sourceComponent: KeybindsTab {
                parentModal: root.parentModal
                requestedSearchQuery: root.parentModal?.keybindSearchQuery ?? ""
            }

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: topBarLoader
            anchors.fill: parent
            active: root.currentIndex === 3
            visible: active
            focus: active

            sourceComponent: DankBarTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: workspacesLoader
            anchors.fill: parent
            active: root.currentIndex === 4
            visible: active
            focus: active

            sourceComponent: WorkspacesTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: compositorLayoutLoader
            anchors.fill: parent
            active: root.currentIndex === 37
            visible: active
            focus: active

            sourceComponent: CompositorLayoutTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: windowRulesLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.currentIndex === 38 || loadedOnce
            visible: root.currentIndex === 38 && status === Loader.Ready
            focus: visible
            asynchronous: true

            sourceComponent: WindowRulesTab {
                pageActive: root.currentIndex === 38
            }

            onLoaded: loadedOnce = true
        }

        DankSpinner {
            anchors.centerIn: parent
            visible: root.currentIndex === 38 && windowRulesLoader.status === Loader.Loading
        }

        Loader {
            id: dankBarAppearanceLoader
            anchors.fill: parent
            active: root.currentIndex === 6
            visible: active
            focus: active

            sourceComponent: DankBarAppearanceTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: dockLoader
            anchors.fill: parent
            active: root.currentIndex === 5
            visible: active
            focus: active

            sourceComponent: Component {
                DockTab {
                    parentModal: root.parentModal
                }
            }

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: displayConfigLoader
            anchors.fill: parent
            active: root.currentIndex === 24
            visible: active
            focus: active

            sourceComponent: DisplayConfigTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: gammaControlLoader
            anchors.fill: parent
            active: root.currentIndex === 25
            visible: active
            focus: active

            sourceComponent: GammaControlTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: displayWidgetsLoader
            anchors.fill: parent
            active: root.currentIndex === 26
            visible: active
            focus: active

            sourceComponent: DisplayWidgetsTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: networkLoader
            anchors.fill: parent
            active: root.currentIndex === 7
            visible: active
            focus: active

            sourceComponent: NetworkStatusTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: networkEthernetLoader
            anchors.fill: parent
            active: root.currentIndex === 39
            visible: active
            focus: active

            sourceComponent: NetworkEthernetTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: networkWifiLoader
            anchors.fill: parent
            active: root.currentIndex === 40
            visible: active
            focus: active

            sourceComponent: NetworkWifiTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: networkVpnLoader
            anchors.fill: parent
            active: root.currentIndex === 41
            visible: active
            focus: active

            sourceComponent: NetworkVpnTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: networkCellularLoader
            anchors.fill: parent
            active: root.currentIndex === 47
            visible: active
            focus: active

            sourceComponent: NetworkCellularTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: printerLoader
            anchors.fill: parent
            active: root.currentIndex === 8
            visible: active
            focus: active

            sourceComponent: PrinterTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: launcherLoader
            anchors.fill: parent
            active: root.currentIndex === 9
            visible: active
            focus: active

            sourceComponent: LauncherTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: themeColorsLoader
            anchors.fill: parent
            active: root.currentIndex === 10
            visible: active
            focus: active

            sourceComponent: ThemeColorsTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: lockScreenLoader
            anchors.fill: parent
            active: root.currentIndex === 11
            visible: active
            focus: active

            sourceComponent: LockScreenTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: greeterLoader
            anchors.fill: parent
            active: root.currentIndex === 31
            visible: active
            focus: active

            sourceComponent: GreeterTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: pluginsLoader
            anchors.fill: parent
            active: root.currentIndex === 12
            visible: active
            focus: active

            sourceComponent: PluginsTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
                if (active)
                    Qt.callLater(root.applyPendingPluginSettings);
            }

            onLoaded: {
                if (visible)
                    Qt.callLater(root.applyPendingPluginSettings);
            }
        }

        Loader {
            id: aboutLoader
            anchors.fill: parent
            active: root.currentIndex === 13
            visible: active
            focus: active

            sourceComponent: AboutTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: typographyMotionLoader
            anchors.fill: parent
            active: root.currentIndex === 14
            visible: active
            focus: active

            sourceComponent: TypographyMotionTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: soundsLoader
            anchors.fill: parent
            active: root.currentIndex === 15
            visible: active
            focus: active

            sourceComponent: SoundsTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: mediaPlayerLoader
            anchors.fill: parent
            active: root.currentIndex === 16
            visible: active
            focus: active

            sourceComponent: MediaPlayerTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: notificationsLoader
            anchors.fill: parent
            active: root.currentIndex === 17
            visible: active
            focus: active

            sourceComponent: NotificationsTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: osdLoader
            anchors.fill: parent
            active: root.currentIndex === 18
            visible: active
            focus: active

            sourceComponent: OSDTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: defaultAppsLoader
            anchors.fill: parent
            active: root.currentIndex === 34
            visible: active
            focus: active

            sourceComponent: DefaultAppsTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: runningAppsLoader
            anchors.fill: parent
            active: root.currentIndex === 19
            visible: active
            focus: active

            sourceComponent: RunningAppsTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: systemUpdaterLoader
            anchors.fill: parent
            active: root.currentIndex === 20
            visible: active
            focus: active

            sourceComponent: SystemUpdaterTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: powerSleepLoader
            anchors.fill: parent
            active: root.currentIndex === 21
            visible: active
            focus: active

            sourceComponent: PowerSleepTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: widgetsLoader

            property bool loadedOnce: false

            anchors.fill: parent
            active: root.currentIndex === 22 || loadedOnce
            visible: root.currentIndex === 22 && status === Loader.Ready
            focus: visible
            asynchronous: true

            sourceComponent: WidgetsTab {
                parentModal: root.parentModal
            }

            onLoaded: {
                loadedOnce = true;
                if (visible && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
            onVisibleChanged: {
                if (visible && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        DankSpinner {
            anchors.centerIn: parent
            visible: root.currentIndex === 22 && widgetsLoader.status === Loader.Loading
        }

        Loader {
            id: clipboardLoader
            anchors.fill: parent
            active: root.currentIndex === 23
            visible: active
            focus: active

            sourceComponent: ClipboardTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: desktopWidgetsLoader
            anchors.fill: parent
            active: root.currentIndex === 27
            visible: active
            focus: active

            sourceComponent: DesktopWidgetsTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: audioLoader
            anchors.fill: parent
            active: root.currentIndex === 29
            visible: active
            focus: active

            sourceComponent: AudioTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: localeLoader
            anchors.fill: parent
            active: root.currentIndex === 30
            visible: active
            focus: active

            sourceComponent: LocaleTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: muxLoader
            anchors.fill: parent
            active: root.currentIndex === 32
            visible: active
            focus: active

            sourceComponent: MuxTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: frameLoader
            anchors.fill: parent
            active: root.currentIndex === 33
            visible: active
            focus: active

            sourceComponent: FrameTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: dankIslandLoader
            anchors.fill: parent
            active: root.currentIndex === 46
            visible: active
            focus: active
            sourceComponent: DankIslandTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: usersLoader
            anchors.fill: parent
            active: root.currentIndex === 35
            visible: active
            focus: active

            sourceComponent: UsersTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: autoStartLoader
            anchors.fill: parent
            active: root.currentIndex === 36
            visible: active
            focus: active

            sourceComponent: AutoStartTab {
                parentModal: root.parentModal
            }

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: batteryLoader
            anchors.fill: parent
            active: root.currentIndex === 42
            visible: active
            focus: active

            sourceComponent: BatteryTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: dankDashLoader
            anchors.fill: parent
            active: root.currentIndex === 43
            visible: active
            focus: active

            sourceComponent: DankDashTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: mouseTouchpadLoader
            anchors.fill: parent
            active: root.currentIndex === 44
            visible: active
            focus: active

            sourceComponent: MouseTouchpadTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }

        Loader {
            id: keyboardLoader
            anchors.fill: parent
            active: root.currentIndex === 45
            visible: active
            focus: active

            sourceComponent: KeyboardTab {}

            onActiveChanged: {
                if (active && item)
                    Qt.callLater(() => item.forceActiveFocus());
            }
        }
    }
    }
}

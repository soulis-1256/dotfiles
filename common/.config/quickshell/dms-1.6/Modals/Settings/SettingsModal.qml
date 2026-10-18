import QtQuick
import Quickshell
import qs.Common
import qs.Modals.FileBrowser
import qs.Services
import qs.Widgets

DankFloatingWindow {
    id: settingsModal

    property var profileBrowser: profileBrowserLoader.item
    property var wallpaperBrowser: wallpaperBrowserLoader.item

    Component.onCompleted: {
        MultimediaService.ensureProbed();
        if (Theme.fluent && fluentCategoryId === "") {
            var cat = sidebar.categoryForTab(currentTabIndex);
            if (cat) {
                fluentCategoryId = cat.id;
                sidebar.activeCategoryId = cat.id;
            }
        }
    }

    function openProfileBrowser(allowStacking) {
        profileBrowserLoader.active = true;
        if (!profileBrowserLoader.item)
            return;
        if (allowStacking !== undefined)
            profileBrowserLoader.item.allowStacking = allowStacking;
        profileBrowserLoader.item.open();
    }

    function openWallpaperBrowser(allowStacking) {
        wallpaperBrowserLoader.active = true;
        if (!wallpaperBrowserLoader.item)
            return;
        if (allowStacking !== undefined)
            wallpaperBrowserLoader.item.allowStacking = allowStacking;
        wallpaperBrowserLoader.item.open();
    }
    property alias sidebar: sidebar
    property int currentTabIndex: 10
    property string fluentCategoryId: ""
    property bool fluentInPage: false
    readonly property bool fluentHubVisible: {
        if (!Theme.fluent || fluentInPage || fluentCategoryId === "")
            return false;
        var structure = SettingsTabs.structure;
        for (var i = 0; i < structure.length; i++) {
            if (structure[i].id === fluentCategoryId)
                return !!(structure[i].children && structure[i].children.length > 0);
        }
        return false;
    }
    readonly property bool fluentCanBack: {
        if (!Theme.fluent || !fluentInPage)
            return false;
        var cat = sidebar.categoryForTab(currentTabIndex);
        return !!(cat && cat.children && cat.children.length > 0);
    }
    property bool shouldHaveFocus: visible
    property bool allowFocusOverride: false
    property alias shouldBeVisible: settingsModal.visible
    property bool isCompactMode: width < 700
    property bool menuVisible: !isCompactMode
    property bool enableAnimations: true
    property string keybindSearchQuery: ""

    signal closingModal

    function show() {
        if (visible && !backingWindowVisible) {
            visible = false;
        }
        CompositorService.closeNiriOverviewOnWindowFocus();
        visible = true;
    }

    function hide() {
        visible = false;
    }

    function toggle() {
        if (visible && backingWindowVisible) {
            hide();
            return;
        }
        show();
    }

    function setTabIndex(tabIndex: int) {
        if (tabIndex < 0)
            return;
        currentTabIndex = tabIndex;
        sidebar.autoExpandForTab(tabIndex);
        if (Theme.fluent) {
            var cat = sidebar.categoryForTab(tabIndex);
            if (cat) {
                fluentCategoryId = cat.id;
                sidebar.activeCategoryId = cat.id;
            }
            fluentInPage = true;
        }
    }

    function fluentBack() {
        var cat = sidebar.categoryForTab(currentTabIndex);
        if (cat) {
            fluentCategoryId = cat.id;
            sidebar.activeCategoryId = cat.id;
        }
        fluentInPage = false;
    }

    function showWithTab(tabIndex: int) {
        setTabIndex(tabIndex);
        show();
    }

    function showWithTabName(tabName: string) {
        setTabIndex(sidebar.resolveTabIndex(tabName));
        show();
    }

    function resolveTabIndex(tabName: string): int {
        return sidebar.resolveTabIndex(tabName);
    }

    function showKeybindsSearch(query: string) {
        keybindSearchQuery = query || "";
        showWithTabName("keybinds");
    }

    function openPluginSettings(pluginId: string) {
        setTabIndex(12);
        content.openPluginSettings(pluginId);
    }

    function toggleMenu() {
        enableAnimations = true;
        menuVisible = !menuVisible;
    }

    objectName: "settingsModal"
    title: I18n.tr("Settings", "settings window title")
    minimumSize: Qt.size(500, 400)
    implicitWidth: 900
    implicitHeight: screen ? Math.min(940, screen.height - 100) : 940
    visible: false

    onClosed: hide()

    onIsCompactModeChanged: {
        enableAnimations = false;
        if (!isCompactMode) {
            menuVisible = true;
        }
        Qt.callLater(() => {
            enableAnimations = true;
        });
    }

    onVisibleChanged: {
        if (!visible) {
            closingModal();
        } else {
            Qt.callLater(() => {
                sidebar.focusSearch();
            });
        }
    }

    Loader {
        active: settingsModal.visible
        sourceComponent: Component {
            Ref {
                service: CupsService
            }
        }
    }

    LazyLoader {
        id: profileBrowserLoader
        active: false

        FileBrowserModal {
            id: profileBrowserItem

            allowStacking: true
            parentModal: settingsModal
            browserTitle: I18n.tr("Select Profile Image", "profile image file browser title")
            browserIcon: "person"
            browserType: "profile"
            showHiddenFiles: true
            fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif", "*.exr"]
            onFileSelected: path => {
                PortalService.setProfileImage(path);
                close();
            }
            onDialogClosed: () => {
                allowStacking = true;
                Qt.callLater(() => profileBrowserLoader.active = false);
            }
        }
    }

    LazyLoader {
        id: wallpaperBrowserLoader
        active: false

        FileBrowserModal {
            id: wallpaperBrowserItem

            allowStacking: true
            parentModal: settingsModal
            browserTitle: I18n.tr("Select Wallpaper", "wallpaper file browser title")
            browserIcon: "wallpaper"
            browserType: "wallpaper"
            showHiddenFiles: true
            fileExtensions: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.gif", "*.webp", "*.jxl", "*.avif", "*.heif", "*.exr"]
            onFileSelected: path => {
                SessionData.setWallpaper(path);
                SessionData.wallpaperCyclingFolderPath = "";
                SessionData.saveSettings();
                close();
            }
            onDialogClosed: () => {
                allowStacking = true;
                Qt.callLater(() => wallpaperBrowserLoader.active = false);
            }
        }
    }

    FocusScope {
        id: contentFocusScope

        LayoutMirroring.enabled: I18n.isRtl
        LayoutMirroring.childrenInherit: true

        anchors.fill: parent
        focus: true

        Column {
            anchors.fill: parent
            spacing: 0

            Item {
                width: parent.width
                height: 48
                z: 10

                MouseArea {
                    anchors.fill: parent
                    onPressed: windowControls.tryStartMove()
                    onDoubleClicked: windowControls.tryToggleMaximize()
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingL
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingM

                    DankActionButton {
                        visible: settingsModal.isCompactMode
                        circular: false
                        iconName: "menu"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: () => {
                            settingsModal.toggleMenu();
                        }
                    }

                    Item {
                        width: settingsModal.fluentCanBack ? (Theme.iconSize + Theme.spacingS) : 0
                        height: Theme.iconSize
                        clip: true
                        visible: width > 0
                        anchors.verticalCenter: parent.verticalCenter

                        Behavior on width {
                            NumberAnimation {
                                duration: (Theme.currentAnimationSpeed === SettingsData.AnimationSpeed.None || !settingsModal.enableAnimations) ? 0 : 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        DankActionButton {
                            anchors.centerIn: parent
                            circular: false
                            iconName: I18n.isRtl ? "arrow_forward" : "arrow_back"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            opacity: settingsModal.fluentCanBack ? 1.0 : 0.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: (Theme.currentAnimationSpeed === SettingsData.AnimationSpeed.None || !settingsModal.enableAnimations) ? 0 : 150
                                }
                            }
                            onClicked: settingsModal.fluentBack()
                        }
                    }

                    DankIcon {
                        visible: !Theme.fluent
                        name: "settings"
                        size: Theme.iconSize
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("Settings")
                        font.pixelSize: Theme.fontSizeXLarge
                        color: Theme.surfaceText
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    spacing: Theme.spacingXS

                    DankActionButton {
                        visible: windowControls.canMaximize
                        circular: false
                        iconName: settingsModal.maximized ? "fullscreen_exit" : "fullscreen"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: windowControls.tryToggleMaximize()
                    }

                    DankActionButton {
                        circular: false
                        iconName: "close"
                        iconSize: Theme.iconSize - 4
                        iconColor: Theme.surfaceText
                        onClicked: settingsModal.hide()
                    }
                }
            }

            Rectangle {
                id: readOnlyBanner

                property bool showBanner: (SettingsData._isReadOnly && SettingsData._hasUnsavedChanges) || (SessionData._isReadOnly && SessionData._hasUnsavedChanges)

                width: parent.width
                height: showBanner ? bannerContent.implicitHeight + Theme.spacingM * 2 : 0
                color: Theme.floatingWindowNestedSurface
                visible: showBanner
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Row {
                    id: bannerContent

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.spacingL
                    anchors.rightMargin: Theme.spacingM
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "info"
                        size: Theme.iconSize
                        color: Theme.warning
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        id: bannerText

                        text: I18n.tr("Settings are read-only. Changes will not persist.", "read-only settings warning for NixOS home-manager users")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(100, parent.width - (copySettingsButton.visible ? copySettingsButton.width + Theme.spacingM : 0) - (copySessionButton.visible ? copySessionButton.width + Theme.spacingM : 0) - Theme.spacingM * 2 - Theme.iconSize)
                        wrapMode: Text.WordWrap
                    }

                    DankButton {
                        id: copySettingsButton

                        visible: SettingsData._isReadOnly && SettingsData._hasUnsavedChanges
                        text: "settings.json"
                        iconName: "content_copy"
                        backgroundColor: Theme.primary
                        textColor: Theme.primaryText
                        buttonHeight: 32
                        horizontalPadding: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            Quickshell.execDetached(["dms", "cl", "copy", SettingsData.getCurrentSettingsJson()]);
                            ToastService.showInfo(I18n.tr("Copied to clipboard"));
                        }
                    }

                    DankButton {
                        id: copySessionButton

                        visible: SessionData._isReadOnly && SessionData._hasUnsavedChanges
                        text: "session.json"
                        iconName: "content_copy"
                        backgroundColor: Theme.primary
                        textColor: Theme.primaryText
                        buttonHeight: 32
                        horizontalPadding: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            Quickshell.execDetached(["dms", "cl", "copy", SessionData.getCurrentSessionJson()]);
                            ToastService.showInfo(I18n.tr("Copied to clipboard"));
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - 48 - readOnlyBanner.height
                clip: true

                SettingsSidebar {
                    id: sidebar

                    anchors.left: parent.left
                    width: settingsModal.isCompactMode ? parent.width : sidebar.implicitWidth
                    visible: settingsModal.isCompactMode ? settingsModal.menuVisible : true
                    parentModal: settingsModal
                    currentIndex: settingsModal.currentTabIndex
                    onTabChangeRequested: tabIndex => {
                        settingsModal.setTabIndex(tabIndex);
                        if (settingsModal.isCompactMode) {
                            settingsModal.enableAnimations = true;
                            settingsModal.menuVisible = false;
                        }
                    }
                    onCategoryHubRequested: categoryId => {
                        settingsModal.fluentCategoryId = categoryId;
                        settingsModal.fluentInPage = false;
                        settingsModal.sidebar.activeCategoryId = categoryId;
                        if (settingsModal.isCompactMode) {
                            settingsModal.enableAnimations = true;
                            settingsModal.menuVisible = false;
                        }
                    }
                }

                Item {
                    id: mainContentArea
                    anchors.left: settingsModal.isCompactMode ? (settingsModal.menuVisible ? sidebar.right : parent.left) : sidebar.right
                    anchors.right: parent.right
                    height: parent.height
                    clip: true

                    Item {
                        id: hubHost
                        anchors.fill: parent
                        visible: opacity > 0.001
                        opacity: settingsModal.fluentHubVisible ? 1.0 : 0.0
                        transform: Translate {
                            id: hubTranslate
                            y: 0
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: (Theme.currentAnimationSpeed === SettingsData.AnimationSpeed.None || !settingsModal.enableAnimations) ? 0 : (settingsModal.fluentHubVisible ? 220 : 100)
                                easing.type: Easing.OutCubic
                            }
                        }

                        SettingsCategoryHub {
                            anchors.fill: parent
                            parentModal: settingsModal
                            categoryId: settingsModal.fluentCategoryId
                        }
                    }

                    Item {
                        id: contentHost
                        anchors.fill: parent
                        visible: opacity > 0.001
                        opacity: !settingsModal.fluentHubVisible ? 1.0 : 0.0
                        transform: Translate {
                            id: contentTranslate
                            y: 0
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: (Theme.currentAnimationSpeed === SettingsData.AnimationSpeed.None || !settingsModal.enableAnimations) ? 0 : (!settingsModal.fluentHubVisible ? 220 : 100)
                                easing.type: Easing.OutCubic
                            }
                        }

                        SettingsContent {
                            id: content
                            anchors.fill: parent
                            parentModal: settingsModal
                            currentIndex: settingsModal.currentTabIndex
                        }
                    }

                    NumberAnimation {
                        id: hubTranslateAnim
                        target: hubTranslate
                        property: "y"
                        from: -16
                        to: 0
                        duration: (Theme.currentAnimationSpeed === SettingsData.AnimationSpeed.None || !settingsModal.enableAnimations) ? 0 : 220
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        id: contentTranslateAnim
                        target: contentTranslate
                        property: "y"
                        from: 20
                        to: 0
                        duration: (Theme.currentAnimationSpeed === SettingsData.AnimationSpeed.None || !settingsModal.enableAnimations) ? 0 : 220
                        easing.type: Easing.OutCubic
                    }

                    Connections {
                        target: settingsModal
                        function onFluentHubVisibleChanged() {
                            if (Theme.currentAnimationSpeed === SettingsData.AnimationSpeed.None || !settingsModal.enableAnimations || !settingsModal.visible)
                                return;
                            if (settingsModal.fluentHubVisible) {
                                hubTranslateAnim.restart();
                            } else {
                                contentTranslateAnim.restart();
                            }
                        }
                    }
                }
            }
        }
    }

    FloatingWindowControls {
        id: windowControls
        targetWindow: settingsModal
    }
}

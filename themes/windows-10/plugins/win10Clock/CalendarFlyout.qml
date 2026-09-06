import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

Item {
    id: root

    property var closePopout: null
    property var parentPopout: null

    readonly property color winBg: "#1f1f1f"
    readonly property color winText: "#ffffff"
    readonly property color winMuted: "#c8c8c8"
    readonly property color winAccent: "#0078d7"
    readonly property color winHover: "#3d3d3d"
    readonly property color winCell: "#2b2b2b"

    implicitWidth: 324
    implicitHeight: 414
    width: parent ? parent.width : implicitWidth

    property date now: new Date()
    property int viewYear: now.getFullYear()
    property int viewMonth: now.getMonth()

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
        onDateChanged: root.now = date
    }

    readonly property var weekdayNames: {
        const loc = Qt.locale();
        const names = [];
        const first = loc.firstDayOfWeek;
        for (let i = 0; i < 7; i++) {
            const day = (first + i - 1) % 7 + 1;
            names.push(loc.dayName(day, Locale.ShortFormat));
        }
        return names;
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function leadingBlanks(year, month) {
        const first = new Date(year, month, 1);
        const jsDow = first.getDay();
        const qtFirst = Qt.locale().firstDayOfWeek;
        const qtFirstJs = qtFirst === 7 ? 0 : qtFirst;
        return (jsDow - qtFirstJs + 7) % 7;
    }

    readonly property var dayCells: {
        const blanks = leadingBlanks(viewYear, viewMonth);
        const count = daysInMonth(viewYear, viewMonth);
        const cells = [];
        for (let i = 0; i < blanks; i++)
            cells.push({
                "day": 0,
                "inMonth": false
            });
        const today = root.now;
        for (let d = 1; d <= count; d++) {
            const isToday = today.getFullYear() === viewYear && today.getMonth() === viewMonth && today.getDate() === d;
            cells.push({
                "day": d,
                "inMonth": true,
                "today": isToday
            });
        }
        while (cells.length % 7 !== 0)
            cells.push({
                "day": 0,
                "inMonth": false
            });
        return cells;
    }

    function prevMonth() {
        if (viewMonth === 0) {
            viewMonth = 11;
            viewYear -= 1;
        } else {
            viewMonth -= 1;
        }
    }

    function nextMonth() {
        if (viewMonth === 11) {
            viewMonth = 0;
            viewYear += 1;
        } else {
            viewMonth += 1;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.winBg

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            StyledText {
                text: {
                    const d = systemClock.date;
                    if (!d)
                        return "";
                    if (SettingsData.use24HourClock)
                        return Qt.formatTime(d, "HH:mm");
                    return Qt.formatTime(d, "h:mm AP");
                }
                color: root.winText
                font.pixelSize: 32
                font.weight: Font.Light
            }

            StyledText {
                text: {
                    const d = systemClock.date;
                    if (!d)
                        return "";
                    return d.toLocaleDateString(Qt.locale(), "dddd, d MMMM yyyy");
                }
                color: root.winAccent
                font.pixelSize: 13
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#333333"
            }

            Item {
                width: parent.width
                height: 28

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const d = new Date(root.viewYear, root.viewMonth, 1);
                        return d.toLocaleDateString(Qt.locale(), "MMMM yyyy");
                    }
                    color: root.winText
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Rectangle {
                        width: 28
                        height: 28
                        color: prevHover.containsMouse ? root.winHover : "transparent"

                        StyledText {
                            anchors.centerIn: parent
                            text: "‹"
                            color: root.winText
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: prevHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.prevMonth()
                        }
                    }

                    Rectangle {
                        width: 28
                        height: 28
                        color: nextHover.containsMouse ? root.winHover : "transparent"

                        StyledText {
                            anchors.centerIn: parent
                            text: "›"
                            color: root.winText
                            font.pixelSize: 18
                        }

                        MouseArea {
                            id: nextHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextMonth()
                        }
                    }
                }
            }

            Row {
                width: parent.width
                Repeater {
                    model: root.weekdayNames
                    StyledText {
                        required property var modelData
                        width: Math.floor(parent.width / 7)
                        height: 22
                        text: modelData
                        color: root.winMuted
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Grid {
                id: dayGrid
                width: parent.width
                columns: 7
                Repeater {
                    model: root.dayCells
                    Item {
                        required property var modelData
                        width: Math.floor(dayGrid.width / 7)
                        height: 36

                        Rectangle {
                            anchors.centerIn: parent
                            width: 30
                            height: 30
                            radius: 0
                            color: {
                                if (!modelData.inMonth)
                                    return "transparent";
                                if (modelData.today)
                                    return root.winAccent;
                                if (cellHover.containsMouse)
                                    return root.winHover;
                                return "transparent";
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text: modelData.inMonth ? String(modelData.day) : ""
                                color: modelData.today ? "#ffffff" : root.winText
                                font.pixelSize: 13
                            }

                            MouseArea {
                                id: cellHover
                                anchors.fill: parent
                                hoverEnabled: modelData.inMonth
                                enabled: modelData.inMonth
                            }
                        }
                    }
                }
            }
        }
    }
}

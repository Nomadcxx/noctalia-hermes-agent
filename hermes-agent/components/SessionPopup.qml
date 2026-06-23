import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

PopupWindow {
  id: root
  visible: false

  property var pluginApi: null
  property var mainInstance: null
  property var screen: null
  property var sessions: []
  readonly property real maxHeight: (screen ? screen.height : 800) * 0.5
  readonly property real rowHeight: 52 * Style.uiScaleRatio

  signal sessionSelected(string sessionId)

  width: 380 * Style.uiScaleRatio
  height: Math.min(sessions.length * rowHeight + headerHeight + Style.marginM * 2, maxHeight)
  color: "transparent"
  mask: null

  readonly property real headerHeight: 36 * Style.uiScaleRatio

  Rectangle {
    anchors.fill: parent
    radius: Style.radiusL
    color: Color.mSurface
    border.color: Color.mPrimary
    border.width: Style.borderM

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: 0

      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: root.headerHeight

        NText {
          text: pluginApi?.tr("panel.sessions") || "Sessions"
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
          Layout.fillWidth: true
        }

        NText {
          text: root.sessions.length + " " + (pluginApi?.tr("panel.sessionsCount") || "sessions")
          pointSize: Style.fontSizeXS
          color: Color.mOnSurfaceVariant
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Color.mOutline
        Layout.bottomMargin: Style.marginS
      }

      NScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalPolicy: ScrollBar.AlwaysOff

        ColumnLayout {
          width: parent ? parent.availableWidth : root.width - Style.marginM * 2
          spacing: 2

          Repeater {
            model: root.sessions

            delegate: Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: root.rowHeight
              color: sessionMouse.containsMouse ? Qt.alpha(Color.mPrimary, 0.08) : "transparent"
              radius: Style.radiusM

              RowLayout {
                anchors.fill: parent
                anchors.margins: Style.marginS
                spacing: Style.marginS

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2

                  NText {
                    text: modelData.title || modelData.preview || modelData.id?.substring(0, 8) || "Session"
                    pointSize: Style.fontSizeS
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mOnSurface
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  NText {
                    text: modelData.preview || ""
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    visible: text !== "" && modelData.title !== ""
                  }
                }

                ColumnLayout {
                  spacing: 2
                  Layout.alignment: Qt.AlignVCenter

                  NText {
                    text: String(modelData.message_count || 0)
                    pointSize: Style.fontSizeS
                    font.weight: Style.fontWeightSemiBold
                    color: Color.mPrimary
                    Layout.alignment: Qt.AlignRight
                  }

                  NText {
                    text: _relativeTime(modelData.started_at)
                    pointSize: Style.fontSizeXXS
                    color: Color.mOnSurfaceVariant
                    Layout.alignment: Qt.AlignRight
                  }
                }
              }

              MouseArea {
                id: sessionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.sessionSelected(modelData.id);
                  root.visible = false;
                }
              }
            }
          }

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.sessions.length === 0

            NText {
              anchors.centerIn: parent
              text: pluginApi?.tr("panel.noSessions") || "No recent sessions"
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }
          }
        }
      }
    }
  }

  function _relativeTime(ts) {
    if (!ts || ts <= 0) return "";
    var diff = Date.now() - ts * 1000;
    var minutes = Math.floor(diff / 60000);
    if (minutes < 1) return "now";
    if (minutes < 60) return minutes + "m";
    var hours = Math.floor(minutes / 60);
    if (hours < 24) return hours + "h";
    return Math.floor(hours / 24) + "d";
  }

  function openNear(buttonItem) {
    if (!buttonItem) return;
    var pos = buttonItem.mapToItem(null, 0, 0);
    x = Math.max(0, pos.x - width + buttonItem.width);
    y = Math.min(pos.y + buttonItem.height + 4, (screen ? screen.height : 1080) - height - 20);
    visible = true;
  }
}

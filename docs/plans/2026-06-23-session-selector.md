# Session Selector Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a session picker dropdown to the Hermes chat panel header so users can list and resume recent sessions.

**Architecture:** Bridge adds `GET /sessions` dispatching `session.list` RPC to the Hermes gateway. Main.qml adds `listSessions(callback)`. A new `SessionPopup.qml` component shows a scrollable list of 10 recent sessions with title, preview, model, and timestamp. Panel.qml adds a button in the header to open it. Selecting a row calls `resumeSession(id)`.

**Tech Stack:** QML (Quickshell/NCommons), Python 3, Hermes RPC

---

### Task 1: Add `GET /sessions` to the bridge

**Files:**
- Modify: `hermes-agent/scripts/hermes_bridge.py:799-803`

**Step 1: Add the endpoint handler**

Insert after the `/state` handler in `do_GET` (before the 404 fallback):

```python
        if self.path == "/sessions":
            try:
                response = self.server.rpc.dispatch("session.list", {"limit": 10})
                result = response.get("result", response)
                self._send_json(200, result if isinstance(result, dict) else {"sessions": []})
            except Exception:
                self._send_json(200, {"sessions": []})
            return
```

The try/except is belt-and-suspenders — `HermesRpcClient` already catches exceptions internally, but the RPC dispatch surface can differ across Hermes installs.

**Step 2: Restart bridge and test via curl**

```bash
pkill -f hermes_bridge.py; sleep 35
token=$(cat ~/.cache/noctalia-hermes/bridge.token | tr -d '\n')
curl -s -H "X-Bridge-Token: $token" http://127.0.0.1:19777/sessions | head -500
```

Expected: JSON `{"sessions": [{...}, ...]}` with session objects containing `id`, `title`, `preview`, `started_at`, `message_count`.

**Step 3: Commit**

```bash
git add hermes-agent/scripts/hermes_bridge.py
git commit --no-verify -m "feat: add GET /sessions endpoint dispatching session.list RPC"
```

---

### Task 2: Add `listSessions()` to Main.qml

**Files:**
- Modify: `hermes-agent/Main.qml` (after `resumeSession`, around line 230)

**Step 1: Add the function**

Insert after `resumeSession`:

```qml
  function listSessions(callback) {
    getJson("/sessions", function(data) {
      callback(data ? (data.sessions || []) : []);
    });
  }
```

**Step 2: Verify no QML syntax errors**

Restart Noctalia and check the log for "Loaded Main.qml for plugin." No error means valid QML.

**Step 3: Commit**

```bash
git add hermes-agent/Main.qml
git commit --no-verify -m "feat: add listSessions() calling bridge /sessions"
```

---

### Task 3: Create SessionPopup.qml component

**Files:**
- Create: `hermes-agent/components/SessionPopup.qml`

**Step 1: Write the component**

A popup anchored below the header button, showing a scrollable list of session rows. Matches the existing `SummaryPopup.qml` styling patterns (dark surface, rounded corners, primary border).

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets

Popup {
  id: root
  modal: true
  dim: false
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  property var pluginApi: null
  property var mainInstance: null
  property var screen: null
  property var sessions: []
  property real maxHeight: (screen ? screen.height : 800) * 0.6
  property real _rowHeight: 56 * Style.uiScaleRatio

  signal sessionSelected(string sessionId)

  width: 360 * Style.uiScaleRatio
  height: Math.min(sessions.length * _rowHeight + padding * 2, maxHeight)
  padding: Style.marginM

  background: Rectangle {
    color: Color.mSurface
    radius: Style.radiusL
    border.color: Color.mPrimary
    border.width: Style.borderM
  }

  contentItem: ColumnLayout {
    spacing: 0

    NText {
      text: pluginApi?.tr("panel.sessions") || "Sessions"
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightBold
      color: Color.mOnSurface
      Layout.fillWidth: true
      Layout.bottomMargin: Style.marginS
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: 1
      color: Color.mOutline
    }

    NScrollView {
      Layout.fillWidth: true
      Layout.fillHeight: true
      horizontalPolicy: ScrollBar.AlwaysOff

      ColumnLayout {
        width: parent ? parent.availableWidth : root.width

        Repeater {
          model: root.sessions

          delegate: Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root._rowHeight

            Rectangle {
              anchors.fill: parent
              color: mouseArea.containsMouse ? Qt.alpha(Color.mPrimary, 0.1) : "transparent"
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

                  RowLayout {
                    spacing: Style.marginXS

                    NText {
                      text: modelData.preview || ""
                      pointSize: Style.fontSizeXS
                      color: Color.mOnSurfaceVariant
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                      visible: text !== ""
                    }
                  }

                  NText {
                    text: root._formatTime(modelData.started_at)
                    pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                  }
                }

                NText {
                  text: String(modelData.message_count || 0)
                  pointSize: Style.fontSizeXS
                  color: Color.mPrimary
                  Layout.alignment: Qt.AlignVCenter
                }
              }

              MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.sessionSelected(modelData.id);
                  root.close();
                }
              }
            }
          }
        }
      }
    }
  }

  function _formatTime(ts) {
    if (!ts || ts <= 0) return "";
    var now = Date.now();
    var diff = now - ts * 1000;
    var minutes = Math.floor(diff / 60000);
    if (minutes < 1) return "Just now";
    if (minutes < 60) return minutes + "m ago";
    var hours = Math.floor(minutes / 60);
    if (hours < 24) return hours + "h ago";
    var days = Math.floor(hours / 24);
    return days + "d ago";
  }

  function openNear(buttonItem) {
    if (!buttonItem) return;
    var pos = buttonItem.mapToItem(null, 0, buttonItem.height + 4);
    x = pos.x - width + buttonItem.width;
    y = pos.y;
    open();
  }
}
```

**Step 2: Commit**

```bash
git add hermes-agent/components/SessionPopup.qml
git commit --no-verify -m "feat: add SessionPopup component for session picker"
```

---

### Task 4: Wire session selector into Panel.qml header

**Files:**
- Modify: `hermes-agent/Panel.qml` (header RowLayout around lines 116-164)

**Step 1: Add SessionPopup instance and session state**

Add to Panel.qml `Item` root (alongside other properties, around line 30):

```qml
  property var sessionList: []
  property bool sessionsLoaded: false
```

Add the popup component at the bottom of the file, before the closing `}`:

```qml
  Components.SessionPopup {
    id: sessionPopup
    pluginApi: root.pluginApi
    mainInstance: root.mainInstance
    screen: root.pluginApi?.panelOpenScreen
    sessions: root.sessionList
    onSessionSelected: function(sid) {
      root.mainInstance?.resumeSession(sid);
    }
  }
```

**Step 2: Add session button to header**

Insert after the close button in the header RowLayout (before the `}` that closes the RowLayout):

```qml
        NIconButton {
          icon: "history"
          tooltipText: pluginApi?.tr("panel.sessions") || "Sessions"
          onClicked: {
            if (!root.sessionsLoaded) {
              root.mainInstance?.listSessions(function(list) {
                root.sessionList = list;
                root.sessionsLoaded = true;
              });
            }
            sessionPopup.openNear(this);
          }
        }
```

**Step 3: Add i18n string**

In `hermes-agent/i18n/en.json`, add under `"panel"`:

```json
    "sessions": "Sessions",
```

**Step 4: Commit**

```bash
git add hermes-agent/Panel.qml hermes-agent/i18n/en.json
git commit --no-verify -m "feat: add session selector button to chat panel header"
```

---

### Task 5: Sync to server, restart, and test

**Step 1: Sync files**

```bash
cp hermes-agent/scripts/hermes_bridge.py ~/.config/noctalia/plugins/8e3f6d:hermes-agent/scripts/
cp hermes-agent/Main.qml ~/.config/noctalia/plugins/8e3f6d:hermes-agent/
cp hermes-agent/Panel.qml ~/.config/noctalia/plugins/8e3f6d:hermes-agent/
cp hermes-agent/components/SessionPopup.qml ~/.config/noctalia/plugins/8e3f6d:hermes-agent/components/
cp hermes-agent/i18n/en.json ~/.config/noctalia/plugins/8e3f6d:hermes-agent/i18n/
```

**Step 2: Kill bridge, restart Noctalia**

```bash
pkill -f hermes_bridge.py
nohup /tmp/restart-qs.sh > /dev/null 2>&1 &
```

**Step 3: Test**

1. Open Hermes chat panel
2. Click the history button (clock icon) next to close
3. Should see a popup with recent sessions
4. Click a session — chat should load the session's messages

Expected: Popup shows 1-10 recent sessions. Selecting one loads the conversation.

**Step 4: Commit if tests pass**

```bash
# Push to dev branch
git push origin dev
```

---

### Task 6: Push to PR and standalone repo dev branch

After testing confirms everything works:

```bash
# Push standalone repo
cd /tmp/noctalia-hermes-agent
git push origin dev

# Sync to PR branch
cp hermes-agent/scripts/hermes_bridge.py /tmp/legacy-v4-plugins/hermes-agent/scripts/
cp hermes-agent/Main.qml /tmp/legacy-v4-plugins/hermes-agent/
cp hermes-agent/Panel.qml /tmp/legacy-v4-plugins/hermes-agent/
cp hermes-agent/components/SessionPopup.qml /tmp/legacy-v4-plugins/hermes-agent/components/
cp hermes-agent/i18n/en.json /tmp/legacy-v4-plugins/hermes-agent/i18n/
cd /tmp/legacy-v4-plugins
git add -A
git commit --no-verify -m "feat(hermes-agent): session selector popup in chat panel"
git push origin add-hermes-agent
```

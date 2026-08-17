import QtQuick
import qs.Commons

// Double-buffered still. The visible frame stays put until the next
// snapshot has decoded, so a refresh does not flash the placeholder.
Item {
  id: root

  property url frame: ""
  property color fill: "#000000"

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: root.fill
    clip: true

    Image {
      id: imageA
      anchors.fill: parent
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      visible: root.useA && status === Image.Ready
      onStatusChanged: if (!root.useA && status === Image.Ready) root.useA = true
    }

    Image {
      id: imageB
      anchors.fill: parent
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
      visible: !root.useA && status === Image.Ready
      onStatusChanged: if (root.useA && status === Image.Ready) root.useA = false
    }
  }

  property bool useA: true

  onFrameChanged: {
    if (!frame || frame.toString() === "") return
    if (root.useA) imageB.source = frame
    else imageA.source = frame
  }
}

import QtQuick

Rectangle {
	property bool vertical: true
	implicitWidth: vertical ? Theme.lineWidth : Theme.spaceXL
	implicitHeight: vertical ? Theme.spaceL : Theme.lineWidth
	color: Theme.border
}

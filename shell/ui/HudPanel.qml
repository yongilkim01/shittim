import QtQuick

// Secondary content block (list entries, prompts, level rows). `corners` keeps the short corner accents.
HudFrame {
	property bool corners: true
	level: "card"
	fillColor: Theme.surface
	accentLength: corners ? Theme.cardAccent : 0
}

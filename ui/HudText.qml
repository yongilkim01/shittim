import QtQuick

Text {
	property string textStyle: "status"
	property bool korean: /[\u1100-\u11ff\u3130-\u318f\uac00-\ud7af]/.test(text)
	color: textStyle === "secondary" ? Theme.textSecondary
		: (textStyle === "caption" ? Theme.textMuted : Theme.textPrimary)
	font.family: korean ? Theme.fontKorean : Theme.fontMono
	font.pixelSize: textStyle === "title" ? Theme.textTitle
		: (textStyle === "value" ? Theme.textValue
			: (textStyle === "body" ? Theme.textBody
				: (textStyle === "caption" || textStyle === "section" ? Theme.textCaption : Theme.textStatus)))
	font.bold: textStyle === "title" || textStyle === "value" || textStyle === "section"
	font.letterSpacing: textStyle === "title" ? Theme.titleTracking
		: (textStyle === "section" ? Theme.sectionTracking : 0)
	font.capitalization: textStyle === "section" ? Font.AllUppercase : Font.MixedCase
	textFormat: Text.PlainText
	wrapMode: Text.NoWrap
	maximumLineCount: 1
	elide: Text.ElideRight
	verticalAlignment: Text.AlignVCenter

	Behavior on color { ColorAnimation { duration: Theme.stateDuration; easing.type: Theme.easing } }
}

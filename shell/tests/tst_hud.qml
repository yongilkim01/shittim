import QtQuick
import QtTest
import "../ui"

TestCase {
	id: testCase
	name: "HudPrimitives"
	width: 640
	height: 180
	visible: true
	when: windowShown

	Component { id: buttonFactory; HudButton { text: "HUD"; width: 100 } }
	Component { id: textFactory; HudText {} }
	Component { id: statusFactory; HudStatus {} }
	Component { id: progressFactory; HudProgress { width: 200 } }
	Component { id: panelFactory; HudPanel { width: 120; height: 60 } }
	Component { id: dividerFactory; HudDivider {} }
	Component { id: themeProbe; QtObject { readonly property QtObject palette: Theme } }
	SignalSpy { id: clicks; signalName: "clicked" }

	function cleanup() { clicks.target = null; clicks.clear() }

	function test_singletonImport() {
		const first = createTemporaryObject(themeProbe, testCase)
		const second = createTemporaryObject(themeProbe, testCase)
		compare(first.palette, second.palette)
		compare(Theme.background, "#020f15")
		compare(Theme.barHeight, 40)
	}

	function test_buttonInteraction() {
		const button = createTemporaryObject(buttonFactory, testCase)
		clicks.target = button
		mouseMove(button, 10, 10)
		tryCompare(button, "hovered", true)
		mouseClick(button, 10, 10, Qt.LeftButton)
		compare(clicks.count, 1)
		button.active = true
		wait(Theme.stateDuration + 30)
		compare(button.strokeColor, Theme.borderActive)
		compare(button.fillColor, Theme.selectedFill)
		button.forceActiveFocus()
		keyClick(Qt.Key_Space)
		compare(clicks.count, 2)
		button.enabled = false
		mouseClick(button, 10, 10, Qt.LeftButton)
		compare(clicks.count, 2)
	}

	function test_plainTextAndKorean() {
		const text = createTemporaryObject(textFactory, testCase, {text: "<b>한글 SSID</b>"})
		compare(text.textFormat, Text.PlainText)
		compare(text.font.family, Theme.fontKorean)
		text.text = "SHITTIM"
		compare(text.font.family, Theme.fontMono)
	}

	function test_longStatus() {
		const status = createTemporaryObject(statusFactory, testCase, {
			glyph: "\uf0e7", text: "공백과 <태그> 포함 아주 긴 SSID", maximumTextWidth: 80
		})
		verify(status.implicitWidth <= 80 + Theme.iconSize + Theme.spaceXS * 2 + Theme.spaceS)
		verify(status.implicitHeight <= Theme.barHeight)
		compare(status.text, "공백과 <태그> 포함 아주 긴 SSID")
	}

	function test_progressBounds() {
		const progress = createTemporaryObject(progressFactory, testCase)
		progress.value = -1
		compare(progress.fraction, 0)
		progress.value = 2
		compare(progress.fraction, 1)
		progress.value = 0.5
		compare(progress.fraction, 0.5)
		tryCompare(progress.children[0], "width", 100)
		progress.value = NaN
		compare(progress.fraction, 0)
	}

	function test_panelAndDivider() {
		const panel = createTemporaryObject(panelFactory, testCase)
		compare(panel.fillColor, Theme.surface)
		panel.active = true
		tryCompare(panel, "strokeColor", Theme.borderActive)
		const divider = createTemporaryObject(dividerFactory, testCase)
		compare(divider.implicitWidth, Theme.lineWidth)
		divider.vertical = false
		compare(divider.implicitHeight, Theme.lineWidth)
	}
}

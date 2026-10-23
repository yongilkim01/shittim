import QtQuick
import "./Search.js" as Search

QtObject {
    id: root
    property var applications: []
    property string query: ""
    property int selectedIndex: 0
    readonly property var indexed: Search.index(applications)
    readonly property var results: Search.filter(indexed, query)
    readonly property var selected: selectedIndex >= 0 && selectedIndex < results.length ? results[selectedIndex] : null
    onQueryChanged: selectedIndex = 0
    onResultsChanged: selectedIndex = Math.max(0, Math.min(selectedIndex, results.length - 1))
    function move(step) {
        if (results.length > 0) selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + step))
    }
    function reset() { query = ""; selectedIndex = 0 }
}

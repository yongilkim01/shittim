import QtQuick

QtObject {
    id: root
    property var windows: []
    property var recent: []
    property var allowedAddresses: []
    property string selectedAddress: ""
    readonly property var entries: windows.filter(window => allowedAddresses.length === 0 || allowedAddresses.indexOf(window.address) >= 0).slice().sort((a, b) => {
        const ar = recent.indexOf(a.address), br = recent.indexOf(b.address)
        return (ar < 0 ? 999 : ar) - (br < 0 ? 999 : br)
    })
    readonly property var selected: entries.find(window => window.address === selectedAddress) || null
    onEntriesChanged: if (!entries.some(window => window.address === selectedAddress)) selectedAddress = entries.length ? entries[0].address : ""
    function start(cycle) {
        const ordered = entries.slice().sort((a, b) => {
            const ar = recent.indexOf(a.address), br = recent.indexOf(b.address)
            return (ar < 0 ? 999 : ar) - (br < 0 ? 999 : br)
        })
        selectedAddress = ordered.length ? ordered[0].address : ""
        if (cycle && ordered.length > 1) selectedAddress = ordered[cycle < 0 ? ordered.length - 1 : 1].address
    }
    function step(direction) {
        if (!entries.length) return
        const index = entries.findIndex(window => window.address === selectedAddress)
        selectedAddress = entries[(index + direction + entries.length) % entries.length].address
    }
}

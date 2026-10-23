import QtQuick

QtObject {
    id: root
    property var entries: []
    property int limit: 100
    property bool dnd: false
    property bool viewed: false
    readonly property var history: entries.filter(entry => !entry.transient)
    readonly property int unread: history.filter(entry => !entry.read).length
    readonly property var popups: entries.filter(entry => entry.popup).sort((a, b) => b.urgency - a.urgency || b.received - a.received).slice(0, 3)
    readonly property real nextDeadline: entries.reduce((next, entry) => entry.live && entry.deadline > 0 ? Math.min(next, entry.deadline) : next, Infinity)
    signal expireRequested(int id)
    signal dismissRequested(int id)
    function get(id) { return entries.find(entry => entry.id === id) || null }
    function replace(id, changes) {
        entries = entries.map(entry => entry.id === id ? Object.assign({}, entry, changes) : entry)
    }
    function receive(data, timestamp) {
        const now = timestamp === undefined ? Date.now() : timestamp
        const old = get(data.id)
        // expireTimeout is milliseconds in the 0.3.2 implementation (despite its header comment).
        const duration = data.timeout < 0 ? (data.urgency === 2 ? 0 : 6000) : Math.min(86400000, Math.max(0, data.timeout))
        const restoring = data.restored && old !== null
        const entry = Object.assign({}, data, {live: true, read: viewed || (restoring ? old.read : data.restored),
            received: restoring ? old.received : now, created: old ? old.created : now, deadline: restoring ? old.deadline : duration > 0 ? now + duration : 0,
            popup: !viewed && !data.restored && (!dnd || data.urgency === 2)})
        entries = restoring ? entries.map(item => item.id === entry.id ? entry : item)
            : [entry].concat(entries.filter(item => item.id !== entry.id))
        while (entries.length > limit) {
            const removed = entries[entries.length - 1]
            entries = entries.slice(0, -1)
            if (removed.live) dismissRequested(removed.id)
        }
    }
    function closed(id, reason) {
        const entry = get(id)
        if (!entry) return
        if (reason === 3 || entry.transient) entries = entries.filter(item => item.id !== id)
        else replace(id, {live: false, popup: false, image: "", actions: [], deadline: 0})
    }
    function dismissPopup(id) {
        const entry = get(id)
        if (!entry) return
        replace(id, {popup: false})
        if (entry.live) dismissRequested(id)
    }
    function remove(id) {
        const entry = get(id)
        entries = entries.filter(item => item.id !== id)
        if (entry && entry.live) dismissRequested(id)
    }
    function clear() {
        const old = entries
        entries = []
        old.filter(entry => entry.live).forEach(entry => dismissRequested(entry.id))
    }
    function restore(saved) {
        // JSON snapshots only; native objects and actions are reacquired by NotificationServer.
        entries = saved.slice(0, limit).map(entry => Object.assign({}, entry, {live: false, popup: false, image: "", actions: []}))
    }
    function markRead() { entries = entries.map(entry => Object.assign({}, entry, {read: true, popup: false})) }
    function expireDue(timestamp) {
        const due = entries.filter(entry => entry.live && entry.deadline > 0 && entry.deadline <= timestamp)
        due.forEach(entry => { replace(entry.id, {deadline: 0, popup: false}); expireRequested(entry.id) })
    }
    onViewedChanged: if (viewed) markRead()
    onDndChanged: if (dnd) entries = entries.map(entry => entry.urgency === 2 ? entry : Object.assign({}, entry, {popup: false}))
}

import QtQuick

// One keyboard owner across monitors; passive surfaces never take a second grab.
QtObject {
    id: root
    property var _state: ({owner:null,screen:null,generation:0})
    readonly property var owner:_state.owner
    readonly property var screen:_state.screen
    readonly property int generation:_state.generation
    readonly property bool blockingPopups: owner !== null && owner.kind === "panel"
    // Last few ownership changes with the reason, for runtime status and diagnostics.
    property var history: []
    function note(participant, event) {
        history=history.concat([{time:Date.now(),name:participant ? participant.name : "",event:event}]).slice(-12)
    }
    function acquire(participant, output) {
        if (!participant || !output) return false
        if (owner === participant && screen === output) return true
        const previous=owner
        const revision=generation+1
        _state={owner:null,screen:null,generation:revision}
        if (previous) previous.revoked("superseded")
        // A close callback cannot overwrite a newer, reentrant request.
        if (owner !== null || generation!==revision) return false
        _state={owner:participant,screen:output,generation:revision}
        note(participant,"open")
        return generation===revision && owner===participant
    }
    function release(participant, reason) {
        if (owner !== participant) return false
        _state={owner:null,screen:null,generation:generation+1}
        note(participant,"close:" + (reason || "dismiss"))
        participant.revoked(reason || "dismiss")
        return true
    }
    function dismiss(reason) { if (owner) release(owner,reason) }
    function forget(participant) { if(owner===participant)_state={owner:null,screen:null,generation:generation+1} }
    function anchorTapped(window, point) {
        if (owner && owner.anchorWindow===window && !owner.containsAnchor(point)) release(owner,"outside")
    }
}

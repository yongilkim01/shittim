.pragma library

function maximized(ipc) { return Number(ipc.fullscreen || 0)===1 || (ipc.tags || []).indexOf("shittim-maximized")>=0 }
function hidden(ipc) { return Boolean(ipc.workspace && /^special:shittim-hidden-\d+-[0-3]-[0-3]-[0-9a-f]+$/.test(ipc.workspace.name)) }
function normalize(window) {
    const ipc=window.lastIpcObject
    return {handle:window,address:window.address,activated:window.activated,title:window.title,
        appId:window.wayland ? window.wayland.appId : "",className:ipc.class || "",initialClass:ipc.initialClass || "",
        floating:Boolean(ipc.floating),fullscreen:Number(ipc.fullscreen || 0),maximized:maximized(ipc),hidden:hidden(ipc),
        monitor:Number(ipc.monitor),at:ipc.at || [0,0],size:ipc.size || [0,0],workspace:ipc.workspace ? ipc.workspace.name : ""}
}

-- Observe pointer presses without consuming them. App CSD dragging remains native.
local snap_command = __SHITTIM_SNAP_COMMAND__
local drag, previous, last_zone, ticks = nil, {}, "", 0
local timer
local sequence=0
local function emit(state, w, zone, monitor)
    if w and w.address and w.address:match("^0x%x+$") then
        sequence=math.max(sequence+1,os.time()*1000000)
        hl.exec_cmd(snap_command .. " " .. state .. " " .. w.address .. " " .. zone .. " " .. tostring(math.floor(monitor or -1)) .. " " .. string.format("%.0f",sequence))
    end
end
local function valid(w)
    return w and w.mapped and w.floating and not w.pinned and not w.group and w.workspace and w.workspace.id > 0 and w.fullscreen ~= 2 and w.fullscreen_client ~= 2
end
local function region(p)
    for _,m in ipairs(hl.get_monitors()) do
        local width,height = m.width / m.scale,m.height / m.scale
        if m.transform % 2 == 1 then width,height=height,width end
        if p.x >= m.x and p.x < m.x+width and p.y >= m.y and p.y < m.y+height then
            local left,right,top,bottom=p.x-m.x<22,m.x+width-p.x<22,p.y-m.y<22,m.y+height-p.y<22
            if left and p.y-m.y<64 then return "top-left",m.id end
            if right and p.y-m.y<64 then return "top-right",m.id end
            if left and m.y+height-p.y<64 then return "bottom-left",m.id end
            if right and m.y+height-p.y<64 then return "bottom-right",m.id end
            if top and p.x-m.x<64 then return "top-left",m.id end
            if top and m.x+width-p.x<64 then return "top-right",m.id end
            if bottom and p.x-m.x<64 then return "bottom-left",m.id end
            if bottom and m.x+width-p.x<64 then return "bottom-right",m.id end
            if left then return "left",m.id end
            if right then return "right",m.id end
            if top then return "top",m.id end
            return "none",m.id
        end
    end
    return "none",-1
end
local function cancel()
    if drag and drag.previewed then emit("clear",drag.window,"none",-1) end
    drag=nil; last_zone=""; timer:set_enabled(false)
end
local function update()
    if not drag then return end
    ticks=ticks+1
    local w,p=drag.window,hl.get_cursor_pos()
    if ticks>600 or not valid(w) or not p then cancel(); return end
    -- Focus is assigned after the original press; take the first timer sample.
    if not drag.sampled then
        w=hl.get_active_window()
        if not valid(w) then cancel(); return end
        if drag.window.address~=w.address then
            drag.at={x=w.at.x,y=w.at.y}; drag.size={x=w.size.x,y=w.size.y}; drag.pointer=p
        end
        drag.window=w; drag.sampled=true
        return
    end
    local moved=math.abs(w.at.x-drag.at.x)+math.abs(w.at.y-drag.at.y)>6
    if math.abs(w.size.x-drag.size.x)+math.abs(w.size.y-drag.size.y)>3 then previous[w.address]=nil; cancel(); return end
    if not moved then return end
    if math.abs(p.x-drag.pointer.x)+math.abs(p.y-drag.pointer.y)<6 then return end
    if not drag.moved and math.abs((w.at.x-drag.at.x)-(p.x-drag.pointer.x))+math.abs((w.at.y-drag.at.y)-(p.y-drag.pointer.y))>24 then return end
    drag.moved=true
    local old=previous[w.address]
    if old and not drag.restored then
        local ratio=math.max(0,math.min(1,(p.x-w.at.x)/math.max(w.size.x,1)))
        if w.fullscreen==1 then hl.dispatch(hl.dsp.window.fullscreen({window=w,mode="maximized",action="unset"})) end
        hl.dispatch(hl.dsp.window.resize({window=w,x=old.width,y=old.height,relative=false}))
        hl.dispatch(hl.dsp.window.move({window=w,x=math.floor(p.x-old.width*ratio),y=math.floor(p.y-18),relative=false}))
        drag.size={x=old.width,y=old.height}; drag.restored=true; previous[w.address]=nil
    end
    local zone,monitor=region(p)
    local key=zone .. tostring(monitor)
    if key~=last_zone then
        if zone~="none" or drag.previewed then emit("preview",w,zone,monitor); drag.previewed=true end
        last_zone=key
    end
    drag.zone=zone; drag.monitor=monitor
end
timer=hl.timer(update,{timeout=40,type="repeat"})
timer:set_enabled(false)
hl.bind("mouse:272",function()
    local w,p=hl.get_active_window(),hl.get_cursor_pos()
    if not valid(w) or not p then return end
    drag={window=w,pointer=p,at={x=w.at.x,y=w.at.y},size={x=w.size.x,y=w.size.y}}; last_zone=""; ticks=0; timer:set_enabled(true)
end,{non_consuming=true,transparent=true,ignore_mods=true})
hl.bind("mouse:272",function()
    if drag then
        update()
        if drag and drag.moved and drag.zone and drag.zone~="none" then
            local w=drag.window
            previous[w.address]=previous[w.address] or {x=drag.at.x,y=drag.at.y,width=drag.size.x,height=drag.size.y}
            emit("commit",w,drag.zone,drag.monitor)
        end
    end
    cancel()
end,{release=true,non_consuming=true,transparent=true,ignore_mods=true})
hl.on("window.close",function(w) if w then previous[w.address]=nil end end)

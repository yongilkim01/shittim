// Included in the pinned hyprbars source after its own declarations and headers.
void CHyprBar::clearShittimHover() {
    if (m_shittimHoverPayload.empty()) return;
    if (g_pEventManager)
        g_pEventManager->postEvent({"shittim_titlebar_hover", m_shittimHoverPayload.substr(0, m_shittimHoverPayload.find(',')) + ",leave"});
    m_shittimHoverPayload.clear();
    m_shittimHoverIndex = -1;
    if (validMapped(m_pWindow)) damageEntire();
}

void CHyprBar::updateShittimHover() {
    if (!validMapped(m_pWindow) || m_hidden || !g_pGlobalState->config.enabled->value() ||
        !m_pWindow->m_ruleApplicator->decorate().valueOrDefault() || !inputIsValid()) {
        clearShittimHover(); return;
    }
    if (!(__SHITTIM_UNDER_CURSOR__)) { clearShittimHover(); return; }
    const auto monitor = m_pWindow->m_monitor.lock();
    if (!monitor) { clearShittimHover(); return; }
    const auto box = assignedBoxGlobal();
    const auto cursor = cursorRelativeToBar();
    const auto height = g_pGlobalState->config.barHeight->value();
    const auto padding = g_pGlobalState->config.barButtonPadding->value();
    const bool right = g_pGlobalState->config.barButtonsAlignment->value() != "left";
    const auto count = getVisibleButtonCount(padding, g_pGlobalState->config.barPadding->value(), Vector2D{box.w, height}, 1.0);
    double offset = g_pGlobalState->config.barPadding->value();
    for (size_t index = 0; index < count; ++index) {
        const auto& button = g_pGlobalState->buttons[index];
        const ShittimHUD::HoverRect hit{right ? box.w - offset - button.size : offset, (height - button.size) / 2.0, button.size, button.size};
        offset += padding + button.size;
        const ShittimHUD::HoverRect click{hit.x - (right ? padding : 0), hit.y, hit.width + padding, hit.height};
        if (!ShittimHUD::isControl(button.icon) || !ShittimHUD::contains(click, cursor.x, cursor.y)) continue;
        const auto icon = ShittimHUD::displayIcon(button.icon, button.icon == "□" && (__SHITTIM_MAXIMIZED__));
        const auto action = icon == "×" ? "close" : icon == "−" ? "minimize" : icon == "restore" ? "restore" : "maximize";
        const auto payload = std::format("{:x},{},{},{},{},{},{}", reinterpret_cast<uintptr_t>(m_pWindow.lock().get()), action, monitor->m_id,
            std::round(box.x + hit.x - monitor->m_position.x), std::round(box.y + hit.y - monitor->m_position.y), button.size, button.size);
        if (payload != m_shittimHoverPayload) {
            m_shittimHoverIndex = static_cast<int>(index);
            m_shittimHoverPayload = payload;
            if (g_pEventManager) g_pEventManager->postEvent({"shittim_titlebar_hover", payload});
            damageEntire();
        }
        return;
    }
    clearShittimHover();
}

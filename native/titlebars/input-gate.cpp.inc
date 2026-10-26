// Drawing and input must agree, including zero-height decorations on CSD windows.
if (!validMapped(m_pWindow) || m_hidden || !g_pGlobalState->config.enabled->value() ||
    !m_pWindow->m_ruleApplicator->decorate().valueOrDefault() ||
    g_pGlobalState->config.barHeight->value() <= 0)
    return false;
const auto SHITTIM_INPUT_BOX = assignedBoxGlobal();
if (SHITTIM_INPUT_BOX.w <= 0 || SHITTIM_INPUT_BOX.h <= 0)
    return false;

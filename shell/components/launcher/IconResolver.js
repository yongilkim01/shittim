function resolve(app, lookup, bundledIcon) {
    if (app.iconFile) return app.iconFile
    const names = app.icons || []
    for (const name of names) {
        const path = lookup(name)
        if (path.length > 0) return path
    }
    if (app.id === "nemo.desktop" || names.indexOf("system-file-manager") >= 0)
        return bundledIcon("system-file-manager")
    return lookup("application-x-executable") || bundledIcon("application-x-executable")
}

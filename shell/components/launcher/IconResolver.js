function resolve(app, lookup, bundledIcon) {
    if (app.iconFile) return app.iconFile
    const names = app.icons || []
    if (app.id === "org.shittim.Files.desktop" || app.id === "nemo.desktop" || names.indexOf("system-file-manager") >= 0)
        return bundledIcon("system-file-manager")
    if (app.id === "kitty.desktop" || names.indexOf("kitty") >= 0)
        return bundledIcon("utilities-terminal")
    for (const name of names) {
        const path = lookup(name)
        if (path.length > 0) return path
    }
    return lookup("application-x-executable") || bundledIcon("application-x-executable")
}

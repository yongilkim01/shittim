function resolve(app, lookup, bundledIcon, bundledPlaceIcon) {
    if (app.iconFile) return app.iconFile
    const names = app.icons || []
    if (app.directory && bundledPlaceIcon) {
        const places = ["user-home", "folder-projects", "user-trash", "folder", "user-desktop", "folder-documents", "folder-download", "folder-music", "folder-pictures", "folder-videos"]
        const place = names.find(name => places.indexOf(name) >= 0)
        if (place) return bundledPlaceIcon(place)
    }
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

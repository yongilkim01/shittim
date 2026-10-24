// Startup errors and protocol errors are handled separately; warnings are not failures.
function isFailure(line) {
    return /Traceback \(most recent call last\):|Fatal Python error:|(?:GLib|Gio|GObject)(?:-[A-Za-z]+)?-ERROR\b/.test(String(line))
}

.pragma library

function normalize(text) {
    return String(text || "").normalize("NFKC").toLocaleLowerCase()
}

function index(applications) {
    return applications.map(app => ({app: app, name: normalize(app.name),
        metadata: normalize([app.genericName || "", (app.keywords || []).join(" "), app.id].join(" "))}))
}

function filter(indexed, query) {
    const terms = normalize(query).trim().split(/\s+/).filter(term => term.length > 0)
    const matches = []
    for (const entry of indexed) {
        let score = 0, found = true
        for (const term of terms) {
            const position = entry.name.indexOf(term)
            if (position === 0) score += entry.name === term ? 0 : 1
            else if (position > 0) score += 2
            else if (entry.metadata.indexOf(term) >= 0) score += 4
            else { found = false; break }
        }
        if (found) matches.push({app: entry.app, score: score})
    }
    matches.sort((a, b) => a.score - b.score || a.app.name.localeCompare(b.app.name) || a.app.id.localeCompare(b.app.id))
    return matches.map(match => match.app)
}

// Window identities survive TasksModel's active-child reordering. Never retain QModelIndex.
.pragma library
function identity(ids) {
    if (!ids || !ids.length) return "";
    return Array.from(ids, String).sort().join("|");
}
function ordered(windows) {
    return windows.slice().sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
}
// LastActivated is exposed by Plasma 6.8's taskmanager.qmltypes. Its value is
// a timestamp (QDateTime converts to Date). Fall back to observed activations
// when the backend supplies no timestamps, with identities as a stable tie-break.
function activationOrder(windows, history, app) {
    const hasDates = windows.some(w => w.lastActivated > 0);
    const stamp = w => hasDates ? w.lastActivated : (history[app + "|" + w.id] || 0);
    return ordered(windows).sort((a, b) => stamp(a) - stamp(b) || Number(a.active) - Number(b.active));
}

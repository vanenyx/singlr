// Window identities survive TasksModel's active-child reordering. Never retain QModelIndex.
.pragma library
function identity(ids) {
    if (!ids || !ids.length) return "";
    return Array.from(ids, String).sort().join("|");
}
function ordered(windows) {
    return windows.slice().sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
}
function next(windows, last, direction) {
    const list = ordered(windows);
    if (!list.length) return "";
    let current = list.findIndex(w => w.id === last);
    if (current < 0) current = list.findIndex(w => w.active);
    if (current < 0) return direction < 0 ? list[list.length - 1].id : list[0].id;
    return list[(current + direction + list.length) % list.length].id;
}
function recent(windows, last) {
    const active = windows.find(w => w.active);
    if (active) return active.id;
    const dated = windows.slice().sort((a, b) => b.lastActivated - a.lastActivated);
    if (dated.length && dated[0].lastActivated > 0) return dated[0].id;
    return windows.some(w => w.id === last) ? last : (windows[0]?.id || "");
}

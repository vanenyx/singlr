// Window identities survive TasksModel's active-child reordering. Never retain QModelIndex.
.pragma library
function identity(ids) {
    if (!ids || !ids.length) return "";
    return Array.from(ids, String).sort().join("|");
}
function ordered(windows) {
    return windows.slice().sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
}

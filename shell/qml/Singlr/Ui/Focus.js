.pragma library

function belongsTo(item, root) {
    for (let current = item; current; current = current.parent)
        if (current === root) return true;
    return false;
}

// Keep keyboard traversal inside a surface, including at either end of a list.
function advance(root, origin, forward) {
    let current = origin || root;
    const visited = new Set();
    while (current && !visited.has(current)) {
        visited.add(current);
        current = current.nextItemInFocusChain(forward);
        if (!current) return;
        if (current !== root && belongsTo(current, root) && current.activeFocusOnTab
                && current.visible && current.enabled) {
            current.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
            return;
        }
    }
}

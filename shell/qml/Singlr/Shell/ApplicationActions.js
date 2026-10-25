.pragma library

function entries(bridge, url) {
    if (!url || !bridge || typeof bridge.applicationActions !== "function") return [];
    return Array.from(bridge.applicationActions(url), a => ({
        label: a.text, iconName: a.iconName, action: "application", name: a.name, url: url, enabled: true
    }));
}

function hasNewWindow(actions) {
    // Desktop Entry defines no semantic type for actions. Match established IDs
    // (Chrome/Firefox/Dolphin/Kate), independent of the translated display text.
    return actions.some(a => /^(newwindow|newemptywindow|windownew|opennewwindow)$/.test(
        String(a.name).toLowerCase().replace(/[^a-z]/g, "")));
}

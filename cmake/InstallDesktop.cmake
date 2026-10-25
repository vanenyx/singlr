# Keep source launchers usable for development; configure only the installed copies.
set(SINGLR_ROOT "${KDE_INSTALL_FULL_LIBDIR}/singlr")
function(singlr_configure_path source output)
    file(READ "${PROJECT_SOURCE_DIR}/${source}" content)
    string(REPLACE "/usr/lib/singlr" "${SINGLR_ROOT}" content "${content}")
    file(WRITE "${PROJECT_BINARY_DIR}/${output}" "${content}")
endfunction()
singlr_configure_path(session/startsinglr-wayland startsinglr-wayland)
singlr_configure_path(session/systemd/singlr-kwin-recover.service singlr-kwin-recover.service)
singlr_configure_path(session/singlr.desktop singlr.desktop)
singlr_configure_path(session/systemd/singlr-shell.service singlr-shell.service)
singlr_configure_path(session/systemd/singlr-shell-failed.service singlr-shell-failed.service)
singlr_configure_path(apps/settings/singlr-settings singlr-settings)
install(PROGRAMS "${PROJECT_BINARY_DIR}/startsinglr-wayland" DESTINATION "${KDE_INSTALL_LIBDIR}/singlr")
install(PROGRAMS "${PROJECT_BINARY_DIR}/singlr-settings" DESTINATION "${KDE_INSTALL_BINDIR}")
install(FILES "${PROJECT_BINARY_DIR}/singlr.desktop" DESTINATION "${KDE_INSTALL_DATADIR}/wayland-sessions")
install(FILES "${PROJECT_BINARY_DIR}/singlr-shell.service" session/systemd/singlr-workspace.target
    "${PROJECT_BINARY_DIR}/singlr-shell-failed.service"
    DESTINATION "${KDE_INSTALL_SYSTEMDUSERUNITDIR}")
install(FILES apps/settings/singlr-settings.desktop DESTINATION "${KDE_INSTALL_APPDIR}")
# Main.qml is delivered by Codex 1. Fail at install time if it has not been integrated.
install(DIRECTORY apps/settings/ DESTINATION "${KDE_INSTALL_LIBDIR}/singlr/apps/settings"
    FILES_MATCHING PATTERN "*.qml" PATTERN "*.js" PATTERN "qmldir")
install(CODE "if(NOT EXISTS \"${PROJECT_SOURCE_DIR}/apps/settings/Main.qml\")\n message(FATAL_ERROR \"Integrate apps/settings/Main.qml before packaging\")\nendif()")
install(DIRECTORY shell/qml/ DESTINATION "${KDE_INSTALL_FULL_LIBDIR}/singlr/qml"
    FILES_MATCHING PATTERN "*.qml" PATTERN "*.js" PATTERN "qmldir" PATTERN "tests" EXCLUDE)
# Source Theme.qml addresses fonts relative to the repository root. Adapt only
# the generated installation copy, keeping all assets private to Singlr.
file(READ "${PROJECT_SOURCE_DIR}/shell/qml/Singlr/Ui/Theme.qml" theme)
string(REPLACE "../../../../third_party/" "../../../third_party/" theme "${theme}")
file(WRITE "${PROJECT_BINARY_DIR}/Theme.qml" "${theme}")
install(FILES "${PROJECT_BINARY_DIR}/Theme.qml" DESTINATION "${KDE_INSTALL_LIBDIR}/singlr/qml/Singlr/Ui")
install(DIRECTORY third_party/ DESTINATION "${KDE_INSTALL_LIBDIR}/singlr/third_party"
    FILES_MATCHING PATTERN "*.ttf" PATTERN "LICENSE*")
install(DIRECTORY decoration/aurorae/Singlr DESTINATION "${KDE_INSTALL_DATADIR}/aurorae/themes"
    FILES_MATCHING PATTERN "*.svg" PATTERN "*.json" PATTERN "*.desktop" PATTERN "*rc")
foreach(kind effects scripts)
    if(kind STREQUAL "effects")
        set(package singlr-overview)
    else()
        set(package singlr-gestures)
    endif()
    install(DIRECTORY "kwin/${kind}/${package}" DESTINATION "${KDE_INSTALL_DATADIR}/kwin/${kind}"
        FILES_MATCHING PATTERN "*.qml" PATTERN "*.js" PATTERN "*.json" PATTERN "qmldir"
        PATTERN "tools" EXCLUDE)  # utilidades de desarrollo, no se instalan
endforeach()

# Shared transaction helper and offline recovery before the standard Plasma KWin.
install(PROGRAMS session/singlr-kwin DESTINATION "${KDE_INSTALL_LIBDIR}/singlr")
install(FILES session/singlr_kwin.py DESTINATION "${KDE_INSTALL_LIBDIR}/singlr")
install(FILES "${PROJECT_BINARY_DIR}/singlr-kwin-recover.service"
    DESTINATION "${KDE_INSTALL_SYSTEMDUSERUNITDIR}")
install(FILES session/systemd/plasma-kwin_wayland.service.d/50-singlr-recovery.conf
    DESTINATION "${KDE_INSTALL_SYSTEMDUSERUNITDIR}/plasma-kwin_wayland.service.d")

add_subdirectory(session/appearance)
install(DIRECTORY session/look-and-feel/ DESTINATION "${KDE_INSTALL_DATADIR}/plasma/look-and-feel")
install(FILES session/xdg/kdeglobals DESTINATION "${KDE_INSTALL_LIBDIR}/singlr/xdg")

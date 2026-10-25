# Private, independently loadable Plasma/Shell package; never replaces Plasma's package.
set(SINGLR_SHELL_PACKAGE_DIR "${KDE_INSTALL_DATADIR}/plasma/shells/org.singlr.desktop")
install(DIRECTORY session/shell-package/org.singlr.desktop/
    DESTINATION "${SINGLR_SHELL_PACKAGE_DIR}"
    FILES_MATCHING PATTERN "*.json" PATTERN "*.qml" PATTERN "*.js"
    PATTERN "*.xml" PATTERN "qmldir")
# Greeter cannot rely on the shell executable's import path or registered singletons.
install(FILES third_party/inter/InterVariable.ttf third_party/phosphor/Phosphor.ttf
    DESTINATION "${SINGLR_SHELL_PACKAGE_DIR}/contents/fonts")
install(FILES third_party/inter/LICENSE.txt DESTINATION "${SINGLR_SHELL_PACKAGE_DIR}/contents/fonts" RENAME Inter-LICENSE.txt)
install(FILES third_party/phosphor/LICENSE DESTINATION "${SINGLR_SHELL_PACKAGE_DIR}/contents/fonts" RENAME Phosphor-LICENSE.txt)

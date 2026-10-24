# Base técnica

La primera base de Singlr es Plasma 6. Qt Quick/QML, estilos de Plasma y scripting de KWin son opciones por validar según los escenarios de producto. Quickshell es una opción futura, no una dependencia seleccionada.

Este repositorio contiene únicamente preparación. No se ha elegido aún sistema de compilación, estructura de componentes, contrato de servicios, versión mínima concreta de KDE/Qt ni empaquetado. No crear un proyecto web o dependencias de Node para sustituir estas decisiones.

Antes de implementar: inventariar Qt/KDE, contrastar APIs oficiales, proponer límites entre componentes y acordar un entorno de prueba separado de la sesión diaria. Cada propuesta debe incluir motivo, compatibilidad, verificación y reversión.

Fuentes para investigación futura: [Qt](https://doc.qt.io/), [desarrollo de Plasma](https://develop.kde.org/docs/plasma/), [KWin scripting](https://develop.kde.org/docs/plasma/kwin/).

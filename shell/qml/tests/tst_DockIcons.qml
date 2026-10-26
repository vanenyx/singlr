import QtQuick
import QtTest
import Singlr.Ui
import Singlr.Shell

Item {
    id: fixture
    width: 300; height: 160
    DockAppIcon { id: icon; width: 32; height: 32 }
    DockItem { id: tile; x: 80; task: ({AppName: "Prueba", IsWindow: true, decoration: ""}) }
    TestCase {
        name: "DockIcons"; when: windowShown
        function test_visibleBounds_data() {
            return [27, 32, 37, 43, 48].map(size => ({tag: String(size), size: size}));
        }
        function test_visibleBounds(data) {
            icon.width = data.size; icon.height = data.size;
            icon.source = Qt.resolvedUrl("fixtures/padded-logo.svg");
            const mark = findChild(icon, "dockBrandIcon");
            compare(mark.roundToIconSize, false);
            compare(icon.inkBounds, Qt.rect(.25, .125, .5, .75));
            const extent = mark.width * mark.scale;
            const left = mark.x + extent * icon.inkBounds.x;
            const top = mark.y + extent * icon.inkBounds.y;
            const width = extent * icon.inkBounds.width;
            const height = extent * icon.inkBounds.height;
            fuzzyCompare((left + width / 2), data.size / 2, .01);
            fuzzyCompare((top + height / 2), data.size / 2, .01);
            fuzzyCompare(height, data.size - 2, .01);
            verify(left >= 0 && top >= 0 && left + width <= data.size && top + height <= data.size);
        }
        function test_sourceReplacementAndMissingIcon() {
            icon.source = Qt.resolvedUrl("fixtures/full-logo.svg");
            compare(icon.inkBounds, Qt.rect(0, 0, 1, 1));
            icon.source = "singlr-missing-icon-test";
            compare(icon.inkBounds, Qt.rect(0, 0, 1, 1));
            verify(isFinite(icon.renderExtent));
        }
        function test_centeredAndAccessibleState() {
            const image = findChild(tile, "dockBrandIcon").parent;
            for (const height of [40, 48, 56, 64, 72]) {
                tile.dockHeight = height;
                const point = image.mapToItem(tile, 0, 0);
                // Qt centers odd-sized items on the nearest logical pixel.
                fuzzyCompare(point.y + image.height / 2, height / 2, .51);
            }
            compare(tile.Accessible.description, "Aplicación abierta");
            tile.task = ({AppName: "Prueba", IsLauncher: true});
            compare(tile.Accessible.description, "Iniciar aplicación");
        }
    }
}

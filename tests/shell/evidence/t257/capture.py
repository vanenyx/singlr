#!/usr/bin/env python3
"""T257: three historical/proposed variants with installed app icons, isolated XDG."""
from pathlib import Path
import os,tempfile,subprocess
root=Path(__file__).resolve().parents[4]; out=root/'tests/shell/evidence/t257'; out.mkdir(exist_ok=True)
base=subprocess.check_output(['git','show','a9b9763:shell/qml/Singlr/Shell/DockItem.qml'], cwd=root, text=True)
start=base.index('    Rectangle {\n        anchors.horizontalCenter: parent.horizontalCenter\n        y: tile.height - height')
end=base.index('    // MouseArea keeps',start)
box=base[:start]+base[end:]
box=box.replace('anchors.horizontalCenter: parent.horizontalCenter; y: Math.round(5 * tile.sizeFactor);','anchors.centerIn: parent;').replace('AppIcon { visible:', 'AppIcon { roundToIconSize: false; visible:')
with tempfile.TemporaryDirectory(prefix='singlr-t257-capture-') as t:
 p=Path(t);(p/'runtime').mkdir(mode=0o700)
 (p/'before').mkdir()
 (p/'before/DockItem.qml').write_text(base)
 (p/'before/BoxDockItem.qml').write_text(box)
 qml='''import QtQuick
import QtTest
import Singlr.Ui
import Singlr.Shell
import "file:///tmp/singlr-t257-before" as Before
Item {
 id: fixture; width:1024; height:560
 property int dockHeight:48
 property var apps:[{name:"Dolphin",icon:"org.kde.dolphin"},{name:"Konsole",icon:"utilities-terminal"},{name:"Firefox",icon:"firefox"},{name:"Warp",icon:"dev.warp.Warp"},{name:"Codex",icon:"chatgpt"},{name:"Chrome",icon:"google-chrome"}]
 Rectangle { anchors.fill:parent; color:Theme.background }
 UiText { x:40; y:16; text:"Dock · tamaño visible de las marcas originales"; font.pixelSize:18 }
 UiText { x:40; y:62; text:"Antes · indicador de abierta y márgenes de cada icono"; color:Theme.secondary }
 Rectangle { x:40;y:98;width:944;height:fixture.dockHeight;radius:14;color:Theme.dockSurface;border.color:Theme.border }
 Row { x:80;y:98;spacing:72
  Repeater { model:fixture.apps
   Before.DockItem { required property var modelData; dockHeight:fixture.dockHeight; task:({AppName:modelData.name,decoration:modelData.icon,IsWindow:true,IsActive:true}) }
  }
 }
 UiText { x:40; y:220; text:"Variante 1 · sin punto, caja uniforme sin compensar márgenes"; color:Theme.secondary }
 Rectangle { x:40;y:256;width:944;height:fixture.dockHeight;radius:14;color:Theme.dockSurface;border.color:Theme.border }
 Row { x:80;y:256;spacing:72
  Repeater { model:fixture.apps
   Before.BoxDockItem { required property var modelData; dockHeight:fixture.dockHeight; task:({AppName:modelData.name,decoration:modelData.icon,IsWindow:true,IsActive:true}) }
  }
 }
 UiText { x:40; y:378; text:"Variante 2 · sin punto, tamaño visible y centro compensados"; color:Theme.secondary }
 Rectangle { x:40;y:414;width:944;height:fixture.dockHeight;radius:14;color:Theme.dockSurface;border.color:Theme.border }
 Row { x:80;y:414;spacing:72
  Repeater { model:fixture.apps
   DockItem { required property var modelData; dockHeight:fixture.dockHeight; task:({AppName:modelData.name,decoration:modelData.icon,IsWindow:true,IsActive:true}) }
  }
 }
 TestCase { name:"DockPolishCapture";when:windowShown
  function test_capture() {
   for(const mode of ["dark","light"]) for(const size of [48,72]) {
    Theme.dark=mode==="dark";fixture.dockHeight=size;wait(150);let done=false;
    verify(fixture.grabToImage(result=>{verify(result.saveToFile("OUTPUT/"+mode+"-"+size+".png"));done=true;}));tryVerify(()=>done);
   }
  }
 }
}'''.replace('OUTPUT',str(out)).replace('file:///tmp/singlr-t257-before',(p/'before').as_uri())
 (p/'tst_Capture.qml').write_text(qml)
 env=os.environ|{'QT_QPA_PLATFORM':'offscreen','QT_QPA_PLATFORMTHEME':'kde','QT_QUICK_BACKEND':'software','QT_FORCE_STDERR_LOGGING':'1','XDG_CONFIG_HOME':t+'/config','XDG_DATA_HOME':t+'/data','XDG_CACHE_HOME':t+'/cache','XDG_STATE_HOME':t+'/state','XDG_RUNTIME_DIR':t+'/runtime','DBUS_SESSION_BUS_ADDRESS':'unix:path=/nonexistent','DBUS_SYSTEM_BUS_ADDRESS':'unix:path=/nonexistent'}
 r=subprocess.run(['/usr/lib/qt6/bin/qmltestrunner','-import',str(root/'build/qml'),'-import',str(root/'shell/qml'),'-input',str(p/'tst_Capture.qml')],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=20)
 Path('/tmp/singlr-t257-capture.log').write_text(r.stdout);print(r.returncode);print('\n'.join(l for l in r.stdout.splitlines() if 'FAIL' in l or 'Totals:' in l))

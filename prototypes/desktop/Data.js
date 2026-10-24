.pragma library
var apps = [
    {name:"Archivos", icon:"folder", logo:"file:///usr/share/icons/hicolor/scalable/apps/org.kde.dolphin.svg",kind:"files"},
    {name:"Terminal", icon:"terminal", logo:"file:///usr/share/icons/breeze/apps/48/utilities-terminal.svg",kind:"terminal"},
    {name:"Tareas", icon:"check-circle",logo:"",kind:"tasks"},
    {name:"Firefox",icon:"circle",logo:"file:///usr/share/icons/hicolor/scalable/apps/firefox.svg",kind:"browser"}
];
var files = [
    ["Interfaz","Carpeta","12 elementos","Hoy, 10:18","folder"],
    ["Identidad","Carpeta","8 elementos","Ayer, 16:40","folder"],
    ["Referencias","Carpeta","6 elementos","23 oct, 09:12","folder"],
    ["Brief del escritorio.md","Markdown","18 KB","Hoy, 09:42","file-text"],
    ["Notas de interacción.md","Markdown","6 KB","Ayer, 18:05","file-text"],
    ["Tokens.json","JSON","4 KB","23 oct, 14:30","file-code"],
    ["README.md","Markdown","3 KB","22 oct, 11:04","file-text"]
];
var tasks = [
    ["En curso", "2"],
    ["SG-104","Refinar el escritorio integrado","Interfaz","circle-dashed","Hoy"],
    ["SG-102","Definir los estados del lanzador","Interacción","circle-dashed","Hoy"],
    ["Pendientes", "4"],
    ["SG-108","Revisar el contraste del modo claro","Interfaz","circle","Lun"],
    ["SG-107","Navegar entre espacios con teclado","Interacción","circle","Lun"],
    ["SG-106","Ajustar los controles de audio","Sistema","circle","Mar"],
    ["SG-105","Validar el material de los paneles","Interfaz","circle","Mar"],
    ["Completadas", "2"],
    ["SG-101","Organizar las referencias de diseño","Proyecto","check-circle","Ayer"],
    ["SG-100","Preparar el entorno aislado","Sistema","check-circle","Ayer"]
];
var results = [
    {section:"Aplicaciones",title:"Archivos",subtitle:"Explorar carpetas y documentos",accessory:"Aplicación",icon:"folder",app:0,kind:"files"},
    {section:"Aplicaciones",title:"Terminal",subtitle:"Konsole",accessory:"Aplicación",icon:"terminal",app:1,kind:"terminal"},
    {section:"Aplicaciones",title:"Tareas",subtitle:"Proyecto Singlr",accessory:"Aplicación",icon:"check-circle",app:2,kind:"tasks"},
    {section:"Aplicaciones",title:"Firefox",subtitle:"Navegador web",accessory:"Aplicación",icon:"circle",app:3,kind:"browser"},
    {section:"Recientes",title:"Brief del escritorio.md",subtitle:"Proyectos / Singlr",accessory:"Documento",icon:"file-text",app:-1,kind:"files"},
    {section:"Comandos",title:"No molestar",subtitle:"Activar o desactivar",accessory:"Sistema",icon:"moon",app:-1,kind:"dnd"},
    {section:"Comandos",title:"Cambiar apariencia",subtitle:"Alternar entre claro y oscuro",accessory:"Sistema",icon:"sun",app:-1,kind:"mode"}
];
function normalize(s) { return s.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,""); }
function filter(query) { var q=normalize(query.trim()); return results.filter(function(r) { return normalize(r.title+" "+r.subtitle+" "+r.section).indexOf(q)!==-1; }); }

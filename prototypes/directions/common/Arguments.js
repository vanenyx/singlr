.pragma library
function value(args, name, fallback) {
    var prefix = "--" + name + "=";
    for (var i=args.length-1;i>=0;--i)
        if (args[i].indexOf(prefix)===0) return args[i].slice(prefix.length);
    return fallback;
}
function material(args, fallback) {
    var name=value(args,"material",fallback);
    return ({mate:0,matte:0,glass:1,cristal:1,liquid:2})[name] ?? 1;
}

import java.nio.file.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.vm.*;
import se.krka.kahlua.luaj.compiler.LuaCompiler;

// Runs real mod Lua under the installed game's Kahlua VM, without starting a save.
// UI/world objects remain explicit mocks; this is not multiplayer integration QA.
public class EngineLua {
    public static void main(String[] args) throws Exception {
        var platform = J2SEPlatform.getInstance();
        var env = platform.newEnvironment();
        var thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        env.rawset("print", (JavaFunction)(frame, n) -> {
            for (int i=0; i<n; i++) System.out.print((i==0 ? "" : "\t") + frame.get(i));
            System.out.println();
            return 0;
        });
        var root = Path.of(args[0]);
        env.rawset("loadFile", (JavaFunction)(frame, n) -> {
            try {
                var path = Path.of((String)frame.get(0));
                var closure = LuaCompiler.loadstring(Files.readString(path), path.toString(), env);
                frame.push(closure);
                return 1;
            } catch (Exception e) { throw new RuntimeException(e); }
        });
        String prefix = "arg={[1]='" + root.toString().replace('\\','/') + "'}; "
            + "package={path='',loaded={},preload={}}; "
            + "function dofile(p) return loadFile(p)() end; "
            + "function require(name) if package.loaded[name] then return package.loaded[name] end; "
            + "local f=package.preload[name]; if not f then "
            + "for part in string.gmatch(package.path, '[^;]+') do "
            + "local path=string.gsub(part,'?',(string.gsub(name,'%.','/'))); "
            + "local ok,v=pcall(loadFile,path); if ok then f=v; break end end end; "
            + "assert(f,'Module missing: '..name); local v=f(); package.loaded[name]=v or true; return package.loaded[name] end; ";
        String source = prefix + Files.readString(Path.of(args[1]));
        var closure = LuaCompiler.loadstring(source, args[1], env);
        Object[] result = thread.pcall(closure, new Object[0]);
        if (!Boolean.TRUE.equals(result[0])) {
            for (Object v : result) System.err.println(v);
            System.exit(1);
        }
        System.out.println("PASS: installed Project Zomboid Kahlua VM execution");
    }
}

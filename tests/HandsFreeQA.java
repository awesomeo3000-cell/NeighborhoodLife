import java.lang.instrument.Instrumentation;
import java.lang.reflect.Field;
import java.nio.file.*;

/** Isolated QA launcher only. Never installed into the production mod. */
public final class HandsFreeQA {
    static Object read(Class<?> c, Object instance, String name) throws Exception {
        Field f=c.getDeclaredField(name); f.setAccessible(true); return f.get(instance);
    }
    public static void premain(String profile, Instrumentation ignored) {
        profile = profile.replace('\\', '/');
        if (!profile.startsWith("E:/pzmod/test-profile")) throw new IllegalArgumentException("isolated QA profile required");
        String command=System.getProperty("sun.java.command","").replace('\\','/');
        if (!command.contains("-cachedir="+profile)) throw new IllegalArgumentException("Isolated cachedir required");
        Thread worker=new Thread(() -> {
            try {
                ClassLoader cl=ClassLoader.getSystemClassLoader();
                Class<?> window=Class.forName("zombie.GameWindow",false,cl);
                Class<?> loading=Class.forName("zombie.gameStates.GameLoadingState",false,cl);
                Object completed=null;
                for (int i=0;i<1200;i++) {
                    Thread.sleep(500);
                    Object machine=window.getField("states").get(null);
                    if(machine==null) continue;
                    Object current=machine.getClass().getField("current").get(machine);
                    if(current==null || !loading.isInstance(current) || current==completed) continue;
                    if(!(Boolean)read(loading,null,"done") || !(Boolean)read(loading,null,"showedClickToSkip")) continue;
                    if((Boolean)read(loading,null,"unexpectedError") || (Boolean)read(loading,null,"worldVersionError")
                        || (Boolean)read(loading,null,"mapDownloadFailed") || (Boolean)read(loading,null,"playerWrongIP")) continue;
                    // The game's update still checks its streamer and animation readiness.
                    // No OS input, no forced state transition, no change to the game jar.
                    Field force=loading.getDeclaredField("forceDone"); force.setAccessible(true); force.setBoolean(current,true);
                    completed=current;
                    Files.writeString(Path.of(profile,"hands-free-qa.log"),"PASS: ready loading screen acknowledged without OS input\n",StandardOpenOption.CREATE,StandardOpenOption.APPEND);
                }
            } catch(Exception ex) {
                try { Files.writeString(Path.of(profile,"hands-free-qa.log"),"FAIL: "+ex+"\n",StandardOpenOption.CREATE,StandardOpenOption.APPEND); }
                catch(Exception ignoredError) { ex.printStackTrace(); }
            }
        },"Neighborhood-QA-start");
        worker.setDaemon(true); worker.start();
    }
}

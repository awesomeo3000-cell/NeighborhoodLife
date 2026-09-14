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
        final String qaProfile = profile;
        String command=System.getProperty("sun.java.command","").replace('\\','/');
        if (!command.contains("-cachedir="+qaProfile)) throw new IllegalArgumentException("Isolated cachedir required");
        Thread worker=new Thread(() -> {
            try {
                ClassLoader cl=ClassLoader.getSystemClassLoader();
                Class<?> window=Class.forName("zombie.GameWindow",false,cl);
                Class<?> loading=Class.forName("zombie.gameStates.GameLoadingState",false,cl);
                Object completed=null;
                boolean menuSeen=false;
                boolean reconnectRequested=false;
                String lastState="";
                String lastConnectState="";
                Path reconnectMarker=Path.of(qaProfile,"reconnect-request");
                for (int i=0;i<1200;i++) {
                    Thread.sleep(500);
                    Object machine=window.getField("states").get(null);
                    if(machine==null) continue;
                    Object current=machine.getClass().getField("current").get(machine);
                    String state=current==null ? "null" : current.getClass().getName();
                    if(!state.equals(lastState)) {
                        lastState=state;
                        Files.writeString(Path.of(qaProfile,"hands-free-qa.log"),"STATE: "+state+"\n",
                            StandardOpenOption.CREATE,StandardOpenOption.APPEND);
                    }
                    if(current != null && current.getClass().getName().equals("zombie.gameStates.TermsOfServiceState")) {
                        try {
                            // Fresh disposable profiles can stop here before Lua's menu
                            // callbacks are installed. Mark the QA-only terms state as
                            // created and exited through its public engine bridge; this
                            // replaces the one-time UI acknowledgement without OS input.
                            var fromLua= current.getClass().getMethod("fromLua0", String.class);
                            fromLua.invoke(current, "created");
                            fromLua.invoke(current, "exit");
                            Files.writeString(Path.of(qaProfile,"hands-free-qa.log"),
                                "PASS: terms state acknowledged without OS input\n",
                                StandardOpenOption.CREATE,StandardOpenOption.APPEND);
                        } catch(Exception termsFailure) {
                            Files.writeString(Path.of(qaProfile,"hands-free-qa.log"),
                                "FAIL: terms acknowledgement "+termsFailure+"\n",
                                StandardOpenOption.CREATE,StandardOpenOption.APPEND);
                        }
                    }
                    if(current != null && current.getClass().getName().equals("zombie.gameStates.MainScreenState")) {
                        try {
                            Field link=current.getClass().getDeclaredField("connectToServerState"); link.setAccessible(true);
                            Object cts=link.get(current);
                            String cs=cts==null ? "none" : String.valueOf(read(cts.getClass(),cts,"state"));
                            if(!cs.equals(lastConnectState)) {
                                lastConnectState=cs;
                                Files.writeString(Path.of(qaProfile,"hands-free-qa.log"),"CONNECT STATE: "+cs+"\n",
                                    StandardOpenOption.CREATE,StandardOpenOption.APPEND);
                            }
                        } catch(Exception ignoredConnect) { }
                    }
                    if(!menuSeen && current != null
                        && current.getClass().getName().equals("zombie.gameStates.MainScreenState")) {
                        menuSeen=true;
                        // The QA mod owns the server connect through the game's own
                        // Lua serverConnect API; this agent only assists load screens.
                        Files.writeString(Path.of(qaProfile,"hands-free-qa.log"),
                            "PASS: main menu reached; QA Lua owns the no-Steam server connect\n",
                            StandardOpenOption.CREATE,StandardOpenOption.APPEND);
                    }
                    if(!reconnectRequested && Files.exists(reconnectMarker) && current != null
                        && current.getClass().getName().equals("zombie.gameStates.IngameState")) {
                        try {
                            Class<?> client=Class.forName("zombie.network.GameClient",false,cl);
                            Object instance=client.getField("instance").get(null);
                            try {
                                client.getMethod("doDisconnect",String.class)
                                    .invoke(instance,"Neighborhood Life QA server restart");
                            } catch(Exception gracefulFailure) {
                                client.getMethod("connectionLost").invoke(instance);
                            }
                            // Build 42's Lua-visible disconnect callback is not
                            // guaranteed when doDisconnect is invoked from the
                            // QA worker thread. Mark both native flags so the
                            // normal IngameState redirect can run without OS
                            // input; this remains QA-only.
                            try { client.getMethod("connectionLost").invoke(instance); }
                            catch(Exception ignoredConnectionLost) { }
                            Field disconnected=window.getField("serverDisconnected");
                            disconnected.setBoolean(null,true);
                            reconnectRequested=true;
                            Files.deleteIfExists(reconnectMarker);
                            Files.writeString(Path.of(qaProfile,"hands-free-qa.log"),
                                "PASS: QA requested engine disconnect for same-client reconnect; serverDisconnected=true\n",
                                StandardOpenOption.CREATE,StandardOpenOption.APPEND);
                        } catch(Exception disconnectFailure) {
                            Files.writeString(Path.of(qaProfile,"hands-free-qa.log"),
                                "FAIL: reconnect request "+disconnectFailure+"\n",
                                StandardOpenOption.CREATE,StandardOpenOption.APPEND);
                        }
                    }
                    if(current==null || !loading.isInstance(current) || current==completed) continue;
                    if(!(Boolean)read(loading,null,"done") || !(Boolean)read(loading,null,"showedClickToSkip")) continue;
                    if((Boolean)read(loading,null,"unexpectedError") || (Boolean)read(loading,null,"worldVersionError")
                        || (Boolean)read(loading,null,"mapDownloadFailed") || (Boolean)read(loading,null,"playerWrongIP")) continue;
                    // The game's update still checks its streamer and animation readiness.
                    // No OS input, no forced state transition, no change to the game jar.
                    Field force=loading.getDeclaredField("forceDone"); force.setAccessible(true); force.setBoolean(current,true);
                    completed=current;
                    Files.writeString(Path.of(qaProfile,"hands-free-qa.log"),"PASS: ready loading screen acknowledged without OS input\n",StandardOpenOption.CREATE,StandardOpenOption.APPEND);
                }
            } catch(Exception ex) {
                try { Files.writeString(Path.of(qaProfile,"hands-free-qa.log"),"FAIL: "+ex+"\n",StandardOpenOption.CREATE,StandardOpenOption.APPEND); }
                catch(Exception ignoredError) { ex.printStackTrace(); }
            }
        },"Neighborhood-QA-start");
        worker.setDaemon(true); worker.start();
    }
}

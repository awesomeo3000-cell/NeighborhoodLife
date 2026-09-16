import java.io.IOException;
import java.lang.instrument.Instrumentation;
import java.lang.reflect.Array;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.LuaCallFrame;

/**
 * QA-only typed bridge for the installed Build 42 server.
 *
 * The production Lua adapter discovers these functions only when an external
 * engine bridge provides them. This agent is deliberately built and launched
 * from tests/, never copied into NeighborhoodLife's release package.
 */
public final class NativeBridgeQA {
    private static final Set<String> setterLogs = ConcurrentHashMap.newKeySet();
    private static final Set<String> bridgeLogs = ConcurrentHashMap.newKeySet();
    private static final Set<String> positionLogs = ConcurrentHashMap.newKeySet();
    private static Path profile;
    private static ClassLoader loader;

    private NativeBridgeQA() { }

    public static void premain(String profileArg, Instrumentation ignored) {
        profile = Path.of(profileArg.replace('\\', '/'));
        String command = System.getProperty("sun.java.command", "").replace('\\', '/');
        if (!profile.toString().replace('\\', '/').toLowerCase().startsWith("e:/pzmod/test-profile")) {
            throw new IllegalArgumentException("isolated QA profile required");
        }
        if (!command.toLowerCase().contains("-cachedir=" + profile.toString().replace('\\', '/').toLowerCase())
                || !command.contains("zombie.network.GameServer")) {
            throw new IllegalArgumentException("typed native bridge requires the isolated dedicated server");
        }
        Thread worker = new Thread(NativeBridgeQA::installWhenLuaIsReady, "Neighborhood-Native-Bridge-QA");
        worker.setDaemon(true);
        worker.start();
    }

    private static void installWhenLuaIsReady() {
        try {
            loader = ClassLoader.getSystemClassLoader();
            Class<?> luaManager = Class.forName("zombie.Lua.LuaManager", false, loader);
            Field envField = luaManager.getField("env");
            for (int attempt = 0; attempt < 1200; attempt++) {
                Object value = envField.get(null);
                if (value instanceof KahluaTable env) {
                    env.rawset("NLNativeOnlineIdSetter", new OnlineIdSetter());
                    env.rawset("NLNativeNpcBridge", new NpcBridge());
                    env.rawset("NLNativeNpcPositionSync", new PositionSync());
                    log("PASS: typed Lua bridge installed functions=NLNativeOnlineIdSetter,NLNativeNpcBridge,NLNativeNpcPositionSync");
                    return;
                }
                Thread.sleep(250L);
            }
            log("FAIL: LuaManager.env did not become available");
        } catch (Throwable failure) {
            log("FAIL: typed bridge install " + failure);
        }
    }

    private static final class OnlineIdSetter implements JavaFunction {
        @Override
        public int call(LuaCallFrame frame, int nArguments) {
            Object body = frame.get(0);
            Object value = frame.get(1);
            boolean ok = false;
            String detail = "missing-argument";
            try {
                short expected = number(value).shortValue();
                invoke(body, "setOnlineID", new Class<?>[]{short.class}, Short.valueOf(expected));
                short actual = number(invoke(body, "getOnlineID", new Class<?>[0])).shortValue();
                ok = actual == expected;
                detail = "id=" + expected + " actual=" + actual;
                if (setterLogs.add(String.valueOf(expected))) log("SETTER " + detail + " ok=" + ok);
            } catch (Throwable failure) {
                detail = String.valueOf(failure);
                log("SETTER error=" + detail);
            }
            return frame.push(Boolean.valueOf(ok));
        }
    }

    private static final class NpcBridge implements JavaFunction {
        @Override
        public int call(LuaCallFrame frame, int nArguments) {
            Object body = frame.get(0);
            Object recipient = frame.get(1);
            boolean ok = false;
            String detail;
            synchronized (NativeBridgeQA.class) {
                try {
                    detail = registerAndSend(body, recipient);
                    ok = true;
                } catch (Throwable failure) {
                    detail = String.valueOf(failure);
                }
            }
            String key = String.valueOf(identity(body)) + ":" + String.valueOf(identity(recipient));
            if (bridgeLogs.add(key) || !ok) log("BRIDGE " + detail + " ok=" + ok);
            return frame.push(Boolean.valueOf(ok));
        }
    }

    private static final class PositionSync implements JavaFunction {
        @Override
        public int call(LuaCallFrame frame, int nArguments) {
            Object body = frame.get(0);
            boolean ok = false;
            String detail;
            try {
                float x = number(frame.get(1)).floatValue();
                float y = number(frame.get(2)).floatValue();
                float z = number(frame.get(3)).floatValue();
                invoke(body, "setX", new Class<?>[]{float.class}, Float.valueOf(x));
                invoke(body, "setY", new Class<?>[]{float.class}, Float.valueOf(y));
                invoke(body, "setZ", new Class<?>[]{float.class}, Float.valueOf(z));
                setField(body, "realx", Float.valueOf(x));
                setField(body, "realy", Float.valueOf(y));
                setField(body, "realz", Byte.valueOf((byte) z));
                ok = true;
                detail = "id=" + identity(body) + " x=" + x + " y=" + y + " z=" + z;
            } catch (Throwable failure) {
                detail = String.valueOf(failure);
            }
            if (ok) {
                String key = String.valueOf(identity(body));
                if (positionLogs.add(key)) log("POSITION " + detail + " ok=true");
            } else {
                log("POSITION error=" + detail);
            }
            return frame.push(Boolean.valueOf(ok));
        }
    }

    private static String registerAndSend(Object body, Object recipient) throws Exception {
        if (body == null || recipient == null) throw new IllegalArgumentException("body or recipient is nil");
        Class<?> isoPlayer = Class.forName("zombie.characters.IsoPlayer", false, loader);
        Class<?> gameServer = Class.forName("zombie.network.GameServer", false, loader);
        Class<?> connectionInterface = Class.forName("zombie.network.IConnection", false, loader);
        Class<?> connectionClass = Class.forName("zombie.core.raknet.UdpConnection", false, loader);

        short onlineId = number(invoke(body, "getOnlineID", new Class<?>[0])).shortValue();
        String username = String.valueOf(invoke(body, "getUsername", new Class<?>[0]));
        if (username.isEmpty() || "null".equals(username)) throw new IllegalArgumentException("NPC username is empty");

        Object connection = staticInvoke(gameServer, "getConnectionFromPlayer",
            new Class<?>[]{isoPlayer}, recipient);
        if (connection == null) throw new IllegalStateException("recipient connection is unavailable");

        Field playersField = connectionClass.getField("players");
        Object playerArray = playersField.get(connection);
        int length = Array.getLength(playerArray);
        int slot = -1;
        for (int index = 0; index < length; index++) {
            Object existing = Array.get(playerArray, index);
            if (existing == body) { slot = index; break; }
            if (slot < 0 && existing == null) slot = index;
        }
        if (slot < 0) throw new IllegalStateException("recipient connection has no free player slot");

        setField(body, "remote", Boolean.TRUE);
        setField(body, "playerIndex", Integer.valueOf(slot));
        setField(body, "serverPlayerIndex", Integer.valueOf(slot));
        invoke(connection, "setPlayerAt", new Class<?>[]{int.class, isoPlayer}, Integer.valueOf(slot), body);
        invoke(connection, "setPlayerId", new Class<?>[]{int.class, short.class}, Integer.valueOf(slot), Short.valueOf(onlineId));
        invoke(connection, "setUserName", new Class<?>[]{int.class, String.class}, Integer.valueOf(slot), username);

        @SuppressWarnings("unchecked")
        List<Object> roster = (List<Object>) staticField(gameServer, "Players");
        if (!roster.contains(body)) roster.add(body);
        @SuppressWarnings("unchecked")
        Map<Object, Object> idMap = (Map<Object, Object>) staticField(gameServer, "IDToPlayerMap");
        idMap.put(Short.valueOf(onlineId), body);
        @SuppressWarnings("unchecked")
        Map<Object, Object> nameMap = (Map<Object, Object>) staticField(gameServer, "UserNameToPlayerMap");
        nameMap.put(username, Short.valueOf(onlineId));

        staticInvoke(gameServer, "sendPlayerConnected",
            new Class<?>[]{isoPlayer, connectionInterface}, body, connection);
        staticInvoke(gameServer, "sendPlayerExtraInfo",
            new Class<?>[]{isoPlayer, connectionClass, boolean.class}, body, connection, Boolean.TRUE);
        staticInvoke(gameServer, "syncVisuals", new Class<?>[]{isoPlayer}, body);
        return "id=" + onlineId + " username=" + username + " slot=" + slot
            + " target=" + identity(recipient) + " roster=" + roster.size();
    }

    private static Object staticField(Class<?> type, String name) throws Exception {
        return type.getField(name).get(null);
    }

    private static void setField(Object target, String name, Object value) throws Exception {
        Field field = target.getClass().getField(name);
        field.set(target, value);
    }

    private static Object staticInvoke(Class<?> type, String name, Class<?>[] parameterTypes,
                                       Object... arguments) throws Exception {
        return type.getMethod(name, parameterTypes).invoke(null, arguments);
    }

    private static Object invoke(Object target, String name, Class<?>[] parameterTypes,
                                 Object... arguments) throws Exception {
        if (target == null) throw new IllegalArgumentException("receiver is nil for " + name);
        Method method = target.getClass().getMethod(name, parameterTypes);
        return method.invoke(target, arguments);
    }

    private static Number number(Object value) {
        if (!(value instanceof Number number)) throw new IllegalArgumentException("expected number, got " + value);
        return number;
    }

    private static Object identity(Object object) {
        if (object == null) return "nil";
        try {
            Object username = invoke(object, "getUsername", new Class<?>[0]);
            Object onlineId = invoke(object, "getOnlineID", new Class<?>[0]);
            return username + "/" + onlineId;
        } catch (Throwable ignored) {
            return object.getClass().getName();
        }
    }

    private static void log(String message) {
        try {
            Files.writeString(profile.resolve("native-bridge-qa.log"), message + System.lineSeparator(),
                StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (IOException ignored) { }
    }
}

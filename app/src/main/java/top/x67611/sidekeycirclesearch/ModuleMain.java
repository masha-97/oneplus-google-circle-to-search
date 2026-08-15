package top.x67611.sidekeycirclesearch;

import android.os.Build;
import android.os.IBinder;
import android.util.Log;

import java.lang.reflect.Executable;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.ConcurrentHashMap;

import io.github.libxposed.api.XposedInterface;
import io.github.libxposed.api.XposedModule;
import io.github.libxposed.api.XposedModuleInterface.ModuleLoadedParam;
import io.github.libxposed.api.XposedModuleInterface.PackageReadyParam;
import io.github.libxposed.api.XposedModuleInterface.SystemServerStartingParam;

/** Google App-only eligibility compatibility for Android contextual search. */
public final class ModuleMain extends XposedModule {
    private static final String TAG = "CircleSearchEligibility";
    private static final String MODULE_VERSION = "1.2.2";
    private static final String GOOGLE_PACKAGE = "com.google.android.googlequicksearchbox";
    private static final String CONTEXTUAL_SEARCH_SERVICE = "contextual_search";
    private static final String CONTEXTUAL_SEARCH_CLASS =
            "com.android.server.contextualsearch.ContextualSearchManagerService";
    private static final String OPA_ELIGIBLE_DEVICE = "ro.opa.eligible_device";
    private static final Set<String> GOOGLE_FEATURES = Set.of(
            "android.software.contextualsearch",
            "com.google.android.feature.CONTEXTUAL_SEARCH",
            "com.google.android.feature.GOOGLE_BUILD",
            "com.google.android.feature.GOOGLE_EXPERIENCE"
    );

    private final AtomicBoolean installed = new AtomicBoolean();
    private final Set<String> observedQueries = ConcurrentHashMap.newKeySet();
    private String processName;

    @Override
    public void onModuleLoaded(ModuleLoadedParam param) {
        processName = param.getProcessName();
        log(Log.INFO, "v" + MODULE_VERSION + " onModuleLoaded process=" + processName);
    }

    @Override
    public void onSystemServerStarting(SystemServerStartingParam param) {
        installContextualSearchBootstrap(param.getClassLoader());
        installContextualSearchPackage(param.getClassLoader());
    }

    @Override
    public void onPackageReady(PackageReadyParam param) {
        if (!GOOGLE_PACKAGE.equals(param.getPackageName())) {
            return;
        }
        log(Log.INFO, "v" + MODULE_VERSION + " onPackageReady process=" + processName);
        if (!installed.compareAndSet(false, true)) {
            return;
        }

        spoofGoogleBuild();
        hookSystemProperties();
        hookGoogleFeatures(param.getClassLoader());
        log(Log.INFO, "v" + MODULE_VERSION + " eligibility active process=" + processName
                + "; model=" + Build.MODEL + "; device=" + Build.DEVICE);
    }

    private void spoofGoogleBuild() {
        setStaticField(Build.class, "MANUFACTURER", "samsung");
        setStaticField(Build.class, "BRAND", "samsung");
        setStaticField(Build.class, "MODEL", "SM-S928B");
        setStaticField(Build.class, "PRODUCT", "e3s");
        setStaticField(Build.class, "DEVICE", "e3s");
    }

    private void installContextualSearchBootstrap(ClassLoader classLoader) {
        Class<?> systemServer = findClass(classLoader, "com.android.server.SystemServer");
        Class<?> timings = findClass(classLoader, "com.android.server.utils.TimingsTraceAndSlog");
        Method startOtherServices = systemServer == null || timings == null
                ? null : findMethod(systemServer, "startOtherServices", timings);
        if (startOtherServices == null) {
            log(Log.ERROR, "v" + MODULE_VERSION + " bootstrap method missing");
            return;
        }

        try {
            deoptimize(startOtherServices);
        } catch (RuntimeException exception) {
            log(Log.WARN, "v" + MODULE_VERSION + " bootstrap deoptimize failed: "
                    + exception.getClass().getSimpleName());
        }
        hook(startOtherServices, "contextual-search-bootstrap", chain -> {
            Object result = chain.proceed();
            ensureContextualSearchService(chain.getThisObject(), classLoader);
            return result;
        });
        log(Log.INFO, "v" + MODULE_VERSION + " bootstrap hook installed");
    }

    private void installContextualSearchPackage(ClassLoader classLoader) {
        Class<?> serviceClass = findClass(classLoader, CONTEXTUAL_SEARCH_CLASS);
        Method resolver = serviceClass == null
                ? null : findMethod(serviceClass, "getContextualSearchPackageName");
        if (resolver == null) {
            log(Log.ERROR, "v" + MODULE_VERSION + " package resolver missing");
            return;
        }
        hook(resolver, "contextual-search-package", chain -> GOOGLE_PACKAGE);
        log(Log.INFO, "v" + MODULE_VERSION + " package resolver set to Google App");
    }

    private void ensureContextualSearchService(Object systemServer, ClassLoader classLoader) {
        if (isContextualSearchServiceAlive()) {
            log(Log.INFO, "v" + MODULE_VERSION + " contextual_search already alive");
            return;
        }

        Object manager = getField(systemServer, "mSystemServiceManager");
        Class<?> serviceClass = findClass(classLoader, CONTEXTUAL_SEARCH_CLASS);
        Method startService = manager == null ? null
                : findMethod(manager.getClass(), "startService", Class.class);
        if (manager == null || serviceClass == null || startService == null) {
            log(Log.ERROR, "v" + MODULE_VERSION + " bootstrap dependencies missing");
            return;
        }

        try {
            getInvoker(startService).invoke(manager, serviceClass);
            log(isContextualSearchServiceAlive() ? Log.INFO : Log.ERROR,
                    "v" + MODULE_VERSION + " contextual_search bootstrap alive="
                            + isContextualSearchServiceAlive());
        } catch (Exception exception) {
            log(Log.ERROR, "v" + MODULE_VERSION + " contextual_search bootstrap failed: "
                    + exception.getClass().getSimpleName());
        }
    }

    private static boolean isContextualSearchServiceAlive() {
        try {
            Method getService = Class.forName("android.os.ServiceManager")
                    .getDeclaredMethod("getService", String.class);
            getService.setAccessible(true);
            IBinder binder = (IBinder) getService.invoke(null, CONTEXTUAL_SEARCH_SERVICE);
            return binder != null && binder.isBinderAlive();
        } catch (ReflectiveOperationException | RuntimeException exception) {
            return false;
        }
    }

    private void hookSystemProperties() {
        Class<?> systemProperties;
        try {
            systemProperties = Class.forName("android.os.SystemProperties");
        } catch (ClassNotFoundException | LinkageError exception) {
            log(Log.ERROR, "SystemProperties unavailable: " + exception.getClass().getSimpleName());
            return;
        }

        hookSystemPropertyMethod(systemProperties, "get", String.class);
        hookSystemPropertyMethod(systemProperties, "get", String.class, String.class);
        hookSystemPropertyMethod(systemProperties, "getBoolean", String.class, boolean.class);
    }

    private void hookSystemPropertyMethod(Class<?> type, String name, Class<?>... parameters) {
        try {
            Method method = type.getDeclaredMethod(name, parameters);
            method.setAccessible(true);
            hook(method, "system-properties." + name + "." + parameters.length, chain -> {
                if (!OPA_ELIGIBLE_DEVICE.equals(chain.getArg(0))) {
                    return chain.proceed();
                }
                logQueryOnce("property:" + name + "/" + parameters.length);
                return method.getReturnType() == boolean.class ? Boolean.TRUE : "true";
            });
        } catch (ReflectiveOperationException | SecurityException exception) {
            log(Log.WARN, "missing SystemProperties." + name + "/" + parameters.length);
        }
    }

    private void hookGoogleFeatures(ClassLoader classLoader) {
        Class<?> packageManager;
        try {
            packageManager = Class.forName("android.app.ApplicationPackageManager", false, classLoader);
        } catch (ClassNotFoundException | LinkageError exception) {
            log(Log.ERROR, "ApplicationPackageManager unavailable");
            return;
        }

        int count = 0;
        for (Method method : packageManager.getDeclaredMethods()) {
            if (!method.getName().equals("hasSystemFeature")
                    || method.getReturnType() != boolean.class
                    || method.getParameterCount() == 0
                    || method.getParameterTypes()[0] != String.class) {
                continue;
            }
            try {
                method.setAccessible(true);
            } catch (RuntimeException exception) {
                log(Log.WARN, "hasSystemFeature access fallback: "
                        + exception.getClass().getSimpleName());
            }
            hook(method, "package-manager-feature." + method.getParameterCount(), chain -> {
                Object feature = chain.getArg(0);
                if (GOOGLE_FEATURES.contains(feature)) {
                    logQueryOnce("feature:" + feature);
                    return Boolean.TRUE;
                }
                return chain.proceed();
            });
            count++;
        }
        if (count == 0) {
            log(Log.ERROR, "no hasSystemFeature overload found");
        }
    }

    private void setStaticField(Class<?> type, String name, String value) {
        try {
            Field field = type.getDeclaredField(name);
            field.setAccessible(true);
            try {
                field.set(null, value);
            } catch (ReflectiveOperationException | RuntimeException directFailure) {
                setStaticFieldWithUnsafe(field, value);
            }
        } catch (ReflectiveOperationException | RuntimeException exception) {
            log(Log.ERROR, "failed to spoof Build." + name + ": "
                    + exception.getClass().getSimpleName());
        }
    }

    private static Class<?> findClass(ClassLoader classLoader, String name) {
        try {
            return Class.forName(name, false, classLoader);
        } catch (ClassNotFoundException | LinkageError exception) {
            return null;
        }
    }

    private static Method findMethod(Class<?> type, String name, Class<?>... parameters) {
        for (Class<?> current = type; current != null; current = current.getSuperclass()) {
            try {
                Method method = current.getDeclaredMethod(name, parameters);
                method.setAccessible(true);
                return method;
            } catch (NoSuchMethodException | SecurityException | LinkageError ignored) {
                // Continue through the hierarchy.
            }
        }
        return null;
    }

    private static Object getField(Object target, String name) {
        for (Class<?> current = target.getClass(); current != null; current = current.getSuperclass()) {
            try {
                Field field = current.getDeclaredField(name);
                field.setAccessible(true);
                return field.get(target);
            } catch (NoSuchFieldException ignored) {
                // Continue through the hierarchy.
            } catch (IllegalAccessException | SecurityException | LinkageError exception) {
                return null;
            }
        }
        return null;
    }

    private static void setStaticFieldWithUnsafe(Field field, String value)
            throws ReflectiveOperationException {
        Class<?> unsafeClass = Class.forName("sun.misc.Unsafe");
        Field unsafeField = unsafeClass.getDeclaredField("theUnsafe");
        unsafeField.setAccessible(true);
        Object unsafe = unsafeField.get(null);
        Object base = unsafeClass.getDeclaredMethod("staticFieldBase", Field.class)
                .invoke(unsafe, field);
        long offset = (Long) unsafeClass.getDeclaredMethod("staticFieldOffset", Field.class)
                .invoke(unsafe, field);
        unsafeClass.getDeclaredMethod("putObjectVolatile", Object.class, long.class, Object.class)
                .invoke(unsafe, base, offset, value);
    }

    private void hook(Executable executable, String id, XposedInterface.Hooker hooker) {
        try {
            hook(executable)
                    .setExceptionMode(XposedInterface.ExceptionMode.PROTECTIVE)
                    .setId("circle-search-eligibility." + id)
                    .intercept(hooker);
        } catch (Exception exception) {
            log(Log.ERROR, "hook failed " + id + ": " + exception.getClass().getSimpleName());
        }
    }

    private void logQueryOnce(String query) {
        if (observedQueries.add(query)) {
            log(Log.INFO, "v" + MODULE_VERSION + " forced eligible query=" + query
                    + " process=" + processName);
        }
    }

    private void log(int priority, String message) {
        Log.println(priority, TAG, message);
        log(priority, TAG, message);
    }
}

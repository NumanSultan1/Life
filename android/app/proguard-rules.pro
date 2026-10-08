# Release builds: remove Android log calls (some plugins log health values,
# e.g. step counts) so nothing personal reaches the system log.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static boolean isLoggable(java.lang.String, int);
}

/* buildinfo.c
 *
 * Prints compile-time information (compiler, target, optimization-related macros),
 * and libc info in JSON. Zero external deps beyond the C standard library.
 *
 * If you want to embed the exact gcc command that built this binary, compile with:
 *   gcc ... -DCC_ARGS="\"gcc <your flags here>\"" buildinfo.c -o buildinfo
 * (Optional; safe to omit.)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <limits.h>

#if defined(__GLIBC__)
  #include <gnu/libc-version.h>    /* for gnu_get_libc_version/release() */
#endif

/* JSON string escaper for safety */
static void json_escape_and_print(const char *s) {
    putchar('"');
    for (const unsigned char *p = (const unsigned char*)s; *p; ++p) {
        unsigned char c = *p;
        switch (c) {
            case '\"': fputs("\\\"", stdout); break;
            case '\\': fputs("\\\\", stdout); break;
            case '\b': fputs("\\b", stdout);  break;
            case '\f': fputs("\\f", stdout);  break;
            case '\n': fputs("\\n", stdout);  break;
            case '\r': fputs("\\r", stdout);  break;
            case '\t': fputs("\\t", stdout);  break;
            default:
                if (c < 0x20) { /* control chars */
                    char buf[7];
                    snprintf(buf, sizeof(buf), "\\u%04x", c);
                    fputs(buf, stdout);
                } else {
                    putchar(c);
                }
        }
    }
    putchar('"');
}

/* Helper to print a JSON string field: "key": "value" */
static void js_kv_str(const char *key, const char *val, int trailing_comma) {
    json_escape_and_print(key);
    fputs(": ", stdout);
    if (val) json_escape_and_print(val); else fputs("null", stdout);
    if (trailing_comma) fputc(',', stdout);
    fputc('\n', stdout);
}

/* Helper to print a JSON integer/bool field */
static void js_kv_int(const char *key, long long val, int trailing_comma) {
    json_escape_and_print(key);
    fputs(": ", stdout);
    printf("%lld", val);
    if (trailing_comma) fputc(',', stdout);
    fputc('\n', stdout);
}

static void js_kv_bool(const char *key, int val, int trailing_comma) {
    json_escape_and_print(key);
    fputs(": ", stdout);
    fputs(val ? "true" : "false", stdout);
    if (trailing_comma) fputc(',', stdout);
    fputc('\n', stdout);
}

int main(void) {
    /* --- Compiler block --- */
    fputs("{\n", stdout);
    json_escape_and_print("compiler");
    fputs(": {\n", stdout);

    /* __VERSION__ is a GCC-provided string (also defined by Clang-in-GCC-mode). */
#ifdef __VERSION__
    js_kv_str("version_string", __VERSION__, 1);
#else
    js_kv_str("version_string", "unknown", 1);
#endif

#ifdef __GNUC__
    js_kv_int("gcc_major", __GNUC__, 1);
#else
    js_kv_str("gcc_major", NULL, 1);
#endif
#ifdef __GNUC_MINOR__
    js_kv_int("gcc_minor", __GNUC_MINOR__, 1);
#else
    js_kv_str("gcc_minor", NULL, 1);
#endif
#ifdef __GNUC_PATCHLEVEL__
    js_kv_int("gcc_patchlevel", __GNUC_PATCHLEVEL__, 1);
#else
    js_kv_str("gcc_patchlevel", NULL, 1);
#endif

#ifdef __clang__
    js_kv_bool("is_clang", 1, 1);
#else
    js_kv_bool("is_clang", 0, 1);
#endif

#ifdef __OPTIMIZE__
    js_kv_bool("optimize_any", 1, 1);
#else
    js_kv_bool("optimize_any", 0, 1);
#endif
#ifdef __OPTIMIZE_SIZE__
    js_kv_bool("optimize_for_size", 1, 1);
#else
    js_kv_bool("optimize_for_size", 0, 1);
#endif
#ifdef __NO_INLINE__
    js_kv_bool("no_inline", 1, 1);
#else
    js_kv_bool("no_inline", 0, 1);
#endif
#ifdef __FAST_MATH__
    js_kv_bool("fast_math", 1, 1);
#else
    js_kv_bool("fast_math", 0, 1);
#endif
#ifdef __PIC__
    js_kv_bool("pic", 1, 1);
#else
    js_kv_bool("pic", 0, 1);
#endif
#ifdef __PIE__
    js_kv_bool("pie", 1, 1);
#else
    js_kv_bool("pie", 0, 1);
#endif
#ifdef __SANITIZE_ADDRESS__
    js_kv_bool("asan", 1, 1);
#else
    js_kv_bool("asan", 0, 1);
#endif
#ifdef __SANITIZE_THREAD__
    js_kv_bool("tsan", 1, 1);
#else
    js_kv_bool("tsan", 0, 1);
#endif
#ifdef __SANITIZE_UNDEFINED__
    js_kv_bool("ubsan", 1, 1);
#else
    js_kv_bool("ubsan", 0, 1);
#endif
#ifdef __SSE__
    js_kv_bool("sse", 1, 1);
#endif
#ifdef __SSE2__
    js_kv_bool("sse2", 1, 1);
#endif
#ifdef __SSE3__
    js_kv_bool("sse3", 1, 1);
#endif
#ifdef __SSSE3__
    js_kv_bool("ssse3", 1, 1);
#endif
#ifdef __SSE4_1__
    js_kv_bool("sse4_1", 1, 1);
#endif
#ifdef __SSE4_2__
    js_kv_bool("sse4_2", 1, 1);
#endif
#ifdef __AVX__
    js_kv_bool("avx", 1, 1);
#endif
#ifdef __AVX2__
    js_kv_bool("avx2", 1, 1);
#endif

    /* AVX-512 family */
#ifdef __AVX512F__
    js_kv_bool("avx512f", 1, 1);
#endif
#ifdef __AVX512CD__
    js_kv_bool("avx512cd", 1, 1);
#endif
#ifdef __AVX512ER__
    js_kv_bool("avx512er", 1, 1);
#endif
#ifdef __AVX512PF__
    js_kv_bool("avx512pf", 1, 1);
#endif
#ifdef __AVX512BW__
    js_kv_bool("avx512bw", 1, 1);
#endif
#ifdef __AVX512DQ__
    js_kv_bool("avx512dq", 1, 1);
#endif
#ifdef __AVX512VL__
    js_kv_bool("avx512vl", 1, 1);
#endif
#ifdef __AVX512IFMA__
    js_kv_bool("avx512ifma", 1, 1);
#endif
#ifdef __AVX512VBMI__
    js_kv_bool("avx512vbmi", 1, 1);
#endif
#ifdef __AVX512VNNI__
    js_kv_bool("avx512vnni", 1, 1);
#endif

#ifdef CC_ARGS
    js_kv_str("embedded_cc_command", CC_ARGS, 0);
#else
    js_kv_str("embedded_cc_command", NULL, 0);
#endif

    fputs("},\n", stdout);

    /* --- Build block --- */
    json_escape_and_print("build");
    fputs(": {\n", stdout);
#ifdef __DATE__
    js_kv_str("date", __DATE__, 1);
#else
    js_kv_str("date", "unknown", 1);
#endif
#ifdef __TIME__
    js_kv_str("time", __TIME__, 1);
#else
    js_kv_str("time", "unknown", 1);
#endif
#ifdef __BASE_FILE__
    js_kv_str("base_file", __BASE_FILE__, 1);
#else
    js_kv_str("base_file", __FILE__, 1);
#endif

#ifdef __STDC_VERSION__
    js_kv_int("stdc_version", (long long)__STDC_VERSION__, 1);
#else
    js_kv_str("stdc_version", NULL, 1);
#endif
#ifdef __STDC_HOSTED__
    js_kv_bool("hosted", __STDC_HOSTED__, 0);
#else
    js_kv_str("hosted", NULL, 0);
#endif
    fputs("},\n", stdout);

    /* --- Target block --- */
    json_escape_and_print("target");
    fputs(": {\n", stdout);

#ifdef __x86_64__
    js_kv_str("arch", "x86_64", 1);
#elif defined(__i386__)
    js_kv_str("arch", "i386", 1);
#elif defined(__aarch64__)
    js_kv_str("arch", "aarch64", 1);
#elif defined(__arm__)
    js_kv_str("arch", "arm", 1);
#elif defined(__ppc64__)
    js_kv_str("arch", "ppc64", 1);
#elif defined(__powerpc__)
    js_kv_str("arch", "powerpc", 1);
#elif defined(__riscv)
    js_kv_str("arch", "riscv", 1);
#else
    js_kv_str("arch", "unknown", 1);
#endif

#ifdef __linux__
    js_kv_str("os", "linux", 1);
#elif defined(__APPLE__) && defined(__MACH__)
    js_kv_str("os", "darwin", 1);
#elif defined(_WIN32)
    js_kv_str("os", "windows", 1);
#else
    js_kv_str("os", "unknown", 1);
#endif

#if defined(__BYTE_ORDER__) && defined(__ORDER_LITTLE_ENDIAN__) && defined(__ORDER_BIG_ENDIAN__)
    js_kv_str("endianness",
        (__BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__) ? "little" :
        (__BYTE_ORDER__ == __ORDER_BIG_ENDIAN__)  ? "big" : "unknown",
        1);
#else
    js_kv_str("endianness", "unknown", 1);
#endif

    js_kv_int("pointer_bits", (long long)(sizeof(void*) * CHAR_BIT), 0);
    fputs("},\n", stdout);

    /* --- Libc block --- */
    json_escape_and_print("libc");
    fputs(": {\n", stdout);

#if defined(__GLIBC__)
    js_kv_str("kind", "glibc", 1);
    /* From <gnu/libc-version.h> (available on glibc) */
    js_kv_str("glibc_version", gnu_get_libc_version(), 1);
    js_kv_str("glibc_release", gnu_get_libc_release(), 0);
#elif defined(__APPLE__)
    js_kv_str("kind", "Apple libc", 0);
#else
    /* Could be musl or another libc; there is no universal macro. */
    js_kv_str("kind", "unknown_or_non_glibc", 0);
#endif

    fputs("}\n", stdout);

    /* --- Optional: echo argv if you run the binary with args (not gcc’s args) --- */
    /* We won’t include runtime argv in the JSON root to keep output stable for scripting.
       Uncomment below if you want the executed program’s argv echoed as well.

    fputs(",\n", stdout);
    json_escape_and_print("program_argv");
    fputs(": [\n", stdout);
    for (int i = 0; i < argc; ++i) {
        json_escape_and_print(argv[i]);
        if (i + 1 < argc) fputc(',', stdout);
        fputc('\n', stdout);
    }
    fputs("]\n", stdout);
    */

    fputs("}\n", stdout);
    return 0;
}

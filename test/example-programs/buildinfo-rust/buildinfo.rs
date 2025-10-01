/* buildinfo.rs
 *
 * Prints compile-time information (compiler, target, optimization-related macros),
 * in JSON. Zero external deps beyond the Rust standard library.
 */

use std::env;

fn main() {
    // Start JSON output
    println!("{{");

    // --- Compiler block ---
    print!("\"compiler\": {{");

    // Rust version
    println!("\"version_string\": \"{}\",", option_env!("CARGO_PKG_VERSION").unwrap_or("unknown"));

    // Check if we're using rustc
    println!("\"is_rustc\": true,");

    // Optimization level
    #[cfg(debug_assertions)]
    println!("\"optimize_any\": false,");
    #[cfg(not(debug_assertions))]
    println!("\"optimize_any\": true,");

    // Fast math
    #[cfg(target_feature = "fma")]
    println!("\"fast_math\": true,");
    #[cfg(not(target_feature = "fma"))]
    println!("\"fast_math\": false,");

    // Check for SIMD instruction sets
    #[cfg(target_feature = "sse")]
    println!("\"sse\": true,");
    #[cfg(target_feature = "sse2")]
    println!("\"sse2\": true,");
    #[cfg(target_feature = "sse3")]
    println!("\"sse3\": true,");
    #[cfg(target_feature = "ssse3")]
    println!("\"ssse3\": true,");
    #[cfg(target_feature = "sse4.1")]
    println!("\"sse4_1\": true,");
    #[cfg(target_feature = "sse4.2")]
    println!("\"sse4_2\": true,");

    #[cfg(target_feature = "avx")]
    println!("\"avx\": true,");
    #[cfg(target_feature = "avx2")]
    println!("\"avx2\": true,");

    // AVX-512 family
    #[cfg(target_feature = "avx512f")]
    println!("\"avx512f\": true,");
    #[cfg(target_feature = "avx512cd")]
    println!("\"avx512cd\": true,");
    #[cfg(target_feature = "avx512er")]
    println!("\"avx512er\": true,");
    #[cfg(target_feature = "avx512pf")]
    println!("\"avx512pf\": true,");
    #[cfg(target_feature = "avx512bw")]
    println!("\"avx512bw\": true,");
    #[cfg(target_feature = "avx512dq")]
    println!("\"avx512dq\": true,");
    #[cfg(target_feature = "avx512vl")]
    println!("\"avx512vl\": true,");
    #[cfg(target_feature = "avx512ifma")]
    println!("\"avx512ifma\": true,");
    #[cfg(target_feature = "avx512vbmi")]
    println!("\"avx512vbmi\": true,");
    #[cfg(target_feature = "avx512vnni")]
    println!("\"avx512vnni\": true,");
    println!("\"comma_terminate\": \"hack here\"");

    println!("}},");

    // --- Target block ---
    println!("\"target\": {{");

    // Architecture
    #[cfg(target_arch = "x86_64")]
    println!("\"arch\": \"x86_64\",");
    #[cfg(target_arch = "x86")]
    println!("\"arch\": \"x86\",");
    #[cfg(target_arch = "aarch64")]
    println!("\"arch\": \"aarch64\",");
    #[cfg(target_arch = "arm")]
    println!("\"arch\": \"arm\",");
    #[cfg(not(any(target_arch = "x86_64", target_arch = "x86", target_arch = "aarch64", target_arch = "arm")))]
    println!("\"arch\": \"unknown\",");

    // OS
    #[cfg(target_os = "linux")]
    println!("\"os\": \"linux\",");
    #[cfg(target_os = "macos")]
    println!("\"os\": \"darwin\",");
    #[cfg(target_os = "windows")]
    println!("\"os\": \"windows\",");
    #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
    println!("\"os\": \"unknown\",");

    // Endianness
    #[cfg(target_endian = "little")]
    println!("\"endianness\": \"little\",");
    #[cfg(target_endian = "big")]
    println!("\"endianness\": \"big\",");
    #[cfg(not(any(target_endian = "little", target_endian = "big")))]
    println!("\"endianness\": \"unknown\",");

    // Pointer width
    println!("\"pointer_bits\": {}", std::mem::size_of::<usize>() * 8);
    println!("}}");

    // End JSON output
    println!("}}");
}

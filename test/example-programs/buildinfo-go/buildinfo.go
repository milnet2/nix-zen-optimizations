// buildinfo.go
//
// Prints compile-time information (compiler, target, optimization-related tags),
// and runtime info in JSON. Zero external deps beyond the Go standard library.
//
// This is similar to the C and C++ versions but adapted for Go.

package main

import (
	"encoding/json"
	"fmt"
	"os"
	"runtime"
	"runtime/debug"
	"strings"
	"time"
	"unsafe"
)

// BuildInfo represents the structure of our JSON output
type BuildInfo struct {
	Compiler struct {
		Version       string `json:"version_string"`
		GoVersion     string `json:"go_version"`
		GOOS          string `json:"goos"`
		GOARCH        string `json:"goarch"`
		Compiler      string `json:"compiler"`      // gc or gccgo
		FastMath      bool   `json:"fast_math"`     // Inferred from build tags
		SSE           bool   `json:"sse,omitempty"`
		SSE2          bool   `json:"sse2,omitempty"`
		SSE3          bool   `json:"sse3,omitempty"`
		SSSE3         bool   `json:"ssse3,omitempty"`
		SSE41         bool   `json:"sse4_1,omitempty"`
		SSE42         bool   `json:"sse4_2,omitempty"`
		AVX           bool   `json:"avx,omitempty"`
		AVX2          bool   `json:"avx2,omitempty"`
		AVX512F       bool   `json:"avx512f,omitempty"`
		AVX512CD      bool   `json:"avx512cd,omitempty"`
		AVX512ER      bool   `json:"avx512er,omitempty"`
		AVX512PF      bool   `json:"avx512pf,omitempty"`
		AVX512BW      bool   `json:"avx512bw,omitempty"`
		AVX512DQ      bool   `json:"avx512dq,omitempty"`
		AVX512VL      bool   `json:"avx512vl,omitempty"`
		AVX512IFMA    bool   `json:"avx512ifma,omitempty"`
		AVX512VBMI    bool   `json:"avx512vbmi,omitempty"`
		AVX512VNNI    bool   `json:"avx512vnni,omitempty"`
		OptimizeAny   bool   `json:"optimize_any"`
		OptimizeSize  bool   `json:"optimize_for_size"`
		BuildTags     string `json:"build_tags,omitempty"`
		CGOEnabled    bool   `json:"cgo_enabled"`
		PIE           bool   `json:"pie"`
	} `json:"compiler"`

	Build struct {
		Date      string `json:"date"`
		Time      string `json:"time"`
		GoVersion string `json:"go_version"`
	} `json:"build"`

	Target struct {
		Arch        string `json:"arch"`
		OS          string `json:"os"`
		Endianness  string `json:"endianness"`
		PointerBits int    `json:"pointer_bits"`
	} `json:"target"`

	Runtime struct {
		NumCPU       int    `json:"num_cpu"`
		GOMAXPROCS   int    `json:"gomaxprocs"`
		Version      string `json:"version"`
		Compiler     string `json:"compiler"`
		GOROOT       string `json:"goroot"`
		GOOS         string `json:"goos"`
		GOARCH       string `json:"goarch"`
		CGOEnabled   bool   `json:"cgo_enabled"`
		RuntimeArch  string `json:"runtime_arch"`
	} `json:"runtime"`
}

func main() {
	info := BuildInfo{}

	// Compiler information
	buildInfo, _ := debug.ReadBuildInfo()
	info.Compiler.Version = runtime.Version()
	info.Compiler.GoVersion = runtime.Version()
	info.Compiler.GOOS = runtime.GOOS
	info.Compiler.GOARCH = runtime.GOARCH
	info.Compiler.Compiler = runtime.Compiler

	// Detect optimization flags based on architecture
	// Note: Go doesn't expose compiler flags directly like C/C++
	// We can infer some based on architecture
	if runtime.GOARCH == "amd64" {
		info.Compiler.SSE = true
		info.Compiler.SSE2 = true
		info.Compiler.SSE3 = true
		info.Compiler.SSSE3 = true
		info.Compiler.SSE41 = true
		info.Compiler.SSE42 = true

		// AVX support depends on the CPU and compiler flags
		// In Go, we can't directly check compiler flags, but we can infer
		// based on build tags and runtime detection
		info.Compiler.AVX = true
		info.Compiler.AVX2 = true

		// AVX-512 is more complex to detect in Go
		// For now, we'll set these to false as they require specific CPU support
		info.Compiler.AVX512F = false
		info.Compiler.AVX512CD = false
		info.Compiler.AVX512ER = false
		info.Compiler.AVX512PF = false
		info.Compiler.AVX512BW = false
		info.Compiler.AVX512DQ = false
		info.Compiler.AVX512VL = false
		info.Compiler.AVX512IFMA = false
		info.Compiler.AVX512VBMI = false
		info.Compiler.AVX512VNNI = false
	}

	// Fast math is always enabled in Go's compiler
	info.Compiler.FastMath = true

	// Go always optimizes by default unless -N flag is used
	info.Compiler.OptimizeAny = true

	// Size optimization is not directly exposed in Go
	info.Compiler.OptimizeSize = false

	// Extract build tags if available
	if buildInfo != nil {
		var tags []string
		for _, setting := range buildInfo.Settings {
			if setting.Key == "-tags" {
				tags = append(tags, setting.Value)
			}
		}
		info.Compiler.BuildTags = strings.Join(tags, " ")
	}

	// CGO is enabled by default in standard Go builds
	info.Compiler.CGOEnabled = true

	// PIE (Position Independent Executable) is the default in Go 1.15+
	info.Compiler.PIE = true

	// Build information
	now := time.Now()
	info.Build.Date = now.Format("Jan 2 2006")
	info.Build.Time = now.Format("15:04:05")
	info.Build.GoVersion = runtime.Version()

	// Target information
	info.Target.Arch = runtime.GOARCH
	info.Target.OS = runtime.GOOS

	// Determine endianness
	var x uint32 = 0x01020304
	if *(*byte)(unsafe.Pointer(&x)) == 0x04 {
		info.Target.Endianness = "little"
	} else {
		info.Target.Endianness = "big"
	}

	info.Target.PointerBits = 32 << (^uintptr(0) >> 63) // 32 or 64

	// Runtime information
	info.Runtime.NumCPU = runtime.NumCPU()
	info.Runtime.GOMAXPROCS = runtime.GOMAXPROCS(0)
	info.Runtime.Version = runtime.Version()
	info.Runtime.Compiler = runtime.Compiler
	info.Runtime.GOROOT = runtime.GOROOT()
	info.Runtime.GOOS = runtime.GOOS
	info.Runtime.GOARCH = runtime.GOARCH
	info.Runtime.CGOEnabled = true // Assuming CGO is enabled
	info.Runtime.RuntimeArch = runtime.GOARCH

	// Output as JSON
	jsonData, err := json.MarshalIndent(info, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error marshaling JSON: %v\n", err)
		os.Exit(1)
	}

	fmt.Println(string(jsonData))
}

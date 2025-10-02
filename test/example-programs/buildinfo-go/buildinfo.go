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
	"unsafe"
)

// Handed in via -ldflags="-X 'main.goamd64=$(go env GOAMD64)'"
var goamd64 string
var goflags string

// BuildInfo represents the structure of our JSON output
type BuildInfo struct {
	Compiler struct {
		Version   string `json:"version_string"`
		GoVersion string `json:"go_version"`

		GOOS    string `json:"GOOS"`
		GOARCH  string `json:"GOARCH"`
		GOAMD64 string `json:"GOAMD64"`
		GOFLAGS string `json:"GOFLAGS"`

		Compiler  string `json:"compiler"` // gc or gccgo
		BuildTags string `json:"build_tags,omitempty"`
	} `json:"compiler"`

	Target struct {
		Arch        string `json:"arch"`
		OS          string `json:"os"`
		Endianness  string `json:"endianness"`
		PointerBits int    `json:"pointer_bits"`
	} `json:"target"`

	Runtime struct {
		NumCPU      int    `json:"num_cpu"`
		GOMAXPROCS  int    `json:"gomaxprocs"`
		Version     string `json:"version"`
		Compiler    string `json:"compiler"`
		GOOS        string `json:"goos"`
		GOARCH      string `json:"goarch"`
		CGOEnabled  bool   `json:"cgo_enabled"`
		RuntimeArch string `json:"runtime_arch"`
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
	info.Compiler.GOAMD64 = goamd64
	info.Compiler.GOFLAGS = goflags
	info.Compiler.Compiler = runtime.Compiler

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

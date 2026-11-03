//go:build windows

package main

import (
	"fmt"
	"path/filepath"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

// PROCESSENTRY32W from tlhelp32.h; structure uses native pointer size on x64.
type processEntry struct {
	Size            uint32
	Usage           uint32
	ProcessID       uint32
	DefaultHeapID   uintptr
	ModuleID        uint32
	Threads         uint32
	ParentProcessID uint32
	Priority        int32
	Flags           uint32
	ExeFile         [260]uint16
}

func runningPortableBrave(browserPath string) (int, error) {
	snapProc := syscall.NewLazyDLL("kernel32.dll").NewProc("CreateToolhelp32Snapshot")
	firstProc := syscall.NewLazyDLL("kernel32.dll").NewProc("Process32FirstW")
	nextProc := syscall.NewLazyDLL("kernel32.dll").NewProc("Process32NextW")
	openProc := syscall.NewLazyDLL("kernel32.dll").NewProc("OpenProcess")
	nameProc := syscall.NewLazyDLL("kernel32.dll").NewProc("QueryFullProcessImageNameW")
	closeProc := syscall.NewLazyDLL("kernel32.dll").NewProc("CloseHandle")
	snap, _, err := snapProc.Call(0x2, 0)
	if snap == ^uintptr(0) {
		return 0, fmt.Errorf("CreateToolhelp32Snapshot: %v", err)
	}
	defer closeProc.Call(snap)
	target := strings.ToLower(filepath.Clean(browserPath))
	var p processEntry
	p.Size = uint32(unsafe.Sizeof(p))
	ok, _, _ := firstProc.Call(snap, uintptr(unsafe.Pointer(&p)))
	if ok == 0 {
		return 0, nil
	}
	count := 0
	for {
		if strings.EqualFold(syscall.UTF16ToString(p.ExeFile[:]), "brave.exe") {
			h, _, _ := openProc.Call(0x1000, 0, uintptr(p.ProcessID))
			if h != 0 {
				name := make([]uint16, 32768)
				n := uint32(len(name))
				result, _, _ := nameProc.Call(h, 0, uintptr(unsafe.Pointer(&name[0])), uintptr(unsafe.Pointer(&n)))
				closeProc.Call(h)
				if result != 0 && strings.ToLower(filepath.Clean(syscall.UTF16ToString(name[:n]))) == target {
					count++
				}
			}
		}
		ok, _, _ = nextProc.Call(snap, uintptr(unsafe.Pointer(&p)))
		if ok == 0 {
			break
		}
	}
	return count, nil
}
func waitForPortableChildren(browserPath string, limit time.Duration, logf func(string)) error {
	deadline := time.Now().Add(limit)
	for {
		n, err := runningPortableBrave(browserPath)
		if err != nil {
			return err
		}
		if n == 0 {
			return nil
		}
		if time.Now().After(deadline) {
			return fmt.Errorf("%d portable Brave process(es) still running after %s; cleanup postponed to protect active files", n, limit)
		}
		logf(fmt.Sprintf("waiting for %d portable Brave child process(es)", n))
		time.Sleep(750 * time.Millisecond)
	}
}

//go:build windows

// Brave PortableApps launcher. No registry editing, privilege escalation, injected
// DLLs, executable packers, profile encryption bypasses, or automatic host deletion.
package main

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"example.com/independent/braveportable/internal/traceguard"
)

var kernel = syscall.NewLazyDLL("kernel32.dll")
var user32 = syscall.NewLazyDLL("user32.dll")

func alert(message string) {
	title, _ := syscall.UTF16PtrFromString("Brave Portable")
	body, _ := syscall.UTF16PtrFromString(message)
	user32.NewProc("MessageBoxW").Call(0, uintptr(unsafe.Pointer(body)), uintptr(unsafe.Pointer(title)), 0x10)
}
func getMutex(key string) (func(), error) {
	digest := sha256.Sum256([]byte(strings.ToLower(key)))
	name, _ := syscall.UTF16PtrFromString("Local\\BravePortable-" + hex.EncodeToString(digest[:12]))
	h, _, e := kernel.NewProc("CreateMutexW").Call(0, 0, uintptr(unsafe.Pointer(name)))
	if h == 0 {
		return nil, fmt.Errorf("CreateMutexW failed: %v", e)
	}
	if e == syscall.Errno(183) {
		kernel.NewProc("CloseHandle").Call(h)
		return nil, errors.New("another Brave Portable launcher is already using this folder")
	}
	return func() { kernel.NewProc("CloseHandle").Call(h) }, nil
}
// A GUI error dialog has no place in unattended GitHub Actions. The normal
// desktop launcher still shows an actionable dialog; smoke mode logs instead.
func smokeRequested() bool {
	for _, a := range os.Args[1:] {
		if a == "--portable-smoke-test" {
			return true
		}
	}
	return false
}
func reportSmokeError(err error) {
	exe, pathErr := os.Executable()
	if pathErr != nil {
		fmt.Fprintln(os.Stderr, "portable smoke failed:", err)
		return
	}
	dir := filepath.Join(filepath.Dir(exe), "Data", "TraceGuard")
	if mkErr := os.MkdirAll(dir, 0700); mkErr == nil {
		if f, openErr := os.OpenFile(filepath.Join(dir, "launcher.log"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600); openErr == nil {
			fmt.Fprintln(f, time.Now().Format(time.RFC3339), "SMOKE FAILED:", err)
			_ = f.Close()
		}
	}
	fmt.Fprintln(os.Stderr, "portable smoke failed:", err)
}
func main() {
	if err := run(); err != nil {
		if smokeRequested() {
			reportSmokeError(err)
		} else {
			alert(err.Error())
		}
		os.Exit(1)
	}
}
func run() error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	base := filepath.Dir(exe)
	data := filepath.Join(base, "Data")
	profile := filepath.Join(data, "profile")
	browser := filepath.Join(base, "App", "Brave", "brave.exe")
	if _, err = os.Stat(browser); err != nil {
		return fmt.Errorf("missing authentic Brave binary: %s\n%s", browser, err)
	}
	if err = os.MkdirAll(profile, 0700); err != nil {
		return err
	}
	if err = os.MkdirAll(filepath.Join(data, "TraceGuard"), 0700); err != nil {
		return err
	}
	closeMutex, err := getMutex(base)
	if err != nil {
		return err
	}
	defer closeMutex()
	lf, err := os.OpenFile(filepath.Join(data, "TraceGuard", "launcher.log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	defer lf.Close()
	logger := log.New(lf, "", log.LstdFlags)
	logger.Printf("launcher starting; base=%q", base)
	var roots []traceguard.Root
	for _, r := range []struct{ Environment, Name string }{{"LOCALAPPDATA", "LocalAppData"}, {"APPDATA", "RoamingAppData"}, {"PROGRAMDATA", "ProgramData"}} {
		home := os.Getenv(r.Environment)
		if home == "" {
			continue
		}
		// Never include the entire AppData or ProgramData directory as a watched root.
		roots = append(roots, traceguard.Root{Name: r.Name, Path: filepath.Join(home, "BraveSoftware")})
		// Some Brave documentation spells this vendor directory with a space.
		roots = append(roots, traceguard.Root{Name: r.Name + "Spaced", Path: filepath.Join(home, "Brave Software")})
	}
	guard := traceguard.New(data, roots, func(m string) { logger.Println(m) })
	// After a previous crash, preserve suspected differences without deleting host data.
	if err = guard.RecoverInterrupted(); err != nil {
		return fmt.Errorf("previous session recovery failed: %w", err)
	}
	before, err := guard.Snapshot()
	if err != nil {
		return fmt.Errorf("host snapshot failed: %w", err)
	}
	if err = guard.Restore(); err != nil {
		return fmt.Errorf("restore failed; no Brave process started: %w", err)
	}
	if err = guard.Start(before); err != nil {
		return err
	}
	args := []string{"--user-data-dir=" + profile, "--disable-brave-update", "--no-default-browser-check", "--disable-logging", "--disable-breakpad", "--disable-machine-id", "--disable-encryption-win", "--no-first-run"}
	testMode := false
	for _, a := range os.Args[1:] {
		if a == "--portable-smoke-test" {
			testMode = true
			continue
		}
		if strings.HasPrefix(strings.ToLower(a), "--user-data-dir") {
			logger.Printf("rejected override: %s", a)
			continue
		}
		args = append(args, a)
	}
	if testMode {
		args = append(args, "--headless=new", "--disable-gpu", "--dump-dom", "about:blank")
	}
	cmd := exec.Command(browser, args...)
	cmd.Dir = filepath.Dir(browser)
	// Normal launch uses the default Windows process creation APIs and no elevated rights.
	if testMode {
		dump, err := os.Create(filepath.Join(data, "TraceGuard", "smoke-output.txt"))
		if err != nil {
			return err
		}
		defer dump.Close()
		cmd.Stdout = dump
		cmd.Stderr = dump
	}
	logger.Printf("starting Brave; smoke=%t", testMode)
	startErr := cmd.Start()
	var waitErr error
	if startErr == nil {
		completed := make(chan error, 1)
		go func() { completed <- cmd.Wait() }()
		if testMode {
			select {
			case waitErr = <-completed:
			case <-time.After(75 * time.Second):
				// Kill ONLY our directly launched smoke-test process, never unrelated browsers.
				_ = cmd.Process.Kill()
				waitErr = <-completed
				waitErr = fmt.Errorf("smoke test exceeded 75 seconds: %w", waitErr)
			}
		} else {
			waitErr = <-completed
		}
	}
	// Wait for any matching executable-path Brave children, not just the initial
	// process. Never kill unrelated browser processes. When active children remain,
	// preserve the interrupted marker and do not touch in-use files.
	if startErr == nil {
		if err := waitForPortableChildren(browser, 45*time.Second, func(m string) { logger.Println(m) }); err != nil {
			logger.Printf("cleanup postponed: %v", err)
			return err
		}
	}
	// File-based cleanup runs after our portable Brave children have exited.
	capErr := guard.Capture(before)
	if capErr != nil {
		logger.Printf("capture incomplete: %v", capErr)
	}
	if startErr != nil {
		return fmt.Errorf("Brave failed to start: %w; capture: %v", startErr, capErr)
	}
	if capErr != nil {
		return fmt.Errorf("external storage could not be fully preserved; see Data\\TraceGuard\\launcher.log: %w", capErr)
	}
	if waitErr != nil {
		logger.Printf("Brave exit: %v", waitErr)
		return fmt.Errorf("Brave returned an error: %w", waitErr)
	}
	logger.Println("Brave session ended normally; recovery completed")
	return nil
}

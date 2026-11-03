package traceguard

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCaptureFilesAndEmptyDirectories(t *testing.T) {
	base := t.TempDir()
	external := filepath.Join(base, "host", "BraveSoftware")
	data := filepath.Join(base, "portable", "Data")
	g := New(data, []Root{{Name: "LocalAppData", Path: external}}, func(string) {})
	before, e := g.Snapshot()
	if e != nil {
		t.Fatal(e)
	}
	if e = g.Start(before); e != nil {
		t.Fatal(e)
	}
	for _, p := range []string{"nonempty/nested", "empty", "empty-tree/child/grandchild"} {
		if e = os.MkdirAll(filepath.Join(external, p), 0700); e != nil {
			t.Fatal(e)
		}
	}
	if e = os.WriteFile(filepath.Join(external, "nonempty", "nested", "new.txt"), []byte("data"), 0600); e != nil {
		t.Fatal(e)
	}
	if e = os.WriteFile(filepath.Join(external, "new-root.txt"), []byte("root"), 0600); e != nil {
		t.Fatal(e)
	}
	if e = g.Capture(before); e != nil {
		t.Fatal(e)
	}
	for _, p := range []string{"nonempty/nested/new.txt", "new-root.txt", "empty", "empty-tree/child/grandchild"} {
		if _, e = os.Stat(filepath.Join(data, "TraceGuard", "Owned", "LocalAppData", p)); e != nil {
			t.Fatal(p, e)
		}
	}
	if _, e = os.Stat(filepath.Join(external, "new-root.txt")); !os.IsNotExist(e) {
		t.Fatal("owned new host file not cleaned")
	}
	if e = g.Restore(); e != nil {
		t.Fatal(e)
	}
	if _, e = os.Stat(filepath.Join(external, "empty-tree/child/grandchild")); e != nil {
		t.Fatal(e)
	}
	if _, e = os.Stat(filepath.Join(external, "new-root.txt")); e != nil {
		t.Fatal(e)
	}
}
func TestExistingHostContentNeverRemoved(t *testing.T) {
	base := t.TempDir()
	external := filepath.Join(base, "host")
	data := filepath.Join(base, "portable", "Data")
	os.MkdirAll(external, 0700)
	os.WriteFile(filepath.Join(external, "existing.txt"), []byte("KEEP"), 0600)
	g := New(data, []Root{{Name: "Roaming", Path: external}}, func(string) {})
	before, e := g.Snapshot()
	if e != nil {
		t.Fatal(e)
	}
	g.Start(before)
	os.MkdirAll(filepath.Join(external, "new-empty"), 0700)
	os.WriteFile(filepath.Join(external, "new.txt"), []byte("new"), 0600)
	if e = g.Capture(before); e != nil {
		t.Fatal(e)
	}
	b, e := os.ReadFile(filepath.Join(external, "existing.txt"))
	if e != nil || string(b) != "KEEP" {
		t.Fatal("existing file damaged")
	}
	if _, e = os.Stat(filepath.Join(external, "new.txt")); e != nil {
		t.Fatal("new file in preexisting host root removed")
	}
	if _, e = os.Stat(filepath.Join(data, "TraceGuard", "Quarantine", "Roaming", "new-empty")); e != nil {
		t.Fatal(e)
	}
	b, e = os.ReadFile(filepath.Join(data, "TraceGuard", "Quarantine", "Roaming", "new.txt"))
	if e != nil || !strings.Contains(string(b), "new") {
		t.Fatal("quarantine missing")
	}
}
func TestManifestTraversalRejected(t *testing.T) {
	g := New(t.TempDir(), []Root{{Name: "R", Path: t.TempDir()}}, nil)
	for _, p := range []string{"../x", "../../secret"} {
		if _, e := g.hostPath(Entry{Root: "R", Rel: p}); e == nil {
			t.Fatal("accepted traversal")
		}
	}
}

func TestReopenedOwnedDirectoryCapturesNewChildren(t *testing.T) {
	root := t.TempDir()
	host := filepath.Join(root, "external")
	data := filepath.Join(root, "Data")
	g := New(data, []Root{{Name: "OwnedRoot", Path: host}}, nil)
	first, err := g.Snapshot()
	if err != nil {
		t.Fatal(err)
	}
	if err = g.Start(first); err != nil {
		t.Fatal(err)
	}
	if err = os.MkdirAll(filepath.Join(host, "persistent", "deep"), 0700); err != nil {
		t.Fatal(err)
	}
	if err = g.Capture(first); err != nil {
		t.Fatal(err)
	}
	second, err := g.Snapshot()
	if err != nil {
		t.Fatal(err)
	}
	if err = g.Restore(); err != nil {
		t.Fatal(err)
	}
	if err = g.Start(second); err != nil {
		t.Fatal(err)
	}
	// New content inside a restored, launcher-owned directory must remain owned.
	os.WriteFile(filepath.Join(host, "persistent", "deep", "new-file.txt"), []byte("new value"), 0600)
	if err = g.Capture(second); err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(filepath.Join(data, "TraceGuard", "Owned", "OwnedRoot", "persistent", "deep", "new-file.txt"))
	if err != nil || string(b) != "new value" {
		t.Fatalf("new file not captured inside restored directory: %v", err)
	}
}

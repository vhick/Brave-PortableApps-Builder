// Package traceguard conservatively tracks Brave-owned external storage locations.
// It never follows symlinks and never changes pre-existing host files.
package traceguard

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type Root struct {
	Name string `json:"name"`
	Path string `json:"path"`
}
type Entry struct {
	Root string `json:"root"`
	Rel  string `json:"rel"`
	Dir  bool   `json:"dir"`
}
type Snapshot struct {
	Items       map[string]bool
	RootExisted map[string]bool
}
type Guard struct {
	Data     string
	Roots    []Root
	Restored map[string]bool
	Log      func(string)
	Session  string
}
type Manifest struct {
	Items []Entry `json:"items"`
}

func New(data string, roots []Root, log func(string)) *Guard {
	if log == nil {
		log = func(string) {}
	}
	return &Guard{Data: data, Roots: roots, Restored: map[string]bool{}, Log: log, Session: filepath.Join(data, "TraceGuard", "session.active")}
}
func id(name, rel string) string { return strings.ToLower(name + "/" + filepath.ToSlash(rel)) }
func validRel(rel string) bool {
	return rel != "" && rel != "." && !filepath.IsAbs(rel) && !strings.HasPrefix(rel, "..") && !strings.Contains(filepath.ToSlash(rel), "/../")
}
func (g *Guard) rootFor(name string) (string, bool) {
	for _, r := range g.Roots {
		if r.Name == name {
			return r.Path, true
		}
	}
	return "", false
}
func (g *Guard) dataPath(e Entry) (string, error) {
	if _, ok := g.rootFor(e.Root); !ok || !validRel(e.Rel) {
		return "", fmt.Errorf("unsafe manifest root or relative path: %q/%q", e.Root, e.Rel)
	}
	return filepath.Join(g.Data, "TraceGuard", "Owned", e.Root, e.Rel), nil
}
func (g *Guard) hostPath(e Entry) (string, error) {
	base, ok := g.rootFor(e.Root)
	if !ok || !validRel(e.Rel) {
		return "", fmt.Errorf("unsafe root/relative path %q %q", e.Root, e.Rel)
	}
	// Never traverse an existing symbolic link or junction in a host path.
	candidate := filepath.Join(base, e.Rel)
	current := base
	if st, er := os.Lstat(current); er == nil && st.Mode()&os.ModeSymlink != 0 {
		return "", fmt.Errorf("host root is symlink: %s", base)
	}
	parts := strings.Split(filepath.Clean(e.Rel), string(filepath.Separator))
	for _, part := range parts {
		current = filepath.Join(current, part)
		st, er := os.Lstat(current)
		if er == nil && st.Mode()&os.ModeSymlink != 0 {
			return "", fmt.Errorf("host path uses symlink: %s", current)
		}
		if er != nil && !errors.Is(er, os.ErrNotExist) {
			return "", er
		}
	}
	return candidate, nil
}
func (g *Guard) restoredOwnership(root, rel string) bool {
	if g.Restored[id(root, rel)] {
		return true
	}
	path := filepath.Dir(rel)
	for path != "." && path != "" && path != string(filepath.Separator) {
		if g.Restored[id(root, path)] {
			return true
		}
		next := filepath.Dir(path)
		if next == path {
			break
		}
		path = next
	}
	return false
}
func loadManifest(p string) (Manifest, error) {
	b, err := os.ReadFile(p)
	if errors.Is(err, os.ErrNotExist) {
		return Manifest{}, nil
	}
	if err != nil {
		return Manifest{}, err
	}
	var m Manifest
	err = json.Unmarshal(b, &m)
	return m, err
}
func writeAtomic(p string, v any) error {
	if err := os.MkdirAll(filepath.Dir(p), 0700); err != nil {
		return err
	}
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	tmp := p + ".pending"
	if err = os.WriteFile(tmp, b, 0600); err != nil {
		return err
	}
	if err = os.Rename(tmp, p); err != nil { // Windows cannot rename over an existing file.
		bak := p + ".previous"
		_ = os.Remove(bak)
		if e := os.Rename(p, bak); e != nil && !errors.Is(e, os.ErrNotExist) {
			return e
		}
		if e := os.Rename(tmp, p); e != nil {
			_ = os.Rename(bak, p)
			return e
		}
		_ = os.Remove(bak)
	}
	return nil
}
func safeWalk(root string, fn func(rel string, dir bool)) error {
	_, err := os.Lstat(root)
	if errors.Is(err, os.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	return filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if path == root {
			return nil
		}
		if d.Type()&os.ModeSymlink != 0 {
			return nil
		}
		rel, er := filepath.Rel(root, path)
		if er != nil || !validRel(rel) {
			return fmt.Errorf("invalid external path %s", path)
		}
		fn(rel, d.IsDir())
		return nil
	})
}
func (g *Guard) Snapshot() (Snapshot, error) {
	s := Snapshot{Items: map[string]bool{}, RootExisted: map[string]bool{}}
	for _, r := range g.Roots {
		st, err := os.Lstat(r.Path)
		if errors.Is(err, os.ErrNotExist) {
			continue
		}
		if err != nil {
			return s, err
		}
		if !st.IsDir() || st.Mode()&os.ModeSymlink != 0 {
			g.Log("skip unsafe root: " + r.Path)
			continue
		}
		s.RootExisted[r.Name] = true
		if err = safeWalk(r.Path, func(rel string, dir bool) { s.Items[id(r.Name, rel)] = dir }); err != nil {
			return s, err
		}
	}
	return s, nil
}
func sha(p string) (string, error) {
	f, e := os.Open(p)
	if e != nil {
		return "", e
	}
	defer f.Close()
	h := sha256.New()
	if _, e = io.Copy(h, f); e != nil {
		return "", e
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
func copyVerified(src, dst string) error {
	st, err := os.Lstat(src)
	if err != nil {
		return err
	}
	if !st.Mode().IsRegular() {
		return fmt.Errorf("not a regular file: %s", src)
	}
	if err = os.MkdirAll(filepath.Dir(dst), 0700); err != nil {
		return err
	}
	tmp := dst + fmt.Sprintf(".pending-%d", os.Getpid())
	defer os.Remove(tmp)
	in, e := os.Open(src)
	if e != nil {
		return e
	}
	defer in.Close()
	out, e := os.OpenFile(tmp, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0600)
	if e != nil {
		return e
	}
	_, e = io.Copy(out, in)
	if x := out.Sync(); e == nil {
		e = x
	}
	if x := out.Close(); e == nil {
		e = x
	}
	if e != nil {
		return e
	}
	a, e := sha(src)
	if e != nil {
		return e
	}
	b, e := sha(tmp)
	if e != nil {
		return e
	}
	if a != b {
		return fmt.Errorf("SHA256 mismatch: %s", src)
	}
	if _, e = os.Stat(dst); e == nil { // never discard the previous portable copy before retaining a backup
		old := dst + ".previous"
		if _, x := os.Stat(old); x == nil {
			return fmt.Errorf("previous backup already exists: %s", old)
		}
		if x := os.Rename(dst, old); x != nil {
			return x
		}
		if x := os.Rename(tmp, dst); x != nil {
			_ = os.Rename(old, dst)
			return x
		}
		_ = os.Remove(old)
	} else if errors.Is(e, os.ErrNotExist) {
		return os.Rename(tmp, dst)
	} else {
		return e
	}
	return nil
}

// Restore only previously owned entries, and only if each host target does not exist.
func (g *Guard) Restore() error {
	m, e := loadManifest(filepath.Join(g.Data, "TraceGuard", "manifest.json"))
	if e != nil {
		return e
	}
	sort.SliceStable(m.Items, func(i, j int) bool { return (len(m.Items[i].Rel) < len(m.Items[j].Rel)) })
	for _, entry := range m.Items {
		src, e := g.dataPath(entry)
		if e != nil {
			return e
		}
		dst, e := g.hostPath(entry)
		if e != nil {
			return e
		}
		if _, e = os.Lstat(dst); e == nil {
			g.Log("host collision; not restoring: " + dst)
			continue
		} else if !errors.Is(e, os.ErrNotExist) {
			return e
		}
		if entry.Dir {
			if e = os.MkdirAll(dst, 0700); e != nil {
				return e
			}
		} else {
			if e = copyVerified(src, dst); e != nil {
				return e
			}
		}
		g.Restored[id(entry.Root, entry.Rel)] = true
	}
	return nil
}
func (g *Guard) Start(baseline Snapshot) error {
	if _, e := os.Stat(g.Session); e == nil {
		return fmt.Errorf("previous session is unfinished; inspect TraceGuard before new launch")
	}
	if err := writeAtomic(filepath.Join(g.Data, "TraceGuard", "baseline.json"), baseline); err != nil {
		return err
	}
	return os.WriteFile(g.Session, []byte(time.Now().UTC().Format(time.RFC3339Nano)), 0600)
}

// Capture saves newly created external entries and restored entries. Only entries
// definitely owned by this launcher (restored or under a previously absent root)
// are removed from the host after verification. Under pre-existing host roots,
// new entries are COPIED into Quarantine, never removed or restored automatically.
func (g *Guard) Capture(before Snapshot) error {
	old, err := loadManifest(filepath.Join(g.Data, "TraceGuard", "manifest.json"))
	if err != nil {
		return err
	}
	own := map[string]Entry{}
	for _, e := range old.Items {
		own[id(e.Root, e.Rel)] = e
	}
	var failure []string
	for _, r := range g.Roots {
		var entries []Entry
		if e := safeWalk(r.Path, func(rel string, dir bool) {
			k := id(r.Name, rel)
			if _, existed := before.Items[k]; !existed || g.restoredOwnership(r.Name, rel) {
				entries = append(entries, Entry{Root: r.Name, Rel: rel, Dir: dir})
			}
		}); e != nil {
			failure = append(failure, e.Error())
			continue
		}
		// Directories first when copying, deepest-first when attempting safe removal.
		sort.SliceStable(entries, func(i, j int) bool {
			if entries[i].Dir != entries[j].Dir {
				return entries[i].Dir
			}
			return len(entries[i].Rel) < len(entries[j].Rel)
		})
		saved := map[string]bool{}
		for _, e := range entries {
			source, x := g.hostPath(e)
			if x != nil {
				failure = append(failure, x.Error())
				continue
			}
			owned := !before.RootExisted[r.Name] || g.restoredOwnership(e.Root, e.Rel)
			target, x := g.dataPath(e)
			if x != nil {
				failure = append(failure, x.Error())
				continue
			}
			if !owned {
				target = filepath.Join(g.Data, "TraceGuard", "Quarantine", e.Root, e.Rel)
			}
			if e.Dir {
				x = os.MkdirAll(target, 0700)
			} else {
				x = copyVerified(source, target)
			}
			if x != nil {
				failure = append(failure, x.Error())
				continue
			}
			if owned {
				own[id(e.Root, e.Rel)] = e
				saved[id(e.Root, e.Rel)] = true
			} else {
				g.Log("host root pre-existed; copied, not removed: " + source)
			}
		}
		// Delete only verified owned files. A concurrent host modification is detected by hash comparison.
		for i := len(entries) - 1; i >= 0; i-- {
			e := entries[i]
			if e.Dir || !saved[id(e.Root, e.Rel)] {
				continue
			}
			src, _ := g.hostPath(e)
			dst, _ := g.dataPath(e)
			a, ae := sha(src)
			b, be := sha(dst)
			if ae != nil || be != nil || a != b {
				failure = append(failure, "changed before cleanup: "+src)
				continue
			}
			if err := os.Remove(src); err != nil {
				failure = append(failure, "unable to remove owned file: "+src+": "+err.Error())
			}
		}
		sort.SliceStable(entries, func(i, j int) bool { return len(entries[i].Rel) > len(entries[j].Rel) })
		for _, e := range entries {
			if !e.Dir || !saved[id(e.Root, e.Rel)] {
				continue
			}
			p, _ := g.hostPath(e)
			_ = os.Remove(p) /* only empty directories removed */
		}
		if !before.RootExisted[r.Name] {
			_ = os.Remove(r.Path)
		}
	}
	var manifest Manifest
	for _, v := range own {
		manifest.Items = append(manifest.Items, v)
	}
	sort.Slice(manifest.Items, func(i, j int) bool {
		return id(manifest.Items[i].Root, manifest.Items[i].Rel) < id(manifest.Items[j].Root, manifest.Items[j].Rel)
	})
	if err := writeAtomic(filepath.Join(g.Data, "TraceGuard", "manifest.json"), manifest); err != nil {
		failure = append(failure, err.Error())
	}
	if len(failure) > 0 {
		return errors.New(strings.Join(failure, "\n"))
	}
	_ = os.Remove(g.Session)
	return nil
}

// Recover after a crash by preserving a non-destructive copy of everything which
// did not appear in the on-disk baseline. No attribution or host removal is claimed.
func (g *Guard) RecoverInterrupted() error {
	if _, e := os.Stat(g.Session); errors.Is(e, os.ErrNotExist) {
		return nil
	}
	b, e := os.ReadFile(filepath.Join(g.Data, "TraceGuard", "baseline.json"))
	if e != nil {
		return e
	}
	var base Snapshot
	if e = json.Unmarshal(b, &base); e != nil {
		return e
	}
	for _, r := range g.Roots {
		err := safeWalk(r.Path, func(rel string, dir bool) {
			if _, found := base.Items[id(r.Name, rel)]; found {
				return
			}
			src := filepath.Join(r.Path, rel)
			dst := filepath.Join(g.Data, "TraceGuard", "CrashRecovery", r.Name, rel)
			var e error
			if dir {
				e = os.MkdirAll(dst, 0700)
			} else {
				e = copyVerified(src, dst)
			}
			if e != nil {
				g.Log("crash recovery copy failed: " + e.Error())
			}
		})
		if err != nil {
			return err
		}
	}
	_ = os.Remove(g.Session)
	g.Log("interrupted run: external differences were COPIED without deleting host data; check CrashRecovery")
	return nil
}

//go:build windows

package main

import (
    "os"
    "testing"
)

func TestSmokeModeIsExplicit(t *testing.T) {
    original := os.Args
    defer func(){ os.Args = original }()
    for _, tc := range []struct{
        args []string
        want bool
    }{
        {[]string{"BravePortable.exe"}, false},
        {[]string{"BravePortable.exe", "--portable-smoke-test"}, true},
        {[]string{"BravePortable.exe", "--no-first-run"}, false},
        {[]string{"BravePortable.exe", "--portable-smoke-test=false"}, false},
    } {
        os.Args = tc.args
        if got := smokeRequested(); got != tc.want {
            t.Errorf("smokeRequested(%v) = %v, want %v", tc.args, got, tc.want)
        }
    }
}

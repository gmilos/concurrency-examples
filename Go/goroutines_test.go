package example

import "testing"
import "time"

func TestA(t *testing.T) {
	start := time.Now()
	main()
	elapsed := time.Since(start)
	if elapsed.Seconds() >= 1.1 {
		t.Fatal("Execution took longer than 1.1 secs")
	}
}

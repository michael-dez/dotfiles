# Known issues

## Overwatch frametime stalls (bcpc), unsolved

~100 ms stalls during play; the main thread is parked in `poll()` on `/dev/nvidia0`.

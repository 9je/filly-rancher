G11 -- 60-pony performance, PS11 second pass (2026-11-08)
==========================================================

Probe: game/scenes/test/perf.gd --ponies=60, rendered under xvfb (invisible) on the RX 9070 XT,
via the scratchpad perf_one.sh. "before" = 4592742 (pony.gd, rump_bounce.gd, body_space.gd as
they were), "after" = 23ebb0b. Runs alternate before/after so the machine's other load (a
1280x720 --fixed-fps 144 render job at 100% CPU, load average 4 to 7 throughout) falls on both.

1. THE PROBE AT 1920x1080 (the gate). Logs g11_{before,after}_1080_{1,2,3}.log

            avg_ms   p95_ms   p99_ms   worst_1s_fps
  before 1  22.26    38.23    44.82    43
  before 2  22.07    38.65    43.62    39
  before 3  21.99    38.65    44.58    39
  after 1   21.06    33.75    39.97    43
  after 2   21.35    35.01    41.06    44
  after 3   21.61    35.02    43.17    40
  All six PERF_FAILED.

2. THE SAME AT 960x540 (--window=960x540: less presentation, so the game's own threads show).
   Logs g11_{before,after}_540_{1,2,3}.log

            avg_ms   p95_ms   p99_ms   worst_1s_fps
  before    15.98 / 15.11 / 15.51   26.51 / 25.43 / 25.80   32.93 / 33.13 / 32.45   56 / 60 / 57
  after     14.34 / 14.91 / 14.61   23.51 / 25.39 / 24.05   28.35 / 32.50 / 28.87   56 / 54 / 61

3. PER-SECTION PROFILE (temporary timers, removed before commit; two alternating runs each).
   Logs g11_prof_{before,after}_{1,2}.log. Per physics tick unless marked per frame.

                                       before 1 / 2      after 1 / 2
  frame (ms per frame)                 21.33 / 21.69     20.82 / 21.84
  idle pass (ms per frame)              3.69 / 3.68       2.68 / 2.85
  all physics scripts (ms per tick)     7.93 / 8.29       6.35 / 6.63
    pony._physics_process total         6.74 / 7.29       5.27 / 5.51
      BodySpace (push, aside, solve)    3.91 / 4.24       2.59 / 2.73
        of which the solve              4.03 / 4.15       2.50 / 2.62
      facing (turn checks)              1.39 / 1.52       1.13 / 1.17
      anim advance / think / slide / anim update: about 0.3 / 0.3 / 0.3 / 0.2 both
  physics step after the last tick      1.05 / 1.12       1.03 / 1.08
  waiting on the render thread and the
  rest of the frame (ms per frame)      8.57 / 8.24      10.68 / 10.78

   The main thread's work fell by about 2.5 ms a frame (1.6 ms a tick at 1.25 to 1.3 ticks a
   frame, and 1 ms of idle pass), and the time it waits on the render thread grew by the same
   amount: at 1920x1080 under this display the frame is the render thread's, not the scripts'.

4. WHERE THE REST OF THE FRAME GOES (why PERF_OK cannot be shown here).
   - PERF_SPLIT's process_ms and physics_ms are Godot's per-second MAXIMA of the whole idle step
     (which includes waiting on the render thread) and of a whole physics step, not per-frame
     script time; the measured script time is 6.4 to 8.3 ms a tick (section 3).
   - Pony physics switched off entirely (exp=latephys, g11_late2.log): tick scripts 3.46 ms,
     avg 19.43 ms, p99 31.88 ms, PERF_FAILED, with the main thread waiting 13.6 ms a frame on
     the render thread.
   - An all-but-empty 3D scene (one box, one light) at 1920x1080 under the same display: avg
     6.81 ms, p99 13.34 ms (scratchpad run). That is the invisible display's presentation floor.
   - Thread CPU during the measured window: main thread 55 to 60%, render thread 47 to 52%:
     neither is saturated; each frame the render thread is blocked about half its time on
     presenting through the software WSI path (MESA_VK_WSI_DEBUG=sw under Xvfb).

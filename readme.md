# Benchmark

Nimrod module to help with benchmarks while adding as low overhead as possible. 

Example:

```
var sw = StopWatchInit()
let repeats = 100_000

sw.start()
for i in 0 .. <repeats:
  bar()
  sw.lap(store=true)
    
let total_time = sw.pause()
let laps = sw.getLaps()

echo("Laps total time: ", laps.sum(), "Laps per second: ", 60/laps.mean())
echo("Total time: ", total_time)
```


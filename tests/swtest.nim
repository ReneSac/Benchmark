import "../src/benchmark"
import math
import os
import times

proc bar(): float = 
  var sw = StopWatchInit(auto_start = true)
  assert sw.isRunning() == true
  sw.lap(pause=true, store=true)
  assert sw.isRunning() == false
  assert sw.getLaps().len == 1
  
  sw.reset()
  assert sw.peek() == 0.0
  assert sw.getLaps().len == 0
  
  sw.start()
  assert sw.isRunning() == true
  
  sw.lap()
  assert sw.getLaps().len == 0
  assert sw.isRunning() == true
  #sleep(100000)
  sw.pause()
  assert sw.isRunning() == false
  let peek = sw.peek()
  #assert peek > 0.0  # 
  return sw.peek()
    
proc swtest() =    
  var sw = StopWatchInit()
  var sum_time: float = 0.0
  let repeats = 100_000
  
  sw.start()
  for i in 0 .. <repeats:
    sum_time += bar()
    sw.lap(store=true)
    
  let total_time = sw.pause()
  let laps = sw.getLaps()
  let sum_laps = laps.sum()
  assert laps.len == repeats
  assert total_time > sum_time
  assert sum_laps > sum_time
  assert total_time >= sum_laps
  
  #   for i, e in laps:
  #     if e != 0:
  #       echo i
  
  echo("Inner partial time sum: ", sum_time)
  echo("Laps total time: ", sum_laps, "  Laps per second: ", 60/laps.mean())
  echo("Total time: ", total_time)
 


proc main() =
  swtest()

  #echo timeit(100_000, 3) do:
  #  discard bar()


when isMainModule:
  main()

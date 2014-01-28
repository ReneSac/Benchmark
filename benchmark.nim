# Copyright (C) 2014, René du R. Sacramento. All rights reserved.
# MIT License. Look at license.txt for more info.

import times

type
  TStopWatch = object
    start_time, total_time: float
    laps: seq[float]
    running: bool
    
    

# If the program was started more than 3 hours ago in a system where float 
# defaults to float32 we don't even have mili-seconds time precision anymore. 
# And we already lost our micro-second time precision after 9 seconds of 
# execution.

proc StopWatchInit*(auto_start:bool = false): TStopWatch = 
  ## Returns a new stop watch object. It can also start automatically to count time.
  result = TStopWatch(start_time: 0.0, total_time: 0.0, 
                      laps: newSeq[float](), running: auto_start)
  if auto_start:
    result.start_time = cpuTime()


proc start*(sw: var TStopWatch) {.inline} =
  ## Starts the stop watch. Can't be called when it is already running.
  assert(not sw.running)
  sw.start_time = cpuTime()
  sw.running = true
  
  
proc pause*(sw: var TStopWatch): float {.discardable, inline.} =
  ## Pauses the stop watch. Can't be called if it is already stopped.
  assert(sw.running)
  sw.total_time += cpuTime() - sw.start_time
  sw.running = false
  return sw.total_time


proc reset*(sw: var TStopWatch): float {.discardable, inline.} =
  ## Resets the stop watch to the initial state, but keeps it running or paused.
  sw.start_time = if sw.running: cpuTime() else: 0
  result = sw.total_time
  sw.laps = newSeq[float]()
  sw.total_time = 0
  
  
proc peek*(sw: TStopWatch): float {.inline.} =
  ## Peeks at the amount of time that has passed since the stop watch was 
  ## first started, excluding the periods where it was paused. 
  ##
  ## It can be safely called even when the stop watch is paused or running.
  if sw.running:
    return sw.total_time + cpuTime() - sw.start_time
  else:
    return sw.total_time
    
    
proc lap*(sw: var TStopWatch, pause: bool = false,
          store: bool = false): float {.discardable, inline.} =
  ## Gives the time since start() or lap() was last called (or since last 
  ## reset(), if it was called while the stop watch was running). It don't affects
  ## the accumulated time.
  ##
  ## Do not call if the stop watch isn't running.
  assert(sw.running) 
  let cur = cpuTime()
  result = cur - sw.start_time
  sw.start_time = cur
  sw.total_time += result
  if store:            # Those 'if's will probably be optimized out when inlined.
    sw.laps.add(result)
    sw.start_time = cpuTime()  # Don't count any time spent appending to the seq.
  if pause:
    sw.running = false
    
    
proc getLaps*(sw: TStopWatch): seq[float] {.inline, noSideEffect.} =
  ## Returns a sequence with all the laps finished till now.
  return sw.laps
    
  
proc isRunning*(sw: TStopWatch): bool {.inline, noSideEffect.} =
  ## Says wether the stop watch is running or not.
  return sw.running


when isMainModule:
  import math
  
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
    
    sw.pause()
    assert sw.isRunning() == false
    let peek = sw.peek()
    #assert peek > 0.0  # 
    return sw.peek()
    
    
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
  
  echo("Inner partial time sum: ", sum_time)
  echo("Laps total time: ", sum_laps, "  Laps per second: ", 60/laps.mean())
  echo("Total time: ", total_time)
  

# Copyright (C) 2014, René du R. Sacramento. All rights reserved.
# MIT License. Look at license.txt for more info.

import times, math, strutils

type
  TStopWatch = ref object
    start_time, total_time: float
    laps*: seq[float]
    running*: bool
    
let s = TStopWatch()


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


proc start*(sw: var TStopWatch) {.inline.} =
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


type TimeitResult* = tuple
  best: float
  loops, repeats: int
  laps: seq[float]
  

proc `$`*(r: TimeitResult): string =
  result = $r.loops & " loops, best of " & $r.repeats & ": "
  var t = r.best * 1_000_000 / r.loops.float  # time in micro seconds.
  
  if t < 1000:
    result &= formatFloat(t, precision=3) & " usec per loop"
  else:
    t = t / 1000
    if t < 1000:
      result &= formatFloat(t, precision=3) & " msec per loop"
    else:
      result &= formatFloat(t/1000, precision=3) & " sec per loop"
  
template timeit*(loop: int = 0, repeat: int = 3, code: stmt): TimeitResult = 
  var res: TimeitResult# = (loops: loop, repeats: repeat)
  var sw = StopWatchInit()
  var vloop = loop
  var vrepeat = repeat
  res.repeats = repeat
  
  # If 0, automatically find a suitable loop value so that:
  # 0.2 <= total time < 2.0 secs
  if vloop == 0:  
    vrepeat -= 1  # The first repeat will be the last one done here.
    vloop = 1
    
    for i in 0 .. 10: # Try up to 10^10 loops. Could be a while true.
      sw.start()
      for i in 0 .. <vloop:
        code
      var x = sw.lap(store=true, pause=true)
      if x >= 0.2:
        break
      else:
        vloop *= 10
        sw.reset()
        
  res.loops = vloop
  sw.start()
  for i in 0.. <vrepeat:
    for j in 0.. <vloop:
      code
    sw.lap(store=true)
  res.laps = sw.laps
  res.best = min(sw.laps) # the minimum time is the most consistent.
  res
  
#template timeit*(code: stmt): TimeitResult {.immediate.} = 
#  # {.immediate.} for allowing overloading, I think.
#  timeit(1000,3,code)

  

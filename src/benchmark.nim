# Copyright (C) 2014, René du R. Sacramento. All rights reserved.
# MIT License. Look at license.txt for more info.

import math, strutils, timers

type
  StopWatch = ref object
    start_time: Ticks
    total_time: Nanos
    laps*: seq[Nanos]
    running: bool
    
type Qwop = distinct Nanos

converter NanosToQwops(t: Nanos):Qwop = t.Qwop

# references:
#  https://gitlab.com/define-private-public/stopwatch/blob/master/stopwatch/regular.nim
#  https://github.com/winksaville/nim-benchmark/blob/master/benchmark.nim

#===============================#
#== Time Conversion Functions ==#
#===============================#

## Converts Qwop to nanoseconds
proc nsecs*(nsecs: Nanos | Qwop): int64 =
  return Nanos(nsecs)

## Converts nanoseconds to microseconds
proc usecs*(nsecs: Nanos | Qwop): int64 =
  return (nsecs.nsecs div 1_000).int64


## Converts nanoseconds to microseconds
proc msecs*(nsecs: Nanos | Qwop): int64 =
  return (nsecs.Nanos div 1_000_000).int64

## Converts nanoseconds to seconds (represented as a float)
proc secs*(nsecs: Nanos | Qwop): float =
  return nsecs.float / 1_000_000_000.0



proc StopWatchInit*(auto_start:bool = false): StopWatch =
  ## Returns a new stop watch object. It can also start automatically to count time.
  result = StopWatch(start_time: 0.Ticks, total_time: 0,
                      laps: newSeq[Nanos](), running: auto_start)
  if auto_start:
    result.start_time = getTicks()


proc start*(sw: var StopWatch) {.inline.} =
  ## Starts the stop watch. Can't be called when it is already running.
  assert(not sw.running)
  sw.start_time = getTicks()
  sw.running = true
  
  
proc pause*(sw: var StopWatch): Qwop {.discardable, inline.} =
  ## Pauses the stop watch. Can't be called if it is already stopped.
  assert(sw.running)
  sw.total_time += getTicks() - sw.start_time
  sw.running = false
  return sw.total_time


proc reset*(sw: var StopWatch): Qwop {.discardable, inline.} =
  ## Resets the stop watch to the initial state, but keeps it running or paused.
  sw.start_time = if sw.running: getTicks() else: 0.Ticks
  result = sw.total_time
  sw.laps = newSeq[Nanos]()
  sw.total_time = 0
  
  
proc peek*(sw: StopWatch): Qwop {.inline.} =
  ## Peeks at the amount of time that has passed since the stop watch was 
  ## first started, excluding the periods where it was paused. 
  ##
  ## It can be safely called even when the stop watch is paused or running.
  if sw.running:
    return sw.total_time + (getTicks() - sw.start_time)
  else:
    return sw.total_time
    
    
proc lap*(sw: var StopWatch, pause: bool = false,
          store: bool = false): Qwop {.discardable, inline.} =
  ## Gives the time since start() or lap() was last called (or since last 
  ## reset(), if it was called while the stop watch was running). It don't affects
  ## the accumulated time.
  ##
  ## Do not call if the stop watch isn't running.
  assert(sw.running) 
  let cur = getTicks()
  result = cur - sw.start_time
  sw.start_time = cur
  sw.total_time += result.Nanos
  if store:            # Those 'if's will probably be optimized out when inlined.
    sw.laps.add(result.Nanos)
    sw.start_time = getTicks()  # Don't count any time spent appending to the seq.
  if pause:
    sw.running = false
    
    
proc getLaps*(sw: StopWatch): seq[Nanos] {.inline, noSideEffect.} =
  ## Returns a sequence with all the laps finished till now.
  return sw.laps
    
  
proc isRunning*(sw: StopWatch): bool {.inline, noSideEffect.} =
  ## Says wether the stop watch is running or not.
  return sw.running


type TimeitResult* = tuple
  best: Nanos
  loops, repeats: int
  laps: seq[Nanos]
  

proc `$`*(n: Qwop): string =
  if n.Nanos< 1000:
    return $(n.Nanos) & " ns"
  var t = n.float64/1_000_000_000'f64
  const unit = ["s", "ms", "us"]
  var count = 0
  while t < 1 and count < unit.len:
    t *= 1000
    inc count
  result = formatFloat(t, precision=4) & " " & unit[count]
  

proc `$`*(r: TimeitResult): string =
  result = $r.loops & " loops, best of " & $r.repeats & ": "
  #var t = r.best * 1_000_000_000_000 / r.loops.float #pico seconds
  var t = r.best.float64 / r.loops.float64
  const unit = ["s", "ms", "us", "ns", "ps"]
  var count = 0
  while t < 1 and count < unit.len:
    t *= 1000
    count += 1
  result &= formatFloat(t, precision=4) & " " & unit[count] & " per loop"

  
template timeit*(loop: int = 0, repeat: int = 3, code: typed): TimeitResult = 
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

  

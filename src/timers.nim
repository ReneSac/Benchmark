#
#
#            Nim's Runtime Library
#        (c) Copyright 2012 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## Timer support for the realtime GC. Based on
## `<https://github.com/jckarter/clay/blob/master/compiler/src/hirestimer.cpp>`_


import rationals

type
  Ticks* = distinct int64
  Nanos* = int64 ## Nanoseconds


# Plataform specific functions and data types for high resolution clock that are
# not exported.

when defined(windows):
  proc QueryPerformanceCounter(res: var Ticks) {.
    importc: "QueryPerformanceCounter", stdcall, dynlib: "kernel32".}
  proc QueryPerformanceFrequency(res: var int64) {.
    importc: "QueryPerformanceFrequency", stdcall, dynlib: "kernel32".}

elif defined(macosx):
  type
    TMachTimebaseInfoData {.pure, final,
        importc: "mach_timebase_info_data_t",
        header: "<mach/mach_time.h>".} = object
      numer, denom: int32

  proc mach_absolute_time(): int64 {.importc, header: "<mach/mach.h>".}
  proc mach_timebase_info(info: var TMachTimebaseInfoData) {.importc,
    header: "<mach/mach_time.h>".}

  var timeBaseInfo: TMachTimebaseInfoData
  mach_timebase_info(timeBaseInfo)

else: #elif defined(posixRealtime):
  type
    TClockid {.importc: "clockid_t", header: "<time.h>", final.} = object

    TTimeSpec {.importc: "struct timespec", header: "<time.h>",
               final, pure.} = object ## struct timespec
      tv_sec: int  ## Seconds.
      tv_nsec: int ## Nanoseconds.

  var
    CLOCK_REALTIME {.importc: "CLOCK_REALTIME", header: "<time.h>".}: TClockid

  proc clock_gettime(clkId: TClockid, tp: var TTimespec) {.
    importc: "clock_gettime", header: "<time.h>".}

when false:
  # fallback Posix implementation:
  type
    Ttimeval {.importc: "struct timeval", header: "<sys/select.h>",
               final, pure.} = object ## struct timeval
      tv_sec: int  ## Seconds.
      tv_usec: int ## Microseconds.

  proc posix_gettimeofday(tp: var Ttimeval, unused: pointer = nil) {.
    importc: "gettimeofday", header: "<sys/time.h>".}


#
# High resolution clock functions that are exported
#

proc getTicks*(): Ticks {.inline.} =
  ## Gets global time by the system's highest resolution timer.
  ## This value by itself has no defined meaning.
  ##
  ## WARNING: There is no guarantee of a monotonously increasing time value.
  ## The value returned can randomly jump forwards or backwards when the kernel
  ## moves your thread across cores/CPUs, for example.
  when defined(windows):
    QueryPerformanceCounter(result)

  elif defined(macosx):
    result = Ticks(mach_absolute_time())

  else: #elif defined(posixRealtime):
    var t: TTimespec
    clock_gettime(CLOCK_REALTIME, t)
    result = Ticks(int64(t.tv_sec) * 1_000_000_000'i64 + int64(t.tv_nsec))

  when false:
    var t: Ttimeval
    posix_gettimeofday(t)
    result = Ticks(int64(t.tv_sec) * 1_000_000_000'i64 +
                    int64(t.tv_usec) * 1000'i64)

proc `-`*(a, b: Ticks): Nanos =
  ## Subtracts two time values aquired by getTicks. The result is the number of
  ## nanoseconds that elapsed between the two measurements. The precision is in
  ## nanoseconds, but the accuracy may be lower.
  when defined(windows):
    var frequency: int64
    QueryPerformanceFrequency(frequency)
    var performanceCounterRate = 1000000000.0 / toFloat(frequency.int)
    result = ((a.int64 - b.int64).int.toFloat * performanceCounterRate).Nanos

  elif defined(macosx):
    result = (a.int64 - b.int64)  * timeBaseInfo.numer div timeBaseInfo.denom

  else: # for posixRealtime and other Posix
    result = (a.int64 - b.int64)


## Information about each native time functions

type
  ClockInfo = ref object
    adjustable, monotonic: bool
    implementation: string

    resolution: Rational



# Direct hardware instruction access
type
  Clocks = int64

proc getClockCycles(): Clocks =
  ## Access directly the CPU cycle counter, w/o any intermediate syscall.
  ## It is the lowest latency and highest precision ticker available, but is
  ## not not monotonic nor measure time at a constant rate.
  ## On intel processors it uses the rdtsc instruction.
  result = 0

when isMainModule:
  echo "test:"
  var a = getTicks()
  var b = getClockCycles()
  var c = getTicks()
  echo c - a
  echo b

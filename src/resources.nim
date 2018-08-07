## This is similar to the Resource library from Python.


type
  Ticks = distinct int64
  Nanos = int64 ## Nanoseconds
  Seconds* = float

type ExecStats* = object
  userTime, sysTime : Seconds # In seconds. Nanos would be better?
  maxMem, curMem, gcTotalMem, gcOccupiedMem: int64 # in bytes

when defined(windows):
  import windows, psapi

#   type
#     HANDLE* = int
#     DWORD* = int32
#     SIZE_T* = ByteAddress
#     WINBOOL* = int32
#
#   type
#     ProcessMemoryCounters {.importc: "struct PROCESS_MEMORY_COUNTERS",
#                            header: "<psapi.h>", final, pure.} = object
#       cb, PageFaultCount: DWORD
#       PeakWorkingSetSize: SIZE_T
#       WorkingSetSize: SIZE_T
#       QuotaPeakPagedPoolUsage: SIZE_T
#       QuotaPagedPoolUsage: SIZE_T
#       QuotaPeakNonPagedPoolUsage: SIZE_T
#       QuotaNonPagedPoolUsage: SIZE_T
#       PagefileUsage: SIZE_T
#       PeakPagefileUsage : SIZE_T
#
#   proc GetProcessMemoryInfo(id: HANDLE, res: var PPROCESS_MEMORY_COUNTERS,
#                             size: DWORD): WINBOOL {.
#                   importc: "GetProcessMemoryInfo", stdcall, dynlib: "psapi".}
#
#   proc GetCurrentProcess(): HANDLE{.stdcall, dynlib: "kernel32",
#                                    importc: "GetCurrentProcess".}
#



# elif defined(macosx):
#   type
#      MachTaskBasicInfo {.pure, final,
#         importc: "mach_task_basic_info",
#         header: "<mach/mach.h>".} = object
#
#
# struct mach_task_basic_info {
#         mach_vm_size_t  virtual_size;       /* virtual memory size (bytes) */
#         mach_vm_size_t  resident_size;      /* resident memory size (bytes) */
#         mach_vm_size_t  resident_size_max;  /* maximum resident memory size (bytes) */
#         time_value_t    user_time;          /* total user run time for terminated threads */
#         time_value_t    system_time;        /* total system run time for terminated threads */
#         policy_t        policy;             /* default policy for new threads */
#         integer_t       suspend_count;      /* suspend count for task */
# };
#
#   struct mach_task_basic_info info;
#   mach_msg_type_number_t infoCount = MACH_TASK_BASIC_INFO_COUNT;
#   if ( task_info( mach_task_self( ), MACH_TASK_BASIC_INFO,
#     (task_info_t)&info, &infoCount ) != KERN_SUCCESS )
#     return (size_t)0L;    /* Can't access? */
#   return (size_t)info.resident_size;

else:
  # fallback Posix implementation:
  type
    Timeval {.importc: "struct timeval", header: "<sys/select.h>",
               final, pure.} = object ## struct timeval
      tv_sec: int  ## Seconds.
      tv_usec: int ## Microseconds.

    RUsage {.importc: "struct rusage", header: "<sys/resource.h>",
            final, pure.} = object
      # Only the two initial fields are defined by Posix. The other
      # fields can be zero if not implemented (and often are).
      ru_utime: Timeval     # user time used
      ru_stime: Timeval     # system time used
      ru_maxrss: int        # maximum resident set size
      ru_ixrss: int         # integral shared memory size
      ru_idrss: int         # integral unshared data size
      ru_isrss: int         # integral unshared stack size
      ru_minflt: int        # page reclaims
      ru_majflt: int        # page faults
      ru_nswap: int         # swaps
      ru_inblock: int       # block input operations
      ru_oublock: int       # block output operations
      ru_msgsnd: int        # messages sent
      ru_msgrcv: int        # messages received
      ru_nsignals: int      # signals received
      ru_nvcsw: int         # voluntary context switches
      ru_nivcsw: int        # involuntary context switches

  var
    RUSAGE_SELF* {.importc: "RUSAGE_SELF", header: "<sys/resource.h>".}: int32
    RUSAGE_CHILDREN* {.importc: "RUSAGE_SELF", header: "<sys/resource.h>".}: int32
    RUSAGE_BOTH* {.importc: "RUSAGE_BOTH", header: "<sys/resource.h>".}: int32

  proc posix_getrusage(target: int32, data: var RUsage): int32 {.
    importc: "getrusage", header: "<sys/resource.h>".}

proc toNanos(t: Timeval): Nanos =
  return Nanos(int64(t.tv_sec) * 1000_000_000'i64 +
                    int64(t.tv_usec) * 1000'i64)
proc toSeconds(t: Timeval): Seconds =
  return Seconds(Seconds(t.tv_sec) + Seconds(t.tv_usec) / 1_000_000.Seconds)

proc `+`(a, b: Timeval): Timeval =
  result.tv_sec = a.tv_sec + b.tv_sec
  result.tv_usec = a.tv_usec + b.tv_usec

proc getExecStats*(target: int32): ExecStats =
  when defined(windows):
    PROCESS_MEMORY_COUNTERS info;
    discard GetProcessMemoryInfo(GetCurrentProcess(), info, sizeof(info) )
    result.maxMem = info.PeakWorkingSetSize;
    result.curMem = info.WorkingSetSize;
  else:
    var info: RUsage
    discard posix_getrusage(target, info)
    result.userTime = info.ru_utime.toSeconds()
    result.sysTime = info.ru_stime.toSeconds()
    when defined(linux):
      result.maxMem = info.ru_maxrss * 1000
      result.curMem = 0 # must read on procfs for linux

  # This is unnecessary... I will get rid of it
  result.gcTotalMem = getTotalMem()
  result.gcOccupiedMem = getOccupiedMem()

proc cpuTime*() {.inline.}: float =
  # About 5% slower than the times.cpuTime() function on linux, that calls
  # clock(), but on the other hand don't wraps around every 72 minutes like
  # clock() does.
  when false:
    var info = getExecStats(RUSAGE_SELF)
    result = info.userTime + info.sysTime
  else:
    var info: RUsage
    discard posix_getrusage(RUSAGE_SELF, info)
    result = toSeconds(info.ru_utime + info.ru_stime)

import benchmark
from times import nil

echo repr(getExecStats(RUSAGE_SELF))

var a:float = 0
echo timeit(0,5, a += times.cpuTime())
echo a
echo times.cpuTime()
echo cpuTime()
echo times.cpuTime()
echo cpuTime()

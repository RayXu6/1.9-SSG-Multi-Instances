; 1.9 SSG juice based on Peej's 1.16 SSG macro backported to Pre 1.9 by FinestPigeon
; Latest Atum and TabFocus are required mods
; SleepBackground and StandardSettings recommended
; Pause on lost focus must be DISABLED

; Instructions: https://github.com/pjagada/spawn-juicer#readme

#NoEnv
#SingleInstance Force
;#Warn

SetKeyDelay, 0
SetWinDelay, 1
SetTitleMatchMode, 2

; macro options:
global unpauseOnSwitch := False ; unpause when switched to instance with ready spawn
global playSound := False ; will play a windows sound or the sound stored as spawnready.mp3 whenever a spawn is ready
global disableTTS := False ; this is the "ready" sound that plays when the macro is ready to go
global restartDelay := 200 ; increase if saying missing instanceNumber in .minecraft (and you ran setup)
global maxLoops := 20 ; increase if macro regularly locks
global f3showDuration = -1 ; how many milliseconds f3 is shown for at the start of a run (for verification purposes). Make this -1 if you don't want it to show f3. Remember that one frame at 60 fps is 17 milliseconds, and one frame at 30 fps is 33 milliseconds. You'll probably want to show this for 2 or 3 frames to be safe.
global f3showDelay = 100 ; how many milliseconds of delay before showing f3. If f3 isn't being shown, this is all probably happening during the joining world screen, so increase this number.
global muteResets := True ; mute resetting sounds
global beforePauseDelay := 0 ; increase if macro doesnt pause
global logging = True ; turn this to True to generate logs in macro_logs.txt and DebugView; don't keep this on True because it'll slow things down

; Autoresetter Options:
; The autoresetter will automatically reset if your spawn is greater than a certain number of blocks away from a certain point (ignoring y)
global centerPointX := -1516.5 ; this is the x coordinate of that certain point
global centerPointZ := 139.5 ; this is the z coordinate of that certain point
global radius := 5 ; if this is 10 for example, the autoresetter will not reset if you are within 10 blocks of the point specified above. Set this smaller for better spawns but more resets
; if you would only like to reset the blacklisted spawns or don't want automatic resets, then just set this number really large (1000 should be good enough), and if you would only like to play out whitelisted spawns, then just make this number negative
global giveAngle := False ; Give the angle (TTS) that you need to travel at to get to your starting point

; Multi options (single-instance users ignore these)
global affinity := True ;
global lowBitmaskMultiplier := 0.3 ; for affinity, find a happy medium, max=1.0; lower means more threads to the main instance and less to the background instances, higher means more threads to background instances and less to main instance
global obsDelay := 50 ; increase if not changing scenes in obs



; Don't configure these, scroll to the very bottom to configure hotkeys
EnvGet, threadCount, NUMBER_OF_PROCESSORS
global currInst := -1
global pauseAuto := False
global SavesDirectories := []
global McDirectories := []
global instances := 0
global rawPIDs := []
global PIDs := []
global titles := []
global resetStates := []
global resetTimes := []
global startTimes := []
global reachedSave := []
global xCoords := []
global zCoords := []
global distances := []
global playerState := 0 ; needs spawn
global highBitMask := (2 ** threadCount) - 1
global lowBitMask := (2 ** Ceil(threadCount * lowBitmaskMultiplier)) - 1

GetAllPIDs()
SetTitles()

tmptitle := ""
for i, tmppid in PIDs{
  WinGetTitle, tmptitle, ahk_pid %tmppid%
  titles.Push(tmptitle)
  resetStates.push(2) ; need to exit
  resetTimes.push(0)
  xCoords.Push(0)
  zCoords.Push(0)
  distances.Push(0)
  startTimes.Push(A_TickCount)
  reachedSave.Push(false)
  WinSet, AlwaysOnTop, Off, ahk_pid %tmppid%
}

if (affinity) {
  Logg("Setting high affinity for all instances since starting script")
  for i, tmppid in PIDs {
    Logg("Setting high affinity for instance " . i . " since starting script")
    SetAffinity(tmppid, highBitMask)
  }
}

if (!disableTTS)
  ComObjCreate("SAPI.SpVoice").Speak("Ready")
MsgBox, resetting will start when you close this box

#Persistent
SetTimer, Repeat, 100
return

Repeat:
  Critical
  for i, pid in PIDs {
    HandleResetState(pid, i)
  }
  HandlePlayerState()
return

HandlePlayerState()
{
  if (playerState == 0) ; needs spawn
  {
    instancesWithGoodSpawns := []
    for r, state in resetStates
    {
      if (state >= 8)
      {
        instancesWithGoodSpawns.Push(r)
        Logg("Instance " . r . " has a good spawn so adding it to instancesWithGoodSpawns")
      }
    }
    bestSpawn := -1
    counter = 0
    for p, q in instancesWithGoodSpawns
    {
      counter += 1
      if (counter = 1)
      {
        minDist := distances[q]
        bestSpawn := q
      }
      theDistance := distances[q]
      if (theDistance <= minDist)
      {
        minDist := distances[q]
		    bestSpawn := q
      }
	}
	if (counter > 0)
	{
      writeString := "player given spawn of distance " . minDist . "`n"
      Logg(writeString)
      resetStates[bestSpawn] := 0 ; running
      SwitchInstance(bestSpawn)
      AlertUser(bestSpawn)
      playerState := 1 ; running
      ;if (stopResetsWhilePlaying)
      ;  playerState := 2 ; running and stop background resetting
    }
  }
}

HandleResetState(pid, idx) {
  if (resetStates[idx] == 0) ; running
    return
  else if (resetStates[idx] == 1) ; needs to reset from play
  {
    theState := resetStates[idx]
    Logg("Instance " . idx . " in state " . theState)
    WinSet, AlwaysOnTop, Off, ahk_pid %pid%
    ControlSend, ahk_parent, {Blind}{F6}, ahk_pid %pid%
  }
  else if (resetStates[idx] == 2) ; need to exit world from pause
  {
    theState := resetStates[idx]
    Logg("Instance " . idx . " in state " . theState)
    ControlSend, ahk_parent, {Blind}{F6}, ahk_pid %pid%
  }
  else if (resetStates[idx] == 3) ; waiting to enter time between worlds
  {
    theState := resetStates[idx]
    p := PixelColorSimple(0, 0, getHwndForPid(pid))
    if (p != 0x2E2117)
      return
    Logg("Instance " . idx . " exited world so switching to state 4")
  }
  else if (resetStates[idx] == 4) { ; checking if loaded in
    theState := resetStates[idx]
    p := PixelColorSimple(0, 0, getHwndForPid(pid))
    if (p == 0x2E2117)
      return
    Logg("Instance " . idx . " exited world so switching to state 4")
  }
  else if (resetStates[idx] == 5) { ; checking if loaded in
    theState := resetStates[idx]
    ;OutputDebug, [macro] Instance %idx% in state %theState%
    Sleep %beforePauseDelay%
    ControlSend, ahk_parent, {Blind}{Esc}, ahk_pid %pid%
  }
  else if (resetStates[idx] == 6) ; get spawn
  {
    theState := resetStates[idx]
    Logg("Instance " . idx . " in state " . theState)
    GetSpawn(idx)
  }
  else if (resetStates[idx] == 7) ; check spawn
  {
    theState := resetStates[idx]
    Logg("Instance " . idx . " in state " . theState)
    if (GoodSpawn(idx)) {
      Logg("Instance " . idx . " has a good spawn so switching to state 7")
      resetStates[idx] := 8 ; good spawn unfrozen
    }
    else
    {
      Logg("Instance " . idx . " has a bad spawn so switching to state 2")
      resetStates[idx] := 2 ; need to exit world
    }
    return
  }
  else if (resetStates[idx] == 8) ; good spawn waiting to reach final save
  {
    theState := resetStates[idx]
    ;OutputDebug, [macro] Instance %idx% in state %theState%
    if (playerState == 0) ; needs spawn so this instance about to be used
    {
      return
    }
    startTimes[idx] := A_TickCount
  }
  else if (resetStates[idx] == 9) ; frozen good spawn waiting to be used
  {
    return
  }
  else {
    theState := resetStates[idx]
    MsgBox, instance %idx% ended up at unknown reset state of %theState%, exiting script
    ExitApp
  }
  resetStates[idx] += 1 ; Progress State
}

GetAllPIDs()
{
  global McDirectories
  global PIDs
  global instances := GetInstanceTotal()
  ; Generate mcdir and order PIDs
  Loop, %instances% {
    mcdir := GetMcDir(rawPIDs[A_Index])
    if (num := GetInstanceNumberFromMcDir(mcdir)) == -1
      ExitApp
    PIDS[num] := rawPIDs[A_Index]
    McDirectories[num] := mcdir
  }
}

RunHide(Command)
{
  dhw := A_DetectHiddenWindows
  DetectHiddenWindows, On
  Run, %ComSpec%,, Hide, cPid
  WinWait, ahk_pid %cPid%
  DetectHiddenWindows, %dhw%
  DllCall("AttachConsole", "uint", cPid)

  Shell := ComObjCreate("WScript.Shell")
  Exec := Shell.Exec(Command)
  Result := Exec.StdOut.ReadAll()

  DllCall("FreeConsole")
  Process, Close, %cPid%
Return Result
}

GetMcDir(pid)
{
  command := Format("powershell.exe $x = Get-WmiObject Win32_Process -Filter \""ProcessId = {1}\""; $x.CommandLine", pid)
  rawOut := RunHide(command)
  if (InStr(rawOut, "--gameDir")) {
    strStart := RegExMatch(rawOut, "P)--gameDir (?:""(.+?)""|([^\s]+))", strLen, 1)
    return SubStr(rawOut, strStart+10, strLen-10) . "\"
  } else {
    strStart := RegExMatch(rawOut, "P)(?:-Djava\.library\.path=(.+?) )|(?:\""-Djava\.library.path=(.+?)\"")", strLen, 1)
    if (SubStr(rawOut, strStart+20, 1) == "=") {
      strLen -= 1
      strStart += 1
    }
    return StrReplace(SubStr(rawOut, strStart+20, strLen-28) . ".minecraft\", "/", "\")
  }
}

GetInstanceTotal() {
  idx := 1
  global rawPIDs
  WinGet, all, list
  Loop, %all%
  {
    WinGet, pid, PID, % "ahk_id " all%A_Index%
    WinGetTitle, title, ahk_pid %pid%
    if (InStr(title, "Minecraft")) {
      rawPIDs[idx] := pid
      idx += 1
    }
  }
return rawPIDs.MaxIndex()
}

GetInstanceNumberFromMcDir(mcdir) {
  numFile := mcdir . "instanceNumber.txt"
  num := -1
  if (mcdir == "" || mcdir == ".minecraft" || mcdir == ".minecraft\" || mcdir == ".minecraft/") ; Misread something
    Reload
  if (!FileExist(numFile))
    MsgBox, Missing instanceNumber.txt in %mcdir%
  else
    FileRead, num, %numFile%
return num
}

SetAffinity(pid, mask) {
  hProc := DllCall("OpenProcess", "UInt", 0x0200, "Int", false, "UInt", pid, "Ptr")
  DllCall("SetProcessAffinityMask", "Ptr", hProc, "Ptr", mask)
  DllCall("CloseHandle", "Ptr", hProc)
  Logg("Set affinity with mask " . mask . " for pid " . pid)
}

PixelColorSimple(pc_x, pc_y, pc_wID) {
    if pc_wID
    {
    pc_hDC := DllCall("GetDC", "UInt", pc_wID)
    pc_fmtI := A_FormatInteger
    SetFormat, IntegerFast, Hex
    pc_c := DllCall("GetPixel", "UInt", pc_hDC, "Int", pc_x, "Int", pc_y, "UInt")
    pc_c := pc_c >> 16 & 0xff | pc_c & 0xff00 | (pc_c & 0xff) << 16
    pc_c .= ""
    SetFormat, IntegerFast, %pc_fmtI%
    DllCall("ReleaseDC", "UInt", pc_wID, "UInt", pc_hDC)
    return pc_c
    }
}

getHwndForPid(pid) {
    pidStr := "ahk_pid " . pid
    WinGet, hWnd, ID, %pidStr%
    StringReplace, hWnd, hWnd, ffffffff
    return hWnd
}

SwitchInstance(idx)
{
  Logg("Switching to instance " . idx)
  currInst := idx
  thePID := PIDs[idx]
  if (affinity) {
    Logg("Setting low affinity for all instances except instance " . idx . " since we're switching to that one")
    for i, tmppid in PIDs {
      if (tmppid != thePID){
        Logg("Setting low affinity for instance " . i)
        SetAffinity(tmppid, lowBitMask)
      }
    }
  }
  if (affinity)
  {
    Logg("Setting high affinity for instance " . idx . " since we're switching to it")
    SetAffinity(thePID, highBitMask)
  }
  WinSet, AlwaysOnTop, On, ahk_pid %thePID%
  WinSet, AlwaysOnTop, Off, ahk_pid %thePID%
  if (instances > 1)
  {
    Logg("More than 1 instance so switching OBS scenes")
    ControlSend,, {Numpad%idx%}, ahk_exe obs64.exe
    send {Numpad%idx% down}
    sleep, %obsDelay%
    send {Numpad%idx% up}
  }
  ShowF3()
  if (unpauseOnSwitch)
  {
    ControlSend, ahk_parent, {Esc}, ahk_pid %thePID%
    Send, {LButton} ; Make sure the window is activated
  }
}

ShowF3()
{
   if (f3showDuration < 0)
   {
      return
   }
   Sleep, f3showDelay
   ControlSend, ahk_parent, {Esc}, ahk_exe javaw.exe
   ControlSend, ahk_parent, {F3}, ahk_exe javaw.exe
   Sleep, %f3showDuration%
   ControlSend, ahk_parent, {F3}, ahk_exe javaw.exe
   ControlSend, ahk_parent, {Esc}, ahk_exe javaw.exe
}

GetActiveInstanceNum() {
  WinGet, thePID, PID, A
    for r, temppid in PIDs {
      if (temppid == thePID)
        return r
    }
return -1
}

Reset(state := 0)
{
  idx := GetActiveInstanceNum()
  playerState := state ; needs spawn or keep resetting
  if (resetStates[idx] == 0) ; instance is being played
  {
    resetStates[idx] := 1 ; needs to exit from play
  }
  if (affinity) {
    Logg("Setting high affinity for all instances since all instances are resetting now")
    for i, tmppid in PIDs {
      Logg("Setting high affinity for instance " . i . " since all instances are resetting now")
      SetAffinity(tmppid, highBitMask)
    }
  }
  
}

SetTitles() {
  for g, thePID in PIDs {
    WinSetTitle, ahk_pid %thePID%, , Minecraft* - Instance %g%
  }
}

getMostRecentFile(mcDirectory)
{
  savesDirectory := mcDirectory . "saves"
  ;MsgBox, %savesDirectory%
	counter := 0
	Loop, Files, %savesDirectory%\*.*, D
	{
		counter += 1
		if (counter = 1)
		{
			maxTime := A_LoopFileTimeModified
			mostRecentFile := A_LoopFileLongPath
		}
		if (A_LoopFileTimeModified >= maxTime)
		{
			maxTime := A_LoopFileTimeModified
			mostRecentFile := A_LoopFileLongPath
		}
	}
   recentFile := mostRecentFile
   return (recentFile)
}

GiveAngle(n)
{
   if (giveAngle == True)
   {
      xDiff := xCoords[n] - centerPointX
      currentX := xCoords[n]
      zDiff := centerPointZ - zCoords[n]
      currentZ := zCoords[n]
      angle := ATan(xDiff / zDiff) * 180 / 3.14159265358979
      if (zDiff < 0)
      {
         angle := angle - 180
      }
      if (zDiff = 0)
      {
         if (xDiff < 0)
         {
            angle := -90.0
         }
         else if (xDiff > 0)
         {
            angle := 90.0
         }
      }
      angleList := StrSplit(angle, ".")
      intAngle := angleList[1]
      ComObjCreate("SAPI.SpVoice").Speak(intAngle)
   }
}

readableTime()
{
   theTime := A_Now
   year := theTime // 10000000000
   month := mod(theTime, 10000000000)
   month := month // 100000000
   day := mod(theTime, 100000000)
   day := day // 1000000
   hour := mod(theTime, 1000000)
   hour := hour // 10000
   minute := mod(theTime, 10000)
   minute := minute // 100
   second := mod(theTime, 100)
   if (second < 10)
      second := "0" . second
   if (minute < 10)
      minute := "0" . minute
   if (hour < 10)
      hour := "0" . hour
   if (day < 10)
      day := "0" . day
   if (month < 10)
      month := "0" . month
   timeString := month . "/" . day . "/" . year . " " . hour . ":" . minute . ":" second
   return (timeString)
}

GoodSpawn(n)
{
  timeString := readableTime()
   xCoord := xCoords[n]
   zCoord := zCoords[n]
   writeString := "Instance " . n . ": Spawn: (" . xCoord . ", " . zCoord . "); Distance: "
   xDisplacement := xCoord - centerPointX
   zDisplacement := zCoord - centerPointZ
   distance := Sqrt((xDisplacement * xDisplacement) + (zDisplacement * zDisplacement))
   distances[n] := distance
   writeString := writeString . distance . "; Decision: "
   if (inList(xCoord, zCoord, "whitelist.txt"))
   {
      ;OutputDebug, [macro] in whitelist
      writeString := writeString . "GOOD spawn (in whitelist) `n"
      Logg(writeString)
      return True
   }
   if (inList(xCoord, zCoord, "blacklist.txt"))
   {
      ;OutputDebug, [macro] in blacklist
      writeString := writeString . "BAD spawn (in blacklist) `n"
      Logg(writeString)
      return False
   }
   if (distance <= radius)
  {
    writeString := writeString . "GOOD spawn (distance less than radius) `n"
      Logg(writeString)
      return True
    }
   else
  {
    writeString := writeString . "BAD spawn (distance more than radius) `n"
      Logg(writeString)
      return False
    }
}

Logg(inString)
{
  if (logging)
  {
    theTime := readableTime()
    writeString := "[macro] " . theTime . ": " . inString
    OutputDebug, %writeString%
    writeString := theTime . ": " . inString . "`n"
    FileAppend, %writeString%, macro_logs.txt
  }
}

inList(xCoord, zCoord, fileName)
{
   if (FileExist(fileName))
   {
      Loop, read, %fileName%
      {
         arr0 := StrSplit(A_LoopReadLine, ";")
         corner1 := arr0[1]
         corner2 := arr0[2]
         arr1 := StrSplit(corner1, ",")
         arr2 := StrSplit(corner2, ",")
         X1 := arr1[1]
         Z1 := arr1[2]
         X2 := arr2[1]
         Z2 := arr2[2]
         if ((((xCoord <= X1) && (xCoord >= X2)) or ((xCoord >= X1) && (xCoord <= X2))) and (((zCoord <= Z1) && (zCoord >= Z2)) or ((zCoord >= Z1) && (zCoord <= Z2))))
            return True
      }
   }
   return False
}

GetSpawn(i)
{
  logFile := McDirectories[i] . "logs\latest.log"
  Loop, Read, %logFile%
  {
    if (InStr(A_LoopReadLine, "logged in with entity id"))
    {
      spawnLine := A_LoopReadLine
    }
  }
  array1 := StrSplit(spawnLine, " at (")
  xyz := array1[2]
  array2 := StrSplit(xyz, ", ")
  xCoord := array2[1]
  zCooord := array2[3]
  array3 := StrSplit(zCooord, ")")
  zCoord := array3[1]
  xCoords[i] := xCoord
  zCoords[i] := zCoord
}

AlertUser(n)
{
   thePID := PIDs[n]
	if (playSound)
	{
		if (FileExist("spawnready.mp3"))
			SoundPlay, spawnready.mp3
		else
			SoundPlay *16
	}
    GiveAngle(n)
}

AddToBlacklist()
{
	t := GetActiveInstanceNum()
   xCoord := xCoords[t]
   zCoord := zCoords[t]
   OutputDebug, [macro] blacklisting %xCoord%, %zCoord%
   theString := xCoord . "," . zCoord . ";" . xCoord . "," . zCoord
   if (!FileExist("blacklist.txt"))
      FileAppend, %theString%, blacklist.txt
   else
      FileAppend, `n%theString%, blacklist.txt
}

#IfWinActive, Minecraft
{
    U:: ; Reset and give spawn
      Reset(0)
    return
   
   ^B:: ; Add a spawn to the blacklisted spawns.
		AddToBlacklist()
	return
}
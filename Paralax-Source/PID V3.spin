''=============================================================================
'' Qic PID Object nov 2010 HJK
'' V1 is more generic. The PID controller only does configurable number of PID-loops.
'' V2 implements separate position and velocity feedback
'' A second Cog is needed in the calling program to copy inputs and outputs from the PID
'' into the real world.
''
'' Controls X number of motors in velocity mode or position mode via its own serial spin
'' object to 2x 2S 12V10
'' 
'' Performance in Spin: Velocity control in 4 fold PID loop at 2400 us
'' Tested with 8 PID loops at 50 Hz
''
'' Febr 2011: Following error check and setpoint min max settings added and axis shut down on FE
'' Mar 2011: In position window added
'' May 2011: Open loop mode added, Scale factors for pos vel and output added
''=============================================================================

CON


  PIDLed = 27         'PID test led

  PIDCnt = 8          'Max PID loop count

  _1ms  = 1_000_000 / 1_000          'Divisor for 1 ms

  cIlimit = 30000         'I- action limiter
  Outlimit = 127        'Output limiter
  
OBJ
  t             : "Timing"

Var Long PotmValue0
    long s, ms, us
    Long MPosAddr, MVelAddr, MSetpAddr, MOutput
    Long lActPos[PIDCnt], MVel[PIDCnt]   'Actual position and velocity
    Long PosScale[PIDCnt], VelScale[PIDCnt], OutputScale[PIDCnt]
    Long PIDMode[PIDCnt]                 'PID loop mode: 0= open 1 = Vel loop 2 = Pos loop
    Long MSetVel[PIDCnt], preMSetVel[PIDCnt]

   'PID parameters
    Long PIDMax, K[PIDCnt], KI[PIDCnt], Kp[PIDCnt], Acc[PIDCnt], MaxVel[PIDCnt], F
    Long ILimit[PIDCnt], lI[PIDCnt], OpenLoopCmd[PIDCnt]
    Long PrevMPos[PIDCnt], DVT[PIDCnt], DPT[PIDCnt]
    Long PIDStack[400]
    Long PIDTime, lPeriod
    Byte PIDCog, PIDStatus, PIDBusy, PIDCyclesPerSec
    Word PIDCntr

    'Limits
    Long SetpMaxPlus[PIDCnt], SetpMaxMin[PIDCnt], FE[PIDCnt], FEMax[PIDCnt], FETrip[PIDCnt], FEAny
    Long InPosWindow[PIDCnt], InPos[PIDCnt]

    Byte MAEState
    
' ----------------  Stop PID loop -----
PUB PIDStop
  CogStop(PIDCog)

' ----------------  Start PID loop -----
PUB PIDStart
  PIDCog:=CogNew(PID(lPeriod), @PIDStack)
Return PIDCog

'--------------------------- Start QiC PID --------------------------------
'With Period in ms 
PUB Start(Period, aMPos, aMVel, aSetp, aOutput, lPIDCnt)

  PIDMax := lPIDCnt-1    'Calculate loop max PID

  lPeriod:=Period                  'Save PID cycle time

  MPosAddr  := aMPos                  'Save PID input and output addresses
  MVelAddr  := aMVel
  MSetpAddr := aSetp
  MOutput   := aOutPut
  
  PIDCog:=CogNew(PID(lPeriod), @PIDStack)       'Start PID loop at 20 ms rate
  PIDMode:=1
  PIDCyclesPerSec:=1000/Period

  
Return PIDCog
  

' ----------------  PID loop ---------------------------------------
PRI PID(Period) | i, T1, T2, ClkCycles, LSetPos, ActRVel ' Cycle runs every Period ms

    dira[PIDLed]~~                 'Set I/O pin for LED to output…
    Period:= 1 #> Period <# 1000   'Limit PID period
    PIDStatus:=1
    ClkCycles := ((clkfreq / _1ms * Period) - 4296) #> 381   'Calculate 1 ms time unit
    Repeat i from 0 to PIDMax                 'Init temp vars
      PrevMPos[i]:=Long[MPosAddr][i]
      K[i]:= 1000                        'Loop gain Prop velocity 
      KI[i]:=50                          'Loop gain I- action velocity loop
      Kp[i]:=1000                        'Loop gain Position loop
      PosScale[i]:=1                     'Pos scale factor. Divides pos encoder input
      VelScale[i]:=1                     'Vel scale factor. Divides vel encoder input
      OutputScale[i]:=1                  'Vel scale factor. Divides vel encoder input
      Acc[i]:=3                          'Default acc value
      MaxVel[i]:=200                     'Default Max vel
      ILimit[i]:=cIlimit                 'I action limit
      FEMax[i]:=1100                     'Following error limit
      InPosWindow[i]:=100                'In position window               
      
    PIDStatus:=2                         'PID Init done
    F:=1000  
    T1:=Cnt
    !outa[PIDLed]                        'Toggle I/O Pin for debug
                                         
    PIDStatus:=3                         'PID running 

    Repeat                               'Main loop     Volgfout!!
      Repeat i from 0 to PIDMax          'Cycle through the loops

        MVel[i]:=(Long[MVelAddr][i]/VelScale[i] - PrevMPos[i])*F 'Calculate velocities M0 - M3 from delta position
        PrevMPos[i]:=Long[MVelAddr][i]/VelScale[i]

        Case PIDMode[i]                        'Process various PID modes
          -2: Long[MOutput][i]:=OpenLoopCmd[i] 'Open loop output command
           
          -1,0: Long[MOutput][i]:=0            'Open loop and in brake mode
             MSetVel[i]:=0
             lI[i]:=0
             FE[i]:=0
             InPos[i]:=false

          3: lSetPos:= Long[MSetpAddr][i]       'current set position for limiter calculation
             FE[i]:= Long[MSetpAddr][i] - Long[MPosAddr][i]/PosScale[i]
             FETrip[i]:= FETrip[i] or (||FE[i] > FEMax[i])     'Keep FE trip even if error disappears
             FEAny:=FEAny OR FETrip[i]
             InPos[i]:=(||FE[i] < InPosWindow[i])              'Check in position of axis
             MSetVel[i]:= -MaxVel[i] #> ( FE[i] * Kp[i]/1000) <# MaxVel[i]
             DVT[i]:= (MSetVel[i]*100-Mvel[i]) / F                              'Delta Velocity

          2: FE[i]:= Long[MSetpAddr][i] - Long[MPosAddr][i]/PosScale[i]
             FETrip[i]:= FETrip[i] or (||FE[i] > FEMax[i])     'Keep FE trip even if error disappears
             FEAny:=FEAny OR FETrip[i]
             InPos[i]:=(||FE[i] < InPosWindow[i])              'Check in position of axis
             MSetVel[i]:= FE[i]  * Kp[i]/1000   'Position mode
             DVT[i]:= (MSetVel[i]*100-Mvel[i]) / F                            'Delta Velocity

          1: MSetVel[i]:= Long[MSetpAddr][i]                                  'Velocity mode
             DVT[i]:= (MSetVel[i]*F-Mvel[i]) / F                              'Delta Velocity
             FE[i]:=0

        if PIDMode[i]>0                  'The actual control loop
          lI[i]:= -Ilimit[i] #> (lI[i]+DVT[i]) <# Ilimit[i]   'Limit I-action
          PIDBusy:=1

           if FETrip[i]
             PIDMode[i]:=0  'Set loop open on FE

          Long[MOutput][i]:=-Outlimit #> (DVT[i]*K[i] + lI[i]*KI[i]) / (F*OutputScale[i]) <# Outlimit 'Calculate limited PID Out
          PIDBusy:=0

      PIDTime:=Cnt-T1                    'Measure actual loop time in clock cycles
      waitcnt(ClkCycles + T1)            'Wait for designated time
      PIDCntr++                          'Update PIDCounter               
      if (PIDCntr//4)==0
        !outa[PIDLed]                      'Toggle I/O Pin for debug
      T1:=Cnt
      
' ----------------------- Public functions -----------------------
' ---------------------  Set In pos Window -----------------------------
PUB SetInPosWindow(i,lInPosWindow)
  i:= 0 #> i <# PIDMax
  InPosWindow[i]:=lInPosWindow

' ---------------------  Get In pos Window ---------------------------
PUB GetInPosWindow(i)
  i:= 0 #> i <# PIDMax
Return InPosWindow[i]

' ---------------------  Get In pos ------- ---------------------------
PUB GetInPos(i)
  i:= 0 #> i <# PIDMax
Return InPos[i]

' ---------------------  Set Setpoint Max Min -----------------------------
PUB SetSetpMaxMin(i,lSetpMaxMin)
  i:= 0 #> i <# PIDMax
  SetpMaxMin[i]:=lSetpMaxMin
  
' ---------------------  Get Setpoint Max Min ---------------------------
PUB GetSetpMaxMin(i)
  i:= 0 #> i <# PIDMax
Return SetpMaxMin[i]
' ---------------------  Set Setpoint Max Plus -----------------------------
PUB SetSetpMaxPlus(i,lSetpMaxPlus)
  i:= 0 #> i <# PIDMax
  SetpMaxPlus[i]:=lSetpMaxPlus
  
' ---------------------  Get Setpoint Max Plus---------------------------
PUB GetSetpMaxPlus(i)
  i:= 0 #> i <# PIDMax
Return SetpMaxPlus[i]

' --------------------- Reset FolErr Trip -----------------------------
PUB ResetFETrip(i)
  i:= 0 #> i <# PIDMax
  FETrip[i]:=0
  
' --------------------- Reset All FolErr Trip -----------------------------
PUB ResetAllFETrip | i
  repeat i from 0 to PIDMax
    FETrip[i]:=false
  FeAny:=false  

' --------------------- Set Max FolErr -----------------------------
PUB SetFEMax(i,lFEMax)
  i:= 0 #> i <# PIDMax
  FEMax[i]:=lFEMax
  
' ---------------------   Get MaxFollErr -----------------------------
PUB GetFEMax(i)
  i:= 0 #> i <# PIDMax
Return FEMax[i]

' ---------------------   Get Actual FollErr -----------------------------
PUB GetFE(i)
  i:= 0 #> i <# PIDMax
Return FE[i]
' ---------------------   Get Foll Err trip -----------------------------
PUB GetFETrip(i)
  i:= 0 #> i <# PIDMax
Return FETrip[i]

PUB GetFEAnyTrip          'Any FE trip
Return FEAny

' ---------------------   Set Ki  -----------------------------
PUB SetKI(i,lKi)
  i:= 0 #> i <# PIDMax
  KI[i]:=lKi
  
' ---------------------   Get Ki  -----------------------------
PUB GetKI(i)
  i:= 0 #> i <# PIDMax
Return KI[i]

' ---------------------   Set Kp  -----------------------------
PUB SetKp(i,lK)
  i:= 0 #> i <# PIDMax
  Kp[i]:=lK
  
' ---------------------   Get Kp  -----------------------------
PUB GetKp(i)
  i:= 0 #> i <# PIDMax
Return Kp[i]

' ---------------------   Set K   -----------------------------
PUB SetK(i,lK)
  i:= 0 #> i <# PIDMax
  K[i]:=lK
  
' ---------------------   Get K   -----------------------------
PUB GetK(i)
  i:= 0 #> i <# PIDMax
Return K[i]

' ---------------------   Set Acc   -----------------------------
PUB SetAcc(i,lAcc)
  i:= 0 #> i <# PIDMax
  Acc[i]:=lAcc
  
' ---------------------   Get Acc   -----------------------------
PUB GetAcc(i)
  i:= 0 #> i <# PIDMax
Return Acc[i]

' ---------------------   Set max Vel   -----------------------------
PUB SetMaxVel(i,lVel)
  i:= 0 #> i <# PIDMax
  MaxVel[i]:=lVel
  
' ---------------------   Get max Vel   -----------------------------
PUB GetMaxVel(i)
  i:= 0 #> i <# PIDMax
Return MaxVel[i]


' ---------------------   Set Position Scale factor  -----------------------------
PUB SetPosScale(i,lS)
  i:= 0 #> i <# PIDMax
  PosScale[i]:=lS
  
' ---------------------   Get PosScale -----------------------------
PUB GetPosScale(i)
  i:= 0 #> i <# PIDMax
Return PosScale[i]


' ---------------------   Set Velocity Scale factor  -----------------------------
PUB SetVelScale(i,lS)
  i:= 0 #> i <# PIDMax
  VelScale[i]:=lS
  
' ---------------------   Get  Velocity Scale factor -----------------------------
PUB GetVelScale(i)
  i:= 0 #> i <# PIDMax
Return VelScale[i]


' ---------------------   Set Output Scale factor    -----------------------------
PUB SetOutputScale(i,lS)
  i:= 0 #> i <# PIDMax
  OutputScale[i]:=lS
  
' ---------------------   Get Output Scale factor -----------------------------
PUB GetOutputScale(i)
  i:= 0 #> i <# PIDMax
Return OutputScale[i]

' ---------------------   Set Integral limiter  -----------------------------
PUB SetIlimit(i,lS)
  i:= 0 #> i <# PIDMax
  Ilimit[i]:=lS
  
' ---------------------   Get Integral limiter -----------------------------
PUB GetIlimit(i)
  i:= 0 #> i <# PIDMax
Return Ilimit[i]

' ---------------------   Return Actual Velocity Cnts/sec -----------------------------
PUB GetActVel(i)
  i:= 0 #> i <# PIDMax
Return MVel[i]/F ' * PIDCyclesPerSec  

' ---------------------   Return Set Velocity Cnts/sec -----------------------------
PUB GetSetVel(i)
  i:= 0 #> i <# PIDMax
Return MSetVel[i] ' * PIDCyclesPerSec  

' ---------------------  Return Position in cnts -----------------------------
PUB GetActPos(i)
  i:= 0 #> i <# PIDMax
Return Long[MPosAddr][i]

' ---------------------  Return Ibuf -----------------------------
PUB GetIBuf(i)
  i:= 0 #> i <# PIDMax
Return lI[i]

' ---------------------  Return Delta vel -----------------------------
PUB GetDeltaVel(i)
  i:= 0 #> i <# PIDMax
Return DVT[i]

' ---------------------   Set PID mode     -----------------------------
PUB SetPIDMode(i,lMode)             '0= open loop, 1=Velocity control, 2= position control 3= Pos cntrl Vel limit
  i:= 0 #> i <# PIDMax
'  if (PIDMode[i]==0 and lMode<>0)   'Do something before closing loop to avoid sudden jumps
  PIDMode[i] := lMode

' ---------------------   Set command output in open loop mode  ------------------------
PUB SetOpenLoop(i,lOpenloopCmd)            
  i:= 0 #> i <# PIDMax
  OpenloopCmd[i] := lOpenloopCmd

' ---------------------   Kill all motors (open loop) -------------------
PUB KillAll  | i
  repeat i from 0 to PIDMax
    PIDMode[i]:=0
    
' ---------------------   Set all motors in the same PID state  -------------------
PUB SetAllPIDMode(m)  | i
  repeat i from 0 to PIDMax
    PIDMode[i]:=m

' ---------------------  Return PID Mode -----------------------------
PUB GetPIDMode(i)
  i:= 0 #> i <# PIDMax
Return PIDMode[i]

' --------------------- Return PID Time in us -----------------------------
PUB GetPIDTime
Return PIDTime/80

' ---------------------  Return PID Status -----------------------------
PUB GetPIDStatus 
Return  PIDStatus

' ---------------------  Return PIDOut -----------------------------
PUB GetPIDOut(i) 
  i:= 0 #> i <# PIDMax
Return Long[MOutput][i]

' ---------------------  Return Get QiK Parameter -----------------------------
PUB GetParameter(Address, Parameter)
Return GetParameter(Address, Parameter)

' ---------------------  Return Return string -----------------------------
PUB Par2Str(ParNr)
Return Par2Str(ParNr)

' ---------------------   Get PID Counter  -----------------------------
PUB GetCntr
Return PIDCntr


{{

┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}
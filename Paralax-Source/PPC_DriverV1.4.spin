'' Paralax_Position_Controller_Driver
'' PPC_DriverV1.3
''******************************************************************************* 
''*****  Hj Kiela Opteq June 2011                                           *****   
''*****  Derived from Michael Boswell's version                             ***** 
''*****                                                                     ***** 
''*****  See end of file for terms of use.                                  ***** 
''*****                                                                     *****  
''***** v1.1 first public release                                           *****
''***** v1.2 embeded PauseMsec and PauseSec as PRI                          *****
''***** v1.3 HJK Replaced original clock work with smooth control           *****
''*****      and position readout for Odometry with ROS                     *****    
''******************************************************************************* 

OBJ

  DrvMtr : "Simple_Serial"  'Communication 19200 baud. Saves a cog
                    
  
CON
  WMin  = 381   ''
  QPOS  = $08   'Query position, returns current position as 16bit value (ile przejechal, nie rotacje)'
  QSPD  = $10   'Query speed, returns current speed in position/0.5s, update every 20ms'
  CHFA  = $18   'Check for arrival'
  TRVL  = $20   'number of positions to travel, move the wheel a user-set distancem, zaczyna jechac o ten dystan z przyspieszeniem SSRR do predkosci SMAX'
  CLRP  = $28   'Clear position'
  SREV  = $30   'Set orientation as reversed'
  STXD  = $38   'Set Tx delay'
  SMAX  = $40   'set  speed maximum'
  SSRR  = $48   'set speed ramp rate, smooth user-set acceleration and '
  AllWheels     = 0   'ID's of wheels (for commands) 0,1,2'
  RightWheel    = 2
  LeftWheel     = 1
  MaxWheel = 2              'This unit is tested with two HB25 drives. Should work with up to four
  MaxIndex = MaxWheel-1    'Change MaxWheel accordinglee
  MaxSp = 128              'Max setpoint for Speed and dir
  Divdr = 12               'Divider to make pos from speed and dir
  
VAR
  Long MtrCogNum
  Long MtrCogRunning
  Long MtrCogStack[200]  ' no attempt has been made to optimize the stack size. I expect that 100 is WAY to large. And now its 200..
  Long Cur_Spd           ' Holds the last selected speed
  Long Req_Spd           ' Holds the currently selected speed value
  Long Req_Turn          ' Holds the currently selected turn value
  Word ActSpeed[2], ActPos[2]       'Actual speed and position
  Long SetPosition[2], SetSpeed[2]  'Set values
  Long State, Cntr, Enabled,MoveMode'State engine, life counter, Loop Enabled, Move mode 0= speed and dir 1= wheel speeds

PUB start(MtrDrvPin)

'' Start MtrLoop - starts a cog
'' returns false if no cog available
''
  MoveMode:=0 
  MtrCogRunning := (MtrCogNum := cognew(MtrDrvLoop(MtrDrvPin),@MtrCogStack)) > 0
Return MtrCogNum

PUB stop

''  Stop MtrDrv - frees a cog

  if MtrCogRunning~
    cogstop(MtrCogNum)

''******************************************************************************* 
''*****  Thes zre the objects to call to set the speed and turn amount        *****
''*****  After initialization, this and Emergency Stop are the only two     ***** 
''*****  objects that need to be called to use the driver.                  *****
''******************************************************************************* 

'------------------------ Move 2 motor platform with speed and direction ---------
PUB MtrMove(Spd,Turn)                     ' input a speed and amount of turn, translate this into Position Controller commnands

        Req_Spd := -MaxSp #> Spd <# MaxSp                  ' Scale is -128 to +128 for full reverse to full forward
        Req_Turn := -MaxSp #> Turn <# MaxSp                  ' Scale is -128 to +128 for full left to full right turn
        
'------------------------ Stop all motion. Loop remains closed -------------------
PUB EmergencyStop                          ' Stop things imediatly

        Req_Spd := 0
        Req_Turn := 0
        ClearPosition(allWheels)

'---------------------- Enable loop effectively stops sending new values ----------
PUB Enable
  Enabled:=true
'  Req_Spd:=0
'  Req_Turn:=0

'---------------------- Disable loop ----------------------------------------------
PUB Disable
  Enabled:=false
  Req_Spd:=0
  Req_Turn:=0
'********************** Objects to call for querying info **************************
'------------------------ Get actual position of wheel [0..1] ---------------------------
PUB Position(lWheel)
  lWheel:= 0 #> lWheel <# MaxIndex
  case lWheel
     1:  Return $FFFF - ActPos[lWheel]     'reverse direction of encoder 1 
Return ActPos[lWheel] 

{'------------------------ Get actual speed of wheel  [0..1]------------------------------
PUB Speed(lWheel)
  lWheel:= 0 #> lWheel <# MaxIndex
Return ActSpeed[lWheel]
}
'------------------------ Get set speed of wheel  [0..1]---------------------------------
PUB GetSetSpeed(lWheel)
  lWheel:= 0 #> lWheel <# MaxIndex
Return SetSpeed[lWheel]

'------------------------ Get set wheel position  [0..1]---------------------------------
PUB GetSetPosition(lWheel)
  lWheel:= 0 #> lWheel <# MaxIndex
Return SetPosition[lWheel]

'------------------------ Get Driver status for debugging ------------------------
PUB GetState
Return State

'------------------------ Get Cog counter to check life --------------------------
PUB GetCntr
Return Cntr

'------------------------ Get loop enabled --------------------------
PUB GetEnabled
Return Enabled

'************************ Private  ***********************************************
PRI MtrDrvLoop  (MtrPin) | NxtSpd , Dir, NxtTurn, LorR, tSpeedL, tSpeedH

''******************************************************************************* 
''*****  This is the main loop for controlling the PPC. First it            *****
''*****  initializes the PPC and loop variables and then begins             ***** 
''*****  positive control                                                   ***** 
''*****                                                                     ***** 
''******************************************************************************* 

case MoveMode
 0: 
   PauseSec(1)                                   ' Pause to ensure PPC's have time to power up (likely could be reduced)
   
  ' DrvMtr.start(MtrPin,MtrPin,0,19200)            ' Establish comunications to PPC
   DrvMtr.start (MtrPin,MtrPin,19200)            ' Establish comunications to PPC
   PauseMSec(100)                                ' Short delay prior to sending first commands

 
   ClearPosition(AllWheels)                      ' This is incase the prop is reset and the PPC is still executing commands prior to reset
   PauseMsec(100)                                ' Quiet period after a ClearPosition command
'  SetAsReversed(LeftWheel)                      ' This might need to be changed depending upon what direction is "Forward"
   SetSpeedRamp(AllWheels,85)                    ' This is set to meet my needs and can be changed as needed. The PPC default would be 15
   SetTXDelay (AllWheels,5)                      ' Set Tx delay ~60 us
   Cur_Spd := 0                                  ' Initialize variables
   Req_Turn := 0
   Req_Spd := 0


  Repeat                                          ' Begin the control loop
     NxtSpd:= Req_Spd / 1
     NxtTurn:= Req_Turn / 3
       
     State:=6
     if Enabled
       State:=5        
       tSpeedH:= || (NxtSpd + NxtTurn)
'       if tSpeed <> SetSpeed[1]
          
       tSpeedL:= || (NxtSpd - NxtTurn)
'       if tSpeed <> SetSpeed[0]  

       if NxtSpd => 0 and NxtTurn => 0
         SetPosition[0]:=(NxtSpd - NxtTurn)/12   
         SetPosition[1]:=(NxtSpd + NxtTurn)/12
         SetSpeed[0]:= tSpeedL
         SetSpeed[1]:= tSpeedH
         State:=1        

       if NxtSpd < 0 and NxtTurn => 0
         SetPosition[0]:=(NxtSpd + NxtTurn)/12          'Change sign of direction when moving backward   
         SetPosition[1]:=(NxtSpd - NxtTurn)/12
         SetSpeed[0]:= tSpeedH
         SetSpeed[1]:= tSpeedL
         State:=2        
         
       if NxtSpd => 0 and NxtTurn < 0
         SetPosition[0]:=(NxtSpd - NxtTurn)/12   
         SetPosition[1]:=(NxtSpd + NxtTurn)/12
         SetSpeed[0]:= tSpeedL
         SetSpeed[1]:= tSpeedH
         State:=3        

       if NxtSpd < 0 and NxtTurn < 0
         SetPosition[0]:=(NxtSpd + NxtTurn)/12          'Change sign of direction when moving backward   
         SetPosition[1]:=(NxtSpd - NxtTurn)/12
         SetSpeed[0]:= tSpeedH
         SetSpeed[1]:= tSpeedL
         State:=4        

       SetMaxSpeed(RightWheel,SetSpeed[0])   
       SetMaxSpeed(LeftWheel,SetSpeed[1])   
       GoForward(RightWheel,-SetPosition[0])            ' The *10 is the distance to travel estimate to keep it going until next loop
       GoForward(LeftWheel,SetPosition[1])            ' set a distance to travel that is positive or negative based or Left or Right (LorR) variable set above

'    ActSpeed[0]:=GetSpeed(1)                          'Optional 
'    ActSpeed[1]:=GetSpeed(2)
    ActPos[0]:=GetPosition(1)
    ActPos[1]:=GetPosition(2)  

    Cntr++
    PauseMSec(50)                                      '50 ms seems to be the right balance between new position targets and speed

'------------------------ Timing routines------ ----------------------------------
PRI PauseMSec(Duration)
{{Pause execution in milliseconds.
  PARAMETERS: Duration = number of milliseconds to delay.
}}
  waitcnt(((clkfreq / 1_000 * Duration - 3932) #> WMin) + cnt)                                     
  

PRI PauseSec(Duration)
{{Pause execution in seconds.
  PARAMETERS: Duration = number of seconds to delay.
}}
  waitcnt(((clkfreq * Duration - 3016) #> WMin) + cnt) 
      
'------------------------ Query speed of wheel ----------------------------------
PRI GetSpeed (Wheel)   | SPD
   SPD := 0
   DrvMtr.TX(QSPD + Wheel) 'we are sending command + ID'
'   PauseMSec(3)
   SPD.BYTE[1] := DrvMtr.RX
   SPD.BYTE[0] := DrvMtr.RX
Return SPD

'------------------------ Query position of wheel --------------------------------
PRI GetPosition (Wheel)   | POS
   POS := 0
   DrvMtr.TX(QPOS + Wheel)
   POS.BYTE[1] := DrvMtr.RX
   POS.BYTE[0] := DrvMtr.RX
Return POS

'------------------------ Check is wheel has arrived in pos window ---------------
PRI ChkForArrival (Wheel, Tollerance) | Arvd
  DrvMtr.TX(CHFA + Wheel)
  DrvMtr.TX(Tollerance.BYTE[0])
  Arvd.BYTE[0] := DrvMtr.RX
Return Arvd     

'------------------------ TSet delay for sending after receive--------------------
PRI SetTXDelay (Wheel,Delay)                                                               
  DrvMtr.TX(STXD + Wheel)
  DrvMtr.TX(Delay.BYTE[0])  

'------------------------ Clears position to zero and resets controller ----------
PRI ClearPosition(Wheel)
   DrvMtr.TX(CLRP+Wheel)

'------------------------ Travel number of positions -----------------------------
PRI GoForward (Wheel, Dist)
   DrvMtr.TX(TRVL + Wheel)
   DrvMtr.TX(Dist.BYTE[1])
   DrvMtr.TX(Dist.BYTE[0])
   
'------------------------ Set max speed for wheel --------------------------------
PRI SetMaxSpeed (Wheel, MaxSpeed) 
   DrvMtr.TX(SMAX + Wheel)
   DrvMtr.TX(MaxSpeed.BYTE[1])
   DrvMtr.TX(MaxSpeed.BYTE[0])

'------------------------ Set speed ramp for wheel -------------------------------
PRI SetSpeedRamp (Wheel,Rate) 
  DrvMtr.TX(SSRR + Wheel)
  DRVMTR.TX(Rate.BYTE[0])

'------------------------ Set wheel set point as reversed ------------------------
PRI SetAsReversed (Wheel) 
  DrvMtr.TX(SREV + Wheel)
  
DAT                             
'***************************************
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
   
      
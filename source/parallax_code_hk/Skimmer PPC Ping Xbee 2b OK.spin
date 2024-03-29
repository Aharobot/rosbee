{
 ************************************************************************************************************
 *                                                                                                          *
 *  AUTO-RECOVER NOTICE: This file was automatically recovered from an earlier Propeller Tool session.      *
 *                                                                                                          *
 *  ORIGINAL FOLDER:     D:\RobotBaseKit\RobotBaseKit\                                                      *
 *  TIME AUTO-SAVED:     over 10 days ago (7/7/2011 11:16:52 AM)                                            *
 *                                                                                                          *
 *  OPTIONS:             1)  RESTORE THIS FILE by deleting these comments and selecting File -> Save.       *
 *                           The existing file in the original folder will be replaced by this one.         *
 *                                                                                                          *
 *                           -- OR --                                                                       *
 *                                                                                                          *
 *                       2)  IGNORE THIS FILE by closing it without saving.                                 *
 *                           This file will be discarded and the original will be left intact.              *
 *                                                                                                          *
 ************************************************************************************************************
.}
'' ***************************************
'' * Skimmercontrol w HB25           
'' * #27906 driver                       
'' * Author: Henk Kiela Opteq           
'' * Copyright (c) 2011 Parallax, Inc.  
'' * See end of file for terms of use.     
'' ***************************************

{{

Code Description : Implements command set for HB25 drives of Parallax .
Can be used for Parallax Robot Base Kit

Xbee remote control:
Uses string handling for xbee command line handling

   XB$500,33251,-369,-88,0,0,0,0,#<cr>   Id ($500),Cntr,JoyX,JoyY,Btn1,btn2,btn3,btn4

Implements PC Interface:
  Move command     :  $900,cntr,speed,dir,<cr>  : where speed and dir = [-128..128]
  Enable motion    :  $901,Enable,<cr>   Enable : 0=no motion 1= motion allowed
  Enable PC control:  $902,PcEnable,<cr> PcEnable=0 or 1
   
  Enable/DisablePf US sensors : $909,Enable  Where Enable  = [0,1] When DisablePfd, no distance check active!
  Clear Errors     :  $908,  (No parameters)
   
  Query wheel pos  :  $911,  Returns 2 wheel positions as word
  Query US sensors :  $912,  Return 10 US sensor readings in mm. Sensor 0 is right front, counting ccw
  Query Status     :  $913,  Query status of various par's, like errors, platform status, life counters Xbee comm time
    
Implements safety Cog
  Check US minimum distance and shut down platform when object < PingAlarmDist   To be finished

Direct connetion laptop Debug via Xbee  
}}

CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

'' Firmware version
   Version = 13            '2 July 2011 HJK

'' Serial Debug port
'   TXD = 30
'   RXD = 31
   TXD = 15
   RXD = 14
   Baud = 115200

'' Control chars.
   CR = 13
   LF = 10
   CS = 16
   CE = 11                 'CE: Clear to End of line
   EOT = 4                 'End of trainsmission

'' Debug Led
   LED1          = 23       ' I/O PIN for LED 1
   Sel0 = 22      

'' HB25 pins
   MotorData = 16          ' Left Motor serial data 


'Command interface and control 
   LineLen = 100          ' Buffer size for incoming line
   SenderLen= 10
   ButtonCnt = 4
   JoyXHyst = 250           'Joystick hysteresis
   JoyYHyst = 150           
   AliveTime = 100         ' Time in ms before shutdown

'Xbee
'   xTXD = 15
'   xRXD = 14
   xTXD = 30
   xRXD = 31
   xBaud = 115200 '38400  '115200 '57600
   XBID  = 400            '' Xbee Id of this Robot platform
   Cmdlen = 10

'String buffer
   MaxStr = 257        'Stringlength is 256 + 1 for 0 termination
   
'Ping
   PING_Pin      = 0              ' I/O Pin For PING)))
   PingCnt       = 10             '10 sensors mounted
   PingAlarmDist = 15             'Shut down distance to unexpected objects for platform
   PingSpeedDiv  = 10             'Distance multiplier = || Speed/PingSpeedDiv  

'Platform status bits
   Serialbit     = 0              '0= Serial Debug of 1= Serial pdebug port on
   USAlarm       = 1              'US alarm bit: 1= object detected in range
   PingBit       = 2              '0= Ping off 1= Ping on
   EnableBit     = 3              '0= Motion DisablePfd 1= Motion enabled
   PCEnableBit   = 4              'PC Enable -> Pf Enable
   PCControlBit  = 5              'PC In control
   CommCntrBit   = 6              'Xbee Timout error
   MotionBit     = 7              'Platform moving
   NoAlarmBit    = 8              'No alarm present 
   
VAR
    'Speed control vars
    Long A
    Long HB25cog, Speed, Dir
    
    'Xbee and joystick input
    Long JoyCntr, JoyX, JoyY, Button[ButtonCnt], oButton[ButtonCnt]  
    Long Sender, CMDi, myID, Debug, XbeeTime, Enabled, XbeeStat, Lp, XbeeCog
    Byte Cmd[LineLen], LastPar1[CmdLen]
    Byte XbeeCmdCog
    Long PCSpeed, PCEnable, oPCEnable, PCDirection, PCCntr, PcMoveMode, PcControl, oPcControl, USBTime
    Long PcCState, lPcCntr

    'Input string handling
    Byte StrBuf[MaxStr], cStrBuf[MaxStr]      'String buffer for receiving chars from serial port
    Long StrSP, StrCnt, StrP, StrLen, XStat   'Instring semaphore, counter, Stringpointer
    Long pcButton[ButtonCnt], SerCog, SerEnabled, oSel0, CmdDone
    Long JoyComActive, PcComActive            'State var for comm monotoring  

    'Platform vars
    Long MoveSpeed, MoveDir, lMoveSpeed, lMoveDir, MoveMode
    Long JogCntr, JogSpeed , LastAlarm, PfStatus
    Word MainCntr
    Long B

    'Safety
    Long SafetyCog, SafetyStack[50], SafetyCntr, NoAlarm

    'Ping
    Long Range[PingCnt], oRange[PingCnt], lRangeAl[PingCnt], RangeAl[PingCnt]  'Array with measured data and alarm
    Long PingCog, PingStack[100], PingCntr, PingAlarm, PingMode, PingState, ActAlRange, PingDistMul
    Long PingEnable

    'Various stacks
    Long JogStack[50], XBeeCMDStack[100], teststack[10]


OBJ

  ppc    : "PPC_DriverV1.3"             'Driver for position controller
'  ser    : "Parallax Serial Terminal"   'Debug cog      
  ser    : "FullDuplexSerial_rr006"   'Debug cog      
  t      : "Timing.spin"
  DrvMtr : "Simple_Serial"
  xBee   : "FullDuplexSerial_rr006" ' "FullDuplexSerialPlus"       ' Xbee serial
  ping   : "ping"
      
'==================================== Main ===============================
PUB Main    'Main 
'  vp.config(string("start:terminal::terminal:1")) 
'  vp.share(@a,@b)
  
  dira[LED1] ~~
  Init
'      EnableSerial
  DisablePfUSsensors
  repeat

    If oSel0 == 0 and Ina[Sel0] == 1
      EnablePfSerial
 
    If oSel0 == 1 and Ina[Sel0] == 0
      DisablePfSerial

    oSel0 := Ina[Sel0]       

    If SerEnabled
      ShowDebug
    else  
      t.Pause1ms(100)          'Compensate loop time if no debug output

    MainCntr++                 'Blink LED 50% DC during enable
    if Enabled
      !outa[LED1]
    else                       'Blink short during DisablePf
      if (MainCntr // 5) == 0
        !outa[LED1]
                
 '   t.Pause1ms(10)

'==================================== EnableSerial ==========================
PRI EnablePfSerial       'Enable serial port
  SerCog:=ser.start(RXD, TXD, 0, Baud)                       'Start debug port
'  rxpin, txpin, mode, baudrate
  t.Pause1ms(500)
  ser.tx(CS)

  ser.str(string("Skimmer control HJK V1.1", CR))
  ser.str(string("Max Cog : "))
  ser.dec(Sercog)
  ser.tx(CR)
  ser.tx(CR)
  
  SerEnabled:=true
'  PfStatus |= 1    'Set serial bit
  SetBit(@PfStatus,Serialbit)
'==================================== DisablePfSerial ==========================
PRI DisablePfSerial      'DisablePf serial port
  ser.tx(CS)
  ser.str(string("Skimmer Debug Comm stopped", CR))
  t.Pause1ms(100)

  Ser.stop
  SerEnabled:=false
'  PfStatus := 0 '&= 0  'reset serial bit
'  PfStatus &= 0  'reset serial bit
  ResetBit(@PfStatus,Serialbit)

'==================================== ShowDebug ==========================
PRI ShowDebug |ii, i     'Show debug info on Parallax terminal
    ser.position(0,9)
    ser.str(string("Instr : "))
    ser.tx(" ")
'    ser.dec(ii++)
'    ser.tx(" ")
    ser.dec(StrCnt)
    ser.tx(" ")
'    repeat while StrSP>0
'    StrSp:=1
    ser.str(@cStrBuf)
    ser.tx(CE)
    ser.position(0,10)
'    XStat:=DoXCommand                        'Check input string for new commands
    ser.tx(CR)
    ser.str(string("XStat : "))
    ser.dec(XStat)

'    showline
'    StrSp:=0
    ser.tx(CE)
'    ppc.MtrMove(Speed,10)
    ser.tx(CR)
    ser.position(0,2)
    ser.str(string(" JoyX : "))
    ser.dec(JoyX)
    ser.str(string(" JoyY : "))
    ser.dec(JoyY)
    ser.str(string(" MoveSpeed : "))
    ser.dec(MoveSpeed)
    ser.str(string(" MoveDir : "))
    ser.dec(MoveDir)
    ser.str(string(" Enabled : "))
    ser.dec(Enabled)

    ser.str(string(" State : "))
    ser.dec(ppc.GetState)
    ser.str(string(" MoveMode : "))
    ser.dec(MoveMode)
    ser.tx(CE)
    ser.tx(CR)
    ser.str(string(CR," Button : "))
    ser.dec(Button[0])
    ser.tx(" ")
    ser.dec(Button[1])
    ser.tx(" ")
    ser.dec(Button[2])
    ser.tx(" ")
    ser.dec(Button[3])
    ser.tx(" ")
    ser.str(string(" oButton : "))
    ser.dec(oButton[0])
    ser.tx(" ")
    ser.dec(oButton[1])
    ser.tx(" ")
    ser.dec(oButton[2])
    ser.tx(" ")
    ser.dec(oButton[3])
    ser.tx(" ")
    ser.tx(CE)
    ser.tx(CR)
    ser.str(string(" PcEnable : "))
    ser.dec(PcEnable)
    ser.str(string(" PcComActive : "))
    ser.dec(PcComActive)
    ser.str(string(" PcControl : "))
    ser.dec(PcControl)
    ser.str(string(" PccState : "))
    ser.dec(PccState)
    ser.str(string(" PcSpeed : "))
    ser.dec(PcSpeed)
    ser.str(string(" PcDirection : "))
    ser.dec(PcDirection)
    ser.str(string(" PcCounter : "))
    ser.dec(PcCntr)
    ser.tx(" ")
    ser.dec(lPcCntr)
    ser.tx(" ")
    ser.dec(PcCntr-lPcCntr)
    ser.tx(CE)
    ser.tx(CR)
    ser.str(string(" Set Speed : "))
    ser.dec(ppc.GetSetSpeed(1))
    ser.str(string(" Set Speed : "))
    ser.dec(ppc.GetSetSpeed(0))
    ser.tx(" ")
    ser.dec(ppc.GetSetSpeed(1))
    ser.str(string(" Set Position : "))
    ser.dec(ppc.GetSetPosition(0))
    ser.tx(" ")
    ser.dec(ppc.GetSetPosition(1))
    ser.str(string(" Act Pos : "))
    ser.dec(ppc.Position(0))
    ser.tx(" ")
    ser.dec(ppc.Position(1))
    ser.tx(CE)

    ser.tx(CR)
    ser.str(string(" HB25 Enabled : "))
    ser.dec(ppc.GetEnabled)

    ser.str(string(" SafetyCntr : "))
    ser.dec(SafetyCntr)
    ser.str(string(" State : "))
    ser.dec(ppc.GetState)
    ser.str(string(" LastAlarm : "))
    ser.dec(LastAlarm)
    
    ser.str(string(" Cntr : "))
    ser.dec(ppc.GetCntr)
    ser.str(string(" Sel0 : "))
    ser.dec(InA[Sel0])
    ser.tx(" ")
    ser.dec(oSel0)
    ser.tx(" ")
    ser.str(string(" PfStatus : $"))
    ser.hex(PfStatus,4)
    ser.tx(CE)
    ser.position(0,20)
    ser.str(string("PING))) Demo ", CR,  "Centimeters = ", CR))
    ser.tx(CR)
    ser.dec(PingCntr)
    ser.tx(" ")
    i:=0
    repeat PingCnt
      ser.dec(Range[i++]/10)
      ser.tx(".")                                       ' Print Decimal Point
      ser.dec(range // 10)                              ' Print Fractional Part
      ser.tx(" ")

    ser.str(string(" PingMode : "))
    ser.dec(PingMode)
    ser.str(string(" PingState : "))
    ser.dec(PingState)

    ser.tx(CR)
    i:=0
    repeat PingCnt
      ser.tx(" ")
      ser.dec(RangeAl[i++])
    ser.str(string(" PingEnable : "))
    ser.dec(PingEnable)

    ser.tx(CR)

    i:=0
    repeat PingCnt
      ser.tx(" ")
      ser.dec(lRangeAl[i++])

    ser.str(string(" Act Al rng : "))
    ser.dec(ActAlRange)
    ser.str(string(" PingDistMul : "))
    ser.dec(PingDistMul)
    ser.tx(CE)


'==================================== ShowLine ==========================
PRI ShowLine | i, l        'Show line chars in decimals
  l:=Strsize(@cStrBuf)
  if l>0
    repeat while Byte[StrBuf][i]>0
      ser.tx("/")
      ser.dec(Byte[StrBuf][i++])


'==================================== Init program ==========================
PRI Init

  XbeeCmdCog:=CogNew(DoXbeeCmd, @XbeeCmdStack)  'Start Xbee command handler

'  cognew(testje,@teststack)
  HB25cog:=ppc.start(MotorData)     
  PingCog:=CogNew(ScanPing,@PingStack)          'Start Scan cog
  safetyCog:=CogNew(DoSafety,@SafetyStack)      'Start Safety cog

  NoAlarm:=true
  
  t.Pause1ms(1500)

pri testje  | iii
  iii++
  
'================================ DoSafety ==========================
PRI DoSafety | lCheckTime, lHB25cnt, lJoyCntr, loPcControl, CheckInterval
  
  CheckInterval:= 240000000     '3 sec
  lCheckTime:=Cnt + CheckInterval   'Next check time after 0.1 sec
  lPcCntr:=PcCntr
  lJoyCntr:=JoyCntr
  
  repeat
    if PingAlarm
      DisablePf
      PingMode:=1
      
    if PcControl <> loPcControl
      lPcCntr:=PcCntr-5                      'Init history counter at enable/DisablePf of PC control
    loPcControl:=PcControl

    if NoAlarm                               'Copy alarm status in alarm bit
      Setbit(@PfStatus,NoAlarmBit)
    else  
      Resetbit(@PfStatus,NoAlarmBit)         

   '------- This section runs every Check interval ---------------- 
    if Cnt>lCheckTime   'Timeout, check safety conditions
      SafetyCntr++
      if PcComActive == 1                    'Check counter while PC com
        if (PcCntr==lPcCntr)
          SetBit(@PfStatus,CommCntrBit)      'Set alarm bit for Pc comm
'          NoAlarm:= false
          LastAlarm:=2                       'Comm error PC
          PcComActive:= 0
'          DisablePf                          'Disable platform movements!
        lPcCntr:=PcCntr  

      if JoyComActive == 1
        if ((JoyCntr-lJoyCntr) < 1)          'Joy stick mode
          SetBit(@PfStatus,CommCntrBit)
'          NoAlarm:= false
          LastAlarm:=3                       'Comm error Joy stick
          JoyComActive:= 1
'          DisablePf                          'Disable platform movements!
        lJoyCntr:=JoyCntr  
  
      lCheckTime:=Cnt + CheckInterval        'Next check time 
      

'================================ Do Xbee comm ==========================
PRI DoXbeeCmd | MaxWaitTime
  MaxWaitTime := 100                    'ms wait time for incoming string  
  StrSp:=0
  
  JoyComActive:=0                      'Reset communication state var's
  PcComActive:=0
  
  ByteFill(@StrBuf,0,MaxStr)
  ByteFill(@cStrBuf,0,MaxStr)
  xBee.start(xTXD, xRXD, 0, xBaud)     'Start xbee:  start(pin, baud, lines)

  repeat
'    repeat until StrSP == 0  'Wait for release of string buf

    StrCnt++
 '   StrSp:=1
 '   StrInMaxTime(stringptr, maxcount,ms)
    Xbee.StrInMaxTime(@StrBuf,MaxStr,MaxWaitTime)   'Non blocking max wait time
    if Strsize(@StrBuf)>3                           'Received string must be larger than 3 char's skip rest
      ByteMove(@cStrBuf,@StrBuf,MaxStr)             'Copy received string in display buffer for debug
 '   StrSp:=0
      XStat:=DoXCommand                             'Check input string for new commands

    ProcessCommand                                  ' Execute new commands


' ---------------- Process External commands into motion commands---------------------------------------
PRI ProcessCommand

  if PcControl ==0               'joy stick                  'PC control Disabled
    if JoyY > JoyYHyst or JoyY < -JoyYHyst        'Make correction for hysteresis
'    if    'Speed
'      MoveSpeed:=(JoyY+JoyYHyst) /10
      MoveSpeed:=(JoyY) /30
      SetBit(@PfStatus,MotionBit)

    else
      MoveSpeed:=0
      ResetBit(@PfStatus,MotionBit)
      
    if JoyX > JoyXHyst or JoyX < -JoyXHyst         'Dir
      MoveDir:=JoyX /30
    else
      MoveDir:=0

    if Enabled
      ppc.MtrMove(MoveSpeed,MoveDir)               'Move command to motor controllers
      if ||MoveSpeed > 4 or ||MoveDir > 4          'Set motion bit when moving
        SetBit(@PfStatus,MotionBit)
      else  
        ResetBit(@PfStatus,MotionBit)
'    else  
'      Move(0, 0, 0)
      
    if Button[0]==1 and oButton[0] ==0 and Enabled          'Enable / DisablePf platform via remote
       oButton[0]:=1
       DisablePf
  
    if Button[0]==1 and oButton[0] ==0 and not Enabled 
       oButton[0]:=1
       EnablePf         'Enable platform
       
    oButton[0]:=Button[0]

    if Button[1]==1 and oButton[1] ==0                       'Ping enable / DisablePf
      if PingEnable ==0
        PingEnable:=1
        SetBit(@PfStatus,PingBit)
      else
        PingEnable:=0  
        ResetBit(@PfStatus,PingBit)
    oButton[1]:=Button[1]
      
    if Button[2]==1 and oButton[2] ==0
      MoveMode:=0                                            'DisablePf
      DisablePf
    oButton[2]:=Button[2]
      
    if Button[3]==1 and oButton[3] ==0
      ResetPfStatus                                          'Reset errors
    oButton[3]:=Button[3]
    ResetBit(@PfStatus,PcControlBit)    

  else 'PC control enabled   
     MoveDir:=(-128 #> PcDirection <# 128) / 3
     MoveSpeed:=(-128 #> PcSpeed <# 128) / 5 
'     MoveSpeed:=PcSpeed / 5
'     MoveDir:=PcDirection / 3
     MoveMode:=PcMoveMode

    if Enabled
       ppc.MtrMove(MoveSpeed,MoveDir)               'Move command to motor controllers
       if ||MoveSpeed > 4 or ||MoveDir > 4          'Set motion bit when moving
         SetBit(@PfStatus,MotionBit)
       else  
         ResetBit(@PfStatus,MotionBit)

    if (PcEnable == 1) and !Enabled and NoAlarm 'Enable / DisablePf platform via PC
      EnablePf
      SetBit(@PfStatus,PcEnableBit)    
      PccState:=4
 
    if (PcEnable==0) and Enabled  
'    if (PcEnable==1) and (oPcEnable == 0) and Enabled  
       DisablePf
       ResetBit(@PfStatus,PcEnableBit)    
       PccState:=3
    oPcEnable:=PcEnable                          'Sync history var 
       
  if PCControl <> oPcControl 
    if PCControl == 1
      SetBit(@PfStatus,PcControlBit)
      PccState:=1
      JoyComActive:=0
    else  'PCControl == 0     
      ResetBit(@PfStatus,PcControlBit)
      PcEnable:=0
      ResetBit(@PfStatus,PcEnableBit)    
      PccState:=2
      PcComActive := 0                           'Stop checking PC comm
  oPCControl:=PCControl

' ---------------- Move mode control platform -------------------------------
PRI ResetPfStatus  | ii

  ResetBit(@PfStatus,USAlarm)          'Reset error bits in PfStatus
  ResetBit(@PfStatus,CommCntrBit)
  NoAlarm:=true                        'Reset global alarm var
  LastAlarm:=0                         'Reset last alarm message
'  ResetBit(@PfStatusNoALarmBit)
  
  PingMode:=0                          'Reset Ping sensors
  PingState:=0

  PcSpeed:=0                           'Reset setpoints
  MoveSpeed:=0
  MoveDir:=0
  
  ii:=0
  Repeat PingCnt                       'Reset Latched Ping alarm
    lRangeAl[ii++]:=0
  
' ----------------  Stop all motion disable motion ---------------------------
PRI DisablePf
' ppc.EmergencyStop
  PcSpeed:=0
  MoveSpeed:=0
  MoveDir:=0
  ResetBit(@PfStatus,MotionBit)
  Enabled:=false
  ResetBit(@PfStatus,EnableBit)
  ppc.Disable

' ----------------------  Enable platform  ---------------------------------------
PRI EnablePf
  PcSpeed:=0
  MoveSpeed:=0
  MoveDir:=0
  SetBit(@PfStatus,EnableBit)
  ppc.enable
  Enabled:=true
  
' -------------- DoXCommand: Get command parameters from Xbee input string --------------
PRI DoXCommand | OK, i, j, Par1, Par2, lCh, t1, c1     
'  ser.position(0,24)
'  ser.position(0,10)
'  ser.str(string("Debug XB "))
  t1:=cnt
  OK:=1

  StrP:=0  'Reset line pointer
  Sender:=0
  StrLen:=strsize(@StrBuf)  
'  ser.dec(StrLen)
'  ser.tx(" ")
'  ser.str(@StrBuf)

  if StrLen > (MaxStr-1)       'Check max len
'    ser.dec(MaxStr-1)
'    ser.tx(" ")
    OK:=-1                      'Error: String too long
    
  if StrLen == 0                'Check zero length
    OK:=-2                      'Error: Null string
    
  if OK==1                      'Parse string
    lCh:=sGetch
'    ser.Tx("1")
    repeat while (lch<>"$") and (OK == 1)       'Find start char
'      ser.Tx(">")
'        Return -5  'timeout
      lCh:=sGetch
      if StrP == StrLen
        OK:=-3                  'Error: No Command Start char found
        Quit                    'Exit loop

'    ser.str(string(" Sender : " ))
    if OK == 1
      Sender:=sGetPar
'    ser.dec(Sender)
'    ser.Tx(" ")
'    ser.Tx("3")
'    lch:=sGetch   'Get comma
'     ser.tx(CR)
      Case Sender
        '== Move command from Joy stick
        500: JoyComActive:=1     'Get Joystick values
'          ser.Tx("4")
'          ser.Tx(" ")
             JoyCntr := sGetPar
             JoyX := sGetPar
             JoyY := sGetPar
             Button[0]:=sGetpar
             Button[1]:=sGetpar
             Button[2]:=sGetpar
             Button[3]:=sGetpar
{          ser.str(string(" JCntr : " ))
          ser.dec(Jcntr)
          ser.str(string(" Button[0] : " ))
          ser.dec(Button[0])
          ser.Tx(" ")  }

        '=== Move commands from PC
        900: PcComActive:=1       'Get PC command for speed and direction from PC move commands
             PcCntr := sGetPar
             PcSpeed := sGetPar
             PcDirection := sGetPar
             SendACK  '$900,CR

        901: PcEnable:=sGetpar    'Enable DisablePf platform in PC control mode
        902: PcControl:=sGetpar    'Enable DisablePf PC control
          
        906: 'PcComActive:=1      'Autonomous mode

        908: ResetPfStatus        'Reset platform status
        
        909: PingEnable := sGetPar
             DoUSsensors(PingEnable)

        910: PcComActive:=1       'Get PC command for speed and direction from PC move commands
             PcCntr := sGetPar
             PcSpeed := sGetPar
             PcDirection := sGetPar
             DoPos2Pc
             
        '=== Status commands
        911: DoSensors2PC 'US sensors
        912: DoStatus2PC  'Status and errors
        913: DoPos2Pc     'Position to PC
           
        
  XbeeTime:=cnt-t1
      
Return OK

' ---------------- Get next parameter from string ---------------------------------------
PRI sGetPar | j, jj, ii, lPar, lch
  j:=0
  Bytefill(@LastPar1,0,CmdLen)   'Clear buffer
  lch:=sGetch                    'Get comma and point to first numeric char
  jj:=0
  repeat until lch=="," 'Get parameter until comma
'    if jj++ >100
'      return -1
    if lch<>"," and j<CmdLen
      LastPar1[j++]:=lch
    lch:=sGetch           'skip next
 
  LPar:=ser.strtodec(@LastPar1)
'  ser.str(string(" GetPar : " ))
'  ser.dec(lPar)
Return Lpar

' ---------------- Get next character from string ---------------------------------------
Pri sGetCh | lch 'Get next character from commandstring
   lch:=Byte[@StrBuf][StrP++]
'   ser.tx("\")          
'   ser.tx(lch)
 '  Cmd[Lp++]:=lch
Return lch

' ---------------- Print program status to PC ---------------------------------------
PRI DoStatus2PC
  Xbee.tx("$")
'  Xbee.tx("%")
  Xbee.dec(Sender)        'Last Sender
  Xbee.tx(",")
  Xbee.dec(MoveMode)      'Mode mode 0 = manual 1= US sensor control
  Xbee.tx(",")
  Xbee.dec(LastAlarm)     'Last error
  Xbee.tx(",")
  Xbee.dec(XbeeTime/80000)      'Time of Xbee comm in ms
  Xbee.tx(",")
  Xbee.dec(ppc.getCntr)   'HB52 counter to check life
  Xbee.tx(",")
  Xbee.dec(Enabled)       'Platform Enabled
  Xbee.tx(",")
  Xbee.dec(PcEnable)     'Pc has control Enabled
  Xbee.tx(",")
  Xbee.dec(PfStatus)     'Platform status
  Xbee.tx(",")
  Xbee.dec(MainCntr)     'Main loop counter
  Xbee.tx(",")
  Xbee.dec(SafetyCntr)   'Safety loop counter
  Xbee.tx(",")
  Xbee.dec(Version)      'Software version
  Xbee.tx(CR)
  Xbee.tx("#")
  Xbee.tx(EOT)   'End of transmission

' ---------------- Print US sensor to PC ---------------------------------------
PRI DoSensors2PC | i
  i:=0
  Xbee.tx("$")
'  Xbee.tx("%")
  Xbee.dec(Sender)
  Xbee.tx(",")
  Repeat PingCnt
    Xbee.dec(Range[i++])
    Xbee.tx(",")
    
  Xbee.tx(CR)
  Xbee.tx("#")
  Xbee.tx(EOT)   'End of transmission
  
' ---------------- Send Wheel Positions to PC ---------------------------------------
PRI DoPos2PC | i
  i:=0
  Xbee.tx("$")
'  Xbee.tx("%")
  Xbee.dec(Sender)
  Xbee.tx(",")
  
  Xbee.dec(||ppc.Position(0))
  Xbee.tx(",")
  Xbee.dec(||ppc.Position(1))
  Xbee.tx(",")
    
  Xbee.tx(CR)
  Xbee.tx("#")
  Xbee.tx(EOT)   'End of transmission

' ---------------- 'Switch  US sensors On and Off-------------------------------
PRI DoUSsensors(State)
  if State == 1
    EnableUSSensors
  else
    DisablePfUSSensors
      
' ---------------- 'DisablePf US sensors -------------------------------
PRI DisablePfUSsensors
  PingEnable := 0
  ResetBit(@PfStatus,PingBit)
  
' ---------------- 'DisablePf US sensors -------------------------------
PRI EnableUSsensors
  PingEnable := 1
  SetBit(@PfStatus,PingBit)

' ---------------- 'Set bit in 32 bit Long var -------------------------------
PRI SetBit(VarAddr,Bit) | lBit, lMask
  lBit:= 0 #> Bit <# 31    'Limit range
  lMask:= |< Bit           'Set Bit mask
  Long[VarAddr] |= lMask   'Set Bit
    

' ---------------- 'Reset bit in 32 bit Long var -------------------------------
PRI ResetBit(VarAddr,Bit) | lBit, lMask
  lBit:= 0 #> Bit <# 31    'Limit range
  lMask:= |< Bit           'Set Bit mask
  
  Long[VarAddr] &= !lMask  'Reset bit

' ---------------- Scan all Ping sensors in mm ---------------------------------------
PRI ScanPing  | i, lRangeAlarm, tt, Avg, AvgMul
'' Scan all Ping sensors
 PingState:=0
 PingMode:=0
 Avg:=2
 AvgMul:=Avg-1
 PingEnable := 1
 SetBit(@PfStatus,PingBit)  'Set Ping Bit
   
 repeat 
   if PingEnable == 1
     i:=0
     PingCntr++
    lRangeAlarm:=0
     if PingMode == 1
       PingState++
       if PingState > 10
         PingState:=0

     PingDistMul:= 1 #> MoveSpeed / PingSpeedDiv
     ActAlRange:= PingDistMul * PingAlarmDist    'Actual alarm distance in cm
        
     repeat PingCnt                              'Check all sensors
       if PingMode == 0
         Range[i]:=(ping.Millimeters(PING_Pin + i) + oRange[i] * AvgMul) / Avg 'Do some averaging
         oRange[i]:=Range[i]
       else   'Ping mode =1 alarm indication for problem spot. The rest measure like before
         if lRangeAl[i]==0
           Range[i]:=(ping.Millimeters(PING_Pin + i) + oRange[i] * AvgMul) / Avg 'Do some averaging
           oRange[i]:=Range[i]

         else
           If PingState == 0                     'Show problem spot once in 5 cycles
'             t.Pause1ms(50)
             Range[i]:=(ping.Millimeters(PING_Pin + i) + oRange[i] * AvgMul) / Avg 'Do some averaging
             oRange[i]:=Range[i]

       if Range[i] < ActAlRange *10              'Check distance (in mm for any sensor uin forward direction
         RangeAl[i]:=1
         if (MoveSpeed > 0 and i < 6) or (MoveSpeed < 0 and i > 5)  'Set alarm only in move direction  
           lRangeAl[i]:=1
           lRangeAlarm:=1                        'Set Alarm
           LastAlarm:=1
           SetBit(@PfStatus,USAlarm)
           NoAlarm:=false  
       else
         RangeAl[i]:=0

       PingAlarm:=lRangeAlarm  
       i++

 '    t.Pause1ms(20)
DAT

USTable  'US distance multiplier
Word 2,6,10,6,2,2,6,10,6,2
              
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
        
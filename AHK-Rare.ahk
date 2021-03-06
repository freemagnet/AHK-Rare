﻿;---------------------------------------------------------------------------------------------------------------------------------------------------------
;																	Collection of rare or very useful functions
; 																collected by IXIKO =>    last change: 30.09.2018
;										for description have a look at README.md (it can be found in the same folder)
;---------------------------------------------------------------------------------------------------------------------------------------------------------


{ ;Clipboard (9)
;1
ClipboardGetDropEffect() {																																	;-- Clipboard function. Retrieves if files in clipboard comes from an explorer cut or copy operation.
	
	/*                              	DESCRIPTION
	
			; explorer copy = 5, explorer cut = 2
			
	*/
	
	
   Static PreferredDropEffect := DllCall("RegisterClipboardFormat", "Str" , "Preferred DropEffect")
   DropEffect := 0
   If DllCall("IsClipboardFormatAvailable", "UInt", PreferredDropEffect) {
      If DllCall("OpenClipboard", "Ptr", 0) {
         hDropEffect := DllCall("GetClipboardData", "UInt", PreferredDropEffect, "UPtr")
         pDropEffect := DllCall("GlobalLock", "Ptr", hDropEffect, "UPtr")
         DropEffect := NumGet(pDropEffect + 0, 0, "UChar")
         DllCall("GlobalUnlock", "Ptr", hDropEffect)
         DllCall("CloseClipboard")
      }
   }
   Return DropEffect
}
;2
ClipboardSetFiles(FilesToSet, DropEffect := "Copy") {																							;-- Explorer function for Drag&Drop and Pasting. Enables the explorer paste context menu option.
   Static TCS := A_IsUnicode ? 2 : 1 ; size of a TCHAR
   Static PreferredDropEffect := DllCall("RegisterClipboardFormat", "Str", "Preferred DropEffect")
   Static DropEffects := {1: 1, 2: 2, Copy: 1, Move: 2}
   ; -------------------------------------------------------------------------------------------------------------------
   ; Count files and total string length
   TotalLength := 0
   FileArray := []
   Loop, Parse, FilesToSet, `n, `r
   {
      If (Length := StrLen(A_LoopField))
         FileArray.Push({Path: A_LoopField, Len: Length + 1})
      TotalLength += Length
   }
   FileCount := FileArray.Length()
   If !(FileCount && TotalLength)
      Return
   ; -------------------------------------------------------------------------------------------------------------------
   ; Add files to the clipboard
   If DllCall("OpenClipboard", "Ptr", A_ScriptHwnd) && DllCall("EmptyClipboard") {
      ; HDROP format ---------------------------------------------------------------------------------------------------
      ; 0x42 = GMEM_MOVEABLE (0x02) | GMEM_ZEROINIT (0x40)
      hPath := DllCall("GlobalAlloc", "UInt", 0x42, "UInt", 20 + (TotalLength + FileCount + 1) * TCS, "UPtr")
      pPath := DllCall("GlobalLock", "Ptr" , hPath)
      Offset := 20
      NumPut(Offset, pPath + 0, "UInt")         ; DROPFILES.pFiles = offset of file list
      NumPut(!!A_IsUnicode, pPath + 16, "UInt") ; DROPFILES.fWide = 0 --> ANSI, fWide = 1 --> Unicode
      For Each, File In FileArray
         Offset += StrPut(File.Path, pPath + Offset, File.Len) * TCS
      DllCall("GlobalUnlock", "Ptr", hPath)
      DllCall("SetClipboardData","UInt", 0x0F, "UPtr", hPath) ; 0x0F = CF_HDROP
      ; Preferred DropEffect format ------------------------------------------------------------------------------------
      If (DropEffect := DropEffects[DropEffect]) {
         ; Write Preferred DropEffect structure to clipboard to switch between copy/cut operations
         ; 0x42 = GMEM_MOVEABLE (0x02) | GMEM_ZEROINIT (0x40)
         hMem := DllCall("GlobalAlloc", "UInt", 0x42, "UInt", 4, "UPtr")
         pMem := DllCall("GlobalLock", "Ptr", hMem)
         NumPut(DropEffect, pMem + 0, "UChar")
         DllCall("GlobalUnlock", "Ptr", hMem)
         DllCall("SetClipboardData", "UInt", PreferredDropEffect, "Ptr", hMem)
      }
      DllCall("CloseClipboard")
   }
   Return
}
;3
CopyFilesToClipboard(arrFilepath, bCopy) {																										;-- copy files to clipboard
	
	/*                              	DESCRIPTION
	
			; this works under both ANSI/Unicode build of AHK
			
	*/
	
	
	; set drop effect to determine whether the files are copied or moved.
	uDropEffect := DllCall("RegisterClipboardFormat", "str", "Preferred DropEffect", "uint")	
	hGblEffect := DllCall("GlobalAlloc", "uint", 0x42, "ptr", 4, "ptr")
	pGblEffect := DllCall("GlobalLock", "ptr", hGblEffect, "ptr")
	; 0x1=DROPEFFECT_COPY, 0x2=DROPEFFECT_MOVE
	NumPut(bCopy ? 1 : 2, pGblEffect+0)

	; Unlock the moveable memory.
	DllCall("GlobalUnlock", "ptr", hGblEffect)


	charsize := A_IsUnicode ? 2 : 1
	AorW := A_IsUnicode ? "W" : "A"

	; calculate the whole size of arrFilepath
	sizeFilepath := charsize*2 ; double null-terminator
	For k, v in arrFilepath {
		sizeFilepath += (StrLen(v)+1)*charsize
	}

	; 0x42 = GMEM_MOVEABLE(0x2) | GMEM_ZEROINIT(0x40)
	hPath := DllCall("GlobalAlloc", "uint", 0x42, "ptr", sizeFilepath + 20, "ptr")
	pPath := DllCall("GlobalLock", "ptr", hPath, "ptr")

	NumPut(20, pPath+0) ;pFiles
	NumPut(A_IsUnicode, pPath+16) ;fWide

	pPath += 20

	; Copy the list of files into moveable memory.
	For k, v in arrFilepath {
		DllCall("lstrcpy" . AorW, "ptr", pPath+0, "str", v)
		pPath += (StrLen(v)+1)*charsize
	}

	; Unlock the moveable memory.
	DllCall("GlobalUnlock", "ptr", hPath)
	
	DllCall("OpenClipboard", "ptr", 0)
	; Empty the clipboard, otherwise SetClipboardData may fail.
	DllCall("EmptyClipboard")
	; Place the data on the clipboard. CF_HDROP=0xF
	DllCall("SetClipboardData","uint",0xF,"ptr",hPath)
	DllCall("SetClipboardData","uint",uDropEffect,"ptr",hGblEffect)
	DllCall("CloseClipboard")
}
;4
FileToClipboard(PathToCopy) {																															;-- copying the path to clipboard
	
	;https://autohotkey.com/board/topic/23162-how-to-copy-a-file-to-the-clipboard/
    ; Expand to full path:
    Loop, %PathToCopy%, 1
        PathToCopy := A_LoopFileLongPath
    
    ; Allocate some movable memory to put on the clipboard.
    ; This will hold a DROPFILES struct, the string, and an (extra) null terminator
    ; 0x42 = GMEM_MOVEABLE(0x2) | GMEM_ZEROINIT(0x40)
    hPath := DllCall("GlobalAlloc","uint",0x42,"uint",StrLen(PathToCopy)+22)
    
    ; Lock the moveable memory, retrieving a pointer to it.
    pPath := DllCall("GlobalLock","uint",hPath)
    
    NumPut(20, pPath+0) ; DROPFILES.pFiles = offset of file list
    
    ; Copy the string into moveable memory.
    DllCall("lstrcpy","uint",pPath+20,"str",PathToCopy)
    
    ; Unlock the moveable memory.
    DllCall("GlobalUnlock","uint",hPath)
    
    DllCall("OpenClipboard","uint",0)
    ; Empty the clipboard, otherwise SetClipboardData may fail.
    DllCall("EmptyClipboard")
    ; Place the data on the clipboard. CF_HDROP=0xF
    DllCall("SetClipboardData","uint",0xF,"uint",hPath)
    DllCall("CloseClipboard")
}
;5
FileToClipboard(PathToCopy) {																															;-- a second way to copying the path to clipboard
    ; Expand to full paths:
    Loop, Parse, PathToCopy, `n, `r
        Loop, %A_LoopField%, 1
            temp_list .= A_LoopFileLongPath "`n"
    PathToCopy := SubStr(temp_list, 1, -1)
    
    ; Allocate some movable memory to put on the clipboard.
    ; This will hold a DROPFILES struct and a null-terminated list of
    ; null-terminated strings.
    ; 0x42 = GMEM_MOVEABLE(0x2) | GMEM_ZEROINIT(0x40)
    hPath := DllCall("GlobalAlloc","uint",0x42,"uint",StrLen(PathToCopy)+22)
    
    ; Lock the moveable memory, retrieving a pointer to it.
    pPath := DllCall("GlobalLock","uint",hPath)
    
    NumPut(20, pPath+0) ; DROPFILES.pFiles = offset of file list
    
    pPath += 20
    ; Copy the list of files into moveable memory.
    Loop, Parse, PathToCopy, `n, `r
    {
        DllCall("lstrcpy","uint",pPath+0,"str",A_LoopField)
        pPath += StrLen(A_LoopField)+1
    }
    
    ; Unlock the moveable memory.
    DllCall("GlobalUnlock","uint",hPath)
    
    DllCall("OpenClipboard","uint",0)
    ; Empty the clipboard, otherwise SetClipboardData may fail.
    DllCall("EmptyClipboard")
    ; Place the data on the clipboard. CF_HDROP=0xF
    DllCall("SetClipboardData","uint",0xF,"uint",hPath)
    DllCall("CloseClipboard")
}
;6
ImageToClipboard(Filename) {																															;-- Copies image data from file to the clipboard. (first of three approaches)
	
	;https://autohotkey.com/board/topic/23162-how-to-copy-a-file-to-the-clipboard/
    hbm := DllCall("LoadImage","uint",0,"str",Filename,"uint",0,"int",0,"int",0,"uint",0x10)
    if !hbm
        return
    DllCall("OpenClipboard","uint",0)
    DllCall("EmptyClipboard")
    ; Place the data on the clipboard. CF_BITMAP=0x2
    if ! DllCall("SetClipboardData","uint",0x2,"uint",hbm)
        DllCall("DeleteObject","uint",hbm)
    DllCall("CloseClipboard")
}
;7
Gdip_ImageToClipboard(Filename) {																													;-- Copies image data from file to the clipboard. (second approach)
	
	;https://autohotkey.com/board/topic/23162-how-to-copy-a-file-to-the-clipboard/
    pBitmap := Gdip_CreateBitmapFromFile(Filename)
    if !pBitmap
        return
    hbm := Gdip_CreateHBITMAPFromBitmap(pBitmap)
    Gdip_DisposeImage(pBitmap)
    if !hbm
        return
;     Gui, Add, Picture, hwndpic W800 H600 0xE
;     SendMessage, 0x172, 0, hbm,, ahk_id %pic%
;     Gui, Show
    DllCall("OpenClipboard","uint",0)
    DllCall("EmptyClipboard")
    ; Place the data on the clipboard. CF_BITMAP=0x2
    if ! DllCall("SetClipboardData","uint",0x2,"uint",hbm)
        DllCall("DeleteObject","uint",hbm)
    DllCall("CloseClipboard")
}
;8
Gdip_ImageToClipboard(Filename) {																													;-- Copies image data from file to the clipboard. (third approach)
	
	;by Lexikos
	;;https://autohotkey.com/board/topic/23162-how-to-copy-a-file-to-the-clipboard/
    pBitmap := Gdip_CreateBitmapFromFile(Filename)
    if !pBitmap
        return
    hbm := Gdip_CreateHBITMAPFromBitmap(pBitmap)
    Gdip_DisposeImage(pBitmap)
    if !hbm
        return
    if hdc := DllCall("CreateCompatibleDC","uint",0)
    {
        ; Get BITMAPINFO.
        VarSetCapacity(bmi,40,0), NumPut(40,bmi)
        DllCall("GetDIBits","uint",hdc,"uint",hbm,"uint",0
             ,"uint",0,"uint",0,"uint",&bmi,"uint",0)
        ; GetDIBits seems to screw up and give the image the BI_BITFIELDS
        ; (i.e. colour-indexed) compression type when it is in fact BI_RGB.
        NumPut(0,bmi,16)
        ; Get bitmap bits.
        if size := NumGet(bmi,20)
        {
            VarSetCapacity(bits,size)
            DllCall("GetDIBits","uint",hdc,"uint",hbm,"uint",0
                ,"uint",NumGet(bmi,8),"uint",&bits,"uint",&bmi,"uint",0)
            ; 0x42 = GMEM_MOVEABLE(0x2) | GMEM_ZEROINIT(0x40)
            hMem := DllCall("GlobalAlloc","uint",0x42,"uint",40+size)
            pMem := DllCall("GlobalLock","uint",hMem)
            DllCall("RtlMoveMemory","uint",pMem,"uint",&bmi,"uint",40)
            DllCall("RtlMoveMemory","uint",pMem+40,"uint",&bits,"uint",size)
            DllCall("GlobalUnlock","uint",hMem)
        }
        DllCall("DeleteDC","uint",hdc)
    }
    if hMem
    {
        DllCall("OpenClipboard","uint",0)
        DllCall("EmptyClipboard")
        ; Place the data on the clipboard. CF_DIB=0x8
        if ! DllCall("SetClipboardData","uint",0x8,"uint",hMem)
            DllCall("GlobalFree","uint",hMem)
        DllCall("CloseClipboard")
    }
}
;9
AppendToClipboard( files, cut=0) { 																													;-- Appends files to CF_HDROP structure in clipboard
	DllCall("OpenClipboard", "Ptr", 0)
	if (DllCall("IsClipboardFormatAvailable", "Uint", 1)) ;If text is stored in clipboard, clear it and consider it empty (even though the clipboard may contain CF_HDROP due to text being copied to a temp file for pasting)
		DllCall("EmptyClipboard")
	DllCall("CloseClipboard")
	txt:=clipboard (clipboard = "" ? "" : "`n") files
	Sort, txt , U ;Remove duplicates
	CopyToClipboard(txt, true, cut)
	return
}


}
;|														|                                                       |														|														|
;|  ClipboardGetDropEffect()         	|   ClipboardSetFiles()                     	|   CopyFilesToClipboard()            	|   FileToClipboard()                      	|
;|	FileToClipboard()                      	|   1.ImageToClipboard()                 	|   2.Gdip_ImageToClipboard()        	|   3.Gdip_ImageToClipboard()        	|
;|   AppendToClipboard()               	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;Command - line interaction (3) , Commandline - Run a exe with parameters examples
CMDret_RunReturn(CMDin, WorkingDir=0) {														;--

/*
; ******************************************************************
; CMDret-AHK functions
; Version 1.10 beta
;
; Updated: Dec 5, 2006
; by: corrupt
; Code modifications and/or contributions made by:
; Laszlo, shimanov, toralf, Wdb
; ******************************************************************
; Usage:
; CMDin - command to execute
; WorkingDir - full path to working directory (Optional)
; ******************************************************************
; Known Issues:
; - If using dir be sure to specify a path (example: cmd /c dir c:\)
; or specify a working directory
; - Running 16 bit console applications may not produce output. Use
; a 32 bit application to start the 16 bit process to receive output
; ******************************************************************
; Additional requirements:
; - none
; ******************************************************************
; Code Start
; ******************************************************************

*/

  Global cmdretPID
  tcWrk := WorkingDir=0 ? "Int" : "Str"
  idltm := A_TickCount + 20
  CMsize = 1
  VarSetCapacity(CMDout, 1, 32)
  VarSetCapacity(sui,68, 0)
  VarSetCapacity(pi, 16, 0)
  VarSetCapacity(pa, 12, 0)
  Loop, 4 {
    DllCall("RtlFillMemory", UInt,&pa+A_Index-1, UInt,1, UChar,12 >> 8*A_Index-8)
    DllCall("RtlFillMemory", UInt,&pa+8+A_Index-1, UInt,1, UChar,1 >> 8*A_Index-8)
  }
  IF (DllCall("CreatePipe", "UInt*",hRead, "UInt*",hWrite, "UInt",&pa, "Int",0) <> 0) {
    Loop, 4
      DllCall("RtlFillMemory", UInt,&sui+A_Index-1, UInt,1, UChar,68 >> 8*A_Index-8)
    DllCall("GetStartupInfo", "UInt", &sui)
    Loop, 4 {
      DllCall("RtlFillMemory", UInt,&sui+44+A_Index-1, UInt,1, UChar,257 >> 8*A_Index-8)
      DllCall("RtlFillMemory", UInt,&sui+60+A_Index-1, UInt,1, UChar,hWrite >> 8*A_Index-8)
      DllCall("RtlFillMemory", UInt,&sui+64+A_Index-1, UInt,1, UChar,hWrite >> 8*A_Index-8)
      DllCall("RtlFillMemory", UInt,&sui+48+A_Index-1, UInt,1, UChar,0 >> 8*A_Index-8)
    }
    IF (DllCall("CreateProcess", Int,0, Str,CMDin, Int,0, Int,0, Int,1, "UInt",0, Int,0, tcWrk, WorkingDir, UInt,&sui, UInt,&pi) <> 0) {
      Loop, 4
        cmdretPID += *(&pi+8+A_Index-1) << 8*A_Index-8
      Loop {
        idltm2 := A_TickCount - idltm
        If (idltm2 < 10) {
          DllCall("Sleep", Int, 10)
          Continue
        }
        IF (DllCall("PeekNamedPipe", "uint", hRead, "uint", 0, "uint", 0, "uint", 0, "uint*", bSize, "uint", 0 ) <> 0 ) {
          Process, Exist, %cmdretPID%
          IF (ErrorLevel OR bSize > 0) {
            IF (bSize > 0) {
              VarSetCapacity(lpBuffer, bSize+1)
              IF (DllCall("ReadFile", "UInt",hRead, "Str", lpBuffer, "Int",bSize, "UInt*",bRead, "Int",0) > 0) {
                IF (bRead > 0) {
                  TRead += bRead
                  VarSetCapacity(CMcpy, (bRead+CMsize+1), 0)
                  CMcpy = a
                  DllCall("RtlMoveMemory", "UInt", &CMcpy, "UInt", &CMDout, "Int", CMsize)
                  DllCall("RtlMoveMemory", "UInt", &CMcpy+CMsize, "UInt", &lpBuffer, "Int", bRead)
                  CMsize += bRead
                  VarSetCapacity(CMDout, (CMsize + 1), 0)
                  CMDout=a
                  DllCall("RtlMoveMemory", "UInt", &CMDout, "UInt", &CMcpy, "Int", CMsize)
                  VarSetCapacity(CMDout, -1)   ; fix required by change in autohotkey v1.0.44.14
                }
              }
            }
          }
          ELSE
            break
        }
        ELSE
          break
        idltm := A_TickCount
      }
      cmdretPID=
      DllCall("CloseHandle", UInt, hWrite)
      DllCall("CloseHandle", UInt, hRead)
    }
  }
  IF (StrLen(CMDout) < TRead) {
    VarSetCapacity(CMcpy, TRead, 32)
    TRead2 = %TRead%
    Loop {
      DllCall("RtlZeroMemory", "UInt", &CMcpy, Int, TRead)
      NULLptr := StrLen(CMDout)
      cpsize := Tread - NULLptr
      DllCall("RtlMoveMemory", "UInt", &CMcpy, "UInt", (&CMDout + NULLptr + 2), "Int", (cpsize - 1))
      DllCall("RtlZeroMemory", "UInt", (&CMDout + NULLptr), Int, cpsize)
      DllCall("RtlMoveMemory", "UInt", (&CMDout + NULLptr), "UInt", &CMcpy, "Int", cpsize)
      TRead2 --
      IF (StrLen(CMDout) > TRead2)
        break
    }
  }
  StringTrimLeft, CMDout, CMDout, 1
  Return, CMDout
}

ConsoleSend(text, WinTitle="", WinText="", ExcludeTitle="", ExcludeText="") {		;-- Sends text to a console's input stream

	; Sends text to a console's input stream. WinTitle may specify any window in
	; the target process. Since each process may be attached to only one console,
	; ConsoleSend fails if the script is already attached to a console.

    WinGet, pid, PID, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
    if !pid
        return false, ErrorLevel:="window"
    ; Attach to the console belonging to %WinTitle%'s process.
    if !DllCall("AttachConsole", "uint", pid)
        return false, ErrorLevel:="AttachConsole"
    hConIn := DllCall("CreateFile", "str", "CONIN$", "uint", 0xC0000000
                , "uint", 0x3, "uint", 0, "uint", 0x3, "uint", 0, "uint", 0)
    if hConIn = -1
        return false, ErrorLevel:="CreateFile"

    VarSetCapacity(ir, 24, 0)       ; ir := new INPUT_RECORD
    NumPut(1, ir, 0, "UShort")      ; ir.EventType := KEY_EVENT
    NumPut(1, ir, 8, "UShort")      ; ir.KeyEvent.wRepeatCount := 1
    ; wVirtualKeyCode, wVirtualScanCode and dwControlKeyState are not needed,
    ; so are left at the default value of zero.

    Loop, Parse, text ; for each character in text
    {
        NumPut(Asc(A_LoopField), ir, 14, "UShort")

        NumPut(true, ir, 4, "Int")  ; ir.KeyEvent.bKeyDown := true
        gosub ConsoleSendWrite

        NumPut(false, ir, 4, "Int") ; ir.KeyEvent.bKeyDown := false
        gosub ConsoleSendWrite
    }
    gosub ConsoleSendCleanup
    return true

    ConsoleSendWrite:
        if ! DllCall("WriteConsoleInput", "uint", hconin, "uint", &ir, "uint", 1, "uint*", 0)
        {
            gosub ConsoleSendCleanup
            return false, ErrorLevel:="WriteConsoleInput"
        }
    return

    ConsoleSendCleanup:
        if (hConIn!="" && hConIn!=-1)
            DllCall("CloseHandle", "uint", hConIn)
        ; Detach from %WinTitle%'s console.
        DllCall("FreeConsole")
    return
}
{ ; sub
ScanCode( wParam, lParam ) {
 Clipboard := "SC" SubStr((((lParam>>16) & 0xFF)+0xF000),-2)
 GuiControl,, SC, %Clipboard%
}
} 

StdOutStream( sCmd, Callback := "", WorkingDir:=0, ByRef ProcessID:=0) { 				;-- Store command line output in autohotkey variable. Supports both x86 and x64.

	; Modified  :  maz-1 https://gist.github.com/maz-1/768bf7938e533907d54bff276db80904
  Static StrGet := "StrGet"           ; Modified  :  SKAN 31-Aug-2013 http://goo.gl/j8XJXY
                                      ; Thanks to :  HotKeyIt         http://goo.gl/IsH1zs
                                      ; Original  :  Sean 20-Feb-2007 http://goo.gl/mxCdn
  tcWrk := WorkingDir=0 ? "Int" : "Str"
  DllCall( "CreatePipe", UIntP,hPipeRead, UIntP,hPipeWrite, UInt,0, UInt,0 )
  DllCall( "SetHandleInformation", UInt,hPipeWrite, UInt,1, UInt,1 )
  If A_PtrSize = 8
  {
    VarSetCapacity( STARTUPINFO, 104, 0  )      ; STARTUPINFO          ;  http://goo.gl/fZf24
    NumPut( 68,         STARTUPINFO,  0 )      ; cbSize
    NumPut( 0x100,      STARTUPINFO, 60 )      ; dwFlags    =>  STARTF_USESTDHANDLES = 0x100
    NumPut( hPipeWrite, STARTUPINFO, 88 )      ; hStdOutput
    NumPut( hPipeWrite, STARTUPINFO, 96 )      ; hStdError
    VarSetCapacity( PROCESS_INFORMATION, 24 )  ; PROCESS_INFORMATION  ;  http://goo.gl/b9BaI
  }
  Else
  {
    VarSetCapacity( STARTUPINFO, 68, 0  )
    NumPut( 68,         STARTUPINFO,  0 )
    NumPut( 0x100,      STARTUPINFO, 44 )
    NumPut( hPipeWrite, STARTUPINFO, 60 )
    NumPut( hPipeWrite, STARTUPINFO, 64 )
    VarSetCapacity( PROCESS_INFORMATION, 16 )
  }

	/* Tip for struct calculation

		  ; Any member should be aligned to multiples of its size
		  ; Full size of structure should be multiples of the largest member size
		  ;============================================================================
		  ;
		  ; x64
		  ; STARTUPINFO
		  ;                             offset    size                    comment
		  ;DWORD  cb;                   0         4
		  ;LPTSTR lpReserved;           8         8(A_PtrSize)            aligned to 8-byte boundary (4 + 4)
		  ;LPTSTR lpDesktop;            16        8(A_PtrSize)
		  ;LPTSTR lpTitle;              24        8(A_PtrSize)
		  ;DWORD  dwX;                  32        4
		  ;DWORD  dwY;                  36        4
		  ;DWORD  dwXSize;              40        4
		  ;DWORD  dwYSize;              44        4
		  ;DWORD  dwXCountChars;        48        4
		  ;DWORD  dwYCountChars;        52        4
		  ;DWORD  dwFillAttribute;      56        4
		  ;DWORD  dwFlags;              60        4
		  ;WORD   wShowWindow;          64        2
		  ;WORD   cbReserved2;          66        2
		  ;LPBYTE lpReserved2;          72        8(A_PtrSize)           aligned to 8-byte boundary (2 + 4)
		  ;HANDLE hStdInput;            80        8(A_PtrSize)
		  ;HANDLE hStdOutput;           88        8(A_PtrSize)
		  ;HANDLE hStdError;            96        8(A_PtrSize)
		  ;
		  ;ALL : 96+8=104=8*13
		  ;
		  ; PROCESS_INFORMATION
		  ;
		  ;HANDLE hProcess              0         8(A_PtrSize)
		  ;HANDLE hThread               8         8(A_PtrSize)
		  ;DWORD  dwProcessId           16        4
		  ;DWORD  dwThreadId            20        4
		  ;
		  ;ALL : 20+4=24=8*3
		  ;============================================================================
		  ; x86
		  ; STARTUPINFO
		  ;                             offset     size
		  ;DWORD  cb;                   0          4
		  ;LPTSTR lpReserved;           4          4(A_PtrSize)
		  ;LPTSTR lpDesktop;            8          4(A_PtrSize)
		  ;LPTSTR lpTitle;              12         4(A_PtrSize)
		  ;DWORD  dwX;                  16         4
		  ;DWORD  dwY;                  20         4
		  ;DWORD  dwXSize;              24         4
		  ;DWORD  dwYSize;              28         4
		  ;DWORD  dwXCountChars;        32         4
		  ;DWORD  dwYCountChars;        36         4
		  ;DWORD  dwFillAttribute;      40         4
		  ;DWORD  dwFlags;              44         4
		  ;WORD   wShowWindow;          48         2
		  ;WORD   cbReserved2;          50         2
		  ;LPBYTE lpReserved2;          52         4(A_PtrSize)
		  ;HANDLE hStdInput;            56         4(A_PtrSize)
		  ;HANDLE hStdOutput;           60         4(A_PtrSize)
		  ;HANDLE hStdError;            64         4(A_PtrSize)
		  ;
		  ;ALL : 64+4=68=4*17
		  ;
		  ; PROCESS_INFORMATION
		  ;
		  ;HANDLE hProcess              0         4(A_PtrSize)
		  ;HANDLE hThread               4         4(A_PtrSize)
		  ;DWORD  dwProcessId           8         4
		  ;DWORD  dwThreadId            12        4
		  ;
		  ;ALL : 12+4=16=4*4

	*/

  If ! DllCall( "CreateProcess", UInt,0, UInt,&sCmd, UInt,0, UInt,0 ;  http://goo.gl/USC5a
              , UInt,1, UInt,0x08000000, UInt,0, tcWrk, WorkingDir
              , UInt,&STARTUPINFO, UInt,&PROCESS_INFORMATION )
   {
    DllCall( "CloseHandle", UInt,hPipeWrite )
    DllCall( "CloseHandle", UInt,hPipeRead )
    DllCall( "SetLastError", Int,-1 )
    Return ""
   }

  hProcess := NumGet( PROCESS_INFORMATION, 0 )
  hThread  := NumGet( PROCESS_INFORMATION, A_PtrSize )
  ProcessID:= NumGet( PROCESS_INFORMATION, A_PtrSize*2 )

  DllCall( "CloseHandle", UInt,hPipeWrite )

  AIC := ( SubStr( A_AhkVersion, 1, 3 ) = "1.0" ) ;  A_IsClassic
  VarSetCapacity( Buffer, 4096, 0 ), nSz := 0

  While DllCall( "ReadFile", UInt,hPipeRead, UInt,&Buffer, UInt,4094, UIntP,nSz, Int,0 ) {

   tOutput := ( AIC && NumPut( 0, Buffer, nSz, "Char" ) && VarSetCapacity( Buffer,-1 ) )
              ? Buffer : %StrGet%( &Buffer, nSz, "CP0" ) ; formerly CP850, but I guess CP0 is suitable for different locales

   Isfunc( Callback ) ? %Callback%( tOutput, A_Index ) : sOutput .= tOutput

  }

  DllCall( "GetExitCodeProcess", UInt,hProcess, UIntP,ExitCode )
  DllCall( "CloseHandle",  UInt,hProcess  )
  DllCall( "CloseHandle",  UInt,hThread   )
  DllCall( "CloseHandle",  UInt,hPipeRead )
  DllCall( "SetLastError", UInt,ExitCode  )
  VarSetCapacity(STARTUPINFO, 0)
  VarSetCapacity(PROCESS_INFORMATION, 0)

Return Isfunc( Callback ) ? %Callback%( "", 0 ) : sOutput
}

{ ;Parameter examples 

/*				DESCRIPTION FOR UTF-8 support of xpftotext.exe

https://autohotkey.com/boards/viewtopic.php?f=5&t=25004&hilit=embedded+pdf

I haven't studied your whole script, but I see that you have a variable called XpdfPath that is assigned the value pdftotext.exe in A_ScriptDir. That's a good approach (although I'd call the var XpdfEXE). Extend the idea as follows:

(1) Define another variable called xpdfrcFile in the same folder and assign it the value xpdfrc.ini.

(2) Create a plain text file called xpdfrc.ini with these lines in it:

Code: [Alles auswählen] [Download] GeSHi © Codebox Plus

unicodeMap Latin1fixed "D:\path\Latin1.unicodeMap"
textEncoding Latin1fixed

where D:\path\ is the script folder. Of course, you may put xpdfrc.ini (and Latin1.unicodeMap) wherever you want, but I think the script folder is fine. My scripts always create xpdfrc.ini via FileAppend so I have programmatic control over its location and contents, but if you want to keep things simple, hard-code it.

(3) Put the Latin1.unicodeMap file in the proper place, i.e., D:\path\, as discussed above.

(4) Call PDFtoText with this additional param:

-cfg "%xpdfrcFile%"

That should do it. Works perfectly here in many scripts. Here's an actual call from one of my working scripts:

*/
xpdftotext.exe
RunWait,%PDFtoTextEXE% -f 1 -l 1 %ConversionType% -cfg "%xpdfrcFile%" "%SourceFolder%%FileNameCurrent%" "%DestFolder%%FileNameCurrentTXT%",,Hide

}

} 
;|														|                                                       |														|														|
;|	CMDret_RunReturn()					|	ConsoleSend()								|	StdOutStream()							|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;Date or Time functions (5)
;1
PrettyTickCount(timeInMilliSeconds) { 																	;-- takes a time in milliseconds and displays it in a readable fashion
   ElapsedHours := SubStr(0 Floor(timeInMilliSeconds / 3600000), -1)
   ElapsedMinutes := SubStr(0 Floor((timeInMilliSeconds - ElapsedHours * 3600000) / 60000), -1)
   ElapsedSeconds := SubStr(0 Floor((timeInMilliSeconds - ElapsedHours * 3600000 - ElapsedMinutes * 60000) / 1000), -1)
   ElapsedMilliseconds := SubStr(0 timeInMilliSeconds - ElapsedHours * 3600000 - ElapsedMinutes * 60000 - ElapsedSeconds * 1000, -2)
   returned := ElapsedHours "h:" ElapsedMinutes "m:" ElapsedSeconds "s." ElapsedMilliseconds
   return returned
}
;2
TimePlus(one, two) {																								;--

   returned:=0
   returned+=Mod(one, 100) + Mod(two, 100)
   ;one/=100
   ;two/=100
   returned+=one
   return returned
}
;3
FormatSeconds(Secs) {																							;-- formats seconds to hours,minutes and seconds -> 12:36:10

	Return SubStr("0" . Secs // 3600, -1) . ":"
        . SubStr("0" . Mod(Secs, 3600) // 60, -1) . ":"
        . SubStr("0" . Mod(Secs, 60), -1)

}
;4
TimeCode(MaT) {																										;-- TimCode can be used for protokoll or error logs

	;Month & Time (MaT) = 1 - it's clear!

	If MaT = 1
		TC:= A_DD "." A_MM "." A_YYYY "`, "

	TC.= A_Hour ":" A_Min ":" A_Sec "`." A_MSec

return TC
}
;5
Time(to,from="",units="d",params="") {											;-- calculate with time, add minutes, hours, days - add or subtract time
	
	/*                              	DESCRIPTION
				Link: https://autohotkey.com/board/topic/42668-time-count-days-hours-minutes-seconds-between-dates/
	*/
	/*                              	EXAMPLE(s)
	
			NoEnv
			SetBatchLines,-1
			MsgBox % "Count days from 12 May until 15 May`n"
					. Time("May-15","12.May","d")
			
			MsgBox % "Working hours from 01.05.2009 00:00:00   to   10.05.09 09:30:00`n"
					. "Count only working hours from 09 to 17 and consider weekends and 01.May bank holiday`n"
					. Time("20090504093000","20090501000000","h","W1.7 H9-17 B0105")
			
			MsgBox % "Days to work till end of 2009`n" . Time("01.01.2010","","d","W1.7")
			
			MsgBox % "Hours to work till end of 2009 from 09 - 17`n" . Time("01.01.2010","","h","W1.7 H9-17")
			
			ExitApp
			
	*/
		
	static _:="0000000000",s:=1,m:=60,h:=3600,d:=86400
				,Jan:="01",Feb:="02",Mar:="03",Apr:="04",May:="05",Jun:="06",Jul:="07",Aug:="08",Sep:="09",Okt:=10,Nov:=11,Dec:=12
	r:=0
	units:=units ? %units% : 8640
	If (InStr(to,"/") or InStr(to,"-") or InStr(to,".")){
		Loop,Parse,to,/-.,%A_Space%
			_%A_Index%:=RegExMatch(A_LoopField,"\d+") ? A_LoopField : %A_LoopField%
			,_%A_Index%:=(StrLen(_%A_Index%)=1 ? "0" : "") . _%A_Index%
		to:=SubStr(A_Now,1,8-StrLen(_1 . _2 . _3)) . _3 . (RegExMatch(SubStr(to,1,1),"\d") ? (_2 . _1) : (_1 . _2))
		_1:="",_2:="",_3:=""
	}
	If (from and InStr(from,"/") or InStr(from,"-") or InStr(from,".")){
		Loop,Parse,from,/-.,%A_Space%
			_%A_Index%:=RegExMatch(A_LoopField,"\d+") ? A_LoopField : %A_LoopField%
			,_%A_Index%:=(StrLen(_%A_Index%)=1 ? "0" : "") . _%A_Index%
		from:=SubStr(A_Now,1,8-StrLen(_1 . _2 . _3)) . _3 . (RegExMatch(SubStr(from,1,1),"\d") ? (_2 . _1) : (_1 . _2))
	}
   count:=StrLen(to)<9 ? "days" : StrLen(to)<11 ? "hours" : StrLen(to)<13 ? "minutes" : "seconds"
	to.=SubStr(_,1,14-StrLen(to)),(from ? from.=SubStr(_,1,14-StrLen(from)))
	Loop,Parse,params,%A_Space%
		If (unit:=SubStr(A_LoopField,1,1))
			 %unit%1:=InStr(A_LoopField,"-") ? SubStr(A_LoopField,2,InStr(A_LoopField,"-")-2) : ""
			,%unit%2:=SubStr(A_LoopField,InStr(A_LoopField,"-") ? (InStr(A_LoopField,"-")+1) : 2)
	count:=!params ? count : "seconds"
	add:=!params ? 1 : (S2="" ? (M2="" ? (H2="" ? ((D2="" and B2="" and W="") ? d : h) : m) : s) : s)
	While % (from<to){
		FormatTime,year,%from%,YYYY
		FormatTime,month,%from%,MM
		FormatTime,day,%from%,dd
		FormatTime,hour,%from%,H
		FormatTime,minute,%from%,m
		FormatTime,second,%from%,s
		FormatTime,WDay,%from%,WDay
		EnvAdd,from,%add%,%count%
		If (W1 or W2){
			If (W1=""){
				If (W2=WDay or InStr(W2,"." . WDay) or InStr(W2,WDay . ".")){
					Continue=1
				}
			} else If WDay not Between %W1% and %W2%
				Continue=1
			;else if (Wday=W2)
			;	Continue=1
			If (Continue){
				tempvar:=SubStr(from,1,8)
				EnvAdd,tempvar,1,days
				EnvSub,tempvar,%from%,seconds
				EnvAdd,from,%tempvar% ,seconds
				Continue=
				continue
			}
		}
		If (D1 or D2 or B2){
			If (D1=""){
				If (D2=day or B2=(day . month) or InStr(B2,"." . day . month) or InStr(B2,day . month . ".") or InStr(D2,"." . day) or InStr(D2,day . ".")){
					Continue=1
				}
			} else If day not Between %D1% and %D2%
				Continue=1
			;else if (day=D2)
			;	Continue=1
			If (Continue){
				tempvar:=SubStr(from,1,8)
				EnvAdd,tempvar,1,days
				EnvSub,tempvar,%from%,seconds
				EnvAdd,from,%tempvar% ,seconds
				Continue=
				continue
			}
		}
		If (H1 or H2){
			If (H1=""){
				If (H2=hour or InStr(H2,hour . ".") or InStr(H2,"." hour)){
					Continue=1
				}
			} else If hour not Between %H1% and %H2%
				continue=1
			;else if (hour=H2)
			;	continue=1
			If (continue){
				tempvar:=SubStr(from,1,10)
				EnvAdd,tempvar,1,hours
				EnvSub,tempvar,%from%,seconds
				EnvAdd,from,%tempvar% ,seconds
				continue=
				continue
			}
		}
		If (M1 or M2){
			If (M1=""){
				If (M2=minute or InStr(M2,minute . ".") or InStr(M2,"." minute)){
					Continue=1
				}
			} else If minute not Between %M1% and %M2%
				continue=1
			;else if (minute=M2)
			;	continue=1
			If (continue){
				tempvar:=SubStr(from,1,12)
				EnvAdd,tempvar,1,minutes
				EnvSub,tempvar,%from%,seconds
				EnvAdd,from,%tempvar% ,seconds
				continue=
				continue
			}
		}
		If (S1 or S2){
			If (S1=""){
				If (S2=second or InStr(S2,second . ".") or InStr(S2,"." second)){
					Continue
				}
			} else if (second!=S2)
				If second not Between %S1% and %S2%
					continue
		}
		r+=add
	}
	tempvar:=SubStr(count,1,1)
	tempvar:=%tempvar%
	Return (r*tempvar)/units
}

} 
;|														|														|														|														|
;|	PrettyTickCount()							|	TimePlus()									|	FormatSeconds()							|	TimeCode()									|
;|   Time()                                       	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;Get - functions for retreaving informations - missing something - see Gui/Window - retreaving ... (18)

GetProcesses() {																									;-- get the name of all running processes

   d = `n  ; string separator
   s := 4096  ; size of buffers and arrays (4 KB)

   Process, Exist  ; sets ErrorLevel to the PID of this running script
   ; Get the handle of this script with PROCESS_QUERY_INFORMATION (0x0400)
   h := DllCall("OpenProcess", "UInt", 0x0400, "Int", false, "UInt", ErrorLevel)
   ; Open an adjustable access token with this process (TOKEN_ADJUST_PRIVILEGES = 32)
   DllCall("Advapi32.dll\OpenProcessToken", "UInt", h, "UInt", 32, "UIntP", t)
   VarSetCapacity(ti, 16, 0)  ; structure of privileges
   NumPut(1, ti, 0)  ; one entry in the privileges array...
   ; Retrieves the locally unique identifier of the debug privilege:
   DllCall("Advapi32.dll\LookupPrivilegeValueA", "UInt", 0, "Str", "SeDebugPrivilege", "Int64P", luid)
   NumPut(luid, ti, 4, "int64")
   NumPut(2, ti, 12)  ; enable this privilege: SE_PRIVILEGE_ENABLED = 2
   ; Update the privileges of this process with the new access token:
   DllCall("Advapi32.dll\AdjustTokenPrivileges", "UInt", t, "Int", false, "UInt", &ti, "UInt", 0, "UInt", 0, "UInt", 0)
   DllCall("CloseHandle", "UInt", h)  ; close this process handle to save memory

   hModule := DllCall("LoadLibrary", "Str", "Psapi.dll")  ; increase performance by preloading the libaray
   s := VarSetCapacity(a, s)  ; an array that receives the list of process identifiers:
   c := 0  ; counter for process idendifiers
   DllCall("Psapi.dll\EnumProcesses", "UInt", &a, "UInt", s, "UIntP", r)
   Loop, % r // 4  ; parse array for identifiers as DWORDs (32 bits):
   {
      id := NumGet(a, A_Index * 4)
      ; Open process with: PROCESS_VM_READ (0x0010) | PROCESS_QUERY_INFORMATION (0x0400)
      h := DllCall("OpenProcess", "UInt", 0x0010 | 0x0400, "Int", false, "UInt", id)
      VarSetCapacity(n, s, 0)  ; a buffer that receives the base name of the module:
      e := DllCall("Psapi.dll\GetModuleBaseNameA", "UInt", h, "UInt", 0, "Str", n, "UInt", s)
      DllCall("CloseHandle", "UInt", h)  ; close process handle to save memory
      if (n && e)  ; if image is not null add to list:
         l .= n . d, c++
   }
   DllCall("FreeLibrary", "UInt", hModule)  ; unload the library to free memory
   Sort, l, C  ; uncomment this line to sort the list alphabetically
   ;MsgBox, 0, %c% Processes, %l%
   return l
}

getProcesses(ignoreSelf := True, searchNames := "") { 										;-- get running processes with search using comma separated list

	s := 100096  ; 100 KB will surely be HEAPS

	array := []
	PID := DllCall("GetCurrentProcessId")
	; Get the handle of this script with PROCESS_QUERY_INFORMATION (0x0400)
	h := DllCall("OpenProcess", "UInt", 0x0400, "Int", false, "UInt", PID, "Ptr")
	; Open an adjustable access token with this process (TOKEN_ADJUST_PRIVILEGES = 32)
	DllCall("Advapi32.dll\OpenProcessToken", "Ptr", h, "UInt", 32, "PtrP", t)
	VarSetCapacity(ti, 16, 0)  ; structure of privileges
	NumPut(1, ti, 0, "UInt")  ; one entry in the privileges array...
	; Retrieves the locally unique identifier of the debug privilege:
	DllCall("Advapi32.dll\LookupPrivilegeValue", "Ptr", 0, "Str", "SeDebugPrivilege", "Int64P", luid)
	NumPut(luid, ti, 4, "Int64")
	NumPut(2, ti, 12, "UInt")  ; enable this privilege: SE_PRIVILEGE_ENABLED = 2
	; Update the privileges of this process with the new access token:
	r := DllCall("Advapi32.dll\AdjustTokenPrivileges", "Ptr", t, "Int", false, "Ptr", &ti, "UInt", 0, "Ptr", 0, "Ptr", 0)
	DllCall("CloseHandle", "Ptr", t)  ; close this access token handle to save memory
	DllCall("CloseHandle", "Ptr", h)  ; close this process handle to save memory

	hModule := DllCall("LoadLibrary", "Str", "Psapi.dll")  ; increase performance by preloading the library
	s := VarSetCapacity(a, s)  ; an array that receives the list of process identifiers:
	DllCall("Psapi.dll\EnumProcesses", "Ptr", &a, "UInt", s, "UIntP", r)
	Loop, % r // 4  ; parse array for identifiers as DWORDs (32 bits):
	{
	   currentPID := NumGet(a, A_Index * 4, "UInt")
	   if (ignoreSelf && currentPID = PID)
			continue ; this is own script
	   ; Open process with: PROCESS_VM_READ (0x0010) | PROCESS_QUERY_INFORMATION (0x0400)
	   h := DllCall("OpenProcess", "UInt", 0x0010 | 0x0400, "Int", false, "UInt", currentPID, "Ptr")
	   if !h
	      continue
	   VarSetCapacity(n, s, 0)  ; a buffer that receives the base name of the module:
	   e := DllCall("Psapi.dll\GetModuleBaseName", "Ptr", h, "Ptr", 0, "Str", n, "UInt", A_IsUnicode ? s//2 : s)
	   if !e    ; fall-back method for 64-bit processes when in 32-bit mode:
	      if e := DllCall("Psapi.dll\GetProcessImageFileName", "Ptr", h, "Str", n, "UInt", A_IsUnicode ? s//2 : s)
	         SplitPath n, n
	   DllCall("CloseHandle", "Ptr", h)  ; close process handle to save memory
	  	if searchNames
	  	{
			  if n not in %searchNames%
			  	continue
	  	}
	   if (n && e)  ; if image is not null add to list:
	   		array.insert({"Name": n, "PID": currentPID})
	}
	DllCall("FreeLibrary", "Ptr", hModule)  ; unload the library to free memory
	return array
}

GetProcessWorkingDir(PID) {																				;-- like the name explains

	static PROCESS_ALL_ACCESS:=0x1F0FFF,MEM_COMMIT := 0x1000,MEM_RELEASE:=0x8000,PAGE_EXECUTE_READWRITE:=64
		,GetCurrentDirectoryW,init:=MCode(GetCurrentDirectoryW,"8BFF558BECFF75088B450803C050FF15A810807CD1E85DC20800")
	nDirLength := VarSetCapacity(nDir, 512, 0)
	hProcess := DllCall("OpenProcess", "UInt", PROCESS_ALL_ACCESS, "Int",0, "UInt", PID)
	if !hProcess
	return
	pBufferRemote := DllCall("VirtualAllocEx", "Ptr", hProcess, "Ptr", 0, "PTR", nDirLength + 1, "UInt", MEM_COMMIT, "UInt", PAGE_EXECUTE_READWRITE, "Ptr")

	pThreadRemote := DllCall("VirtualAllocEx", "Ptr", hProcess, "Ptr", 0, "PTR", 26, "UInt", MEM_COMMIT, "UInt", PAGE_EXECUTE_READWRITE, "Ptr")
	DllCall("WriteProcessMemory", "Ptr", hProcess, "Ptr", pThreadRemote, "Ptr", &GetCurrentDirectoryW, "PTR", 26, "Ptr", 0)

	If hThread := DllCall("CreateRemoteThread", "PTR", hProcess, "UInt", 0, "UInt", 0, "PTR", pThreadRemote, "PTR", pBufferRemote, "UInt", 0, "UInt", 0)
	{
	DllCall("WaitForSingleObject", "PTR", hThread, "UInt", 0xFFFFFFFF)
	DllCall("GetExitCodeThread", "PTR", hThread, "UIntP", lpExitCode)
	If lpExitCode {
		DllCall("ReadProcessMemory", "PTR", hProcess, "PTR", pBufferRemote, "Str", nDir, "UInt", lpExitCode*2, "UInt", 0)
		VarSetCapacity(nDir,-1)
	}
	DllCall("CloseHandle", "PTR", hThread)
	}
	DllCall("VirtualFreeEx","PTR",hProcess,"PTR",pBufferRemote,"PTR",nDirLength + 1,"UInt",MEM_RELEASE)
	DllCall("VirtualFreeEx","PTR",hProcess,"PTR",pThreadRemote,"PTR",31,"UInt",MEM_RELEASE)
	DllCall("CloseHandle", "PTR", hProcess)

	return nDir

}

GetTextSize(pStr, pSize, pFont, pWeight = 400, pHeight = false) {						;-- precalcute the Textsize (Width & Height)

  Gui, 55: Font, s%pSize% w%pWeight%, %pFont%
  Gui, 55: Add, Text, R1, %pStr%
  GuiControlGet T, 55: Pos, Static1
  Gui, 55: Destroy
  Return pHeight ? TW "," TH : TW

}

GetTextSize(pStr, pFont="", pHeight=false, pAdd=0) {										;-- different function to the above one
	
	/*			DESCRIPTION
	;-----------------------------------------------------------------------------------------------------------------------
	; Function: GetTextSize
	; Calculate widht and/or height of text.
	; Font face, style and number of lines is taken into account
	;:
	; <By.majkinetor> https://autohotkey.com/board/topic/16625-function-gettextsize-calculate-text-dimension/
	;
	; Parameters:
	;		pStr	- Text to be measured
	;		pFont	- Font description in AHK syntax, default size is 10, default font is MS Sans Serif
	;		pHeight	- Set to true to return height also. False is default.
	;		pAdd	- Number to add on width and height.
	;
	; Returns:
	;		Text width if pHeight=false. Otherwise, dimension is returned as "width,height"
	;
	; Dependencies:
	;		<ExtractInteger>
	;		
	; Examples:
	;		width := GetTextSize("string to be measured", "bold s22, Courier New" )
	;	
	*/
	
	
	local height, weight, italic, underline, strikeout , nCharSet
	local hdc := DllCall("GetDC", "Uint", 0)
	local hFont, hOldFont
	local resW, resH, SIZE

 ;parse font
	italic		:= InStr(pFont, "italic")	 ?  1	:  0
	underline	:= InStr(pFont, "underline") ?  1	:  0
	strikeout	:= InStr(pFont, "strikeout") ?  1	:  0
	weight		:= InStr(pFont, "bold")		 ? 700	: 400

	;height
	RegExMatch(pFont, "(?<=[S|s])(\d{1,2})(?=[ ,])", height)
	if (height = "")
		height := 10


	RegRead, LogPixels, HKEY_LOCAL_MACHINE, SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontDPI, LogPixels 
	Height := -DllCall("MulDiv", "int", Height, "int", LogPixels, "int", 72)
	;face
	RegExMatch(pFont, "(?<=,).+", fontFace)	
	if (fontFace != "")
		 fontFace := RegExReplace( fontFace, "(^\s*)|(\s*$)")		;trim 
	else fontFace := "MS Sans Serif"

 ;create font
	hFont	:= DllCall("CreateFont", "int",  height,	"int",  0,		  "int",  0, "int", 0
									,"int",  weight,	"Uint", italic,   "Uint", underline
									,"uint", strikeOut, "Uint", nCharSet, "Uint", 0, "Uint", 0, "Uint", 0, "Uint", 0, "str", fontFace) 
	hOldFont := DllCall("SelectObject", "Uint", hDC, "Uint", hFont) 										

	VarSetCapacity(SIZE, 16)
	curW=0
	Loop,  parse, pStr, `n
	{
		DllCall("DrawTextA", "Uint", hDC, "str", A_LoopField, "int", StrLen(pStr), "uint", &SIZE, "uint", 0x400) 
		resW := ExtractInteger(SIZE, 8)
		curW := resW > curW ? resW : curW
	}
	DllCall("DrawTextA", "Uint", hDC, "str", pStr, "int", StrLen(pStr), "uint", &SIZE, "uint", 0x400) 
 ;clean	
	
	DllCall("SelectObject", "Uint", hDC, "Uint", hOldFont) 
	DllCall("DeleteObject", "Uint", hFont) 
	DllCall("ReleaseDC", "Uint", 0, "Uint", hDC) 

	resW := ExtractInteger(SIZE, 8) + pAdd
  	resH := ExtractInteger(SIZE, 12) + pAdd


	if (pHeight)
		resW = W%resW% H%resH%

	return	%resW%
}

MeasureText(hwnd,text,Font,size, layout) {                                                     	;-- alternative to other functions which calculate the text size before display on the screen
    
	; functionstatus: tested, working
	; http://ahkscript.org/germans/forums/viewtopic.php?t=6726&sid=a0d79e1c0831c7bae622912df2b1df9d
	
	/*			EXAMPLE
		MsgBox % MeasureText(0,"Hello world","Consolas",14, "italic") 
	*/
	
   If !pToken := Gdip_Startup() 
   { 
   MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system 
   ExitApp 
   } 
    
   HDC := GetDC(hwnd) 
   G := Gdip_GraphicsFromHDC(hdc) 

   If !hFamily := Gdip_FontFamilyCreate(Font) 
   { 
      MsgBox, 48, Font error!, The font you have specified does not exist on the system 
      ExitApp 
   } 

   hFont := Gdip_FontCreate(hFamily, size, layout) 
   hFormat := Gdip_StringFormatCreate(0x4000) 
    
   CreateRectF(RectF, 0, 0, 0, 0) 
   RECTF_STR := Gdip_MeasureString(G, text, hFont, hFormat, RectF) 
   StringSplit,RCI,RECTF_STR, | 
   Width := RCI3 
    
   Gdip_DeleteFont(hFont),Gdip_DeleteStringFormat(hFormat) 
   DeleteDC(hdc), Gdip_DeleteGraphics(G) 
    
   Gdip_Shutdown(pToken) 
   Return, Width 
} 

monitorInfo() {																										;-- shows infos about your monitors
	sysget,monitorCount,monitorCount
	arr:=[],sorted:=[]
	loop % monitorCount {
		sysget,mon,monitor,% a_index
		arr.insert({l:monLeft,r:monRight,b:monBottom,t:monTop,w:monRight-monLeft+1,h:monBottom-monTop+1})
		k:=a_index
		while strlen(k)<3
			k:="0" k
		sorted[monLeft k]:=a_index
	}
	arr2:=[]
	for k,v in sorted
		arr2.insert(arr[v])
	return arr2
}

whichMonitor(x="",y="",byref monitorInfo="") { 												;-- return [current monitor, monitor count]
	CoordMode,mouse,screen
	if (x="" || y="")
		mousegetpos,x,y
	if !IsObject(monitorInfo)
		monitorInfo:=monitorInfo()

	for k,v in monitorInfo
		if (x>=v.l&&x<=v.r&&y>=v.t&&y<=v.b)
			return [k,monitorInfo.maxIndex()]
}

IsOfficeFile(FileName, Extensions = "doc,docx,xls,xlsx,ppt,pptx") { 					;-- checks if a file is an Office file

	;  Last update: 2014-4-23

	static doc  := "57006f007200640044006f00630075006d0065006e0074"                                 ; W.o.r.d.D.o.c.u.m.e.n.t
	,      docx := "00776F72642F"                                                                   ; .word/
	,      xls  := "0057006f0072006b0062006f006f006b00"                                             ; .W.o.r.k.b.o.o.k.
	,      xlsx := "0000786C2F"                                                                     ; ..xl/
	,      ppt  := "0050006f0077006500720050006f0069006e007400200044006f00630075006d0065006e007400" ; .P.o.w.e.r.P.o.i.n.t. .D.o.c.u.m.e.n.t.
	,      pptx := "00007070742F"                                                                   ; ..ppt/

	; =======================================
	; Check first 4 bytes
	; =======================================
	File := FileOpen(FileName, "r")
	File.RawRead(bin, 4)
	MCode_Bin2Hex(&bin, 4, hex)

	; Magic Numbers (http://en.wikipedia.org/wiki/List_of_file_signatures)
	;   doc/xls/ppt: D0CF11E0
	;   zip/jar/odt/ods/odp/docx/xlsx/pptx/apk: 504B0304, 504B0506 (empty archive) or 504B0708 (spanned archive)
	If hex not in D0CF11E0,504B0304,504B0506,504B0708
		Return "", File.Close()

	; =======================================
	; docx/xlsx/pptx --> check last 1024 bytes
	; =======================================
	If hex in 504B0304,504B0506,504B0708
	{
		File.Position := File.Length - 1024
		File.RawRead(bin, 1024)
		File.Close()
		MCode_Bin2Hex(&bin, 1024, hex)

		Loop, Parse, Extensions, CSV, %A_Space%%A_Tab%
			If (  InStr(hex, %A_LoopField%)  )
				Return A_LoopField

		Return
	}

	; =======================================
	; detect doc/xls/ppt
	; Reference: Daniel Rentz. Microsoft Compound Document File Format. 2006-Dec - 21.
	; =======================================
	; SecID of first sector of the directory stream
	File.Position := 48
	File.RawRead(bin, 4)
	MCode_Bin2Hex(&bin, 4, hex)
	SecID1 := "0x" SubStr(hex, 7, 2) SubStr(hex, 5, 2) SubStr(hex, 3, 2) SubStr(hex, 1, 2)
	SecID1 := SecID1 + 0

	; Jump to this offset...
	Offset := 512 * (SecID1 + 1)
	Length := 5 * 128

	File.Position := Offset
	File.RawRead(bin, Length)
	MCode_Bin2Hex(&bin, Length, hex)

	File.Close()

	; detecting...
	Loop, Parse, Extensions, CSV, %A_Space%%A_Tab%
		If (  InStr(hex, %A_LoopField%)  )
			Return A_LoopField
}

DeskIcons(coords="") {																						;-- i think its for showing all desktop icons

   Critical
   static MEM_COMMIT := 0x1000, PAGE_READWRITE := 0x04, MEM_RELEASE := 0x8000
   static LVM_GETITEMPOSITION := 0x00001010, LVM_SETITEMPOSITION := 0x0000100F, WM_SETREDRAW := 0x000B

   ControlGet, hwWindow, HWND,, SysListView321, ahk_class Progman
   if !hwWindow ; #D mode
      ControlGet, hwWindow, HWND,, SysListView321, A
   IfWinExist ahk_id %hwWindow% ; last-found window set
      WinGet, iProcessID, PID
   hProcess := DllCall("OpenProcess"   , "UInt",   0x438 ; PROCESS-OPERATION|READ|WRITE|QUERY_INFORMATION
                              , "Int",   FALSE         ; inherit = false
                              , "UInt",   iProcessID)
   if hwWindow and hProcess
   {
      ControlGet, list, list,Col1
      if !coords
      {
         VarSetCapacity(iCoord, 8)
         pItemCoord := DllCall("VirtualAllocEx", "UInt", hProcess, "UInt", 0, "UInt", 8, "UInt", MEM_COMMIT, "UInt", PAGE_READWRITE)
         Loop, Parse, list, `n
         {
            SendMessage, %LVM_GETITEMPOSITION%, % A_Index-1, %pItemCoord%
            DllCall("ReadProcessMemory", "UInt", hProcess, "UInt", pItemCoord, "UInt", &iCoord, "UInt", 8, "UIntP", cbReadWritten)
            ret .= A_LoopField ":" (NumGet(iCoord) & 0xFFFF) | ((Numget(iCoord, 4) & 0xFFFF) << 16) "`n"
         }
         DllCall("VirtualFreeEx", "UInt", hProcess, "UInt", pItemCoord, "UInt", 0, "UInt", MEM_RELEASE)
      }
      else
      {
         SendMessage, %WM_SETREDRAW%,0,0
         Loop, Parse, list, `n
            If RegExMatch(coords,"\Q" A_LoopField "\E:\K.*",iCoord_new)
               SendMessage, %LVM_SETITEMPOSITION%, % A_Index-1, %iCoord_new%
         SendMessage, %WM_SETREDRAW%,1,0
         ret := true
      }
   }
   DllCall("CloseHandle", "UInt", hProcess)
   return ret
}

GetFuncDefs(scriptPath) {                                                                                	;-- get function definitions from a script

	; does not include those with a definition of "()" (no parameters)
	; this is part of  "Insert User Function Definitions -- for Notepad++" from boiler, maybe you need a different output 
	;https://autohotkey.com/boards/viewtopic.php?f=60&t=29996
	defs := ""
	FileRead, rawScript, %scriptPath%
	
	; remove comment blocks:
	cleanScript := "`n" ; start with `n so RegEx can know a func def is preceded by one even if first line
	blockStart := 0
	Loop, Parse, rawScript, `n, `r
	{
		if blockStart
		{
			if (SubStr(LTrim(A_LoopField), 1, 2) = "*/")
				blockStart := 0
		}
		else
		{
			if (SubStr(LTrim(A_LoopField), 1, 2) = "/*")
				blockStart := 1
			else
				cleanScript .= A_LoopField "`n"
		}
	}
	
	; get function definitions:
	startPos := 1
	Loop
	{
		; original: if (foundPos := RegExMatch(cleanScript, "\n\s*\K[\w#@$]+\([^\n;]+\)(?=\s*(;[^n]*)*\n*{)", match, startPos))
		if (foundPos := RegExMatch(cleanScript, "U)\n\s*\K[ \t]*(?!(if\(|while\(|for\())([\w#!^+&<>*~$])+\d*\([^)]+\)([\s]|(/\*.*?\*)/|((?<=[\s]);[^\r\n]*?$))*?[\s]*\n*(?=\{)", match, startPos))
		{
			defs .= Trim(RegExReplace(match, "\s*\n\s*$")) " {`n"
			startPos := InStr(cleanScript, "`n",, foundPos) ; start at next line
		}
	} until !foundPos
	
	return defs
}

IndexOfIconResource(Filename, ID) {                                                              	;-- function is used to convert an icon resource id (as those used in the registry) to icon index(as used by ahk)
	
	;By Lexikos http://www.autohotkey.com/community/viewtopic.php?p=168951
    hmod := DllCall("GetModuleHandle", "str", Filename, "PTR")
    ; If the DLL isn't already loaded, load it as a data file.
    loaded := !hmod
        && hmod := DllCall("LoadLibraryEx", "str", Filename, "PTR", 0, "uint", 0x2)
    
    enumproc := RegisterCallback("IndexOfIconResource_EnumIconResources","F")
    VarSetCapacity(param,12,0)
    NumPut(ID,param,0)
    ; Enumerate the icon group resources. (RT_GROUP_ICON=14)
    DllCall("EnumResourceNames", "uint", hmod, "uint", 14, "uint", enumproc, "PTR", &param)
    DllCall("GlobalFree", "PTR", enumproc)
    
    ; If we loaded the DLL, free it now.
    if loaded
        DllCall("FreeLibrary", "PTR", hmod)
    
    return NumGet(param,8) ? NumGet(param,4) : 0
}
;{ sub for IndexOfIconResource()
IndexOfIconResource_EnumIconResources(hModule, lpszType, lpszName, lParam) {
	
	;By Lexikos http://www.autohotkey.com/community/viewtopic.php?p=168951
    NumPut(NumGet(lParam+4)+1, lParam+4)

    if (lpszName = NumGet(lParam+0))
    {
        NumPut(1, lParam+8)
        return false    ; break
    }
    return true
}
;}

GetIconforext(ext) {                                                                                         	;-- Gets default registered icon for an extension
	
	; source: https://github.com/aviaryan/autohotkey-scripts/blob/master/Functions/Miscellaneous-Functions.ahk
	; dependings: none
	
	/*			DESCRIPTION
		Gets default registered icon for an extension
		Eg - GetIconforext(".ahk")
		Note - The icon path is not returned in pure-form but of the form     <path>, <icon index>
	*/
	
    RegRead, ThisExtClass, HKEY_CLASSES_ROOT, %ext%
    RegRead, DefaultIcon, HKEY_CLASSES_ROOT, %ThisExtClass%\DefaultIcon
	IfEqual, Defaulticon
	{
		Regread, Application, HKEY_CURRENT_USER, Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\%ext%\UserChoice, Progid
		IfNotEqual, Application
			Regread, DefaultIcon, HKCR, %Application%\DefaultIcon
	}
    Return DefaultIcon
}

GetImageType(PID) {																							;-- returns whether a process is 32bit or 64bit

	; PROCESS_QUERY_INFORMATION
    hProc := DllCall("OpenProcess", "UInt", 0x400, "Int", False, "UInt", PID, "Ptr")
    If (!hProc) {
        Return "N/A"
    }

    If (A_Is64bitOS) {
        ; Determines whether the specified process is running under WOW64.
        Try DllCall("IsWow64Process", "Ptr", hProc, "Int*", Is32Bit := True)
    } Else {
        Is32Bit := True
    }

    DllCall("CloseHandle", "Ptr", hProc)

    Return (Is32Bit) ? "32-bit" : "64-bit"
}

GetProcessName(hwnd) {																					;-- Gets the process name from a window handle.
	
	WinGet, ProcessName, processname, ahk_id %hwnd%
	return ProcessName
}

GetDisplayOrientation() {																					;-- working function to get the orientation of screen
	
	DEVMODE_Size := 226
	VarSetCapacity(DEVMODE, DEVMODE_Size, 0)
	NumPut(DEVMODE_Size, DEVMODE, 68, "UShort")
	NumPut(64, DEVMODE, 70, "UShort")
	
	ret := DllCall("EnumDisplaySettings", "Ptr", 0, "UInt", 0xFFFFFFFF, "Str", DEVMODE)
	dmDisplayOrientation := 0
	;DM_DISPLAYORIENTATION = 0x00000080
	If (ret && NumGet(DEVMODE, 72, "UInt") & 0x00000080)
			dmDisplayOrientation := NumGet(DEVMODE, 84, "UInt")
	VarSetCapacity(DEVMODE, 0)
	Return dmDisplayOrientation
}

GetSysErrorText(errNr) { 																						;-- method to get meaningful data out of the error codes

	; http://www.autohotkey.com/forum/post-72230.html#72230 by PhiLho
  bufferSize = 1024 ; Arbitrary, should be large enough for most uses
  VarSetCapacity(buffer, bufferSize)
  DllCall("FormatMessage"
     , "UInt", FORMAT_MESSAGE_FROM_SYSTEM := 0x1000
     , "UInt", 0
     , "UInt", errNr
     , "UInt", 0  ;LANG_USER_DEFAULT := 0x20000 ; LANG_SYSTEM_DEFAULT := 0x10000
     , "Str", buffer
     , "UInt", bufferSize
     , "UInt", 0)
  Return buffer
}

getSysLocale() { 																									;-- gets the system language 

	; fork of http://stackoverflow.com/a/7759505/883015
	; Source: https://github.com/joedf/AEI.ahk/blob/master/AEI.ahk
	VarSetCapacity(buf_a,9,0), VarSetCapacity(buf_b,9,0)
	f:="GetLocaleInfo" (A_IsUnicode?"W":"A")
	DllCall(f,"Int",LOCALE_SYSTEM_DEFAULT:=0x800
			,"Int",LOCALE_SISO639LANGNAME:=89
			,"Str",buf_a,"Int",9)
	DllCall(f,"Int",LOCALE_SYSTEM_DEFAULT
			,"Int",LOCALE_SISO3166CTRYNAME:=90
			,"Str",buf_b,"Int",9)
	return buf_a "-" buf_b
}

GetThreadStartAddr(ProcessID) {                                                                     	;-- returns start adresses from all threads of a process
	
	/*                              	EXAMPLE(s)
	
			MsgBox % "StartAddr of first Thread:`t" GetThreadStartAddr(2280)[1].StartAddr
			; Tested with PID of notepad
			; 0x000000003c5aa2
			
			; ================================================================================
			
			for k, v in GetThreadStartAddr(2280)                                             
			    MsgBox % "ThreadID:`t`t" v.ThreadID "`nStartAddr:`t`t" v.StartAddr
			; Tested with PID of notepad
			; ThreadID:     8052              |  1460              |  12116             |  8668              |  5376
			; StartAddr:    0x000000003c5aa2  |  0x000000777ac6d0  |  0x0000000032c660  |  0x000000748875f0  |  0x000000777ac6d0
			
	*/
	
			
    hModule := DllCall("LoadLibrary", "str", "ntdll.dll", "uptr")

    if !(hSnapshot := DllCall("CreateToolhelp32Snapshot", "uint", 0x4, "uint", ProcessID))
        return "Error in CreateToolhelp32Snapshot"

    NumPut(VarSetCapacity(THREADENTRY32, 28, 0), THREADENTRY32, "uint")
    if !(DllCall("Thread32First", "ptr", hSnapshot, "ptr", &THREADENTRY32))
        return "Error in Thread32First", DllCall("CloseHandle", "ptr", hSnapshot)

    Addr := {}, cnt := 1
    while (DllCall("Thread32Next", "ptr", hSnapshot, "ptr", &THREADENTRY32)) {
        if (NumGet(THREADENTRY32, 12, "uint") = ProcessID) {
            hThread := DllCall("OpenThread", "uint", 0x0040, "int", 0, "uint", NumGet(THREADENTRY32, 8, "uint"), "ptr")
            if (DllCall("ntdll\NtQueryInformationThread", "ptr", hThread, "uint", 9, "ptr*", ThreadStartAddr, "uint", A_PtrSize, "uint*", 0) != 0)
                return "Error in NtQueryInformationThread", DllCall("CloseHandle", "ptr", hThread) && DllCall("FreeLibrary", "ptr", hModule)
            Addr[cnt, "StartAddr"] := Format("{:#016x}", ThreadStartAddr)
            Addr[cnt, "ThreadID"]  := NumGet(THREADENTRY32, 8, "uint")
            DllCall("CloseHandle", "ptr", hThread), cnt++
        }
    }

    return Addr, DllCall("CloseHandle", "ptr", hSnapshot) && DllCall("FreeLibrary", "ptr", hModule)
}


} 
;|														|														|														|														|
;|	 GetProcesses()								|	GetProcessWorkingDir()				|	GetTextSize()     							|	GetTextSize()								|
;|   MeasureText()                           	|	monitorInfo()								|	whichMonitor()							|	IsOfficeFile()									|
;|	 DeskIcons()									|   GetFuncDefs()                          	|   IndexOfIconResource()             	|   GetIconforext()                         	|
;|   GetImageType()                         	|   GetProcessName()                   	|   GetDisplayOrientation()            	|   GetSysErrorText()                      	|
;|   getSysLocale()                            	|   GetThreadStartAddr()               	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;Graphic functions (34)
;1
LoadPicture(aFilespec, aWidth:=0, aHeight:=0, ByRef aImageType:="", 				;--Loads a picture and returns an HBITMAP or HICON to the caller
aIconNumber:=0, aUseGDIPlusIfAvailable:=1) {

	; Returns NULL on failure.
	; If aIconNumber > 0, an HICON or HCURSOR is returned (both should be interchangeable), never an HBITMAP.
	; However, aIconNumber==1 is treated as a special icon upon which LoadImage is given preference over ExtractIcon
	; for .ico/.cur/.ani files.
	; Otherwise, .ico/.cur/.ani files are normally loaded as HICON (unless aUseGDIPlusIfAvailable is true or
	; something else unusual happened such as file contents not matching file's extension).  This is done to preserve
	; any properties that HICONs have but HBITMAPs lack, namely the ability to be animated and perhaps other things.
	;
	; Loads a JPG/GIF/BMP/ICO/etc. and returns an HBITMAP or HICON to the caller (which it may call
	; DeleteObject()/DestroyIcon() upon, though upon program termination all such handles are freed
	; automatically).  The image is scaled to the specified width and height.  If zero is specified
	; for either, the image's actual size will be used for that dimension.  If -1 is specified for one,
	; that dimension will be kept proportional to the other dimension's size so that the original aspect
	; ratio is retained.

	static IMAGE_ICON,IMAGE_BITMAP,IMAGE_CURSOR,LR_LOADFROMFILE,LR_CREATEDIBSECTION,GdiplusStartupInput,gdi_input,CLR_DEFAULT,GENERIC_READ,OPEN_EXISTING,GMEM_MOVEABLE,LR_COPYRETURNORG,bitmap,ii,LR_COPYDELETEORG,INVALID_HANDLE_VALUE,IID_IPicture

	if !IMAGE_ICON
    IMAGE_ICON:=1,IMAGE_BITMAP:=0,IMAGE_CURSOR:=2,LR_LOADFROMFILE:=16, LR_CREATEDIBSECTION:=8192
    ,GdiplusStartupInput :="UINT32 GdiplusVersion;PTR DebugEventCallback;BOOL SuppressBackgroundThread;BOOL SuppressExternalCodecs"
    ,gdi_input:=Struct(GdiplusStartupInput),CLR_DEFAULT:=4278190080,GENERIC_READ:=2147483648
    ,OPEN_EXISTING:=3,GMEM_MOVEABLE:=2,LR_COPYRETURNORG:=4
    ,bitmap:=Struct("LONG bmType;LONG bmWidth;LONG bmHeight;LONG bmWidthBytes;WORD bmPlanes;WORD bmBitsPixel;LPVOID bmBits") ;BITMAP
    ,ii:=Struct("BOOL fIcon;DWORD xHotspot;DWORD yHotspot;HBITMAP hbmMask;HBITMAP hbmColor") ; ICONINFO
    ,LR_COPYDELETEORG:=8,INVALID_HANDLE_VALUE:=-1,VarSetCapacity(IID_IPicture,16,0) CLSIDFromString("{7BF80980-BF32-101A-8BBB-00AA00300CAB}", &IID_IPicture)
	hbitmap := 0
	,aImageType := -1 ; The type of image currently inside hbitmap.  Set default value for output parameter as "unknown".

	if (aFilespec="") ; Allow blank filename to yield NULL bitmap (and currently, some callers do call it this way).
		return 0

	; Lexikos: Negative values now indicate an icon's integer resource ID.
	;if (aIconNumber < 0) ; Allowed to be called this way by GUI and others (to avoid need for validation of user input there).
	;	aIconNumber = 0 ; Use the default behavior, which is "load icon or bitmap, whichever is most appropriate".

	file_ext := SubStr(aFilespec, InStr(aFilespec,".",1,-1) + 1)

	; v1.0.43.07: If aIconNumber is zero, caller didn't specify whether it wanted an icon or bitmap.  Thus,
	; there must be some kind of detection for whether ExtractIcon is needed instead of GDIPlus/OleLoadPicture.
	; Although this could be done by attempting ExtractIcon only after GDIPlus/OleLoadPicture fails (or by
	; somehow checking the internal nature of the file), for performance and code size, it seems best to not
	; to incur this extra I/O and instead make only one attempt based on the file's extension.
	; Must use ExtractIcon() if either of the following is true:
	; 1) Caller gave an icon index of the second or higher icon in the file.  Update for v1.0.43.05: There
	;    doesn't seem to be any reason to allow a caller to explicitly specify ExtractIcon as the method of
	;    loading the *first* icon from a .ico file since LoadImage is likely always superior.  This is
	;    because unlike ExtractIcon/Ex, LoadImage: 1) Doesn't distort icons, especially 16x16 icons 2) is
	;    capable of loading icons other than the first by means of width and height parameters.
	; 2) The target file is of type EXE/DLL/ICL/CPL/etc. (LoadImage() is documented not to work on those file types).
	;    ICL files (v1.0.43.05): Apparently ICL files are an unofficial file format. Someone on the newsgroups
	;    said that an ICL is an "ICon Library... a renamed 16-bit Windows .DLL (an NE format executable) which
	;    typically contains nothing but a resource section. The ICL extension seems to be used by convention."
	; L17: Support negative numbers to mean resource IDs. These are supported by the resource extraction method directly, and by ExtractIcon if aIconNumber < -1.
	; Icon library: Unofficial dll container, see notes above. (*.icl)
	; Control panel extension/applet (ExtractIcon is said to work on these). (*.cpl)
	; Screen saver (ExtractIcon should work since these are really EXEs). (*.src)
	If (ExtractIcon_was_used := aIconNumber > 1 || aIconNumber < 0 || file_ext = "exe" || file_ext="dll" || file_ext="icl" || file_ext="cpl" || file_ext="scr"){
		; v1.0.44: Below are now omitted to reduce code size and improve performance. They are still supported
		; indirectly because ExtractIcon is attempted whenever LoadImage() fails further below.
		; !_tcsicmp(file_ext, _T("drv")) ; Driver (ExtractIcon is said to work on these).
		; !_tcsicmp(file_ext, _T("ocx")) ; OLE/ActiveX Control Extension
		; !_tcsicmp(file_ext, _T("vbx")) ; Visual Basic Extension
		; !_tcsicmp(file_ext, _T("acm")) ; Audio Compression Manager Driver
		; !_tcsicmp(file_ext, _T("bpl")) ; Delphi Library (like a DLL?)
		; Not supported due to rarity, code size, performance, and uncertainty of whether ExtractIcon works on them.
		; Update for v1.0.44: The following are now supported indirectly because ExtractIcon is attempted whenever
		; LoadImage() fails further below.
		; !_tcsicmp(file_ext, _T("nil")) ; Norton Icon Library
		; !_tcsicmp(file_ext, _T("wlx")) ; Total/Windows Commander Lister Plug-in
		; !_tcsicmp(file_ext, _T("wfx")) ; Total/Windows Commander File System Plug-in
		; !_tcsicmp(file_ext, _T("wcx")) ; Total/Windows Commander Plug-in
		; !_tcsicmp(file_ext, _T("wdx")) ; Total/Windows Commander Plug-in

		aImageType := IMAGE_ICON

		; L17: Manually extract the most appropriately sized icon resource for the best results.
		,hbitmap := ExtractIconFromExecutable(aFilespec, aIconNumber, aWidth, aHeight)

		if (hbitmap < 2) ; i.e. it's NULL or 1. Return value of 1 means "incorrect file type".
			return 0 ; v1.0.44: Fixed to return NULL vs. hbitmap, since 1 is an invalid handle (perhaps rare since no known bugs caused by it).
		;else continue on below so that the icon can be resized to the caller's specified dimensions.
	}	else if (aIconNumber > 0) ; Caller wanted HICON, never HBITMAP, so set type now to enforce that.
		aImageType := IMAGE_ICON ; Should be suitable for cursors too, since they're interchangeable for the most part.
	else if (file_ext) ; Make an initial guess of the type of image if the above didn't already determine the type.
	{
		if (file_ext = "ico")
			aImageType := IMAGE_ICON
		else if (file_ext="cur" || file_ext="ani")
			aImageType := IMAGE_CURSOR
		else if (file_ext="bmp")
			aImageType := IMAGE_BITMAP
		;else for other extensions, leave set to "unknown" so that the below knows to use IPic or GDI+ to load it.
	}
	;else same comment as above.

	if ((aWidth = -1 || aHeight = -1) && (!aWidth || !aHeight))
		aWidth := aHeight := 0 ; i.e. One dimension is zero and the other is -1, which resolves to the same as "keep original size".
	keep_aspect_ratio := aWidth = -1 || aHeight = -1

	; Caller should ensure that aUseGDIPlusIfAvailable==false when aIconNumber > 0, since it makes no sense otherwise.
	if (aUseGDIPlusIfAvailable && !(hinstGDI := LoadLibrary("gdiplus"))) ; Relies on short-circuit boolean order for performance.
		aUseGDIPlusIfAvailable := false ; Override any original "true" value as a signal for the section below.
	if (!hbitmap && aImageType > -1 && !aUseGDIPlusIfAvailable)
	{
		; Since image hasn't yet be loaded and since the file type appears to be one supported by
		; LoadImage() [icon/cursor/bitmap], attempt that first.  If it fails, fall back to the other
		; methods below in case the file's internal contents differ from what the file extension indicates.
		if (keep_aspect_ratio) ; Load image at its actual size.  It will be rescaled to retain aspect ratio later below.
		{
			desired_width := 0
			,desired_height := 0
		}
		else
		{
			desired_width := aWidth
			,desired_height := aHeight
		}
		; For LoadImage() below:
		; LR_CREATEDIBSECTION applies only when aImageType == IMAGE_BITMAP, but seems appropriate in that case.
		; Also, if width and height are non-zero, that will determine which icon of a multi-icon .ico file gets
		; loaded (though I don't know the exact rules of precedence).
		; KNOWN LIMITATIONS/BUGS:
		; LoadImage() fails when requesting a size of 1x1 for an image whose orig/actual size is small (e.g. 1x2).
		; Unlike CopyImage(), perhaps it detects that division by zero would occur and refuses to do the
		; calculation rather than providing more code to do a correct calculation that doesn't divide by zero.
		; For example:
		; LoadImage() Success:
		;   Gui, Add, Pic, h2 w2, bitmap 1x2.bmp
		;   Gui, Add, Pic, h1 w1, bitmap 4x6.bmp
		; LoadImage() Failure:
		;   Gui, Add, Pic, h1 w1, bitmap 1x2.bmp
		; LoadImage() also fails on:
		;   Gui, Add, Pic, h1, bitmap 1x2.bmp
		; And then it falls back to GDIplus, which in the particular case above appears to traumatize the
		; parent window (or its picture control), because the GUI window hangs (but not the script) after
		; doing a FileSelectFolder.  For example:
		;   Gui, Add, Button,, FileSelectFile
		;   Gui, Add, Pic, h1, bitmap 1x2.bmp   Causes GUI window to hang after FileSelectFolder (due to LoadImage failing then falling back to GDIplus i.e. GDIplus is somehow triggering the problem).
		;   Gui, Show
		;   return
		;   ButtonFileSelectFile:
		;   FileSelectFile, outputvar
		;   return
		if (hbitmap := LoadImage(0, aFilespec, aImageType, desired_width, desired_height, LR_LOADFROMFILE | LR_CREATEDIBSECTION))
		{
			; The above might have loaded an HICON vs. an HBITMAP (it has been confirmed that LoadImage()
			; will return an HICON vs. HBITMAP is aImageType is IMAGE_ICON/CURSOR).  Note that HICON and
			; HCURSOR are identical for most/all Windows API uses.  Also note that LoadImage() will load
			; an icon as a bitmap if the file contains an icon but IMAGE_BITMAP was passed in (at least
			; on Windows XP).
			if (!keep_aspect_ratio) ; No further resizing is needed.
				return hbitmap
			; Otherwise, continue on so that the image can be resized via a second call to LoadImage().
		}
		; v1.0.40.10: Abort if file doesn't exist so that GDIPlus isn't even attempted. This is done because
		; loading GDIPlus apparently disrupts the color palette of certain games, at least old ones that use
		; DirectDraw in 256-color depth.
		else if (GetFileAttributes(aFilespec) = 0xFFFFFFFF) ; For simplicity, we don't check if it's a directory vs. file, since that should be too rare.
			return 0
		; v1.0.43.07: Also abort if caller wanted an HICON (not an HBITMAP), since the other methods below
		; can't yield an HICON.
		else if (aIconNumber > 0)
		{
			; UPDATE for v1.0.44: Attempt ExtractIcon in case its some extension that's
			; was recognized as an icon container (such as AutoHotkeySC.bin) and thus wasn't handled higher above.
			;hbitmap = (HBITMAP)ExtractIcon(g_hInstance, aFilespec, aIconNumber - 1)

			; L17: Manually extract the most appropriately sized icon resource for the best results.
			hbitmap := ExtractIconFromExecutable(aFilespec, aIconNumber, aWidth, aHeight)

			if (hbitmap < 2) ; i.e. it's NULL or 1. Return value of 1 means "incorrect file type".
				return 0
			ExtractIcon_was_used := true
		}
		;else file exists, so continue on so that the other methods are attempted in case file's contents
		; differ from what the file extension indicates, or in case the other methods can be successful
		; even when the above failed.
	}

	; pic := 0 is also used to detect whether IPic method was used to load the image.

	if (!hbitmap) ; Above hasn't loaded the image yet, so use the fall-back methods.
	{
		; At this point, regardless of the image type being loaded (even an icon), it will
		; definitely be converted to a Bitmap below.  So set the type:
		aImageType := IMAGE_BITMAP
		; Find out if this file type is supported by the non-GDI+ method.  This check is not foolproof
		; since all it does is look at the file's extension, not its contents.  However, it doesn't
		; need to be 100% accurate because its only purpose is to detect whether the higher-overhead
		; calls to GdiPlus can be avoided.

		if (aUseGDIPlusIfAvailable || !file_ext || file_ext!="jpg"
			&& file_ext!="jpeg" && file_ext!="gif") ; Non-standard file type (BMP is already handled above).
			if (!hinstGDI) ; We don't yet have a handle from an earlier call to LoadLibary().
				hinstGDI := LoadLibrary("gdiplus")
		; If it is suspected that the file type isn't supported, try to use GdiPlus if available.
		; If it's not available, fall back to the old method in case the filename doesn't properly
		; reflect its true contents (i.e. in case it really is a JPG/GIF/BMP internally).
		; If the below LoadLibrary() succeeds, either the OS is XP+ or the GdiPlus extensions have been
		; installed on an older OS.
		if (hinstGDI)
		{
			; LPVOID and "int" are used to avoid compiler errors caused by... namespace issues?

			gdi_input.Fill()
			if !GdiplusStartup(getvar(token:=0), gdi_input[], 0)
			{
				if !GdipCreateBitmapFromFile(aFilespec, getvar(pgdi_bitmap:=0))
				{
					if GdipCreateHBITMAPFromBitmap(pgdi_bitmap, hbitmap, CLR_DEFAULT)
						hbitmap := 0 ; Set to NULL to be sure.
					GdipDisposeImage(pgdi_bitmap) ; This was tested once to make sure it really returns Gdiplus::Ok.
				}
				; The current thought is that shutting it down every time conserves resources.  If so, it
				; seems justified since it is probably called infrequently by most scripts:
				GdiplusShutdown(token)
			}
			FreeLibrary(hinstGDI)
		}
		else ; Using old picture loading method.
		{
			; Based on code sample at http:;www.codeguru.com/Cpp/G-M/bitmap/article.php/c4935/
			hfile := CreateFile(aFilespec, GENERIC_READ, 0, 0, OPEN_EXISTING, 0, 0)
			if (hfile = INVALID_HANDLE_VALUE)
				return 0
			size := GetFileSize(hfile, 0)
			if !(hglobal := GlobalAlloc(GMEM_MOVEABLE, size)){
				CloseHandle(hfile)
				return 0
			}
			if !(hlocked := GlobalLock(hglobal)){
				CloseHandle(hfile)
				,GlobalFree(hglobal)
				return 0
			}
			; Read the file into memory:
			ReadFile(hfile, hlocked, size, getvar(size), 0)
			,GlobalUnlock(hglobal)
			,CloseHandle(hfile)
			if (0 > CreateStreamOnHGlobal(hglobal, FALSE, getvar(stream:=0)) || !stream )  ; Relies on short-circuit boolean order.
			{
				GlobalFree(hglobal)
				return 0
			}

			; Specify TRUE to have it do the GlobalFree() for us.  But since the call might fail, it seems best
			; to free the mem ourselves to avoid uncertainty over what it does on failure:
			if (0 > OleLoadPicture(stream, size, FALSE, &IID_IPicture,getvar(pic:=0)))
				pic:=0

			DllCall(NumGet(NumGet(stream+0)+8),"PTR",stream) ;->Release()
			,GlobalFree(hglobal)
			if !pic
				return 0
			DllCall(NumGet(NumGet(pic+0)+12),"PTR",pic,"PTR*",hbitmap)
			; Above: MSDN: "The caller is responsible for this handle upon successful return. The variable is set
			; to NULL on failure."
			if (!hbitmap)
			{
				DllCall(NumGet(NumGet(pic+0)+8),"PTR",pic)
				return 0
			}
			; Don't pic->Release() yet because that will also destroy/invalidate hbitmap handle.
		} ; IPicture method was used.
	} ; IPicture or GDIPlus was used to load the image, not a simple LoadImage() or ExtractIcon().

	; Above has ensured that hbitmap is now not NULL.
	; Adjust things if "keep aspect ratio" is in effect:
	if (keep_aspect_ratio)
	{
		ii.Fill()
		if (aImageType = IMAGE_BITMAP)
			hbitmap_to_analyze := hbitmap
		else ; icon or cursor
		{
			if (GetIconInfo(hbitmap, ii[])) ; Works on cursors too.
				hbitmap_to_analyze := ii.hbmMask ; Use Mask because MSDN implies hbmColor can be NULL for monochrome cursors and such.
			else
			{
				DestroyIcon(hbitmap)
				return 0 ; No need to call pic->Release() because since it's an icon, we know IPicture wasn't used (it only loads bitmaps).
			}
		}
		; Above has ensured that hbitmap_to_analyze is now not NULL.  Find bitmap's dimensions.
		bitmap.Fill()
		,GetObject(hbitmap_to_analyze, sizeof(_BITMAP), bitmap[]) ; Realistically shouldn't fail at this stage.
		if (aHeight = -1)
		{
			; Caller wants aHeight calculated based on the specified aWidth (keep aspect ratio).
			if (bitmap.bmWidth) ; Avoid any chance of divide-by-zero.
				aHeight := (bitmap.bmHeight / bitmap.bmWidth) * aWidth + 0.5 ; Round.
		}
		else
		{
			; Caller wants aWidth calculated based on the specified aHeight (keep aspect ratio).
			if (bitmap.bmHeight) ; Avoid any chance of divide-by-zero.
				aWidth := (bitmap.bmWidth / bitmap.bmHeight) * aHeight + 0.5 ; Round.
		}
		if (aImageType != IMAGE_BITMAP)
		{
			; It's our responsibility to delete these two when they're no longer needed:
			DeleteObject(ii.hbmColor)
			,DeleteObject(ii.hbmMask)
			; If LoadImage() vs. ExtractIcon() was used originally, call LoadImage() again because
			; I haven't found any other way to retain an animated cursor's animation (and perhaps
			; other icon/cursor attributes) when resizing the icon/cursor (CopyImage() doesn't
			; retain animation):
			if (!ExtractIcon_was_used)
			{
				DestroyIcon(hbitmap) ; Destroy the original HICON.
				; Load a new one, but at the size newly calculated above.
				; Due to an apparent bug in Windows 9x (at least Win98se), the below call will probably
				; crash the program with a "divide error" if the specified aWidth and/or aHeight are
				; greater than 90.  Since I don't know whether this affects all versions of Windows 9x, and
				; all animated cursors, it seems best just to document it here and in the help file rather
				; than limiting the dimensions of .ani (and maybe .cur) files for certain operating systems.
				return LoadImage(0, aFilespec, aImageType, aWidth, aHeight, LR_LOADFROMFILE)
			}
		}
	}


	if (pic) ; IPicture method was used.
	{
		; The below statement is confirmed by having tested that DeleteObject(hbitmap) fails
		; if called after pic->Release():
		; "Copy the image. Necessary, because upon pic's release the handle is destroyed."
		; MSDN: CopyImage(): "[If either width or height] is zero, then the returned image will have the
		; same width/height as the original."
		; Note also that CopyImage() seems to provide better scaling quality than using MoveWindow()
		; (followed by redrawing the parent window) on the static control that contains it:
		hbitmap_new := CopyImage(hbitmap, IMAGE_BITMAP, aWidth, aHeight ; We know it's IMAGE_BITMAP in this case.
														, (aWidth || aHeight) ? 0 : LR_COPYRETURNORG) ; Produce original size if no scaling is needed.
		,DllCall(NumGet(NumGet(pic+0)+8),"PTR",pic)
		; No need to call DeleteObject(hbitmap), see above.
	}
	else ; GDIPlus or a simple method such as LoadImage or ExtractIcon was used.
	{
		if (!aWidth && !aHeight) ; No resizing needed.
			return hbitmap
		; The following will also handle HICON/HCURSOR correctly if aImageType == IMAGE_ICON/CURSOR.
		; Also, LR_COPYRETURNORG|LR_COPYDELETEORG is used because it might allow the animation of
		; a cursor to be retained if the specified size happens to match the actual size of the
		; cursor.  This is because normally, it seems that CopyImage() omits cursor animation
		; from the new object.  MSDN: "LR_COPYRETURNORG returns the original hImage if it satisfies
		; the criteria for the copy�that is, correct dimensions and color depth�in which case the
		; LR_COPYDELETEORG flag is ignored. If this flag is not specified, a new object is always created."
		; KNOWN BUG: Calling CopyImage() when the source image is tiny and the destination width/height
		; is also small (e.g. 1) causes a divide-by-zero exception.
		; For example:
		;   Gui, Add, Pic, h1 w-1, bitmap 1x2.bmp   Crash (divide by zero)
		;   Gui, Add, Pic, h1 w-1, bitmap 2x3.bmp   Crash (divide by zero)
		; However, such sizes seem too rare to document or put in an exception handler for.
		hbitmap_new := CopyImage(hbitmap, aImageType, aWidth, aHeight, LR_COPYRETURNORG | LR_COPYDELETEORG)
		; Above's LR_COPYDELETEORG deletes the original to avoid cascading resource usage.  MSDN's
		; LoadImage() docs say:
		; "When you are finished using a bitmap, cursor, or icon you loaded without specifying the
		; LR_SHARED flag, you can release its associated memory by calling one of [the three functions]."
		; Therefore, it seems best to call the right function even though DeleteObject might work on
		; all of them on some or all current OSes.  UPDATE: Evidence indicates that DestroyIcon()
		; will also destroy cursors, probably because icons and cursors are literally identical in
		; every functional way.  One piece of evidence:
		;> No stack trace, but I know the exact source file and line where the call
		;> was made. But still, it is annoying when you see 'DestroyCursor' even though
		;> there is 'DestroyIcon'.
		; "Can't be helped. Icons and cursors are the same thing" (Tim Robinson (MVP, Windows SDK)).
		;
		; Finally, the reason this is important is that it eliminates one handle type
		; that we would otherwise have to track.  For example, if a gui window is destroyed and
		; and recreated multiple times, its bitmap and icon handles should all be destroyed each time.
		; Otherwise, resource usage would cascade upward until the script finally terminated, at
		; which time all such handles are freed automatically.
	}
	return hbitmap_new
}
;2
GetImageDimensionProperty(ImgPath, Byref width, Byref height, 						;-- this retrieves the dimensions from a dummy Gui
PropertyName="dimensions") {

    Static DimensionIndex
    SplitPath, ImgPath , FileName, DirPath,
    objShell := ComObjCreate("Shell.Application")
    objFolder := objShell.NameSpace(DirPath)
    objFolderItem := objFolder.ParseName(FileName)

    if !DimensionIndex {
        Loop
            DimensionIndex := A_Index
        Until (objFolder.GetDetailsOf(objFolder.Items, A_Index) = PropertyName) || (A_Index > 300)
    }

    if (DimensionIndex = 301)
        Return

    dimensions := objFolder.GetDetailsOf(objFolderItem, DimensionIndex)
    width := height := ""
    pos := len := 0
    loop 2
    {
        pos := RegExMatch(dimensions, "O)\d+", oM, pos+len+1)
        if (A_Index = 1)
            width := oM.Value(0), len := oM.len(0)
        else
            height := oM.Value(0)
    }

}
;3
GetImageDimensions(ImgPath, Byref width, Byref height) {									;-- Retrieves image width and height of a specified image file

	/*											Description

		;https://sites.g/*                              .com/site/ahkref/custom-functions/getimagedimensions

		Retrieves image width and height of a specified image file.

		Requirements
		AutoHotkey 1.1.05.00 or later. Tested on: Windows 7 64bit, AutoHotkey 32bit Unicode 1.1.05.05.

		License
		Public Domain.

		Format
		GetImageDimensionProperty(ImgPath, Byref width, Byref height, PropertyName="dimensions")
		Parameters
		ImgPath: the path of the file to look up the dimensions.
		width: pass a variable to store the retrieved width.
		height: pass a variable to store the retrieved height.
		PropertyName: the property name which stores the information of image dimensions. In English OS, it is dimensions.
		Return Value
		None.

		Remarks
		This function retrieves the information of detail properties and the PropertyName parameter must match the property name in the property details

	*/

	/*											Example

		ImageFile := A_ScriptDir "\logo.gif"
		if !FileExist(ImageFile)
			UrlDownloadToFile, http://www.autohotkey.com/docs/images/AutoHotkey_logo.gif, % ImageFile

		GetImageDimensions(ImageFile, w, h)
		msgbox % "Width:`t" w "`nHeight:`t" h

	*/


    DHW := A_DetectHiddenWIndows
    DetectHiddenWindows, ON
    Gui, AnimatedGifControl_GetImageDimensions: Add, Picture, hwndhWndImage, % ImgPath
    GuiControlGet, Image, AnimatedGifControl_GetImageDimensions:Pos, % hWndImage
    Gui, AnimatedGifControl_GetImageDimensions: Destroy
    DetectHiddenWindows, % DHW
    width := ImageW,     height := ImageH

}
;4
Gdip_FillRoundedRectangle(pGraphics, pBrush, x, y, w, h, r) {								;--

	Region := Gdip_GetClipRegion(pGraphics)
	Gdip_SetClipRect(pGraphics, x-r, y-r, 2*r, 2*r, 4)
	Gdip_SetClipRect(pGraphics, x+w-r, y-r, 2*r, 2*r, 4)
	Gdip_SetClipRect(pGraphics, x-r, y+h-r, 2*r, 2*r, 4)
	Gdip_SetClipRect(pGraphics, x+w-r, y+h-r, 2*r, 2*r, 4)
	E := Gdip_FillRectangle(pGraphics, pBrush, x, y, w, h)
	Gdip_SetClipRegion(pGraphics, Region, 0)
	Gdip_SetClipRect(pGraphics, x-(2*r), y+r, w+(4*r), h-(2*r), 4)
	Gdip_SetClipRect(pGraphics, x+r, y-(2*r), w-(2*r), h+(4*r), 4)
	Gdip_FillEllipse(pGraphics, pBrush, x, y, 2*r, 2*r)
	Gdip_FillEllipse(pGraphics, pBrush, x+w-(2*r)-1, y, 2*r, 2*r)
	Gdip_FillEllipse(pGraphics, pBrush, x, y+h-(2*r)-1, 2*r, 2*r)
	Gdip_FillEllipse(pGraphics, pBrush, x+w-(2*r)-1, y+h-(2*r)-1, 2*r, 2*r)
	Gdip_SetClipRegion(pGraphics, Region, 0)
	Gdip_DeleteRegion(Region)
	Return E

}
;5
Redraw(hwnd=0) {																									;-- redraws the overlay window(s) using the position, text and scrolling settings

    ;This function redraws the overlay window(s) using the position, text and scrolling settings
    global MainOverlay, PreviewOverlay, PreviewWindow, MainWindow
	outputdebug redraw
	;Called without parameters, recursive calls for both overlays
	if (hwnd=0)
	{
		if (MainOverlay && PreviewOverlay)
		{
			Redraw(MainWindow)
			Redraw(PreviewWindow)
			return
		}
		Else
		{
			msgbox Redraw() called with invalid window handle
			Exit
		}
	}
	;Get Position of overlay area and text position
	GetOverlayArea(x,y,w,h,hwnd)
	GetAbsolutePosition(CenterX,CenterY,hwnd)
	GetDrawingSettings(text,font,FontColor,style,BackColor,hwnd)

	; Create a gdi bitmap with width and height of what we are going to draw into it. This is the entire drawing area for everything
	hbm := CreateDIBSection(w, h)

	; Get a device context compatible with the screen
	hdc := CreateCompatibleDC()

	; Select the bitmap into the device context
	obm := SelectObject(hdc, hbm)

	; Get a pointer to the graphics of the bitmap, for use with drawing functions
	G := Gdip_GraphicsFromHDC(hdc)

	; Set the smoothing mode to antialias = 4 to make shapes appear smother (only used for vector drawing and filling)
	Gdip_SetSmoothingMode(G, 4)
	Gdip_SetTextRenderingHint(G, 1)
	; Create a partially transparent, black brush (ARGB = Transparency, red, green, blue) to draw a rounded rectangle with
	pBrush := Gdip_BrushCreateSolid(backcolor)
	hFont := Font("", style "," font )
	size := Font_DrawText(text, hdc, hFont, "CALCRECT")		;measure the text, use already created font
	StringSplit, size, size, .
	FontWidth := size1,	FontHeight := size2
	DrawX:=CenterX-Round(FontWidth/2)
	DrawY:=CenterY-Round(FontHeight/2)

	corners:=min(Round(min(FontWidth,FontHeight)/5),20)
	Gdip_FillRoundedRectangle(G, pBrush, DrawX, DrawY, FontWidth, FontHeight, corners)
	; Delete the brush as it is no longer needed and wastes memory
	Gdip_DeleteBrush(pBrush)

	Options = x%DrawX% y%DrawY% cff%FontColor% %style% r4
	Gdip_TextToGraphics(G, text, Options, Font)


	; Update the specified window we have created (hwnd1) with a handle to our bitmap (hdc), specifying the x,y,w,h we want it positioned on our screen
	; With some simple maths we can place the gui in the centre of our primary monitor horizontally and vertically at the specified heigth and width
	if (hwnd=PreviewWindow)
		UpdateLayeredWindow(PreviewOverlay, hdc, x, y, w, h)
	else if (hwnd=MainWindow)
		UpdateLayeredWindow(MainOverlay, hdc, x, y, w, h)

	; Select the object back into the hdc
	SelectObject(hdc, obm)

	; Now the bitmap may be deleted
	DeleteObject(hbm)

	; Also the device context related to the bitmap may be deleted
	DeleteDC(hdc)

	; The graphics may now be deleted
	Gdip_DeleteGraphics(G)
}
;6
CreateSurface(monitor := 0, window := 0) {															;-- creates a drawing GDI surface

	global DrawSurface_Hwnd

	if (monitor = 0) {
		if (window) {
			WinGetPos, sX, sY, sW, sH, ahk_id %window%
		} else {
			WinGetPos, sX, sY, sW, sH, Program Manager
		}
	} else {
		Sysget, MonitorInfo, Monitor, %monitor%
		sX := MonitorInfoLeft, sY := MonitorInfoTop
		sW := MonitorInfoRight - MonitorInfoLeft
		sH := MonitorInfoBottom - MonitorInfoTop
	}

	Gui DrawSurface:Color, 0xFFFFFF
	Gui DrawSurface: +E0x20 -Caption +LastFound +ToolWindow +AlwaysOnTop
	WinGet, DrawSurface_Hwnd, ID,
	WinSet, TransColor, 0xFFFFFF

	Gui DrawSurface:Show, x%sX% y%sY% w%sW% h%sH%
	Sleep, 100
	Gui DrawSurface:Submit

	return DrawSurface_Hwnd
}
{ ; additional functions for CreateSurface
ShowSurface() {
	WinGet, active_win, ID, A
	Gui DrawSurface:Show
	WinActivate, ahk_id %active_win%
}

HideSurface() {
	Gui DrawSurface:Submit
}

WipeSurface(hwnd) {
	DllCall("InvalidateRect", UInt, hwnd, UInt, 0, Int, 1)
    DllCall("UpdateWindow", UInt, hwnd)
}

StartDraw(wipe := true) {

	global DrawSurface_Hwnd

	if (wipe)
		WipeSurface(DrawSurface_Hwnd)

    HDC := DllCall("GetDC", Int, DrawSurface_Hwnd)

    return HDC
}

EndDraw(hdc) {
	global DrawSurface_Hwnd
	DllCall("ReleaseDC", Int, DrawSurface_Hwnd, Int, hdc)
}

SetPen(color, thickness, hdc) {

	global DrawSurface_Hwnd

	static pen := 0

	if (pen) {
		DllCall("DeleteObject", Int, pen)
		pen := 0
	}

	pen := DllCall("CreatePen", UInt, 0, UInt, thickness, UInt, color)
    DllCall("SelectObject", Int, hdc, Int, pen)

}
} 
;7
DrawLine(hdc, rX1, rY1, rX2, rY2) {																			;-- used DLLCall to draw a line

	DllCall("MoveToEx", Int, hdc, Int, rX1, Int, rY1, UInt, 0)
	DllCall("LineTo", Int, hdc, Int, rX2, Int, rY2)

}
;8
DrawRectangle(hdc, left, top, right, bottom) {														;-- used DLLCall to draw a rectangle

	DllCall("MoveToEx", Int, hdc, Int, left, Int, top, UInt, 0)
    DllCall("LineTo", Int, hdc, Int, right, Int, top)
    DllCall("LineTo", Int, hdc, Int, right, Int, bottom)
    DllCall("LineTo", Int, hdc, Int, left, Int, bottom)
    DllCall("LineTo", Int, hdc, Int, left, Int, top-1)

}
;9
DrawRectangle(startNewRectangle := false) {															;-- this is for screenshots

	static lastX, lastY
	static xorigin, yorigin

	if (startNewRectangle) {
	  MouseGetPos, xorigin, yorigin
	}

	CoordMode, Mouse, Screen
	MouseGetPos, currentX, currentY

	; Has the mouse moved?
	if (lastX lastY) = (currentX currentY)
	return

	lastX := currentX
	lastY := currentY

	x := Min(currentX, xorigin)
	w := Abs(currentX - xorigin)
	y := Min(currentY, yorigin)
	h := Abs(currentY - yorigin)

	Gui, ScreenshotSelection:Show, % "NA X" x " Y" y " W" w " H" h
	Gui, ScreenshotSelection:+LastFound

}
;10
DrawFrameAroundControl(ControlID, WindowUniqueID, frame_t) {						;-- paints a rectangle around a specified control

    global h_brushC, h_brushW, ChkDrawRectCtrl, ChkDrawRectWin

    ;get coordinates of Window and control again
    ;(could have been past into the function but it seemed too much parameters)
    WinGetPos, WindowX, WindowY, WindowWidth, WindowHeight, ahk_id %WindowUniqueID%
    ControlGetPos, ControlX, ControlY, ControlWidth, ControlHeight, %ControlID%, ahk_id %WindowUniqueID%

    ;find upper left corner relative to screen
    StartX := WindowX + ControlX
    StartY := WindowY + ControlY

    ;show ID in upper left corner
    CoordMode, ToolTip, Screen

    ;show frame gui above AOT apps
    Gui, 2: +AlwaysOnTop

    If ChkDrawRectWin {
        ;if windows upper left corner is outside the screen
        ; it is assumed that the window is maximized and the frame is made smaller
        If ( WindowX < 0 AND WindowY < 0 ){
            WindowX += 4
            WindowY += 4
            WindowWidth -= 8
            WindowHeight -= 8
          }

        ;remove old rectangle from screen and save/buffer screen below new rectangle
        BufferAndRestoreRegion( WindowX, WindowY, WindowWidth, WindowHeight )

        ;draw rectangle frame around window
        DrawFrame( WindowX, WindowY, WindowWidth, WindowHeight, frame_t, h_brushW )

        ;show tooltip above window frame when enough space
        If ( WindowY > 22)
            WindowY -= 22

        ;Show tooltip with windows unique ID
        ToolTip, %WindowUniqueID%, WindowX, WindowY, 3
      }
    Else
        ;remove old rectangle from screen and save/buffer screen below new rectangle
        BufferAndRestoreRegion( StartX, StartY, ControlWidth, ControlHeight )

    If ChkDrawRectCtrl {
        ;draw rectangle frame around control
        DrawFrame( StartX, StartY, ControlWidth, ControlHeight, frame_t, h_brushC )

        ;show tooltip above control frame when enough space, or below
        If ( StartY > 22)
            StartY -= 22
        Else
            StartY += ControlHeight

        ;show control tooltip left of window tooltip if position identical (e.g. Windows Start Button on Taskbar)
        If (StartY = WindowY
            AND StartX < WindowX + 50)
            StartX += 50

        ;Show tooltip with controls unique ID
        ToolTip, %ControlID%, StartX, StartY, 2
      }
    ;set back ToolTip position to default
    CoordMode, ToolTip, Relative
  }
;11
Highlight(reg, delay=1500) {																					;-- Show a red rectangle outline to highlight specified region, it's useful to debug

    { ;-------------------------------------------------------------------------------
    ;
    ; Function: Highlight
    ; Description:
    ;		Show a red rectangle outline to highlight specified region, it's useful to debug
    ; Syntax: Highlight(region [, delay = 1500])
    ; Parameters:
    ;		reg - The region for highlight
    ;		delay - Show time (milliseconds)
    ; Return Value:
    ;		 Real string without variable(s) - "this string has real variable"
    ; Related:
    ;		SendSpiCall, SendWapiCall
    ; Remarks:
    ;		#Include, Gdip.ahk
    ; Example:
    ;		Highlight("100,200,300,400")
    ;		Highlight("100,200,300,400", 1000)
    ;
    ;-------------------------------------------------------------------------------
    } 

    global @reg_global
; Start gdi+
	If !pToken := Gdip_Startup()
	{
		MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
		ExitApp
	}

	StringSplit, g_coors, @reg_global, `,
	; Set the width and height we want as our drawing area, to draw everything in. This will be the dimensions of our bitmap
	Width := g_coors3
	Height := g_coors4
    ; Create a layered window (+E0x80000 : must be used for UpdateLayeredWindow to work!) that is always on top (+AlwaysOnTop), has no taskbar entry or caption
	Gui, 1: -Caption +E0x80000 +LastFound +OwnDialogs +Owner +AlwaysOnTop

	; Show the window
	Gui, 1: Show, NA

	; Get a handle to this window we have created in order to update it later
	hwnd1 := WinExist()

	; Create a gdi bitmap with width and height of what we are going to draw into it. This is the entire drawing area for everything
	hbm := CreateDIBSection(Width, Height)

	; Get a device context compatible with the screen
	hdc := CreateCompatibleDC()

	; Select the bitmap into the device context
	obm := SelectObject(hdc, hbm)

	; Get a pointer to the graphics of the bitmap, for use with drawing functions
	G := Gdip_GraphicsFromHDC(hdc)

	; Set the smoothing mode to antialias = 4 to make shapes appear smother (only used for vector drawing and filling)
	Gdip_SetSmoothingMode(G, 4)


	; Create a slightly transparent (66) blue pen (ARGB = Transparency, red, green, blue) to draw a rectangle
	; This pen is wider than the last one, with a thickness of 10
	pPen := Gdip_CreatePen(0xffff0000, 2)

	; Draw a rectangle onto the graphics of the bitmap using the pen just created
	; Draws the rectangle from coordinates (250,80) a rectangle of 300x200 and outline width of 10 (specified when creating the pen)

	StringSplit, reg_coors, reg, `,
	x := reg_coors1
	y := reg_coors2
	w := reg_coors3 - reg_coors1
	h := reg_coors4 - reg_coors2

	Gdip_DrawRectangle(G, pPen, x, y, w, h)

	; Delete the brush as it is no longer needed and wastes memory
	Gdip_DeletePen(pPen)

	; Update the specified window we have created (hwnd1) with a handle to our bitmap (hdc), specifying the x,y,w,h we want it positioned on our screen
	; So this will position our gui at (0,0) with the Width and Height specified earlier
	UpdateLayeredWindow(hwnd1, hdc, 0, 0, Width, Height)

	; Select the object back into the hdc
	SelectObject(hdc, obm)

	; Now the bitmap may be deleted
	DeleteObject(hbm)

	; Also the device context related to the bitmap may be deleted
	DeleteDC(hdc)

	; The graphics may now be deleted
	Gdip_DeleteGraphics(G)
	Sleep, %delay%
	Gui, 1: Show, Hide
	Gdip_Shutdown(pToken)
}
;12
SetAlpha(hwnd, alpha) {																							;-- set alpha to a layered window

    DllCall("UpdateLayeredWindow","uint",hwnd,"uint",0,"uint",0
        ,"uint",0,"uint",0,"uint",0,"uint",0,"uint*",alpha<<16|1<<24,"uint",2)

}
;13
CircularText(Angle, Str, Width, Height, Font, Options){											;-- given a string it will generate a bitmap of the characters drawn with a given angle between each char

	;-- Given a string it will generate a bitmap of the characters drawn with a given angle between each char, if the angle is 0 it will try to make the string fill the entire circle.
	;--https://autohotkey.com/boards/viewtopic.php?t=32179
	;--by Capn Odin 23 Mai 2017

	pBitmap := Gdip_CreateBitmap(Width, Height)

	G := Gdip_GraphicsFromImage(pBitmap)

	Gdip_SetSmoothingMode(G, 4)

	if (!Angle) {
		Angle := 360 / StrLen(Str)
	}

	for i, chr in StrSplit(Str) {
		RotateAroundCenter(G, Angle, Width, Height)
		Gdip_TextToGraphics(G, chr, Options, Font, Width, Height)
	}

	Gdip_DeleteGraphics(G)

	Return pBitmap
}
;14
RotateAroundCenter(G, Angle, Width, Height) {														;-- GDIP rotate around center

	Gdip_TranslateWorldTransform(G, Width / 2, Height / 2)
	Gdip_RotateWorldTransform(G, Angle)
	Gdip_TranslateWorldTransform(G, - Width / 2, - Height / 2)

}
;Screenshot - functions maybe useful
;15
Screenshot(outfile, screen) {																					;-- screenshot function 1

    pToken := Gdip_Startup()
    raster := 0x40000000 + 0x00CC0020 ; get layered windows

    pBitmap := Gdip_BitmapFromScreen(screen, raster)

    Gdip_SetBitmapToClipboard(pBitmap)
    Gdip_SaveBitmapToFile(pBitmap, outfile)
    Gdip_DisposeImage(pBitmap)
    Gdip_Shutdown(pToken)

    PlaceTooltip("Screenshot copied and saved.")
}
;16
TakeScreenshot(dir) {																								;-- screenshot function 2

    CoordMode, Mouse, Screen
    MouseGetPos, begin_x, begin_y
    DrawRectangle(true)
    SetTimer, rectangle, 10
    KeyWait, RButton

    SetTimer, rectangle, Off
    Gui, ScreenshotSelection:Cancel
    MouseGetPos, end_x, end_y

    Capture_x := Min(end_x, begin_x)
    Capture_y := Min(end_y, begin_y)
    Capture_width := Abs(end_x - begin_x)
    Capture_height := Abs(end_y - begin_y)

    area := Capture_x . "|" . Capture_y . "|" . Capture_width . "|" Capture_height ; X|Y|W|H

    FormatTime, CurrentDateTime,, yyyy-MM-ddTHH-mm-ss

    filename := dir CurrentDateTime ".png"

    Screenshot(filename,area)

return
}
;17
CaptureWindow(hwndOwner, hwnd) {																	;-- screenshot function 3

    VarSetCapacity(RECT, 16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", &RECT)
    width  := NumGet(RECT, 8, "Int")  - NumGet(RECT, 0, "Int")
    height := NumGet(RECT, 12, "Int") - NumGet(RECT, 4, "Int")

    hdc    := DllCall("GetDC", "Ptr", 0, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdc, "UPtr")
    hBmp   := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", width, "Int", height, "UPtr")
    hdcOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBmp)

    DllCall("BitBlt", "Ptr", hdcMem
        , "Int", 0, "Int", 0, "Int", width, "Int", height
        , "Ptr", hdc, "Int", Numget(RECT, 0, "Int"), "Int", Numget(RECT, 4, "Int")
        , "UInt", 0x00CC0020) ; SRCCOPY

    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hdcOld)

    DllCall("OpenClipboard", "Ptr", hwndOwner) ; Clipboard owner
    DllCall("EmptyClipboard")
    DllCall("SetClipboardData", "uint", 0x2, "Ptr", hBmp) ; CF_BITMAP
    DllCall("CloseClipboard")

    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)

    Return True

}
;18
CaptureScreen(aRect = 0,  sFile = "", bCursor = false, nQuality = "") {					;-- screenshot function 4 - orginally from CaptureScreen.ahk

		; from: https://github.com/RaptorX/AHK-ToolKit/blob/master/lib/sc.ahk

	/*			DESCRIPTIONS AND DEPENDING FUNCTIONS

	CaptureScreen(aRect, sFileTo, bCursor, nQuality)

	1) If the optional parameter bCursor is True, captures the cursor too.
	2) If the optional parameter sFileTo is 0, set the image to Clipboard.
	   If it is omitted or "", saves to screen.bmp in the script folder,
	   otherwise to sFileTo which can be BMP/JPG/PNG/GIF/TIF.
	3) The optional parameter nQuality is applicable only when sFileTo is JPG. Set it to the desired quality level of the resulting JPG, an integer between 0 - 100.
	4) If aRect is 0/1/2/3, captures the entire desktop/active window/active client area/active monitor.
	5) aRect can be comma delimited sequence of coordinates, e.g., "Left, Top, Right, Bottom" or "Left, Top, Right, Bottom, Width_Zoomed, Height_Zoomed".
	   In this case, only that portion of the rectangle will be captured. Additionally, in the latter case, zoomed to the new width/height, Width_Zoomed/Height_Zoomed.
	Example:
	CaptureScreen(0)
	CaptureScreen(1)
	CaptureScreen(2)
	CaptureScreen(3)
	CaptureScreen("100, 100, 200, 200")
	CaptureScreen("100, 100, 200, 200, 400, 400")   ; Zoomed

	depending functions:			can be found in library
			   Unicode4Ansi	-			CoHelper.ahk
	 		   Ansi4Unicode	-			CoHelper.ahk
				    	Zoomer	-			this library or ScreenCapture.ahk
	 	 CreateDIBSection	-			Gdip_all.ahk
	  SaveHBITMAPToFile	-			this library or ScreenCapture.ahk
		 SetClipboardData	-			Gdip_all.ahk
						Convert	-			this library
	*/

	If (!aRect) {
		SysGet, nL, 76
		SysGet, nT, 77
		SysGet, nW, 78
		SysGet, nH, 79
	}
	Else If (aRect = 1)
		WinGetPos, nL, nT, nW, nH, A
	Else If (aRect = 2) 	{
		WinGet, hWnd, ID, A
		VarSetCapacity(rt, 16, 0)
		DllCall("GetClientRect" , "Uint", hWnd, "Uint", &rt)
		DllCall("ClientToScreen", "Uint", hWnd, "Uint", &rt)
		nL := NumGet(rt, 0, "int")
		nT := NumGet(rt, 4, "int")
		nW := NumGet(rt, 8)
		nH := NumGet(rt,12)
	} Else If (aRect = 3) 	{
		VarSetCapacity(mi, 40, 0)
		DllCall("GetCursorPos", "int64P", pt)
		DllCall("GetMonitorInfo", "Uint", DllCall("MonitorFromPoint", "int64", pt, "Uint", 2), "Uint", NumPut(40,mi)-4)
		nL := NumGet(mi, 4, "int")
		nT := NumGet(mi, 8, "int")
		nW := NumGet(mi,12, "int") - nL
		nH := NumGet(mi,16, "int") - nT
	} Else If (isObject(aRect)) {
		nL := aRect.Left, nT := aRect.Top, nW := aRect.Right - aRect.Left, nH := aRect.Bottom - aRect.Top
		znW := aRect.ZoomW, znH := aRect.ZoomH
	} Else {
		StringSplit, rt, aRect, `,, %A_Space%%A_Tab%
		nL := rt1, nT := rt2, nW := rt3 - rt1, nH := rt4 - rt2
		znW := rt5, znH := rt6
	}

	mDC := DllCall("CreateCompatibleDC", "Uint", 0)
	hBM := CreateDIBSection(mDC, nW, nH)
	oBM := DllCall("SelectObject", "Uint", mDC, "Uint", hBM)
	hDC := DllCall("GetDC", "Uint", 0)
	DllCall("BitBlt", "Uint", mDC, "int", 0, "int", 0, "int", nW, "int", nH, "Uint", hDC, "int", nL, "int", nT, "Uint", 0x40000000 | 0x00CC0020)
	DllCall("ReleaseDC", "Uint", 0, "Uint", hDC)
	If	bCursor
		CaptureCursor(mDC, nL, nT)
	DllCall("SelectObject", "Uint", mDC, "Uint", oBM)
	DllCall("DeleteDC", "Uint", mDC)
	If	znW && znH
		hBM := Zoomer(hBM, nW, nH, znW, znH)
	If	sFile = 0
		SetClipboardData(hBM)
	Else Convert(hBM, sFile, nQuality), DllCall("DeleteObject", "Uint", hBM)

}
{ ;depending functions for CaptureScreen()
CaptureCursor(hDC, nL, nT) {																					;-- this captures the cursor

	VarSetCapacity(mi, 20, 0)
	mi := Chr(20)
	DllCall("GetCursorInfo", "Uint", &mi)
	bShow   := NumGet(mi, 4)
	hCursor := NumGet(mi, 8)
	xCursor := NumGet(mi,12)
	yCursor := NumGet(mi,16)

	VarSetCapacity(ni, 20, 0)
	DllCall("GetIconInfo", "Uint", hCursor, "Uint", &ni)
	xHotspot := NumGet(ni, 4)
	yHotspot := NumGet(ni, 8)
	hBMMask  := NumGet(ni,12)
	hBMColor := NumGet(ni,16)

	If	bShow
		DllCall("DrawIcon", "Uint", hDC, "int", xCursor - xHotspot - nL, "int", yCursor - yHotspot - nT, "Uint", hCursor)
	If	hBMMask
		DllCall("DeleteObject", "Uint", hBMMask)
	If	hBMColor
		DllCall("DeleteObject", "Uint", hBMColor)

}
Zoomer(hBM, nW, nH, znW, znH) {																			;-- zooms a HBitmap, depending function of CaptureScreen()

	mDC1 := DllCall("CreateCompatibleDC", "Uint", 0)
	mDC2 := DllCall("CreateCompatibleDC", "Uint", 0)
	zhBM := CreateDIBSection(mDC2, znW, znH)
	oBM1 := DllCall("SelectObject", "Uint", mDC1, "Uint",  hBM)
	oBM2 := DllCall("SelectObject", "Uint", mDC2, "Uint", zhBM)
	DllCall("SetStretchBltMode", "Uint", mDC2, "int", 4)
	DllCall("StretchBlt", "Uint", mDC2, "int", 0, "int", 0, "int", znW, "int", znH, "Uint", mDC1, "int", 0, "int", 0, "int", nW, "int", nH, "Uint", 0x00CC0020)
	DllCall("SelectObject", "Uint", mDC1, "Uint", oBM1)
	DllCall("SelectObject", "Uint", mDC2, "Uint", oBM2)
	DllCall("DeleteDC", "Uint", mDC1)
	DllCall("DeleteDC", "Uint", mDC2)
	DllCall("DeleteObject", "Uint", hBM)
	Return	zhBM

}
Convert(sFileFr = "", sFileTo = "", nQuality = "") {													;-- converts from one picture format to another one, depending on Gdip restriction only .bmp, .jpg, .png is possible

	/*			DESCRIPTION AND DEPENDING FUNCTIONS

			Convert(sFileFr, sFileTo, nQuality)
			Convert("C:\image.bmp", "C:\image.jpg")
			Convert("C:\image.bmp", "C:\image.jpg", 95)
			Convert(0, "C:\clip.png")   ; Save the bitmap in the clipboard to sFileTo if sFileFr is "" or 0.

			depending functions:			can be found in library
			   Unicode4Ansi	-			CoHelper.ahk
	 		   Ansi4Unicode	-			CoHelper.ahk
	  SaveHBITMAPToFile	-			this library or ScreenCapture.ahk

	*/

	If	sFileTo  =
		sFileTo := A_ScriptDir . "\screen.bmp"
	SplitPath, sFileTo, , sDirTo, sExtTo, sNameTo

	If Not	hGdiPlus := DllCall("LoadLibrary", "str", "gdiplus.dll")
		Return	sFileFr+0 ? SaveHBITMAPToFile(sFileFr, sDirTo . "\" . sNameTo . ".bmp") : ""
	VarSetCapacity(si, 16, 0), si := Chr(1)
	DllCall("gdiplus\GdiplusStartup", "UintP", pToken, "Uint", &si, "Uint", 0)

	If	!sFileFr
	{
		DllCall("OpenClipboard", "Uint", 0)
		If	 DllCall("IsClipboardFormatAvailable", "Uint", 2) && (hBM:=DllCall("GetClipboardData", "Uint", 2))
		DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Uint", hBM, "Uint", 0, "UintP", pImage)
		DllCall("CloseClipboard")
	}
	Else If	sFileFr Is Integer
		DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "Uint", sFileFr, "Uint", 0, "UintP", pImage)
	Else	DllCall("gdiplus\GdipLoadImageFromFile", a_isunicode ? "Str" : "Uint", a_isunicode ? sFileFr : Unicode4Ansi(wFileFr,sFileFr), "UintP", pImage)

	DllCall("gdiplus\GdipGetImageEncodersSize", "UintP", nCount, "UintP", nSize)
	VarSetCapacity(ci,nSize,0)
	DllCall("gdiplus\GdipGetImageEncoders", "Uint", nCount, "Uint", nSize, "Uint", &ci)
	Loop, %	nCount
		If	InStr(a_isunicode ? StrGet(NumGet(ci,76*(A_Index-1)+44), "UTF-16") : Ansi4Unicode(NumGet(ci,76*(A_Index-1)+44)), "." . sExtTo)
		{
			pCodec := &ci+76*(A_Index-1)
			Break
		}
	If	InStr(".JPG.JPEG.JPE.JFIF", "." . sExtTo) && nQuality<>"" && pImage && pCodec
	{
	DllCall("gdiplus\GdipGetEncoderParameterListSize", "Uint", pImage, "Uint", pCodec, "UintP", nSize)
	VarSetCapacity(pi,nSize,0)
	DllCall("gdiplus\GdipGetEncoderParameterList", "Uint", pImage, "Uint", pCodec, "Uint", nSize, "Uint", &pi)
	Loop, %	NumGet(pi)
		If	NumGet(pi,28*(A_Index-1)+20)=1 && NumGet(pi,28*(A_Index-1)+24)=6
		{
			pParam := &pi+28*(A_Index-1)
			NumPut(nQuality,NumGet(NumPut(4,NumPut(1,pParam+0)+20)))
			Break
		}
	}

	If	pImage
		pCodec	? DllCall("gdiplus\GdipSaveImageToFile", "Uint", pImage, a_isunicode ? "Str" : "Uint", a_isunicode ? sFileTo : Unicode4Ansi(wFileTo,sFileTo), "Uint", pCodec, "Uint", pParam) : DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Uint", pImage, "UintP", hBitmap, "Uint", 0) . SetClipboardData(hBitmap), DllCall("gdiplus\GdipDisposeImage", "Uint", pImage)

	DllCall("gdiplus\GdiplusShutdown" , "Uint", pToken)
	DllCall("FreeLibrary", "Uint", hGdiPlus)
}
SaveHBITMAPToFile(hBitmap, sFile) {																		;-- saves a HBitmap to a file

	DllCall("GetObject", "Uint", hBitmap, "int", VarSetCapacity(oi,84,0), "Uint", &oi)
	hFile:=	DllCall("CreateFile", "Uint", &sFile, "Uint", 0x40000000, "Uint", 0, "Uint", 0, "Uint", 2, "Uint", 0, "Uint", 0)
	DllCall("WriteFile", "Uint", hFile, "int64P", 0x4D42|14+40+NumGet(oi,44)<<16, "Uint", 6, "UintP", 0, "Uint", 0)
	DllCall("WriteFile", "Uint", hFile, "int64P", 54<<32, "Uint", 8, "UintP", 0, "Uint", 0)
	DllCall("WriteFile", "Uint", hFile, "Uint", &oi+24, "Uint", 40, "UintP", 0, "Uint", 0)
	DllCall("WriteFile", "Uint", hFile, "Uint", NumGet(oi,20), "Uint", NumGet(oi,44), "UintP", 0, "Uint", 0)
	DllCall("CloseHandle", "Uint", hFile)
}
} 
;-----------------------------------------------
;19
RGBRange(x, y=0, c=0, delim=",") {																		;-- returns an array for a color transition from x to y

	; RGBRange by [VxE]

	oif := A_FormatInteger
	SetFormat, Integer, H

	dr:=(y>>16&255)-(r:=x>>16&255)
	dg:=(y>>8&255)-(g:=x>>8&255)
	db:=(y&255)-(b:=x&255)
	d := sqrt(dr**2 + dg**2 + db**2)
	v := Floor(d/c)

	IfLessOrEqual, c, 0, SetEnv, c, % d/( v := c<-3 ? -1-Ceil(c) : 2 )
			s := c/d

	cr:=sqrt(d**2-dg**2-db**2)*s*((dr>0)*2-1)
	cg:=sqrt(d**2-dr**2-db**2)*s*((dg>0)*2-1)
	cb:=sqrt(d**2-dg**2-dr**2)*s*((db>0)*2-1)

	Loop %v% {
		u := SubStr("000000" SubStr( "" . ((Round(r+cr*A_Index)&255)<<16) | ((Round(g+cg*A_Index)&255)<<8) | (Round(b+cb*A_Index)&255), 3) ,-5)
		StringUpper, u, u
		x .= delim "0x" u
	}

	SetFormat, Integer, %oif%
	return x
}
;20
getSelectionCoords(ByRef x_start, ByRef x_end, ByRef y_start, ByRef y_end) {		;-- creates a click-and-drag selection box to specify an area

	/*			EXAMPLE

				;hotkey to activate OCR
				!q:: ;press ALT Q
				getSelectionCoords(x_start, x_end, y_start, y_end)
				MsgBox, In area :: x_start: %x_start%, y_start: %y_start% --> x_end: %x_end%, y_end: %y_end%
				return

			Esc:: ExitApp

	*/

	;Mask Screen
	Gui, Color, FFFFFF
	Gui +LastFound
	WinSet, Transparent, 50
	Gui, -Caption
	Gui, +AlwaysOnTop
	Gui, Show, x0 y0 h%A_ScreenHeight% w%A_ScreenWidth%,"AutoHotkeySnapshotApp"

	;Drag Mouse
	CoordMode, Mouse, Screen
	CoordMode, Tooltip, Screen
	WinGet, hw_frame_m,ID,"AutoHotkeySnapshotApp"
	hdc_frame_m := DllCall( "GetDC", "uint", hw_frame_m)
	KeyWait, LButton, D
	MouseGetPos, scan_x_start, scan_y_start
	Loop
	{
		Sleep, 10
		KeyIsDown := GetKeyState("LButton")
		if (KeyIsDown = 1)
		{
			MouseGetPos, scan_x, scan_y
			DllCall( "gdi32.dll\Rectangle", "uint", hdc_frame_m, "int", 0,"int",0,"int", A_ScreenWidth,"int",A_ScreenWidth)
			DllCall( "gdi32.dll\Rectangle", "uint", hdc_frame_m, "int", scan_x_start,"int",scan_y_start,"int", scan_x,"int",scan_y)
		} else {
			break
		}
	}

	;KeyWait, LButton, U
	MouseGetPos, scan_x_end, scan_y_end
	Gui Destroy

	if (scan_x_start < scan_x_end)
	{
		x_start := scan_x_start
		x_end := scan_x_end
	} else {
		x_start := scan_x_end
		x_end := scan_x_start
	}

	if (scan_y_start < scan_y_end)
	{
		y_start := scan_y_start
		y_end := scan_y_end
	} else {
		y_start := scan_y_end
		y_end := scan_y_start
	}

}
;21
GetRange(ByRef x="",ByRef y="",ByRef w="",ByRef h="") {										;-- another good screen area selection function

	 ;Last edited by feiyue on 07 Jun 2018, 16:51, edited

	 SetBatchLines, -1

	  ; Save the initial state and set the current state
	  cmm:=A_CoordModeMouse
	  CoordMode, Mouse, Screen

	  ; Create canvas GUI
	  nW:=A_ScreenWidth, nH:=A_ScreenHeight
	  Gui, Canvas:New, +AlWaysOnTop +ToolWindow -Caption
	  Gui, Canvas:Add, Picture, x0 y0 w%nW% h%nH% +0xE HwndPicID

	  ; Create selection range GUI
	  Gui, Range:New, +LastFound +AlWaysOnTop -Caption +Border
		+OwnerCanvas +HwndRangeID
	  WinSet, Transparent, 50
	  Gui, Range:Color, Yellow

	  ; Screenshots to the memory image and sent to
	  ; the picture control of the canvas window.
	  Ptr:=A_PtrSize ? "UPtr":"UInt", int:="int"
	  hDC:=DllCall("GetDC", Ptr,0, Ptr)
	  mDC:=DllCall("CreateCompatibleDC", Ptr,hDC, Ptr)
	  hBM:=DllCall("CreateCompatibleBitmap", Ptr,hDC, int,nW, int,nH, Ptr)
	  oBM:=DllCall("SelectObject", Ptr,mDC, Ptr,hBM, Ptr)
	  DllCall("BitBlt", Ptr,mDC, int,0, int,0, int,nW, int,nH
		, Ptr,hDC, int,0, int,0, int,0x00CC0020|0x40000000)
	  DllCall("ReleaseDC", Ptr,0, Ptr,hDC)
	  ;---------------------
	  SendMessage, 0x172, 0, hBM,, ahk_id %PicID%
	  if ( E:=ErrorLevel )
		DllCall("DeleteObject", Ptr,E)
	  ;---------------------
	  DllCall("SelectObject", Ptr,mDC, Ptr,oBM)
	  DllCall("DeleteDC", Ptr,mDC)

	  ; Display the canvas window and start to wait for the selection range
	  Gui, Canvas:Show, NA x0 y0 w%nW% h%nH%

	  ; Prompt to hold down the LButton key
	  ListLines, Off

	  oldx:=oldy:=""
	  Loop {
		Sleep, 10
		MouseGetPos, x, y
		if (oldx=x and oldy=y)
		  Continue
		oldx:=x, oldy:=y
		;--------------------
		ToolTip, Please hold down LButton key to select a range
	  }
	  Until GetkeyState("LButton","P")

	  ; Prompt to release the LButton key
	  x1:=x, y1:=y, oldx:=oldy:=""
	  Loop {
		Sleep, 10
		MouseGetPos, x, y
		if (oldx=x and oldy=y)
		  Continue
		oldx:=x, oldy:=y
		;--------------------
		w:=Abs(x1-x), h:=Abs(y1-y)
		x:=(x1+x-w)//2, y:=(y1+y-h)//2
		Gui, Range:Show, NA x%x% y%y% w%w% h%h%
		ToolTip, Please drag the mouse and release the LButton key
	  }
	  Until !GetkeyState("LButton","P")

	  ; Prompt to click the RButton key to determine the range
	  oldx:=oldy:=""
	  Loop {
		Sleep, 10
		MouseGetPos, x, y, id
		if (id=RangeID) and GetkeyState("LButton","P")
		{
		  WinGetPos, x1, y1,,, ahk_id %RangeID%
		  Loop {
			Sleep, 100
			MouseGetPos, x2, y2
			Gui, Range:Show, % "NA x" x1+x2-x " y" y1+y2-y
		  }
		  Until !GetkeyState("LButton","P")
		}
		if (oldx=x and oldy=y)
		  Continue
		oldx:=x, oldy:=y
		;--------------------
		ToolTip, Please click the RButton key to determine the scope`,`n
		and use the LButton key can adjust the scope
	  }
	  Until GetkeyState("RButton","P")
	  KeyWait, RButton
	  ToolTip
	  ListLines, On

	  ; Clean the canvas and selection range GUI
	  WinGetPos, x, y, w, h, ahk_id %RangeID%
	  Gui, Range:Destroy
	  Gui, Canvas:Destroy

	  ; Clean the memory image and restore the initial state
	  DllCall("DeleteObject", Ptr,hBM)
	  CoordMode, Mouse, %cmm%

}
;22
FloodFill(x, y, target, replacement, mode=1, key="") {											;-- filling an area using color banks

	;function is from https://rosettacode.org/wiki/Bitmap/Flood_fill#AutoHotkey

	/*				Example

		SetBatchLines, -1
		CoordMode, Mouse
		CoordMode, Pixel
		CapsLock::
		KeyWait, CapsLock
		MouseGetPos, X, Y
		PixelGetColor, color, X, Y
		FloodFill(x, y, color, 0x000000, 1, "CapsLock")
		MsgBox Done!
		Return

	*/

   If GetKeyState(key, "P")
      Return
   PixelGetColor, color, x, y
   If (color <> target || color = replacement || target = replacement)
      Return
   VarSetCapacity(Rect, 16, 0)
   NumPut(x, Rect, 0)
   NumPut(y, Rect, 4)
   NumPut(x+1, Rect, 8)
   NumPut(y+1, Rect, 12)
   hDC := DllCall("GetDC", UInt, 0)
   hBrush := DllCall("CreateSolidBrush", UInt, replacement); 
   DllCall("FillRect", UInt, hDC, Str, Rect, UInt, hBrush)
   DllCall("ReleaseDC", UInt, 0, UInt, hDC)
   DllCall("DeleteObject", UInt, hBrush)
   FloodFill(x+1, y, target, replacement, mode, key)
   FloodFill(x-1, y, target, replacement, mode, key)
   FloodFill(x, y+1, target, replacement, mode, key)
   FloodFill(x, y-1, target, replacement, mode, key)
   If (mode = 2 || mode = 4)
      FloodFill(x, y, target, replacement, mode, key)
   If (Mode = 3 || mode = 4)
   {
      FloodFill(x+1, y+1, target, replacement, key)
      FloodFill(x-1, y+1, target, replacement, key)
      FloodFill(x+1, y-1, target, replacement, key)
      FloodFill(x-1, y-1, target, replacement, key)
   }
}
;23
CreateBMPGradient(File, RGB1, RGB2, Vertical=1) {												;-- Horizontal/Vertical gradient

	; SKAN: http://www.autohotkey.com/forum/viewtopic.php?p=61081#61081

	; Left/Bottom -> Right/Top color, File is overwritten
	   If Vertical
		 H:="424d3e000000000000003600000028000000010000000200000001001800000000000800000000000000000000000000000000000000"
		   . BGR(RGB1) "00" BGR(RGB2) "00"
	   Else
		 H:="424d3e000000000000003600000028000000020000000100000001001800000000000800000000000000000000000000000000000000"
		   . BGR(RGB1) BGR(RGB2) "0000"

	   Handle:= DllCall("CreateFile",Str,file,Uint,0x40000000,Uint,0,UInt,0,UInt,4,Uint,0,UInt,0)

	   Loop 62 {
		 Hex := "0x" SubStr(H,2*A_Index-1,2)
		 DllCall("WriteFile", UInt,Handle, UCharP,Hex, UInt,1, UInt,0, UInt,0)
		}

	   DllCall("CloseHandle", "Uint", Handle)

}
{ ;depending function
BGR(RGB) {																										;-- BGR() subfunction from CreateBMPGradient()

	RGB = 00000%RGB%
		Return SubStr(RGB,-1) . SubStr(RGB,-3,2) . SubStr(RGB,-5,2)

}
} 
;24
CreatePatternBrushFrom(hbm, x, y, w, h) {																;-- as it says

	;found on https://autohotkey.com/board/topic/20588-adding-pictures-to-controls-eg-as-background/page-3

    hbm1 := DllCall("CopyImage","uint",hbm,"uint",0,"int",0,"int",0,"uint",0x2000)

    VarSetCapacity(dib,84,0)
    DllCall("GetObject","uint",hbm1,"int",84,"uint",&dib)
    NumPut(h,NumPut(w,dib,28))
    hbm2 := DllCall("CreateDIBSection","uint",0,"uint",&dib+24,"uint",0,"uint*",0,"uint",0,"uint",0)

    Loop, 2 {
        hdc%A_Index% := DllCall("CreateCompatibleDC","uint",0)
        obm%A_Index% := DllCall("SelectObject","uint",hdc%A_index%,"uint",hbm%A_Index%)
    }

    DllCall("BitBlt"
        ,"uint",hdc2,"int",0,"int",0,"int",w,"int",h    ; destination
        ,"uint",hdc1,"int",x,"int",y                    ; source
        ,"uint",0xCC0020)                               ; operation = SRCCOPY

    Loop, 2 {
        DllCall("SelectObject","uint",hdc%A_Index%,"uint",obm%A_Index%)
        DllCall("DeleteDC","uint",hdc%A_Index%)
    }

    hbr := DllCall("CreatePatternBrush","uint",hbm2)
    DllCall("DeleteObject","uint",hbm2)
    DllCall("DeleteObject","uint",hbm1)
    return hbr
}
;25
ResConImg(OriginalFile, NewWidth:="", NewHeight:="", NewName:="",				;-- Resize and convert images. png, bmp, jpg, tiff, or gif 
NewExt:="", NewDir:="", PreserveAspectRatio:=true, BitDepth:=24) {
    
    /*  ResConImg
         *    By kon
         *    Updated November 2, 2015
         *    http://ahkscript.org/boards/viewtopic.php?f=6&t=2505
         *
         *  Resize and convert images. png, bmp, jpg, tiff, or gif.
         *
         *  Requires Gdip.ahk in your Lib folder or #Included. Gdip.ahk is available at:
         *      http://www.autohotkey.com/board/topic/29449-gdi-standard-library-145-by-tic/
         *     
         *  ResConImg( OriginalFile             ;- Path of the file to convert
         *           , NewWidth                 ;- Pixels (Blank = Original Width)
         *           , NewHeight                ;- Pixels (Blank = Original Height)
         *           , NewName                  ;- New file name (Blank = "Resized_" . OriginalFileName)
         *           , NewExt                   ;- New file extension can be png, bmp, jpg, tiff, or gif (Blank = Original extension)
         *           , NewDir                   ;- New directory (Blank = Original directory)
         *           , PreserveAspectRatio      ;- True/false (Blank = true)
         *           , BitDepth)                ;- 24/32 only applicable to bmp file extension (Blank = 24)
     */
    SplitPath, OriginalFile, SplitFileName, SplitDir, SplitExtension, SplitNameNoExt, SplitDrive
    pBitmapFile := Gdip_CreateBitmapFromFile(OriginalFile)                  ; Get the bitmap of the original file
    Width := Gdip_GetImageWidth(pBitmapFile)                                ; Original width
    Height := Gdip_GetImageHeight(pBitmapFile)                              ; Original height
    NewWidth := NewWidth ? NewWidth : Width
    NewHeight := NewHeight ? NewHeight : Height
    NewExt := NewExt ? NewExt : SplitExtension
    if SubStr(NewExt, 1, 1) != "."                                          ; Add the "." to the extension if required
        NewExt := "." NewExt
    NewPath := ((NewDir != "") ? NewDir : SplitDir)                         ; NewPath := Directory
            . "\" ((NewName != "") ? NewName : "Resized_" SplitNameNoExt)       ; \File name
            . NewExt                                                            ; .Extension
    if (PreserveAspectRatio) {                                              ; Recalcultate NewWidth/NewHeight if required
        if ((r1 := Width / NewWidth) > (r2 := Height / NewHeight))          ; NewWidth/NewHeight will be treated as max width/height
            NewHeight := Height / r1
        else
            NewWidth := Width / r2
    }
    pBitmap := Gdip_CreateBitmap(NewWidth, NewHeight                        ; Create a new bitmap
    , (SubStr(NewExt, -2) = "bmp" && BitDepth = 24) ? 0x21808 : 0x26200A)   ; .bmp files use a bit depth of 24 by default
    G := Gdip_GraphicsFromImage(pBitmap)                                    ; Get a pointer to the graphics of the bitmap
    Gdip_SetSmoothingMode(G, 4)                                             ; Quality settings
    Gdip_SetInterpolationMode(G, 7)
    Gdip_DrawImage(G, pBitmapFile, 0, 0, NewWidth, NewHeight)               ; Draw the original image onto the new bitmap
    Gdip_DisposeImage(pBitmapFile)                                          ; Delete the bitmap of the original image
    Gdip_SaveBitmapToFile(pBitmap, NewPath)                                 ; Save the new bitmap to file
    Gdip_DisposeImage(pBitmap)                                              ; Delete the new bitmap
    Gdip_DeleteGraphics(G)                                                  ; The graphics may now be deleted
}
;26
CreateCircleProgress(diameter:=50,thickness:=5,color:=0x99009933,               	;-- very nice to see functions for a circle progress
xPos:="center",yPos:="center",guiId:=1) {
	
	; from Learning one
	; https://autohotkey.com/boards/viewtopic.php?t=6947
	
	/* Example scripts
	
		############## Example1
		
		#Include, Gdip.ahk ; http://www.autohotkey.com/board/topic/29449-gdi-standard-library-145-by-tic/
		;#Include progressCircle.ahk

		If !pToken := Gdip_Startup() {
			MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
			ExitApp
		}

		circleObj := CreateCircleProgress(50,5)
		Loop, 100 {
			UpdateCircleProgress(circleObj,A_Index)
			Sleep, 10
		}
		DestroyCircleProgress(circleObj)

		Gdip_Shutdown(pToken)
		ExitApp
		
		############## Example2
		
		#Include, Gdip.ahk ; http://www.autohotkey.com/board/topic/29449-gdi-standard-library-145-by-tic/
	;#Include progressCircle.ahk

	If !pToken := Gdip_Startup() {
		MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
		ExitApp
	}

	DownloadFile("http://download-installer.cdn.mozilla.net/pub/firefox/releases/26.0/win32/en-US/Firefox%20Setup%2026.0.exe", "firefox_setup.exe")

	Gdip_Shutdown(pToken)
	ExitApp

	DownloadFile(UrlToFile, SaveFileAs, Overwrite := True, UseProgressBar := True) {
		;Check if the file already exists and if we must not overwrite it
		  If (!Overwrite && FileExist(SaveFileAs))
			  Return
		;Check if the user wants a progressbar
		  If (UseProgressBar) {
			  ;Initialize the WinHttpRequest Object
				WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
			  ;Download the headers
				WebRequest.Open("HEAD", UrlToFile)
				WebRequest.Send()
			  ;Store the header which holds the file size in a variable:
				FinalSize := WebRequest.GetResponseHeader("Content-Length")
			  ;Create the progressbar and the timer
				Progress, H80, , Downloading..., %UrlToFile%
				circleObj := CreateCircleProgress(450,60)
				SetTimer, __UpdateProgressBar, 100
		  }
		;Download the file
		  UrlDownloadToFile, %UrlToFile%, %SaveFileAs%
		;Remove the timer and the progressbar because the download has finished
		  If (UseProgressBar) {
			  Progress, Off
			  SetTimer, __UpdateProgressBar, Off
			  DestroyCircleProgress(circleObj)
		  }
		Return
		
		;The label that updates the progressbar
		  __UpdateProgressBar:
			  ;Get the current filesize and tick
				CurrentSize := FileOpen(SaveFileAs, "r").Length ;FileGetSize wouldn't return reliable results
				CurrentSizeTick := A_TickCount
			  ;Calculate the downloadspeed
				Speed := Round((CurrentSize/1024-LastSize/1024)/((CurrentSizeTick-LastSizeTick)/1000)) . " Kb/s"
			  ;Save the current filesize and tick for the next time
				LastSizeTick := CurrentSizeTick
				LastSize := FileOpen(SaveFileAs, "r").Length
			  ;Calculate percent done
				PercentDone := Round(CurrentSize/FinalSize*100)
			  ;Update the ProgressBar
				Progress, %PercentDone%, %PercentDone%`% Done, Downloading...  (%Speed%), Downloading %SaveFileAs% (%PercentDone%`%)
				UpdateCircleProgress(circleObj,percentDone)
		  Return
		}
	
	*/
	
    width := height := diameter+thickness*2
    xPos := (xPos=="center" ? A_ScreenWidth/2-diameter/2-thickness : xPos)
    yPos := (yPos=="center" ? A_ScreenHeight/2-diameter/2-thickness : yPos)
    Gui, %guiId%: -Caption +E0x80000 +LastFound +AlwaysOnTop +ToolWindow +OwnDialogs
    Gui, %guiId%: Show, NA
    
    hwnd := WinExist()
    hbm := CreateDIBSection(width, height)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
    Gdip_SetSmoothingMode(G, 4)
    
    pen:=Gdip_CreatePen(color, thickness)
    Gdip_SetCompositingMode(G, 1)
    Return {hwnd:hwnd, hdc:hdc, obm:obm, hbm:hbm, pen:pen, G:G, diameter: diameter, thickness:thickness, xPos:xPos, yPos:yPos, width:width, height:height}
}
{ ; sub CreateCircleProgress
UpdateCircleProgress(circleObj,percent) {
    Gdip_Drawarc(circleObj.G, circleObj.pen, circleObj.thickness, circleObj.thickness, circleObj.diameter, circleObj.diameter, 270, 360/100*percent)
    UpdateLayeredWindow(circleObj.hwnd, circleObj.hdc, circleObj.xPos, circleObj.yPos, circleObj.width, circleObj.height)
}
DestroyCircleProgress(circleObj) {
    Gui % circleObj.hwnd ":Destroy"
    SelectObject(circleObj.hdc, circleObj.obm)
    DeleteObject(circleObj.hbm)
    DeleteDC(circleObj.hdc)
    Gdip_DeleteGraphics(circleObj.G)
}
} 
;27
RGBrightnessToHex(r := 0, g := 0, b := 0, brightness := 1) {                                  	;-- transform rbg (with brightness) values to hex 
	;https://autohotkey.com/boards/viewtopic.php?f=6&p=191294
	return (b * brightness << 16) + (g * brightness << 8) + (r * brightness)
}
;28
GetHueColorFromFraction(hue, brightness := 1) {                                                 ;-- get hue color from fraction. example: h(0) is red, h(1/3) is green and h(2/3) is blue
	
	;https://autohotkey.com/boards/viewtopic.php?f=6&p=191294
	if (hue<0,hue:=abs(mod(hue, 1)))
		hue:=1-hue
	Loop 3
		col+=max(min(-8*abs(mod(hue+A_Index/3-0.5,1)-0.5)+2.5,1),0)*255*brightness<<16-(A_Index-1)*8
	return col
}
;29
SaveHBITMAPToFile(hBitmap, sFile) {																		;-- saves the hBitmap to a file
	DllCall("GetObject", "Uint", hBitmap, "int", VarSetCapacity(oi,84,0), "Uint", &oi)
	hFile:=	DllCall("CreateFile", "Uint", &sFile, "Uint", 0x40000000, "Uint", 0, "Uint", 0, "Uint", 2, "Uint", 0, "Uint", 0)
	DllCall("WriteFile", "Uint", hFile, "int64P", 0x4D42|14+40+NumGet(oi,44)<<16, "Uint", 6, "UintP", 0, "Uint", 0)
	DllCall("WriteFile", "Uint", hFile, "int64P", 54<<32, "Uint", 8, "UintP", 0, "Uint", 0)
	DllCall("WriteFile", "Uint", hFile, "Uint", &oi+24, "Uint", 40, "UintP", 0, "Uint", 0)
	DllCall("WriteFile", "Uint", hFile, "Uint", NumGet(oi,20), "Uint", NumGet(oi,44), "UintP", 0, "Uint", 0)
	DllCall("CloseHandle", "Uint", hFile)
}
;30
DrawRotatePictureOnGraphics(G,pBitmap,x,y,size,angle)	{									;-- rotate a pBitmap
	;X and Y describe the new center of the model  - https://autohotkey.com/board/topic/95329-tower-defense-game-in-ahk/
dist:=(((size/2)**2)*2)**0.5
VarSetCapacity(Points,24,0)
numput(round(sin((45+angle)*0.01745329252)*dist+x),Points,0,"float")
numput(round(cos((45+angle)*0.01745329252)*dist+y),Points,4,"float")
numput(round(sin((135+angle)*0.01745329252)*dist+x),Points,8,"float")
numput(round(cos((135+angle)*0.01745329252)*dist+y),Points,12,"float")
numput(round(sin((315+angle)*0.01745329252)*dist+x),Points,16,"float")
numput(round(cos((315+angle)*0.01745329252)*dist+y),Points,20,"float")
;Msgbox %  "x1:" numget(Points,0,"float") "y1:" numget(Points,4,"float") "x2:" numget(Points,8,"float")"y2:" numget(Points,12,"float") "x3:" numget(Points,16,"float") "y3:" numget(Points,20,"float")
DllCall("gdiplus\GdipDrawImagePointsRect", "uint", G, "uint", pBitmap
	, "ptr", &Points, "int", 3, "float", 0, "float", 0
	, "float", size, "float", size
	, "int", 2, "uint", 0, "uint", 0, "uint", 0)
}
;31
CopyBitmapOnGraphic(pGraphics,pBitmap,w,h) {													;-- copy a pBitmap of a specific width and height to the Gdip graphics container (pGraphics)
return DllCall("gdiplus\GdipDrawImageRectRect", "uint", pGraphics, "uint", pBitmap
	, "float", 0, "float", 0, "float", w, "float", h
	, "float", 0, "float", 0, "float", w, "float", h
	, "int", 2, "uint", 0, "uint", 0, "uint", 0)
}
;32
GDI_GrayscaleBitmap( hBM ) {               																	;-- Converts GDI bitmap to 256 color GreyScale

	; www.autohotkey.com/community/viewtopic.php?t=88996    By SKAN,  Created : 19-Jul-2012

	Static RGBQUAD256  

	If ! VarSetCapacity( RGBQUAD256 ) {
		VarSetCapacity( RGBQUAD256, 256*4, 0 ),  Color := 0
		Loop 255
			Numput( Color := Color + 0x010101, RGBQUAD256, A_Index*4, "UInt" )
	}

	VarSetCapacity( BM,24,0 ),  DllCall( "GetObject", UInt,hBM, UInt,24, UInt,&BM )
	W := NumGet( BM,4 ), H := NumGet( BM,8 )

	hdcSrc := DllCall( "CreateCompatibleDC", UInt,0 )
	hbmPrS := DllCall( "SelectObject", UInt,hdcSrc, UInt,hBM )

	dBM := DllCall( "CopyImage", UInt
				, DllCall( "CreateBitmap", Int,2, Int,2, UInt,1, UInt,8, UInt,0 )
				, UInt,0, Int,W, Int,H, UInt,0x2008, UInt )

	hdcDst  := DllCall( "CreateCompatibleDC", UInt,0 )
	hbmPrD  := DllCall( "SelectObject", UInt,hdcDst, UInt,dBM )
	DllCall( "SetDIBColorTable", UInt,hdcDst, UInt,0, UInt,256, UInt,&RGBQUAD256 )

	DllCall( "BitBlt", UInt,hdcDst, Int,0, Int,0, Int,W, Int,H
                  , UInt,hdcSrc, Int,0, Int,0, UInt,0x00CC0020 )

	DllCall( "SelectObject", UInt,hdcSrc, UInt,hbmPrS )
	DllCall( "DeleteDC",     UInt,hdcSrc )
	DllCall( "SelectObject", UInt,hdcSrc, UInt,hbmPrD )
	DllCall( "DeleteDC",     UInt,hdcDst )

Return dBM
}
;33
Convert_BlackWhite(InputImage, OutputImage) {													;-- Convert exist imagefile to black&white , it uses machine code
	
	/*
			; Best speed
			MCode(blackwhite, "518B4424188B4C24149983E20303C2C1F80285C90F8E820000008B542"
			. "40C535503C05603C0578B7C24208944241089542428894C242485FF7E"
			. "4C8B7424182B74241C8B04168BD8C1FB108BE8C1FD0881E3FF0000008"
			. "1E5FF0000008BC803DD25FF00000003D881E1000000FF81FB7E0100007"
			. "C0681C1FFFFFF00890A83C2044F75C08B7C24208B54242803542410FF4C"
			. "242489542428759E5F5E5D5B33C059C3")

			; Smallest size
			MCode(blackwhite, "558BEC8B45188B4D149983E20383EC0C03C285C97E7753568B75"
			. "0C83E0FC578945F4897514894DFCBAFF0000008B4D1085C97E488"
			. "B45082B450C894D188945F8EB038B45F88B04308BF8C1FF108BD8C"
			. "1FB0823FA23DA8BC803FB23C203F881E1000000FF81FF7E0100007C0"
			. "681C1FFFFFF00890E83C604FF4D1875C68B75140375F4FF4DFC89751"
			. "475A35F5E5B33C0C9C3")
	*/
	
    global blackwhite
    SetBatchLines, -1
    If !pToken := Gdip_Startup()
        {
 	   MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
 	   ExitApp
        }
    InputFile = %InputImage%
    OutputFile = %OutputImage%
    pBitmap := Gdip_CreateBitmapFromFile(InputFile)

    MCode(blackwhite, "518B4424188B4C24149983E20303C2C1F80285C90F8E820000008B54240C535503C05603C0578B7C24208944241089542428894C242"
    . "485FF7E4C8B7424182B74241C8B04168BD8C1FB108BE8C1FD0881E3FF00000081E5FF0000008BC803DD25FF00000003D881E1000000FF81FB7E010000"
    . "7C0681C1FFFFFF00890A83C2044F75C08B7C24208B54242803542410FF4C242489542428759E5F5E5D5B33C059C3")
    ;Get the width and height of the picture, this never changes
    Width := Gdip_GetImageWidth(pBitmap)*2, Height := Gdip_GetImageHeight(pBitmap)
    ;Create a blank bitmap to store the new image in
    pBitmapOut := Gdip_CreateBitmap(Width//2, Height)
    ;Some more good stuff
    hbm := CreateDIBSection(Width, Height), hdc := CreateCompatibleDC(), obm := SelectObject(hdc, hbm)
    G := Gdip_GraphicsFromHDC(hdc)
    Gdip_DrawImage(G, pBitmap, 0, 0, Width, Height, 0, 0, Width, Height)
    BlackWhite(pBitmap, pBitmapOut, Width//2, Height)
    Gdip_DrawImage(G, pBitmapOut, Width//2, 0, Width, Height, 0, 0, Width, Height)
    Gdip_SaveBitmapToFile(pBitmapOut, OutputFile)
    Gdip_DisposeImage(pBitmapOut), Gdip_DisposeImage(pBitmap)
    SelectObject(hdc, obm), DeleteObject(hbm), DeleteDC(hdc)
    Gdip_DeleteGraphics(G)
    Gdip_Shutdown(pToken)


    return
}
 ;{ sub from Convert_BlackWhite
 BlackWhite(pBitmap, ByRef pBitmapOut, Width, Height)       {
           global blackwhite
           E1 := Gdip_LockBits(pBitmap, 0, 0, Width, Height, Stride1, Scan01, BitmapData1)
           E2 := Gdip_LockBits(pBitmapOut, 0, 0, Width, Height, Stride2, Scan02, BitmapData2) 
           R := DllCall(&blackwhite, "uint", Scan01, "uint", Scan02, "int", Width, "int", Height, "int", Stride1)
           Gdip_UnlockBits(pBitmap, BitmapData1), Gdip_UnlockBits(pBitmapOut, BitmapData2)
           return (R)
        }
MCode(ByRef code, hex) ; allocate memory and write Machine Code there  { 
 	  VarSetCapacity(code,StrLen(hex)//2)
 	  Loop % StrLen(hex)//2
          NumPut("0x" . SubStr(hex,2*A_Index-1,2), code, A_Index-1, "Char")
        }
;34
getHBMinfo( hBM ) {
Local SzBITMAP := ( A_PtrSize = 8 ? 32 : 24 ),  BITMAP := VarSetCapacity( BITMAP, SzBITMAP )       
  If DllCall( "GetObject", "Ptr",hBM, "Int",SzBITMAP, "Ptr",&BITMAP )
    Return {  Width:      Numget( BITMAP, 4, "UInt"  ),  Height:     Numget( BITMAP, 8, "UInt"  ) 
           ,  WidthBytes: Numget( BITMAP,12, "UInt"  ),  Planes:     Numget( BITMAP,16, "UShort") 
           ,  BitsPixel:  Numget( BITMAP,18, "UShort"),  bmBits:     Numget( BITMAP,20, "UInt"  ) }
}       

} 
;|														|														|														|														|
;|	LoadPicture()								|	GetImageDimensionProperty		|	GetImageDimensions()				|	Gdip_FillRoundedRectangle()		|
;|	Redraw(hwnd=0)							|	CreateSurface()							|	ShowSurface()								|	HideSurface()								|
;|	WipeSurface()								|	StartDraw()									|	EndDraw()									|	SetPen()										|
;|	DrawLine()									|	SDrawRectangle()						|	SetAlpha()									|	DrawRectangle()							|
;|	Highlight()									|	Screenshot()									|	TakeScreenshot()							|	CaptureWindow()							|
;|	CaptureScreen()							|	CaptureCursor()							|	Zoomer()										|	Convert()										|
;|	SaveHBITMAPToFile()					|	DrawFrameAroundControl			|	CircularText()								|	RotateAroundCenter()					|
;|	RGBRange()									|	getSelectionCoords()					|	GetRange()									|	FloodFill()										|
;|	CreateBMPGradient()					|	CreatePatternBushFrom()			|	ResConImg()								|   CreateCircleProgress()					|
;|   RGBrightnessToHex()               	|   GetHueColorFromFraction()     	|   SaveHBITMAPToFile()                	|   DrawRotatePictureOnGraphics	|
;|   CopyBitmapOnGraphic()          	|   GDI_GrayscaleBitmap()            	|  Convert_BlackWhite()                 	|   getHBMinfo()                            	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;GUI/WINDOW FUNCTIONS SECTION (211)

{ ;Gui - Customizable full gui functions, custom gui elements (22)

HtmlBox(Html, Title="", Timeout=0, Permanent=False,											;-- Gui with ActiveX - Internet Explorer - Control
GUIOptions="Resize MaximizeBox Minsize420x320",
ControlOptions="W400 H300", Margin=10, Hotkey=True) {

    ;AutoHotkey_L 1.1.04+
    ;Timeout : The seconds to make the HTML window disappear.
    ;Permanent : if this is True, closing the GUI window does not destroy it but it is hidden.
    ;Return Value: the handle of the created window(Hwnd).

    static HtmlBoxInfo := [], WindowHideStack := [] , WB , ExecCmd := { a : "selectall", c : "copy",  p : "print", v : "paste" }
    Gui, New, LabelHtmlBox HWNDHwndHtml %GUIOptions%, % Title     ;v1.1.04+
    Gui, Margin, %Margin%, %Margin%
    Gui, Add, ActiveX, vWB HwndHwndHtmlControl %ControlOptions%, Shell.Explorer    ;v1.1.03+
    WB.silent := true
    WB.Navigate("about:blank")
    Loop
       Sleep 10
    Until   (WB.readyState=4 && WB.document.readyState="complete" && !WB.busy)
    WB.document.write(html)
    Gui, Show
    If Timeout {
        ExecuteTime := A_TickCount + Timeout * 1000
        loop % (WindowHideStack.MaxIndex() ? WindowHideStack.MaxIndex() + 1 : 1) {
            if (!(WindowHideStack[A_Index].ExecuteTime) && (A_Index = 1)) || (WindowHideStack[A_Index].ExecuteTime > ExecuteTime) {
                Inserted := True, WindowHideStack.Insert(A_Index, { ExecuteTime: ExecuteTime, Hwnd : HwndHtml })    ;increment the rest
                if (A_Index = 1)
                    SetTimer, HtmlBoxClose, % Timeout * -1 * 1000
            }
        } Until (Inserted)
        if !Inserted
            WindowHideStack.Insert({ ExecuteTime: ExecuteTime, Hwnd : HwndHtml })    ;insert it at the very end
    }
    HtmlBoxInfo[HwndHtml] := { HwndWindow : HwndHtml, Margin : Margin, HwndHtmlControl : HwndHtmlControl, Permanent: Permanent, doc : WB.document }
    If Hotkey {
        Hotkey, IfWinActive, ahk_id %HwndHtml%
        For key in ExecCmd
            Hotkey, ^%key%, HtmlBoxExecCommand
        Hotkey, IfWinActive
    }
Return HwndHtml
    HtmlBoxSize:
        If (A_EventInfo = 1)  ; The window has been minimized.  No action needed.
            Return
        GuiControl, Move, % HtmlBoxInfo[Trim(A_GUI)].HwndHtmlControl
                  , % "H" (A_GuiHeight - HtmlBoxInfo[A_GUI].margin * 2) " W" ( A_GuiWidth - HtmlBoxInfo[A_GUI].margin * 2)
    Return
    HtmlBoxEscape:
    HtmlBoxClose:
        if (_HwndHtml := WindowHideStack[WindowHideStack.MinIndex()].Hwnd)  {     ;this means it's called from the timer, so the least index is removed
            WindowHideStack.Remove(WindowHideStack.MinIndex())
            if (NextTimer := WindowHideStack[WindowHideStack.MinIndex()].ExecuteTime)        ;this means a next timer exists
                SetTimer,, % A_TickCount - NextTimer < 0 ? A_TickCount - NextTimer : -1        ;v1.1.01+
        } else
            _HwndHtml := HtmlBoxInfo[A_GUI].HwndWindow
        DHW := A_DetectHiddenWindows
        DetectHiddenWindows, ON
        if WinExist("ahk_id " _HwndHtml) {        ;in case timeout is set and the user closes before the timeout
            if !HtmlBoxInfo[_HwndHtml].Permanent {
                Gui, %_HwndHtml%:Destroy
                WB := ""
                HtmlBoxInfo.Remove(_HwndHtml, "")
            } else
                Gui, %_HwndHtml%:Hide
        }
        DetectHiddenWindows, % DHW
    Return
    HtmlBoxExecCommand:        ;this is called when the user presses one of the hotkeys
        HtmlBoxInfo[WinExist("A")].doc.ExecCommand(ExecCmd[SubStr(A_ThisHotkey, 2)])
    Return
}

EditBox(Text, Title="", Timeout=0, Permanent=False, 											;-- Displays an edit box with the given text, tile, and options
GUIOptions="Resize MaximizeBox Minsize420x320",
ControlOptions="VScroll W400 H300", Margin=10) {

    ;AutoHotkey_L 1.1.04+
    ;Timeout : The seconds to make the edit window disappear.
    ;Permanent : if this is True, closing the GUI window does not destroy it but it is hidden.
    ;Return Value: the handle of the created window(Hwnd).

	/*											Description

		Displays an edit box with the given text, tile, and options.

		Requirements
		AutoHotkey_L 1.1.04 or later.  Tested on: Windows 7 64bit, AutoHotkey 32bit Unicode 1.1.05.01.

		License
		Public Domain.

		Format
		EditBox(Text, Title="", Timeout=0, Permanent=False, GUIOptions="Resize MaximizeBox Minsize420x320", ControlOptions="VScroll W400 H300", Margin=10)
		Parameters
		Text : 					the text strings to display in the edit box.
		Title : 					the title for the GUI window.
		Timeout : 				if specified, the edit box will disappear in the given seconds.
		Permanent : 			if this is TRUE, closing the window does not destroy the window but hide it. So it can be displayed again with the window handle.
		GUIOptions : 		the options for the Edit box GUI window.
		ControlOptions : 	the options for the Edit control.
		Margin : 				the margin in pixels between the window borders and the control.

		Return Value
		The window handle (hwnd) of the created GUI window.

		Remarks
		No global variables are used. However, it uses these label names: EditBoxClose, EditBoxEscape, EditBoxResize. So the script should avoid using the label names.

	*/

	/*												Example

				Text =
		(
			Copyright 2011 A_Samurai. All rights reserved.

			Redistribution and use in source and binary forms, with or without modification, are
			permitted provided that the following conditions are met:

			   1. Redistributions of source code must retain the above copyright notice, this list of
				  conditions and the following disclaimer.

			   2. Redistributions in binary form must reproduce the above copyright notice, this list
				  of conditions and the following disclaimer in the documentation and/or other materials
				  provided with the distribution.

			THIS SOFTWARE IS PROVIDED BY A_Samurai ''AS IS'' AND ANY EXPRESS OR IMPLIED
			WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
			FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL A_Samurai OR
			CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
			CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
			SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
			ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
			NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
			ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

			The views and conclusions contained in the software and documentation are those of the
			authors and should not be interpreted as representing official policies, either expressed
			or implied, of A_Samurai.
		)
		EditBox(Text, "Free BSD Licence")

	*/


    Static EditBoxInfo := [], WindowHideStack := []
    Gui, New, LabelEditBox HWNDHwndEdit %GUIOptions%, % Title     ;v1.1.04+
    Gui, Margin, %Margin%, %Margin%
    Gui, Add, Edit, HwndHwndEditControl %ControlOptions%, % Text
    ControlFocus,, ahk_id %HwndEditControl%
    Gui, Show
    If Timeout {
        WindowHideStack[A_TickCount + Timeout * 1000] := HwndEdit
        SetTimer, EditBoxClose, % Timeout * -1 * 1000
    }
    EditBoxInfo[HwndEdit] := { HwndWindow : HwndEdit, Margin : Margin, HwndEditControl : HwndEditControl }
Return HwndEdit

    EditBoxSize:
        If (A_EventInfo = 1)  ; The window has been minimized.  No action needed.
            Return
        GuiControl, Move, % EditBoxInfo[Trim(A_GUI)].HwndEditControl
                  , % "H" (A_GuiHeight - EditBoxInfo[A_GUI].margin * 2) " W" ( A_GuiWidth - EditBoxInfo[A_GUI].margin * 2)
    Return
    EditBoxEscape:
    EditBoxClose:
        if (HwndEdit := WindowHideStack.Remove(WindowHideStack.MinIndex(), "")) { ;this means it's called from the timer, so the least index is removed
            if (NextTimer := WindowHideStack.MinIndex())        ;this means a next timer exists
                SetTimer,, % A_TickCount - NextTimer < 0 ? A_TickCount - NextTimer : -1        ;v1.1.01+
        } else
            HwndEdit := EditBoxInfo[A_GUI].HwndWindow
        if !Permanent {
            Gui, %HwndEdit%:Destroy
            EditBoxInfo.Remove(HwndEdit, "")
        } else
            Gui, %HwndEdit%:Hide
    Return
}

Popup(title, action, close=true, image="", w=197, h=46) {										;-- Splashtext Gui

    SysGet, Screen, MonitorWorkArea
    ScreenRight-=w+3
    ScreenBottom-=h+4
    SplashImage,%image%,CWe0dfe3 b1 x%ScreenRight% y%ScreenBottom% w%w% h%h% C00 FM8 FS8, %action%,%title%,Popup
    WinSet, Transparent, 216, Popup
    if close
        SetTimer, ClosePopup, -2000
    return
}
ClosePopup: { ;
    WinGet,WinID,ID,Popup
    MouseGetPos,,,MouseWinID
    ifEqual,WinID,%MouseWinID%
    {
        SetTimer, ClosePopup, -2000
    }else{
        SplashImage, Off
    }
    return

} 

PIC_GDI_GUI(GuiName, byref File, GDIx, GDIy , GDIw, GDIh) { 								;-- a GDI-gui to show a picture

				global GGhdc
			If !pToken := Gdip_Startup() {
			   MsgBox, 0x40048, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
			   ExitApp
			}
			; Create a layered window (+E0x80000 : must be used for UpdateLayeredWindow to work!) that is always on top (+AlwaysOnTop), has no taskbar entry or caption
			Gui, %GuiName%:-Caption +E0x80000 +LastFound +AlwaysOnTop
			Gui, %GuiName%:+Owner
			Gui, %GuiName%: Show, Center ; x%GDIx% y%GDIy%

			hwnd1 := WinExist()

			pBitmap1 := Gdip_CreateBitmapFromFile(file)
			; Check to ensure we actually got a bitmap from the file, in case the file was corrupt or some other error occured
			If (!pBitmap1) {
				MsgBox, 0x40048, File loading error!, Could not load '%file%'
				ExitApp
			}
			;Load picture to pBitmap
			IWidth := Gdip_GetImageWidth(pBitmap1), IHeight := Gdip_GetImageHeight(pBitmap1)
			hbm := CreateDIBSection(GDIw, GDIh)
			GGhdc := CreateCompatibleDC()
			obm := SelectObject(GGhdc, hbm)
			G1 := Gdip_GraphicsFromHDC(GGhdc)
			Gdip_SetInterpolationMode(G, 7)
			Gdip_DrawImage(G1, pBitmap1, 0, 0, GDIw, GDIh, 0, 0, GDIw, GDIh)
			UpdateLayeredWindow(hwnd1, GGhdc, GDIx, GDIy, GDIw, GDIh)

			SelectObject(hdc, obm)
			DeleteObject(hbm)
			DeleteDC(hdc)
			Gdip_DeleteGraphics(G1)

return [hwnd1, GGhdc]
}

SplitButton(hButton, GlyphSize=16, Menu="", hDontUse="") {								;--	drop down button

	;https://autohotkey.com/boards/viewtopic.php?t=22830
	/*						DESCRIPTION

		SplitButton ( hButton [, GlyphSize, MenuName ] )
		- hButton = hWnd of button to turn into SplitButton
		- GlyphSize = size of down arrow glyph (default: 16)
		- MenuName = name of menu to call when clicked (default: SplitButton_Menu)

		Issues/Requirements:
		- statically saved hwnd of button from first call needs turned into array... for now only one button can be a SplitButton
		- will conflict with other code using WM_Notify OnMessage()
		- missing features from API for glyph size, imagelist, styles, etc...
		- Requires Vista+, unsupported on XP

		;;parameters need to be expanded to cover these options:
		;;BUTTON_SPLITINFO struct 	 	;INFO mask flags        				;STYLE flags
		;;  UINT       mask;        				;BCSIF_GLYPH 	:= 0x0001  		;BCSS_NOSPLIT         := 0x0001
		;;  HIMAGELIST himlGlyph;  		;BCSIF_IMAGE 	:= 0x0002  		;BCSS_STRETCH        	:= 0x0002
		;;  UINT       uSplitStyle; 			;BCSIF_STYLE 	:= 0x0004  		;BCSS_ALIGNLEFT		:= 0x0004
		;;  SIZE       size;        				;BCSIF_SIZE  		:= 0x0008  		;BCSS_IMAGE           	:= 0x0008

	*/

	/*					  SIMPLE EXAMPLE more Example see forum link

		Menu, SplitButton_Menu, Add, First Item, DoNothing
		Menu, SplitButton_Menu, Add, Second Item, DoNothing
		Gui, Add, Button, w160 h80 hwndhButton, Button
		SplitButton(hButton)
		Gui, Show
		DoNothing:
		Return

	*/


	Static     _ := OnMessage(0x4E, "SplitButton") ;WM_NOTIFY
	Static Menu_ := "SplitButton_Menu"
	Static hButton_


	If (Menu=0x4E) {

			hCtrl := NumGet(GlyphSize+0, 0, "Ptr") ;-> lParam -> NMHDR -> hCtrl

			If (hCtrl = hButton_) { ;BCN_DROPDOWN for SplitButton

				id := NumGet(GlyphSize+0, A_PtrSize * 2, "uInt")
				If (id = 0xFFFFFB20) {
					ControlGetPos, cX, cY, cW, cH,, ahk_id %hButton_%
					Menu, %Menu_%, Show, % cX+1, % cY + cH
					}
			}
	 } Else {

			If (Menu <> "")
				Menu_ := Menu

			hButton_ := hButton
			Winset,   Style, +0x0C, ahk_id %hButton%          ;BS_SPLITBUTTON
			VarSetCapacity(   pBUTTON_SPLITINFO,  40, 0)
			NumPut(8,         pBUTTON_SPLITINFO,   0, "Int")  ;set glyph size
			NumPut(GlyphSize, pBUTTON_SPLITINFO,  4 + A_PtrSize * 2, "Int")
			SendMessage, BCM_SETSPLITINFO := 0x1607, 0, &pBUTTON_SPLITINFO, , ahk_id %hButton%
			Return

	}

}

BetterBox(Title := "", Prompt := "", Default := "", Pos := -1) {									;--	custom input box allows to choose the position of the text insertion point

	;-------------------------------------------------------------------------------
    ; custom input box allows to choose the position of the text insertion point
    ; return the entered text
    ;
    ; Title is the title for the GUI
    ; Prompt is the text to display
    ; Default is the text initially shown in the edit control
    ; Pos is the position of the text insertion point
    ;   Pos =  0  => at the start of the string
    ;   Pos =  1  => after the first character of the string
    ;   Pos = -1  => at the end of the string
    ;---------------------------------------------------------------------------

    static Result ; used as a GUI control variable

    ; create GUI
    Gui, BetterBox: New, +LastFound, %Title%
    Gui, -MinimizeBox
    Gui, Margin, 30, 18
    Gui, Add, Text,, %Prompt%
    Gui, Add, Edit, w290 vResult, %Default%
    Gui, Add, Button, x80 w80 Default, &OK
    Gui, Add, Button, x+m wp, &Cancel

    ; main loop
    Gui, Show
    SendMessage, 0xB1, %Pos%, %Pos%, Edit1, A ; EM_SETSEL
    WinWaitClose
    Return, Result


    ;-----------------------------------
    ; event handlers
    ;-----------------------------------
    BetterBoxButtonOK: ; "OK" button
        Gui, Submit ; get Result from GUI
        Gui, Destroy
    Return

    BetterBoxButtonCancel: ; "Cancel" button
    BetterBoxGuiClose:     ; {Alt+F4} pressed, [X] clicked
    BetterBoxGuiEscape:    ; {Esc} pressed
        Result := "BetterBoxCancel"
        Gui, Destroy
    Return
}

BtnBox(Title := "", Prompt := "", List := "", Seconds := "") {										;--	show a custom MsgBox with arbitrarily named buttons
;-------------------------------------------------------------------------------
    ; show a custom MsgBox with arbitrarily named buttons
    ; return the text of the button pressed
    ;
    ; Title is the title for the GUI
    ; Prompt is the text to display
    ; List is a pipe delimited list of captions for the buttons
    ; Seconds is the time in seconds to wait before timing out
    ;---------------------------------------------------------------------------

    ; create GUI
    Gui, BtnBox: New, +LastFound, %Title%
    Gui, -MinimizeBox
    Gui, Margin, 30, 18
    Gui, Add, Text,, %Prompt%
    Loop, Parse, List, |
        Gui, Add, Button, % (A_Index = 1 ? "" : "x+10") " gBtn", %A_LoopField%

    ; main loop
    Gui, Show
    WinWaitClose,,, %Seconds%
    If (ErrorLevel = 1) {
        Result := "TimeOut"
        Gui, Destroy
    }
    Return, Result


    ;-----------------------------------
    ; event handlers
    ;-----------------------------------
    Btn: ; all the buttons come here
        Result := A_GuiControl
        Gui, Destroy
    Return

    BtnBoxGuiClose: ; {Alt+F4} pressed, [X] clicked
        Result := "WinClose"
        Gui, Destroy
    Return

    BtnBoxGuiEscape: ; {Esc} pressed
        Result := "EscapeKey"
        Gui, Destroy
    Return
}

LoginBox(Title := "") {																								;-- show a custom input box for credentials, return an object with Username and Password
	;-------------------------------------------------------------------------------
    ; show a custom input box for credentials
    ; return an object with Username and Password
    ;
    ; Title is the title for the GUI
    ;---------------------------------------------------------------------------

    static Name, Pass ; used as a GUI control variables

    ; create GUI
    Gui, LoginBox: New, +LastFound, %Title%
    Gui, -MinimizeBox
    Gui, Margin, 30, 18
    Gui, Add, Text, ym+4 w55, Username:
    Gui, Add, Edit, x+10 yp-4 w100 vName
    Gui, Add, Text, xm y+10 w55, Password:
    Gui, Add, Edit, x+10 yp-4 w100 vPass Password
    Gui, Add, Button, w80 Default, &OK

    ; main loop
    Gui, Show
    WinWaitClose
    Return, Result


    ;-----------------------------------
    ; event handlers
    ;-----------------------------------
    LoginBoxButtonOK:  ; "OK" button, {Enter} pressed
        Gui, Submit
        Result := {Username: Name, Password: Pass}
        Gui, Destroy
    Return

    LoginBoxGuiClose:  ; {Alt+F4} pressed, [X] clicked
        Result := "WinClose"
        Gui, Destroy
    Return

    LoginBoxGuiEscape: ; {Esc} pressed
        Result := "EscapeKey"
        Gui, Destroy
    Return
}

MultiBox(Title := "", Prompt := "", Default := "") {													;-- show a multi-line input box, return the entered text

;-------------------------------------------------------------------------------
    ; show a multi-line input box
    ; return the entered text
    ;
    ; Title is the title for the GUI
    ; Prompt is the text to display
    ; Default is shown in the edit control
    ;---------------------------------------------------------------------------

    static Result ; used as a GUI control variable

    ; create GUI
    Gui, MultiBox: New, +LastFound, %Title%
    Gui, -MinimizeBox
    Gui, Margin, 30, 18
    Gui, Add, Text,, %Prompt%
    Gui, Add, Edit, w640 r10 vResult, %Default%
    Gui, Add, Button, w80 Default, &OK
    Gui, Add, Button, x+m wp, &Cancel

    ; main loop
    Gui, Show
    SendMessage, 0xB1, -1,, Edit1, A ; EM_SETSEL
    WinWaitClose
    Return, Result


    ;-----------------------------------
    ; event handlers
    ;-----------------------------------
    MultiBoxButtonOK: ; "OK" button, {Enter} pressed
        Gui, Submit ; get Result from GUI
        Gui, Destroy
    Return

    MultiBoxButtonCancel: ; "Cancel" button
    MultiBoxGuiClose:     ; {Alt+F4} pressed, [X] clicked
    MultiBoxGuiEscape:    ; {Esc} pressed
        Result := "MultiBoxCancel"
        Gui, Destroy
    Return
}

PassBox(Title := "", Prompt := "") {																			;-- show a custom input box for a password

	;-------------------------------------------------------------------------------
    ; show a custom input box for a password
    ; return the entered password
    ;
    ; Title is the title for the GUI
    ; Prompt is the text to display
    ;---------------------------------------------------------------------------

    static Result ; used as a GUI control variables

    ; create GUI
    Gui, PassBox: New, +LastFound, %Title%
    Gui, -MinimizeBox
    Gui, Margin, 30, 18
    Gui, Add, Text,, %Prompt%
    Gui, Add, Edit, w100 vResult Password
    Gui, Add, Button, w80 Default, &OK

    ; main loop
    Gui, Show
    WinWaitClose
    Return, Result


    ;-----------------------------------
    ; event handlers
    ;-----------------------------------
    PassBoxButtonOK: ; "OK" button, {Enter} pressed
        Gui, Submit ; get Result from GUI
        Gui, Destroy
    Return

    PassBoxGuiClose: ; {Alt+F4} pressed, [X] clicked
        Result := "WinClose"
        Gui, Destroy
    Return

    PassBoxGuiEscape: ; {Esc} pressed
        Result := "EscapeKey"
        Gui, Destroy
    Return
}

CreateHotkeyWindow(key) {      	 																	  		;-- Hotkey Window

	/*											Example

		#7::
		CreateWindow(Win + 7)
		return

	*/

	GetTextSize(key,35,Verdana,height,width)
	bgTopPadding = 40
	bgWidthPadding = 100
	bgHeight = % height + bgTopPadding
	bgWidth = % width + bgWidthPadding
	padding = 20
	yPlacement = % A_ScreenHeight ֠bgHeight ֠padding
	xPlacement = % A_ScreenWidth ֠bgWidth ֠padding

	Gui, Color, 46bfec
	Gui, Margin, 0, 0
	Gui, Add, Picture, x0 y0 w%bgWidth% h%bgHeight%, C:\Users\IrisDaniela\Pictures\bg.png
	Gui, +LastFound +AlwaysOnTop -Border -SysMenu +Owner -Caption +ToolWindow
	Gui, Font, s35 cWhite, Verdana
	Gui, Add, Text, xm y20 x25 ,%key%
	Gui, Show, x%xPlacement% y%yPlacement%
	SetTimer, RemoveGui, 5000

	return

	RemoveGui:
		Gui, Destroy
	return

}

GetUserInput(Default="",Text="",Options="",Control="") {									;-- allows you to create custom dialogs that can store different values (each value has a different set of controls)

	; http://ahkscript.org/germans/forums/viewtopic.php?t=7505 by Banane 2015

	/*			Description:

		This function allows you to create custom dialogs that can store different values (each value has a different set of controls).

		Either the dialog can be used to type plain text or a number, or to let the user select a file, all in one dialog, whose texts and
		Gui options are freely configurable.

		Both option parameters share the same syntax: "Option=Value", separated by commas, some options can also be specified
		without a value, if this is intended by the function, and the options do not have to be written out, since only the first letter
		of the name is important.

		Optionally you can also specify a "Control Definitions List", this is a command chain separated by "`n", which serves to add
		new controls to the dialog, using an AHK-like syntax: "Command, Parameter1, Parameter2,...", you can also leave
		parameters empty and to write a comma, `, must be used.

	*/

	/*			Parameters and available options:

  ==================================================
  	Text - Options Parameter
  ==================================================
  Window = Window Title
  Description = Description
  Ok = Text button
  Select = File selection dialog
  InvalidText = Error / Info Message
  ==================================================
  Options - Options Parameter
  ==================================================
  Gui = Gui Options
  Value = Value Type
    Num: Edit + UpDown Control
    Str: Edit
    File: Edit + Button
  Size = Window Size
  Transparency = Transparency of the Gui
  Region = Changes the Gui form
  NoEmptyStr = Blank text is invalid
  FileExist = Only existing file is valid
  InputRange = Lowest-Highest Number
  DisableEdit = Disables the input field
  ==================================================
  Control - Can create a Control Definitions list
            to display the dialog New Controls
            to add
    Available Controls: :
    Button, text, position, options, label
    GroupBox, Text, Position, Options
    Picture, File, Position, Options, Label
    Text, Text, Position, Options, Label
  ==================================================

	*/

	/*			Examples:

			Example 1 - Numerical value
			Code:
			MsgBox % GetUserInput(0,"Window=Numerical Value,Description=Enter a numerical value,Ok=Ok","Value=Num,Size=xCenter yCenter w250 h80")


			Example 2 - File Selection
			Code:
			MsgBox % GetUserInput("Hello World.txt","Window=File-Selection,Select=Select a file:,Ok=Ok","Gui=+ToolWindow,Value=File")


			Example 3 - List of Control Definitions
			Code:
			Definition =
			(
			GroupBox,, x5 y45 w330 h75, +BackgroundTrans
			Button, Help, x10 y55 w100 h20, -Theme, Dialog_Handler
			)

			MsgBox % GetUserInput("","","Gui=-Theme,Size=xCenter yCenter w340 h150,NoEmptyStr",Definition)

			Dialog_Handler:
			  MsgBox User pressed "Dialog Button-%A_GuiControl%"
			  Return



	*/

  ;--- Default Options
  TXT_W := "Input",TXT_D := "Enter a value:",TXT_O := "Apply",TXT_S := "Select a file",TXT_I := "Invalid Input."
  OPT_G := "+Toolwindow -SysMenu +AlwaysOnTop",OPT_V := "Str",OPT_S := "xCenter yCenter w340 h80"
  OPT_T := 255,OPT_R := "",OPT_N := "",OPT_F := "",OPT_I := "0-100",OPT_D := ""

  ;--- Parse value lists
  Loop, Parse, Text, `,, % A_Space
    If (InStr("W,D,O,S,I",SubStr(A_LoopField,1,1)))
      NM := SubStr(A_LoopField,1,1),TXT_%NM% := SubStr(A_LoopField,InStr(A_LoopField,"=") + 1,StrLen(A_LoopField))
  Loop, Parse, Options, `,, % A_Space
    If (InStr("G,V,S,T,R,N,F,I,D",SubStr(A_LoopField,1,1)))
      NM := SubStr(A_LoopField,1,1),OPT_%NM% := SubStr(A_LoopField,InStr(A_LoopField,"=") + 1,StrLen(A_LoopField))
  ;--- And retrieved positions keyvalue list
  Loop, Parse, OPT_S, % A_Space, % A_Space
    NM := SubStr(A_LoopField,1,1),VL := SubStr(A_LoopField,2,StrLen(A_LoopField)),POS_%NM% := VL
  ;--- Interpret the control definition
  Loop, Parse, Control, `n, % A_Space
    ;--- Only proceed on valid controls
    If (InStr("Pict,Butt,Text,Grou",SubStr(A_LoopField,1,4))) {
      ;--- Reset arguments variables
      ARG_1 := "",ARG_2 := "",ARG_3 := "",ARG_4 := "",ARG_5 := ""
      ;--- Replace `, temporary (as we parse it with comma)
      Values := RegExReplace(A_LoopField,"\``,","[TEXC]")
      ;--- Parse each param
      Loop, Parse, Values, `,, % A_Space
        ;--- Save argument and restore comma
        ARG_%A_Index% := RegExReplace(A_LoopField,"\[TEXC]",",")
      ;--- Add control to gui
      Gui, 99:Add, % ARG_1, %ARG_3% %ARG_4% g%ARG_5%, % ARG_2
    }

  ;--- Create the dialog
  Gui, 99:%OPT_G% -Resize -MinimizeBox -MaximizeBox +LastFound +LabelGetUserInput_
    Gui, 99:Add, Text, x5 y5 w%POS_W% h15 +BackgroundTrans, % TXT_D
    ;--- Add select button and shorten the edit field
    If (OPT_V = "File") {
      W := POS_W - 35
      Gui, 99:Add, Button, x%W% y25 w30 h20 gGetUserInput_SelectFile, ...
      W := W - 10
    } Else W := POS_W - 10
    ;--- Add the edit field with calculated dimensions
    Gui, 99:Add, Edit, x5 y25 w%W% h20, % Default
    ;--- Disable edit if wanted
    If (SubStr(OPT_D,1,1) = "D" && OPT_V = "File")
      GuiControl, 99:+Disabled, Edit1
    ;--- Create UpDown control for numbers and check edit content
    If (OPT_V = "Num") {
      Gui, 99:Add, UpDown, +Range%OPT_I%, % Value
      GuiControl, 99:+gGetUserInput_CheckEdit, Edit1
    }
    ;--- Calculate button position
    X := (POS_W - 100) / 2,Y := POS_H - 25
    Gui, 99:Add, Button, x%X% y%Y% w100 h20 +Default gGetUserInput_Apply, % TXT_O
  ;--- Show the dialog
  Gui, 99:Show, x%POS_X% y%POS_Y% w%POS_W% h%POS_H%, % TXT_W
  ;--- Apply transparency
  WinSet, Transparent, % OPT_T
  ;--- Apply region
  WinSet, Region, % OPT_R
  ;--- Wait until the dialog is closed
  WinWaitClose
  ;--- And return the input
  Return Edit1

  GetUserInput_CheckEdit:
    ;--- Retrieve the edit's value
    GuiControlGet, Edit1
    ;--- Check if edit's content isn't a numerical value
    If Edit1 is not Number
      ;--- If Type isn't the same as specified "Value" option, apply default
      GuiControl, 99:, Edit1, % Default
    Return

  GetUserInput_Apply:
    ;--- Retrieve the edit's value
    GuiControlGet, Edit1
    GoSub, GetUserInput_Do
    Return

  GetUserInput_SelectFile:
    ;--- Let the user select a file
    FileSelectFile, Value,,, % TXT_S
    ;--- Only apply if a file was selected
    If (Value <> "")
      GuiControl, 99:, Edit1, % Value
    Return

  GetUserInput_Close:
  GetUserInput_Do:
    ;--- Check which value to use
    If (A_GuiControl = TXT_O) {
      GuiControlGet, Edit1
      ;--- Stop if value doesn't complies the requirements
      If (SubStr(OPT_N,1,1) = "N" && Edit1 = "") || (SubStr(OPT_F,1,1) = "F" && FileExist(Edit1) = "") {
        MsgBox, 48, % TXT_W, % TXT_I
        Return
      }
    } Else Edit1 := Default
    ;--- Destroy the window to finish function
    Gui, 99:Destroy
    Return
}

guiMsgBox(title, text, owner="", isEditable=0, wait=0, w="", h="") {                  	;-- GUI Message Box to allow selection
		
	;dependings: function - getControlInfo()
	
	static thebox
	wf := getControlInfo("edit", text, "w", "s9", "Lucida Console")
	hf := getControlInfo("edit", text, "h", "s9", "Lucida Console")
	w := !w ? (wf > A_ScreenWidth/1.5 ? A_ScreenWidth/1.5 : wf+200) : w 	;+10 for scl bar
	h := !h ? (hf > A_ScreenHeight ? A_ScreenHeight : hf+65) : h 		;+10 for margin, +more for the button

	Gui, guiMsgBox:New
	Gui, guiMsgBox:+Owner%owner%
	Gui, -MaximizeBox +AlwaysOnTop
	Gui, Font, s9, Lucida Console
	Gui, Add, Edit, % "x5 y5 w" w-10 " h" h-35 (isEditable ? " -" : " +") "Readonly vthebox +multi -Border", % text
	Gui, Add, button, % "x" w/2-20 " w40 y+5", OK
	GuiControl, Focus, button1
	Gui, guiMsgBox:Show, % "w" w " h" h, % title
	if wait
		while GuiEnds
			sleep 100
	return thebox

guiMsgBoxButtonOK:
guiMsgBoxGuiClose:
guiMsgBoxGuiEscape:
	Gui, guiMsgBox:Submit, nohide
	Gui, guiMsgBox:Destroy
	GuiEnds := 1
	return
}

URLPrefGui(p_w, p_l, p_m, p_hw)   {                                                                        ;-- shimanov's workaround for displaying URLs in a gui	
	/*                              	DESCRIPTION
	
			     Thanks to shimanov for this function
				 
			     Details under http://www.autohotkey.com/forum/viewtopic.php?p=37805 <-- link is dead
			     a bit different but uses the same function: https://autohotkey.com/board/topic/5896-gui-hyperlink/ 
			     p_w             : WPARAM value
			     p_l             : LPARAM value
			     p_m             : message number
			     p_hw            : window handle HWND
			    
			     Further details can be found in the documentation for 'OnMessage()'
				 
	*/
	/*                              	EXAMPLE(s)
	
			Gui, Margin, 5, 5
			  Gui, Add, Text, xm ym, Multiple URLs in one GUI
			  Gui, Add, Text, xp( yp"5 cBlue gLink1 v[color=red]URL[/color]_Link1, www.autohotkey.com
			  Gui, Add, Text, xp   yp"0 cBlue gLink2 v[color=red]URL[/color]_Link2, de.autohotkey.com
			  Gui, Add, Text, xp   yp"0 cBlue gLink3 v[color=red]URL[/color]_Link3, www.google.com
			  Gui, Add, Text, xp   yp"0 cBlue gLink4 v[color=red]URL[/color]_Link4, www.msdn.com
			  Gui, Font, norm
			  Gui, Show,, URL
			 
			  ; Retrieve scripts PID
			  Process, Exist
			  pid_this := ErrorLevel
			 
			  ; Retrieve unique ID number (HWND/handle)
			  WinGet, hw_gui, ID, ahk_class AutoHotkeyGUI ahk_pid %pid_this%
			 
			  ; Call "HandleMessage" when script receives WM_SETCURSOR message
			  WM_SETCURSOR = 0x20
			  OnMessage(WM_SETCURSOR, "URLPrefGui")
			 
			  ; Call "HandleMessage" when script receives WM_MOUSEMOVE message
			  WM_MOUSEMOVE = 0x200
			  OnMessage(WM_MOUSEMOVE, "URLPrefGui")
			Return
			
			GuiClose:
			  ExitApp
			;End of GUI 
			
			
			;GUI glabels 
			Link1:
			  Run, http://www.autohotkey.com/forum
			Return
			
			Link2:
			  Run, http://de.autohotkey.com
			Return
			
			Link3:
			  Run, http://www.google.com
			Return
			
			Link4:
			  Run, http://www.msdn.com
			Return
			;End Of GUI glabels 
			
	*/
	
    
    global   WM_SETCURSOR, WM_MOUSEMOVE
    static   URL_hover, h_cursor_hand, h_old_cursor
    
    If (p_m = WM_SETCURSOR)
      {
        If URL_hover
          Return, true
      }
    Else If (p_m = WM_MOUSEMOVE)
      {
        ; Mouse cursor hovers URL Text control
        If (A_GuiControl = "URL_DocLink")
          {
            If URL_hover=
              {
                Gui, Font, cBlue underline
                GuiControl, Font, URL_DocLink
                
                h_cursor_hand := DllCall("LoadCursor", "uint", 0, "uint", 32649)
                
                URL_hover := true
              }                 
              h_old_cursor := DllCall("SetCursor", "uint", h_cursor_hand)
          }
        ; Mouse cursor doesn't hover URL Text control
        Else
          {
            If URL_hover
              {
                Gui, Font, norm cBlue
                GuiControl, Font, URL_DocLink
                
                DllCall("SetCursor", "uint", h_old_cursor)
                
                URL_hover=
              }
          }
      }
  }

;--- maybe these ones belongs together
TaskDialog(Instruction, Content := "", Title := "", Buttons := 1,                              	;-- a Task Dialog is a new kind of dialogbox that has been added in Windows Vista and later. They are similar to message boxes, but with much more power.
IconID := 0, IconRes := "", Owner := 0x10010) { 
    Local hModule, LoadLib, Ret

    If (IconRes != "") {
        hModule := DllCall("GetModuleHandle", "Str", IconRes, "Ptr")
        LoadLib := !hModule
            && hModule := DllCall("LoadLibraryEx", "Str", IconRes, "UInt", 0, "UInt", 0x2, "Ptr")
    } Else {
        hModule := 0
        LoadLib := False
    }

    DllCall("TaskDialog"
        , "Ptr" , Owner        ; hWndParent
        , "Ptr" , hModule      ; hInstance
        , "Ptr" , &Title       ; pszWindowTitle
        , "Ptr" , &Instruction ; pszMainInstruction
        , "Ptr" , &Content     ; pszContent
        , "Int" , Buttons      ; dwCommonButtons
        , "Ptr" , IconID       ; pszIcon
        , "Int*", Ret := 0)    ; *pnButton

    If (LoadLib) {
        DllCall("FreeLibrary", "Ptr", hModule)
    }

    Return {1: "OK", 2: "Cancel", 4: "Retry", 6: "Yes", 7: "No", 8: "Close"}[Ret]
}

TaskDialogDirect(Instruction, Content := "", Title := "", CustomButtons := "",   		;--  
CommonButtons := 0, MainIcon := 0, Flags := 0, Owner := 0x10010, VerificationText := "", ExpandedText := "", FooterText := "", FooterIcon := 0, Width := 0) { ;--
    Static x64 := A_PtrSize == 8, Button := 0, Checked := 0

    If (CustomButtons != "") {
        Buttons := StrSplit(CustomButtons, "|")
        cButtons := Buttons.Length()
        VarSetCapacity(pButtons, 4 * cButtons + A_PtrSize * cButtons, 0)
        Loop %cButtons% {
            iButtonText := &(b%A_Index% := Buttons[A_Index])
            NumPut(100 + A_Index, pButtons, (4 + A_PtrSize) * (A_Index - 1), "Int")
            NumPut(iButtonText, pButtons, (4 + A_PtrSize) * A_Index - A_PtrSize, "Ptr")
        }
    } Else {
        cButtons := 0
        pButtons := 0
    }

    NumPut(VarSetCapacity(TDC, (x64) ? 160 : 96, 0), TDC, 0, "UInt") ; cbSize
    NumPut(Owner, TDC, 4, "Ptr") ; hwndParent
    NumPut(Flags, TDC, (x64) ? 20 : 12, "Int") ; dwFlags
    NumPut(CommonButtons, TDC, (x64) ? 24 : 16, "Int") ; dwCommonButtons
    NumPut(&Title, TDC, (x64) ? 28 : 20, "Ptr") ; pszWindowTitle
    NumPut(MainIcon, TDC, (x64) ? 36 : 24, "Ptr") ; pszMainIcon
    NumPut(&Instruction, TDC, (x64) ? 44 : 28, "Ptr") ; pszMainInstruction
    NumPut(&Content, TDC, (x64) ? 52 : 32, "Ptr") ; pszContent
    NumPut(cButtons, TDC, (x64) ? 60 : 36, "UInt") ; cButtons
    NumPut(&pButtons, TDC, (x64) ? 64 : 40, "Ptr") ; pButtons
    NumPut(&VerificationText, TDC, (x64) ? 92 : 60, "Ptr") ; pszVerificationText
    NumPut(&ExpandedText, TDC, (x64) ? 100 : 64, "Ptr") ; pszExpandedInformation
    NumPut(FooterIcon, TDC, (x64) ? 124 : 76, "Ptr") ; pszFooterIcon
    NumPut(&FooterText, TDC, (x64) ? 132 : 80, "Ptr") ; pszFooter
    NumPut(Width, TDC, (x64) ? 156 : 92, "UInt") ; cxWidth

    If (DllCall("Comctl32.dll\TaskDialogIndirect", "Ptr", &TDC, "Int*", Button, "Int", 0, "Int*", Checked) == 0) {
        Return (VerificationText == "") ? Button : [Button, Checked]
    } Else {
        Return "ERROR"
    }
}

TaskDialogMsgBox(Main, Extra, Title := "", Buttons := 0, Icon := 0,                       	;--  
Parent := 0, TimeOut := 0) {		

	Static MBICON := {1: 0x30, 2: 0x10, 3: 0x40, WARN: 0x30, ERROR: 0x10, INFO: 0x40, QUESTION: 0x20}
		, TDBTNS := {OK: 1, YES: 2, NO: 4, CANCEL: 8, RETRY: 16}
	BTNS := 0
	if Buttons Is Integer
		BTNS := Buttons & 0x1F
	else
		For Each, Btn In StrSplit(Buttons, ["|", " ", ",", "`n"])
	BTNS |= (B := TDBTNS[Btn]) ? B : 0
	Options := 0
	Options |= (I := MBICON[Icon]) ? I : 0
	Options |= Parent = -1 ? 262144 : Parent > 0 ? 8192 : 0
	if ((BTNS & 14) = 14)
		Options |= 0x03 ; Yes/No/Cancel
	else if ((BTNS & 6) = 6)
		Options |= 0x04 ; Yes/No
	else if ((BTNS & 24) = 24)
		Options |= 0x05 ; Retry/Cancel
	else if ((BTNS & 9) = 9)
		Options |= 0x01 ; OK/Cancel
	Main .= Extra <> "" ? "`n`n" . Extra : ""
	MsgBox, % Options, %Title%, %Main%, %TimeOut%
	IfMsgBox, OK
		return 1
	IfMsgBox, Cancel
		return 2
	IfMsgBox, Retry
		return 4
	IfMsgBox, Yes
		return 6
	IfMsgBox, No
		return 7
	IfMsgBox, TimeOut
		return -1
	return 0

}

TaskDialogToUnicode(String, ByRef Var) {													     		;-- 

	VarSetCapacity(Var, StrPut(String, "UTF-16") * 2, 0)
	StrPut(String, &Var, "UTF-16")
	return &Var

}

TaskDialogCallback(H, N, W, L, D) {															     			;-- 

	Static TDM_Click_BUTTON := 0x0466
		, TDN_CREATED := 0
		, TDN_TIMER   := 4
	TD := Object(D)
	if (N = TDN_TIMER) && (W > TD.Timeout) {
		TD.TimedOut := True
		PostMessage, %TDM_Click_BUTTON%, 2, 0, , ahk_id %H% ; IDCANCEL = 2
	}
	else if (N = TDN_CREATED) && TD.AOT {
		DHW := A_DetectHiddenWindows
		DetectHiddenWindows, On
		WinSet, AlwaysOnTop, On, ahk_id %H%
		DetectHiddenWindows, %DHW%
	}
	return 0

}
;-----

TT_Console(msg, keys, x="", y="", fontops=""                                                    	;-- Use Tooltip as a User Interface it returns the key which has been pressed
, fontname="", whichtooltip=1, followMouse=0) {		

	; Source: https://github.com/aviaryan/Clipjump/blob/master/lib/TT_Console.ahk
	; dependings: ToolTipEx()

	/*			DESCRIPTION
			TT_Console() v0.03
				Use Tooltip as a User Interface
			By:
				Avi Aryan
			Info:
				keys - stores space separated values of keys that are prompted for a user input
				font_options - Font options as in Gui ( eg -> s8 bold underline )
				font_face - Font face names. Separate them by a | to set prority
			Returns >
				The key which has been pressed
	*/

	/*			EXAMPLE
			;a := TT_Console( "Hi`nPress Y to see another message.`nPress N to exit script", "y n", empty_var, empty_var, 1, "s12", "Arial|Consolas")
			;if a = y
			;...
			;return
	*/

	hFont := getHFONT(fontops, fontname)
	TooltipEx(msg, x, y, whichtooltip, hFont)

	;create hotkeys
	loop, parse, keys, %A_space%, %a_space%
		hkZ(A_LoopField, "TT_Console_Check", 1)

	is_TTkey_pressed := 0
	while !is_TTkey_pressed
	{
		if followMouse
		{
			TooltipEx(msg,,, whichtooltip)
			sleep 100
		} else {
			sleep 20
		}
	}

	TooltipEx(,,, whichtooltip)

	loop, parse, keys, %A_space%, %a_space%
		hkZ(A_LoopField, "TT_Console_Check", 0)

	return what_pressed


TT_Console_Check:
	what_pressed := A_ThisHotkey
	is_TTkey_pressed := 1
	return
}

ToolTipEx(Text:="", X:="", Y:="", WhichToolTip:=1                                             	;-- Display ToolTips with custom fonts and colors
, HFONT:="", BgColor:="", TxColor:="",            	
HICON:="", CoordMode:="W") {

	;source: https://github.com/aviaryan/Clipjump/blob/master/lib/TooltipEx.ahk
	;dependings: no

	/*		DESCRIPTION
		======================================================================================================================
		 ToolTipEx()     Display ToolTips with custom fonts and colors.
		                 Code based on the original AHK ToolTip implementation in Script2.cpp.
		 Tested with:    AHK 1.1.15.04 (A32/U32/U64)
		 Tested on:      Win 8.1 Pro (x64)
		 Change history:
		     1.1.01.00/2014-08-30/just me     -  fixed  bug preventing multiline tooltips.
		     1.1.00.00/2014-08-25/just me     -  added icon support, added named function parameters.
		     1.0.00.00/2014-08-16/just me     -  initial release.
		 Parameters:
		     Text           -  the text to display in the ToolTip.
		                       If omitted or empty, the ToolTip will be destroyed.
		     X              -  the X position of the ToolTip.
		                       Default: "" (mouse cursor)
		     Y              -  the Y position of the ToolTip.
		                       Default: "" (mouse cursor)
		     WhichToolTip   -  the number of the ToolTip.
		                       Values:  1 - 20
		                       Default: 1
		     HFONT          -  a HFONT handle of the font to be used.
		                       Default: 0 (default font)
		     BgColor        -  the background color of the ToolTip.
		                       Values:  RGB integer value or HTML color name.
		                       Default: "" (default color)
		     TxColor        -  the text color of the TooöTip.
		                       Values:  RGB integer value or HTML color name.
		                       Default: "" (default color)
		     HICON          -  the icon to display in the upper-left corner of the TooöTip.
		                       This can be the number of a predefined icon (1 = info, 2 = warning, 3 = error - add 3 to
		                       display large icons on Vista+) or a HICON handle. Specify 0 to remove an icon from the ToolTip.
		                       Default: "" (no icon)
		     CoordMode      -  the coordinate mode for the X and Y parameters, if specified.
		                       Values:  "C" (Client), "S" (Screen), "W" (Window)
		                       Default: "W" (CoordMode, ToolTip, Window)
		 Return values:
		     On success: The HWND of the ToolTip window.
		     On failure: False (ErrorLevel contains additional informations)
		 ======================================================================================================================
*/

	; ToolTip messages
	Static ADDTOOL  := A_IsUnicode ? 0x0432 : 0x0404 ; TTM_ADDTOOLW : TTM_ADDTOOLA
	Static BKGCOLOR := 0x0413 ; TTM_SETTIPBKCOLOR
	Static MAXTIPW  := 0x0418 ; TTM_SETMAXTIPWIDTH
	Static SETMARGN := 0x041A ; TTM_SETMARGIN
	Static SETTHEME := 0x200B ; TTM_SETWINDOWTHEME
	Static SETTITLE := A_IsUnicode ? 0x0421 : 0x0420 ; TTM_SETTITLEW : TTM_SETTITLEA
	Static TRACKACT := 0x0411 ; TTM_TRACKACTIVATE
	Static TRACKPOS := 0x0412 ; TTM_TRACKPOSITION
	Static TXTCOLOR := 0x0414 ; TTM_SETTIPTEXTCOLOR
	Static UPDTIPTX := A_IsUnicode ? 0x0439 : 0x040C ; TTM_UPDATETIPTEXTW : TTM_UPDATETIPTEXTA
	; Other constants
	Static MAX_TOOLTIPS := 20 ; maximum number of ToolTips to appear simultaneously
	Static SizeTI   := (4 * 6) + (A_PtrSize * 6) ; size of the TOOLINFO structure
	Static OffTxt   := (4 * 6) + (A_PtrSize * 3) ; offset of the lpszText field
	Static TT := [] ; ToolTip array
	; HTML Colors (BGR)
	Static HTML := {AQUA: 0xFFFF00, BLACK: 0x000000, BLUE: 0xFF0000, FUCHSIA: 0xFF00FF, GRAY: 0x808080, GREEN: 0x008000
					  , LIME: 0x00FF00, MAROON: 0x000080, NAVY: 0x800000, OLIVE: 0x008080, PURPLE: 0x800080, RED: 0x0000FF
					  , SILVER: 0xC0C0C0, TEAL: 0x808000, WHITE: 0xFFFFFF, YELLOW: 0x00FFFF}
	; -------------------------------------------------------------------------------------------------------------------
	; Init TT on first call
	If (TT.MaxIndex() = "")
		Loop, 20
			TT[A_Index] := {HW: 0, IC: 0, TX: ""}
	; -------------------------------------------------------------------------------------------------------------------
	; Check params
	TTTX := Text
	TTXP := X
	TTYP := Y
	TTIX := WhichToolTip = "" ? 1 : WhichToolTip
	TTHF := HFONT = "" ? 0 : HFONT
	TTBC := BgColor
	TTTC := TxColor
	TTIC := HICON
	TTCM := CoordMode = "" ? "W" : SubStr(CoordMode, 1, 1)
	If TTXP Is Not Digit
		Return False, ErrorLevel := "Invalid parameter X-position!", False
	If TTYP Is Not Digit
		Return  False, ErrorLevel := "Invalid parameter Y-Position!", False
	If (TTIX < 1) || (TTIX > MAX_TOOLTIPS)
		Return False, ErrorLevel := "Max ToolTip number is " . MAX_TOOLTIPS . ".", False
	If (TTHF) && !(DllCall("Gdi32.dll\GetObjectType", "Ptr", TTHF, "UInt") = 6) ; OBJ_FONT
		Return False, ErrorLevel := "Invalid font handle!", False
	If TTBC Is Integer
		TTBC := ((TTBC >> 16) & 0xFF) | (TTBC & 0x00FF00) | ((TTBC & 0xFF) << 16)
	Else
		TTBC := HTML.HasKey(TTBC) ? HTML[TTBC] : ""
	If TTTC Is Integer
		TTTC := ((TTTC >> 16) & 0xFF) | (TTTC & 0x00FF00) | ((TTTC & 0xFF) << 16)
	Else
		TTTC := HTML.HasKey(TTTC) ? HTML[TTTC] : ""
	If !InStr("CSW", TTCM)
		Return False, ErrorLevel := "Invalid parameter CoordMode!", False
	; -------------------------------------------------------------------------------------------------------------------
	; Destroy the ToolTip window, if Text is empty
	TTHW := TT[TTIX].HW
	If (TTTX = "") && (TTHW) {
		If DllCall("User32.dll\IsWindow", "Ptr", TTHW, "UInt")
			DllCall("User32.dll\DestroyWindow", "Ptr", TTHW)
		TT[TTIX] := {HW: 0, TX: ""}
		Return True
	}
	; -------------------------------------------------------------------------------------------------------------------
	; Get the virtual desktop rectangle
	SysGet, X, 76
	SysGet, Y, 77
	SysGet, W, 78
	SysGet, H, 79
	DTW := {L: X, T: Y, R: X + W, B: Y + H}
	; -------------------------------------------------------------------------------------------------------------------
	; Initialise the ToolTip coordinates. If either X or Y is empty, use the cursor position for the present.
	PT := {X: 0, Y: 0}
	If (TTXP = "") || (TTYP = "") {
		VarSetCapacity(Cursor, 8, 0)
		DllCall("User32.dll\GetCursorPos", "Ptr", &Cursor)
		Cursor := {X: NumGet(Cursor, 0, "Int"), Y: NumGet(Cursor, 4, "Int")}
		PT := {X: Cursor.X + 16, Y: Cursor.Y + 16}
	}
	; -------------------------------------------------------------------------------------------------------------------
	; If either X or Y  is specified, get the position of the active window considering CoordMode.
	Origin := {X: 0, Y: 0}
	If ((TTXP <> "") || (TTYP <> "")) && ((TTCM = "W") || (TTCM = "C")) { ; if (*aX || *aY) // Need the offsets.
		HWND := DllCall("User32.dll\GetForegroundWindow", "UPtr")
		If (TTCM = "W") {
			WinGetPos, X, Y, , , ahk_id %HWND%
			Origin := {X: X, Y: Y}
		}
		Else {
			VarSetCapacity(OriginPT, 8, 0)
			DllCall("User32.dll\ClientToScreen", "Ptr", HWND, "Ptr", &OriginPT)
			Origin := {X: NumGet(OriginPT, 0, "Int"), Y: NumGet(OriginPT, 0, "Int")}
		}
	}
	; -------------------------------------------------------------------------------------------------------------------
	; If either X or Y is specified, use the window related position for this parameter.
	If (TTXP <> "")
		PT.X := TTXP + Origin.X
	If (TTYP <> "")
		PT.Y := TTYP + Origin.Y
	; -------------------------------------------------------------------------------------------------------------------
	; Create and fill a TOOLINFO structure.
	TT[TTIX].TX := "T" . TTTX ; prefix with T to ensure it will be stored as a string in either case
	VarSetCapacity(TI, SizeTI, 0) ; TOOLINFO structure
	NumPut(SizeTI, TI, 0, "UInt")
	NumPut(0x0020, TI, 4, "UInt") ; TTF_TRACK
	NumPut(TT[TTIX].GetAddress("TX") + (1 << !!A_IsUnicode), TI, OffTxt, "Ptr")
	; -------------------------------------------------------------------------------------------------------------------
	; If the ToolTip window doesn't exist, create it.
	If !(TTHW) || !DllCall("User32.dll\IsWindow", "Ptr", TTHW, "UInt") {
		; ExStyle = WS_TOPMOST, Style = TTS_NOPREFIX | TTS_ALWAYSTIP
		TTHW := DllCall("User32.dll\CreateWindowEx", "UInt", 8, "Str", "tooltips_class32", "Ptr", 0, "UInt", 3
								, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr", A_ScriptHwnd, "Ptr", 0, "Ptr", 0, "Ptr", 0)
		DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", ADDTOOL, "Ptr", 0, "Ptr", &TI)
		DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", MAXTIPW, "Ptr", 0, "Ptr", A_ScreenWidth)
		DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", TRACKPOS, "Ptr", 0, "Ptr", PT.X | (PT.Y << 16))
		DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", TRACKACT, "Ptr", 1, "Ptr", &TI)
	}
	; -------------------------------------------------------------------------------------------------------------------
	; Update the text and the font and colors, if specified.
	If (TTBC <> "") || (TTTC <> "") { ; colors
		DllCall("UxTheme.dll\SetWindowTheme", "Ptr", TTHW, "Ptr", 0, "Str", "")
		VarSetCapacity(RC, 16, 0)
		NumPut(4, RC, 0, "Int"), NumPut(4, RC, 4, "Int"), NumPut(4, RC, 8, "Int"), NumPut(1, RC, 12, "Int")
		DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", SETMARGN, "Ptr", 0, "Ptr", &RC)
		If (TTBC <> "")
			DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", BKGCOLOR, "Ptr", TTBC, "Ptr", 0)
		If (TTTC <> "")
			DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", TXTCOLOR, "Ptr", TTTC, "Ptr", 0)
	}
	If (TTIC <> "")
		DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", SETTITLE, "Ptr", TTIC, "Str", " ")
	If (TTHF) ; font
		DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", 0x0030, "Ptr", TTHF, "Ptr", 1) ; WM_SETFONT
	DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", UPDTIPTX, "Ptr", 0, "Ptr", &TI)
	; -------------------------------------------------------------------------------------------------------------------
	; Get the ToolTip window dimensions.
	VarSetCapacity(RC, 16, 0)
	DllCall("User32.dll\GetWindowRect", "Ptr", TTHW, "Ptr", &RC)
	TTRC := {L: NumGet(RC, 0, "Int"), T: NumGet(RC, 4, "Int"), R: NumGet(RC, 8, "Int"), B: NumGet(RC, 12, "Int")}
	TTW := TTRC.R - TTRC.L
	TTH := TTRC.B - TTRC.T
	; -------------------------------------------------------------------------------------------------------------------
	; Check if the Tooltip will be partially outside the virtual desktop and adjust the position, if necessary.
	If (PT.X + TTW >= DTW.R)
		PT.X := DTW.R - TTW - 1
	If (PT.Y + TTH >= DTW.B)
		PT.Y := DTW.B - TTH - 1
	; -------------------------------------------------------------------------------------------------------------------
	; Check if the cursor is inside the ToolTip window and adjust the position, if necessary.
	If (TTXP = "") || (TTYP = "") {
		TTRC.L := PT.X, TTRC.T := PT.Y, TTRC.R := TTRC.L + TTW, TTRC.B := TTRC.T + TTH
		If (Cursor.X >= TTRC.L) && (Cursor.X <= TTRC.R) && (Cursor.Y >= TTRC.T) && (Cursor.Y <= TTRC.B)
			PT.X := Cursor.X - TTW - 3, PT.Y := Cursor.Y - TTH - 3
	}
	; -------------------------------------------------------------------------------------------------------------------
	; Show the Tooltip using the final coordinates.
	DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", TRACKPOS, "Ptr", 0, "Ptr", PT.X | (PT.Y << 16))
	DllCall("User32.dll\SendMessage", "Ptr", TTHW, "UInt", TRACKACT, "Ptr", 1, "Ptr", &TI)
	TT[TTIX].HW := TTHW
	Return TTHW
}

SafeInput(Title, Prompt, Default = "") {     ;-- makes sure sure the same window stays active after showing the InputBox. Otherwise you might get the text pasted into another window unexpectedly.
	
   ActiveWin := WinExist("A")
   InputBox OutPut, %Title%, %Prompt%,,, 120,,,,, %Default%
   WinActivate ahk_id %ActiveWin%
   Return OutPut
}

} 

{ ;Gui - changing functions (17)

FadeGui(guihwnd, fading_time, inout) {															        	;-- used DllCall to Animate (Fade in/out) a window

	AW_BLEND := 0x00080000
	AW_HIDE  := 0x00010000

	if inout	= "out"
		DllCall("user32\AnimateWindow", "ptr", guihwnd, "uint", fading_time, "uint", AW_BLEND|AW_HIDE)    ; Fade Out
	if inout = "in"
		DllCall("user32\AnimateWindow", "ptr", guihwnd, "uint", fading_time, "uint", AW_BLEND)    ; Fade In

return
}

WinFadeToggle(WinTitle, Duration := 1, Hide := false) {								            	;--

	;attention: you need library print.ahk

	/**
	*  WinFadeTo( WinTitle, [, Duration] )
	*   WinTitle
	*      A window title identifying the name of the target window.
	*   Duration (default 1 second)
	*      A number (in seconds) defining how long the animation will take to complete.
	*      NOTE: The duration cannot be set to lower than 1 second.
	*   Hide (disabled by default)
	*      Set the visible state of the target window after fade out.
	*      NOTE: Enabled by default if "DetectHiddenWindows" is set to on, otherwise disabled.
	*/

	DetectHiddenWindows, On     ; Determines whether invisible windows are "seen" by the script.
	; Declarations
	LoopCount := 64 * Duration                      ; Calculated number of iterations for loop
	WinGet, WinOpacity, Transparent, %WinTitle%     ; Get transparency level of target window

	; Return error if target window does not exist or is not active
	If !WinExist(WinTitle) && !WinActive(WinTitle) {
		ErrorMessage := "Target window is not active or does not exist."
	}

	; Check "DetectHiddenWindows" state
	if ( A_DetectHiddenWindows = "On" ) {
		Hide := true
	}

	; Check target window for transparency level
	If ( WinOpacity = "" ) {
		WinSet, Transparent, 255, %WinTitle% ; Set transparency of target window
	}

	; Set the direction of the fade (in/out)
	if (WinOpacity = 255 || WinOpacity = "") {
		start := -255
		} else {
			start := 0
			WinShow, %WinTitle%
			WinActivate, %WinTitle%     ; Activate target window on fade in
		}

		; Iterate through each change in opacity level
		timer_start := A_TickCount ; Log time of fade start
		Loop, % LoopCount {
			opacity := Abs(255/LoopCount * A_Index + start) ; opacity value for the current iteration
			WinSet, Transparent, %opacity%, %WinTitle%      ; Set opacity level for target window
			Sleep, % duration                               ; Pause between each iteration
		}
		timer_stop := A_TickCount ; Log time of fade completion

		; Hide target window after fade-out completes
		if (start != 0 && Hide = true) {
			WinHide, %WinTitle%
		}

		Return ErrorMessage
	}

winfade(w:="",t:=128,i:=1,d:=10) {                                                                             	;-- another winfade function
	
	; https://github.com/joedf/AEI.ahk/blob/master/AEI.ahk
	w:=(w="")?("ahk_id " WinActive("A")):w
	t:=(t>255)?255:(t<0)?0:t
	WinGet,s,Transparent,%w%
	s:=(s="")?255:s ;prevent trans unset bug
	WinSet,Transparent,%s%,%w% 
	i:=(s<t)?abs(i):-1*abs(i)
	while(k:=(i<0)?(s>t):(s<t)&&WinExist(w)) {
		WinGet,s,Transparent,%w%
		s+=i
		WinSet,Transparent,%s%,%w%
		sleep %d%
	}
}

ShadowBorder(handle) {																				             	;-- used DllCall to draw a shadow around a gui

    DllCall("user32.dll\SetClassLongPtr", "ptr", handle, "int", -26, "ptr", DllCall("user32.dll\GetClassLongPtr", "ptr", handle, "int", -26, "uptr") | 0x20000)

}

FrameShadow(handle) {																				            	;-- FrameShadow1
    DllCall("dwmapi.dll\DwmIsCompositionEnabled", "int*", DwmEnabled)
    if !(DwmEnabled)
        DllCall("user32.dll\SetClassLongPtr", "ptr", handle, "int", -26, "ptr", DllCall("user32.dll\GetClassLongPtr", "ptr", handle, "int", -26) | 0x20000)
    else {
        VarSetCapacity(MARGINS, 16, 0) && NumPut(1, NumPut(1, NumPut(1, NumPut(1, MARGINS, "int"), "int"), "int"), "int")
        DllCall("dwmapi.dll\DwmSetWindowAttribute", "ptr", handle, "uint", 2, "ptr*", 2, "uint", 4)
        DllCall("dwmapi.dll\DwmExtendFrameIntoClientArea", "ptr", handle, "ptr", &MARGINS)
    }
}

FrameShadow(HGui) {																					            	;-- FrameShadow(): Drop Shadow On Borderless Window, (DWM STYLE)

	;--https://autohotkey.com/boards/viewtopic.php?t=29117

	/*
	Gui, +HwndHGui -Caption - Example
	FrameShadow(HGui)
	Gui, Add, Button, x10 y130 w100 h30, Minimize
	Gui, Add, Button, x365 y130 w100 h30, Exit
	Gui, Add, GroupBox, x10 y10 w455 h110, GroupBox
	Gui, Add, Edit, x20 y30 w435 h80 +Multi, Edit
	Gui, Show, Center w475 h166, Frame Shadow Test
	*/

	DllCall("dwmapi\DwmIsCompositionEnabled","IntP",_ISENABLED) ; Get if DWM Manager is Enabled
	if !_ISENABLED ; if DWM is not enabled, Make Basic Shadow
		DllCall("SetClassLong","UInt",HGui,"Int",-26,"Int",DllCall("GetClassLong","UInt",HGui,"Int",-26)|0x20000)
	else {
		VarSetCapacity(_MARGINS,16)
		NumPut(1,&_MARGINS,0,"UInt")
		NumPut(1,&_MARGINS,4,"UInt")
		NumPut(1,&_MARGINS,8,"UInt")
		NumPut(1,&_MARGINS,12,"UInt")
		DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", HGui, "UInt", 2, "Int*", 2, "UInt", 4)
		DllCall("dwmapi\DwmExtendFrameIntoClientArea", "Ptr", HGui, "Ptr", &_MARGINS)
	}
}

RemoveWindowFromTaskbar(WinTitle) {															    	;-- remove the active window from the taskbar by using COM

/*
      Example: Temporarily remove the active window from the taskbar by using COM.
      Methods in ITaskbarList's VTable:
        IUnknown:
          0 QueryInterface  -- use ComObjQuery instead
          1 AddRef          -- use ObjAddRef instead
          2 Release         -- use ObjRelease instead
        ITaskbarList:
          3 HrInit
          4 AddTab
          5 DeleteTab
          6 ActivateTab
          7 SetActiveAlt
    */
    IID_ITaskbarList  := "{56FDF342-FD6D-11d0-958A-006097C9A090}"
    CLSID_TaskbarList := "{56FDF344-FD6D-11d0-958A-006097C9A090}"

    ; Create the TaskbarList object and store its address in tbl.
    tbl := ComObjCreate(CLSID_TaskbarList, IID_ITaskbarList)

    activeHwnd := WinExist(WinTitle)

    DllCall(vtable(tbl,3), "ptr", tbl)                     ; tbl.HrInit()
    DllCall(vtable(tbl,5), "ptr", tbl, "ptr", activeHwnd)  ; tbl.DeleteTab(activeHwnd)
    Sleep 3000
    DllCall(vtable(tbl,4), "ptr", tbl, "ptr", activeHwnd)  ; tbl.AddTab(activeHwnd)

    ; Non-dispatch objects must always be manually freed.
    ObjRelease(tbl)
    return

}
{ ; sub
vtable(ptr, n) {
    ; NumGet(ptr+0) returns the address of the object's virtual function
    ; table (vtable for short). The remainder of the expression retrieves
    ; the address of the nth function's address from the vtable.
    return NumGet(NumGet(ptr+0), n*A_PtrSize)
}
} 

ToggleTitleMenuBar(ahkid:=0, bHideTitle:=1, bHideMenuBar:=0) {				         	;-- show or hide Titlemenubar

    if ( ahkid = 0 ) ; must with () wrap
        WinGet, ahkid, ID, A
    ; ToolTip, % "AHKID is: " ahkid, 300, 300,
    if ( bHideTitle = 1 ) {
        WinSet, Style, ^0xC00000, ahk_id %ahkid%     ; titlebar toggle
    }
    if ( bHideMenuBar = 1 ) {
        WinSet, Style, ^0x40000, ahk_id %ahkid%      ; menubar toggle
    }

}

ToggleFakeFullscreen() {																				            	;-- sets styles to a window to look like a fullscreen

    CoordMode Screen, Window
    static WINDOW_STYLE_UNDECORATED := -0xC40000
    static savedInfo := Object() ;; Associative array!
    WinGet, id, ID, A

    if (savedInfo[id]) {
        inf := savedInfo[id]
        WinSet, Style, % inf["style"], ahk_id %id%
        WinMove, ahk_id %id%,, % inf["x"], % inf["y"], % inf["width"], % inf["height"]
        savedInfo[id] := ""
    } else {
        savedInfo[id] := inf := Object()
        WinGet, ltmp, Style, A
        inf["style"] := ltmp
        WinGetPos, ltmpX, ltmpY, ltmpWidth, ltmpHeight, ahk_id %id%
        inf["x"] := ltmpX
        inf["y"] := ltmpY
        inf["width"] := ltmpWidth
        inf["height"] := ltmpHeight
        WinSet, Style, %WINDOW_STYLE_UNDECORATED%, ahk_id %id%
        mon := GetMonitorActiveWindow()
        SysGet, mon, Monitor, %mon%
        WinMove, A,, %monLeft%, %monTop%, % monRight-monLeft, % monBottom-monTop
    }
    WinSet Redraw

}

CreateFont(nHeight, nWidth, nEscapement, nOrientation, fnWeight,                    	;-- creates HFont for use with GDI
fdwItalic, fdwUnderline, fdwStrikeOut, fdwCharSet, fdwOutputPrecision,
fdwClipPrecision, fdwQuality, fdwPitchAndFamily, lpszFace) {

/*
HFONT CreateFont(
  int nHeight,               // height of font
  int nWidth,                // average character width
  int nEscapement,           // angle of escapement
  int nOrientation,          // base-line orientation angle
  int fnWeight,              // font weight
  DWORD fdwItalic,           // italic attribute option
  DWORD fdwUnderline,        // underline attribute option
  DWORD fdwStrikeOut,        // strikeout attribute option
  DWORD fdwCharSet,          // character set identifier
  DWORD fdwOutputPrecision,  // output precision
  DWORD fdwClipPrecision,    // clipping precision
  DWORD fdwQuality,          // output quality
  DWORD fdwPitchAndFamily,   // pitch and family
  LPCTSTR lpszFace           // typeface name
);
*/

	return DllCall("CreateFont"
				, "Int" , nHeight           , "Int" , nWidth          , "Int" , nEscapement
				, "Int" , nOrientation      , "Int" , fnWeight        , "UInt", fdwItalic
				, "UInt", fdwUnderline      , "UInt", fdwStrikeOut    , "UInt", fdwCharSet
				, "UInt", fdwOutputPrecision, "UInt", fdwClipPrecision, "UInt", fdwQuality
				, "UInt", fdwPitchAndFamily , "Str" , lpszFace)
}

FullScreenToggleUnderMouse(WT) {                                                                      	;-- toggles a window under the mouse to look like fullscreen

		DetectHiddenWindows, On
		MouseGetPos,,,WinUnderMouse
		WinGetTitle, WTm, %WinUnderMouse%
		WinSet, Style, ^0xC00000, ahk_id %WinUnderMouse%
		WinSet, AlwaysOnTop, Toggle, ahk_id %WinUnderMouse%
		PostMessage, 0x112, 0xF030,,, ahk_id %WinUnderMouse% ;WinMaximize
		;PostMessage, 0x112, 0xF120,,, Fenstertitel, Fenstertext 	;WinRestore
		WinGet, Style, Style, ahk_class Shell_TrayWnd
			If (Style & 0x10000000) {
				  WinShow ahk_class Shell_TrayWnd
				  WinShow Start ahk_class Button

			} Else {
				WinHide ahk_class Shell_TrayWnd
				  WinHide Start ahk_class Button
			}

}

SetTaskbarProgress(pct, state="", hwnd="") { 													    	;-- accesses Windows 7's ability to display a progress bar behind a taskbar button.

	; https://autohotkey.com/board/topic/46860-windows-7-settaskbarprogress/ - from Lexikos
	; edited version of Lexikos' SetTaskbarProgress() function to work with Unicode 64bit, Unicode 32bit, Ansi 32bit, and Basic/Classic (1.0.48.5)
	; SetTaskbarProgress  -  Requires Windows 7.
	;
	; pct    -  A number between 0 and 100 or a state value (see below).
	; state  -  "N" (normal), "P" (paused), "E" (error) or "I" (indeterminate).
	;           If omitted (and pct is a number), the state is not changed.
	; hwnd   -  The ID of the window which owns the taskbar button.
	;           If omitted, the Last Found Window is used.

	/*		EXAMPLE

		Gui, Font, s15
		Gui, Add, Text,, % "This GUI should show a progress bar on its taskbar button.`n"
						 . "It will demonstrate the four different progress states:`n"
						 . "(N)ormal, (P)aused, (E)rror and (I)ndeterminate."
		Gui, Show        ; Show the window and taskbar button.
		Gui, +LastFound  ; SetTaskbarProgress will use this window.
		Loop
		{
			progress_states=NPE
			Loop, Parse, progress_states
			{
				SetTaskbarProgress(0, A_LoopField)
				Loop 50 {
					SetTaskbarProgress(A_Index*2)
					Sleep 50
				}
				Sleep 1000
				Loop 50 {
					SetTaskbarProgress(100-A_Index*2)
					Sleep 50
				}
				SetTaskbarProgress(0)
				Sleep 1000
			}
			SetTaskbarProgress("I")
			Sleep 4000
		}
		GuiClose:
		GuiEscape:
		ExitApp
	*/

    static tbl, s0:=0, sI:=1, sN:=2, sE:=4, sP:=8
	 if !tbl
	  Try tbl := ComObjCreate("{56FDF344-FD6D-11d0-958A-006097C9A090}"
							, "{ea1afb91-9e28-4b86-90e9-9e9f8a5eefaf}")
	  Catch
	   Return 0
	 If hwnd =
	  hwnd := WinExist()
	 If pct is not number
	  state := pct, pct := ""
	 Else If (pct = 0 && state="")
	  state := 0, pct := ""
	 If state in 0,I,N,E,P
	  DllCall(NumGet(NumGet(tbl+0)+10*A_PtrSize), "uint", tbl, "uint", hwnd, "uint", s%state%)
	 If pct !=
	  DllCall(NumGet(NumGet(tbl+0)+9*A_PtrSize), "uint", tbl, "uint", hwnd, "int64", pct*10, "int64", 1000)
	Return 1

}

SetTaskbarProgress(State, hWnd := "") { 														        	;-- modified function

	;http://ahkscript.org/boards/viewtopic.php?p=48299#p48299 from Flipeador
	;SetTaskbarProgress( [0~100 | Normal, Paused, Indeterminate, Error], [Win ID] )

	/*					EXAMPLE

		Gui, Font, s15
		Gui, Add, Text,, % "------------------------------------------------------"
		Gui, Show
		Gui, +LastFound +HWND_G

		SetTaskbarProgress( 0, _G )
		Sleep 100
		Loop, 50 {
			SetTaskbarProgress( A_Index, _G )
			Sleep 50
		}
		Sleep 100
		SetTaskbarProgress( "Paused", _G )
		Sleep, 1000
		SetTaskbarProgress( "Normal", _G )
		Sleep, 1000
		Loop, 49 {
			SetTaskbarProgress( A_Index * 2, _G )
			Sleep 100
		}
		Sleep 100
		SetTaskbarProgress( "Error", _G )
		Sleep 1000
		SetTaskbarProgress( "Indeterminate", _G )
		Sleep 1000
		ExitApp
		Esc::ExitApp

	*/

	static ppv
	if !ppv
		DllCall("ole32.dll\OleInitialize", "PtrP", 0)
		, VarSetCapacity(CLSID, 16), VarSetCapacity(riid, 16)
		, DllCall("ole32.dll\CLSIDFromString", "Str", "{56FDF344-FD6D-11d0-958A-006097C9A090}", "Ptr", &CLSID)
		, DllCall("ole32.dll\CLSIDFromString", "Str", "{ea1afb91-9e28-4b86-90e9-9e9f8a5eefaf}", "Ptr", &riid)
		, DllCall("ole32.dll\CoCreateInstance", "Ptr", &CLSID, "Ptr", 0, "UInt", 21, "Ptr", &riid, "PtrP", ppv)
	hWnd := hWnd ? hWnd : IsWindow()
	s0 := 0, sI := sIndeterminate := 1, sN := sNormal := 2, sE := sError := 4, sP := sPaused := 8
	if InVar( State, "0,N,P,E,I,Normal,Paused,Error,Indeterminate" )
		return DllCall(NumGet(NumGet(ppv+0)+10*A_PtrSize), "Ptr", ppv, "Ptr", hWnd, "UInt", s%State%)
	return DllCall(NumGet(NumGet(ppv+0)+9*A_PtrSize), "Ptr", ppv, "Ptr", hWnd, "Int64", State * 10, "Int64", 1000)
}
{ ; sub
;If [var] in [ .. ]
InVar(Haystack, Needle, Delimiter := ",", OmitChars := "") {
	Loop, Parse, % Needle, %Delimiter%, %OmitChars%
		if (A_LoopField = Haystack)
			return 1
	return 0
}

IsWindow(hWnd*) {
	if !hWnd.MaxIndex()
		return DllCall("User32.dll\GetForegroundWindow")
	return i := DllCall("User32.dll\IsWindow", "Ptr", hWnd[1] )
		, ErrorLevel := !i
}
} 

WinSetPlacement(hwnd, x="",y="",w="",h="",state="") {											;-- Sets window position using workspace coordinates (-> no taskbar)
	
	WinGetPlacement(hwnd, x1, y1, w1, h1, state1)
	if (x = "")
		x := x1
	if (y = "")
		y := y1
	if (w = "")
		w := w1
	if (h = "")
		h := h1
	if (state = "")
		state := state1
	VarSetCapacity(wp, 44), NumPut(44, wp)
	if (state = 6)
		NumPut(7, wp, 8) ;SW_SHOWMINNOACTIVE
	else if (state = 1)
		NumPut(4, wp, 8) ;SW_SHOWNOACTIVATE
	else if (state = 3)
		NumPut(3, wp, 8) ;SW_SHOWMAXIMIZED and/or SW_MAXIMIZE
	else
		NumPut(state, wp, 8)
	NumPut(x, wp, 28, "Int")
    NumPut(y, wp, 32, "Int")
    NumPut(x+w, wp, 36, "Int")
    NumPut(y+h, wp, 40, "Int")
	DllCall("SetWindowPlacement", "Ptr", hwnd, "Ptr", &wp) 
}

AttachToolWindow(hParent, GUINumber, AutoClose) {												;-- Attaches a window as a tool window to another window from a different process. 
	global ToolWindows
	outputdebug AttachToolWindow %GUINumber% to %hParent%
	if (!IsObject(ToolWindows))
		ToolWindows := Object()
	if (!WinExist("ahk_id " hParent))
		return false
	Gui %GUINumber%: +LastFoundExist
	if (!(hGui := WinExist()))
		return false
	;SetWindowLongPtr is defined as SetWindowLong in x86
	if (A_PtrSize = 4)
		DllCall("SetWindowLong", "Ptr", hGui, "int", -8, "PTR", hParent) ;This line actually sets the owner behavior
	else
		DllCall("SetWindowLongPtr", "Ptr", hGui, "int", -8, "PTR", hParent) ;This line actually sets the owner behavior
	ToolWindows.Insert(Object("hParent", hParent, "hGui", hGui,"AutoClose", AutoClose))
	Gui %GUINumber%: Show, NoActivate
	return true
}

DeAttachToolWindow(GUINumber) {																			;-- removes the attached ToolWindow
	
	global ToolWindows
	Gui %GUINumber%: +LastFoundExist
	if (!(hGui := WinExist()))
		return false
	Loop % ToolWindows.MaxIndex()
	{
		if (ToolWindows[A_Index].hGui = hGui)
		{
			;SetWindowLongPtr is defined as SetWindowLong in x86
			if (A_PtrSize = 4)
				DllCall("SetWindowLong", "Ptr", hGui, "int", -8, "PTR", 0) ;Remove tool window behavior
			else
				DllCall("SetWindowLongPtr", "Ptr", hGui, "int", -8, "PTR", 0) ;Remove tool window behavior
			DllCall("SetWindowLongPtr", "Ptr", hGui, "int", -8, "PTR", 0)
			ToolWindows.Remove(A_Index)
			break
		}
	}
}

Control_SetTextAndResize(controlHwnd, newText) {                                              	;-- set a new text to a control and resize depending on textwidth and -height
	
    dc := DllCall("GetDC", "Ptr", controlHwnd)

    ; 0x31 = WM_GETFONT
    SendMessage 0x31,,,, ahk_id %controlHwnd%
    hFont := ErrorLevel
    oldFont := 0
    if (hFont != "FAIL")
        oldFont := DllCall("SelectObject", "Ptr", dc, "Ptr", hFont)

    VarSetCapacity(rect, 16, 0)
    ; 0x440 = DT_CALCRECT | DT_EXPANDTABS
    h := DllCall("DrawText", "Ptr", dc, "Ptr", &newText, "Int", -1, "Ptr", &rect, "UInt", 0x440)
    ; width = rect.right - rect.left
    w := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")

    if oldFont
        DllCall("SelectObject", "Ptr", dc, "Ptr", oldFont)
    DllCall("ReleaseDC", "Ptr", controlHwnd, "Ptr", dc)

    GuiControl,, %controlHwnd%, %newText%
    GuiControl Move, %controlHwnd%, % "h" h " w" w
}

} 

{ ;Gui - control type functions (48)

		{ ;ComboBox control functions (1)

GetComboBoxChoice(TheList, TheCurrent) {																;-- Combobox function

	; https://github.com/altbdoor/ahk-hs-chara/blob/master/utility.ahk
	TheValue := -1

	Loop % TheList.Length() {
		If (TheCurrent == TheList[A_Index]) {
			TheValue := A_Index
			Break
		}
	}
	TheList := JoinArray(TheList, "|")

	Return {"Index": TheValue, "Choices": TheList}
}

		} 

		{ ;Edit and HEdit control functions (7)

				;************************
				; Edit Control Functions
				;************************
				;
				; http://www.autohotkey.com/forum/topic22748.html
				;
				; Standard parameters:
				;   Control, WinTitle   If WinTitle is not specified, 'Control' may be the
				;                       unique ID (hwnd) of the control.  If "A" is specified
				;                       in Control, the control with input focus is used.
				;
				; Standard/default return value:
				;   true on success, otherwise false.

				Edit_Standard_Params(ByRef Control, ByRef WinTitle) {  								;-- these are helper functions to use with Edit or HEdit controls
					if (Control="A" && WinTitle="") { ; Control is "A", use focused control.
						ControlGetFocus, Control, A
						WinTitle = A
					} else if (Control+0!="" && WinTitle="") {  ; Control is numeric, assume its a ahk_id.
						WinTitle := "ahk_id " . Control
						Control =
					}
				}

				Edit_TextIsSelected(Control="", WinTitle="") {												;--
					; Returns true if text is selected, otherwise false.
				;
					Edit_Standard_Params(Control, WinTitle)
					return Edit_GetSelection(start, end, Control, WinTitle) and (start!=end)
				}

				Edit_GetSelection(ByRef start, ByRef end, Control="", WinTitle="") {				;--
					; Gets the start and end offset of the current selection.
				;
					Edit_Standard_Params(Control, WinTitle)
					VarSetCapacity(start, 4), VarSetCapacity(end, 4)
					SendMessage, 0xB0, &start, &end, %Control%, %WinTitle%  ; EM_GETSEL
					if (ErrorLevel="FAIL")
						return false
					start := NumGet(start), end := NumGet(end)
					return true
				}

				Edit_Select(start=0, end=-1, Control="", WinTitle="") {								;--
					; Selects text in a text box, given absolute character positions (starting at 0.)
					;
					; start:    Starting character offset, or -1 to deselect.
					; end:      Ending character offset, or -1 for "end of text."
					;

					Edit_Standard_Params(Control, WinTitle)
					SendMessage, 0xB1, start, end, %Control%, %WinTitle%  ; EM_SETSEL
					return (ErrorLevel != "FAIL")
				}

				Edit_SelectLine(line=0, include_newline=false, Control="", WinTitle="") {	;--
						; Selects a line of text.
					;
					; line:             One-based line number, or 0 to select the current line.
					; include_newline:  Whether to also select the line terminator (`r`n).
					;

					Edit_Standard_Params(Control, WinTitle)

					ControlGet, hwnd, Hwnd,, %Control%, %WinTitle%
					if (!WinExist("ahk_id " hwnd))
						return false

					if (line<1)
						ControlGet, line, CurrentLine

					SendMessage, 0xBB, line-1, 0  ; EM_LINEINDEX
					offset := ErrorLevel

					SendMessage, 0xC1, offset, 0  ; EM_LINELENGTH
					lineLen := ErrorLevel

					if (include_newline) {
						WinGetClass, class
						lineLen += (class="Edit") ? 2 : 1 ; `r`n : `n
					}

					; Select the line.
					SendMessage, 0xB1, offset, offset+lineLen  ; EM_SETSEL
					return (ErrorLevel != "FAIL")
				}

				Edit_DeleteLine(line=0, Control="", WinTitle="") {										;--
						; Deletes a line of text.
				;
				; line:     One-based line number, or 0 to delete current line.
				;

					Edit_Standard_Params(Control, WinTitle)
					; Select the line.
					if (Edit_SelectLine(line, true, Control, WinTitle))
					{   ; Delete it.
						ControlSend, %Control%, {Delete}, %WinTitle%
						return true
					}
					return false
				}

				Edit_VCenter(HEDIT) {																				;-- Vertically Align Text

					; by just me, http://ahkscript.org/boards/viewtopic.php?f=5&t=4673#p44099
					; the Edit control must have the ES_MULTILINE style (0x0004 \ +Multi)!
					; EM_GETRECT := 0x00B2 <- msdn.microsoft.com/en-us/library/bb761596(v=vs.85).aspx
					; EM_SETRECT := 0x00B3 <- msdn.microsoft.com/en-us/library/bb761657(v=vs.85).aspx

					VarSetCapacity(RC, 16, 0)
					DllCall("User32.dll\GetClientRect", "Ptr", HEDIT, "Ptr", &RC)
					CLHeight := NumGet(RC, 12, "Int")
					SendMessage, 0x0031, 0, 0, , ahk_id %HEDIT% ; WM_GETFONT
					HFONT := ErrorLevel
					HDC := DllCall("GetDC", "Ptr", HEDIT, "UPtr")
					DllCall("SelectObject", "Ptr", HDC, "Ptr", HFONT)
					VarSetCapacity(RC, 16, 0)
					DTH := DllCall("DrawText", "Ptr", HDC, "Str", "W", "Int", 1, "Ptr", &RC, "UInt", 0x2400)
					DllCall("ReleaseDC", "Ptr", HEDIT, "Ptr", HDC)
					SendMessage, 0x00BA, 0, 0, , ahk_id %HEDIT% ; EM_GETLINECOUNT
					TXHeight := DTH * ErrorLevel
					If (TXHeight > CLHeight)
							Return False
					VarSetCapacity(RC, 16, 0)
					SendMessage, 0x00B2, 0, &RC, , ahk_id %HEDIT%
					DY := (CLHeight - TXHeight) // 2
					NumPut(DY, RC, 4, "Int")
					NumPut(TXHeight + DY, RC, 12, "Int")
					SendMessage, 0x00B3, 0, &RC, , ahk_id %HEDIT%

				}

		} 

		{ ;ImageList control type functions (2)

IL_LoadIcon(FullFilePath, IconNumber := 1, LargeIcon := 1) {									;--
	HIL := IL_Create(1, 1, !!LargeIcon)
	IL_Add(HIL, FullFilePath, IconNumber)
	HICON := DllCall("Comctl32.dll\ImageList_GetIcon", "Ptr", HIL, "Int", 0, "UInt", 0, "UPtr")
	IL_Destroy(HIL)
	return HICON
}

IL_GuiButtonIcon(Handle, File, Index := 1, Options := "") {											;--

	RegExMatch(Options, "i)w\K\d+", W), (W="") ? W := 16 :
	RegExMatch(Options, "i)h\K\d+", H), (H="") ? H := 16 :
	RegExMatch(Options, "i)s\K\d+", S), S ? W := H := S :
	RegExMatch(Options, "i)l\K\d+", L), (L="") ? L := 0 :
	RegExMatch(Options, "i)t\K\d+", T), (T="") ? T := 0 :
	RegExMatch(Options, "i)r\K\d+", R), (R="") ? R := 0 :
	RegExMatch(Options, "i)b\K\d+", B), (B="") ? B := 0 :
	RegExMatch(Options, "i)a\K\d+", A), (A="") ? A := 4 :
	Psz := A_PtrSize = "" ? 4 : A_PtrSize, DW := "UInt", Ptr := A_PtrSize = "" ? DW : "Ptr"
	VarSetCapacity( button_il, 20 + Psz, 0 )
	NumPut( normal_il := DllCall( "ImageList_Create", DW, W, DW, H, DW, 0x21, DW, 1, DW, 1 ), button_il, 0, Ptr )   ; Width & Height
	NumPut( L, button_il, 0 + Psz, DW )     ; Left Margin
	NumPut( T, button_il, 4 + Psz, DW )     ; Top Margin
	NumPut( R, button_il, 8 + Psz, DW )     ; Right Margin
	NumPut( B, button_il, 12 + Psz, DW )    ; Bottom Margin
	NumPut( A, button_il, 16 + Psz, DW )    ; Alignment
	SendMessage, BCM_SETIMAGELIST := 5634, 0, &button_il,, AHK_ID %Handle%
	return IL_Add( normal_il, File, Index )

}

		} 

		{ ;Listbox control functions (3)

LB_AdjustItemHeight(HListBox, Adjust) {																		;-- Listbox function
	; https://autohotkey.com/board/topic/89793-set-height-of-listbox-rows/
	; https://github.com/altbdoor/ahk-hs-chara/blob/master/utility.ahk
	Return LB_SetItemHeight(HListBox, LB_GetItemHeight(HListBox) + Adjust)
}

LB_GetItemHeight(HListBox) {																						;-- Listbox function
	; https://github.com/altbdoor/ahk-hs-chara/blob/master/utility.ahk
	Static LB_GETITEMHEIGHT := 0x01A1
	SendMessage, %LB_GETITEMHEIGHT%, 0, 0, , ahk_id %HListBox%
	Return ErrorLevel
}

LB_SetItemHeight(HListBox, NewHeight) {																	;-- Listbox function
	; https://github.com/altbdoor/ahk-hs-chara/blob/master/utility.ahk
	Static LB_SETITEMHEIGHT := 0x01A0
	SendMessage, %LB_SETITEMHEIGHT%, 0, %NewHeight%, , ahk_id %HListBox%
	WinSet, Redraw, , ahk_id %HListBox%
	Return ErrorLevel
}

		} 

		{ ;Listview functions (35)

LV_GetCount(hLV) {																											;-- get current count of notes in from any listview 

	;https://autohotkey.com/boards/viewtopic.php?t=26317
	;hLV - Listview handle

	c := DllCall("SendMessage", "uint", hLV, "uint", 0x18B) ; LB_GETCOUNT
	return c

}

LV_SetSelColors(HLV, BkgClr := "", TxtClr := "", Dummy := "") {										;-- sets the colors for selected rows in a listView.

	; ==================================================================================================================================
	; Sets the colors for selected rows in a ListView.
	; Parameters:
	;     HLV      -  handle (HWND) of the ListView control.
	;     BkgClr   -  background color as RGB integer value (0xRRGGBB).
	;                 If omitted or empty the ListViews's background color will be used.
	;     TxtClr   -  text color as RGB integer value (0xRRGGBB).
	;                 If omitted or empty the ListView's text color will be used.
	;                 If both BkgColor and TxtColor are omitted or empty the control will be reset to use the default colors.
	;     Dummy    -  must be omitted or empty!!!
	; Return value:
	;     No return value.
	; Remarks:
	;     The function adds a handler for WM_NOTIFY messages to the chain of existing handlers.
	; ==================================================================================================================================

   Static OffCode := A_PtrSize * 2              ; offset of code        (NMHDR)
        , OffStage := A_PtrSize * 3             ; offset of dwDrawStage (NMCUSTOMDRAW)
        , OffItem := (A_PtrSize * 5) + 16       ; offset of dwItemSpec  (NMCUSTOMDRAW)
        , OffItemState := OffItem + A_PtrSize   ; offset of uItemState  (NMCUSTOMDRAW)
        , OffClrText := (A_PtrSize * 8) + 16    ; offset of clrText     (NMLVCUSTOMDRAW)
        , OffClrTextBk := OffClrText + 4        ; offset of clrTextBk   (NMLVCUSTOMDRAW)
        , Controls := {}
        , MsgFunc := Func("LV_SetSelColors")
        , IsActive := False
   Local Item, H, LV, Stage
   If (Dummy = "") { ; user call ------------------------------------------------------------------------------------------------------
      If (BkgClr = "") && (TxtClr = "")
         Controls.Delete(HLV)
      Else {
         If (BkgClr <> "")
            Controls[HLV, "B"] := ((BkgClr & 0xFF0000) >> 16) | (BkgClr & 0x00FF00) | ((BkgClr & 0x0000FF) << 16) ; RGB -> BGR
         If (TxtClr <> "")
            Controls[HLV, "T"] := ((TxtClr & 0xFF0000) >> 16) | (TxtClr & 0x00FF00) | ((TxtClr & 0x0000FF) << 16) ; RGB -> BGR
      }

      If (Controls.MaxIndex() = "") {
         If (IsActive) {
            OnMessage(0x004E, MsgFunc, 0)
            IsActive := False
      }  } Else If !(IsActive) {
         OnMessage(0x004E, MsgFunc)
         IsActive := True
   }  }
   Else { ; system call ------------------------------------------------------------------------------------------------------------
      ; HLV : wParam, BkgClr : lParam, TxtClr : uMsg, Dummy : hWnd
      H := NumGet(BkgClr + 0, "UPtr")
      If (LV := Controls[H]) && (NumGet(BkgClr + OffCode, "Int") = -12) { ; NM_CUSTOMDRAW
         Stage := NumGet(BkgClr + OffStage, "UInt")
         If (Stage = 0x00010001) { ; CDDS_ITEMPREPAINT
            Item := NumGet(BkgClr + OffItem, "UPtr")
            If DllCall("SendMessage", "Ptr", H, "UInt", 0x102C, "Ptr", Item, "Ptr", 0x0002, "UInt") { ; LVM_GETITEMSTATE, LVIS_SELECTED
               ; The trick: remove the CDIS_SELECTED (0x0001) and CDIS_FOCUS (0x0010) states from uItemState and set the colors.
               NumPut(NumGet(BkgClr + OffItemState, "UInt") & ~0x0011, BkgClr + OffItemState, "UInt")
               If (LV.B <> "")
                  NumPut(LV.B, BkgClr + OffClrTextBk, "UInt")
               If (LV.T <> "")
                  NumPut(LV.T, BkgClr + OffClrText, "UInt")
               Return 0x02 ; CDRF_NEWFONT
         }  }
         Else If (Stage = 0x00000001) ; CDDS_PREPAINT
            Return 0x20 ; CDRF_NOTIFYITEMDRAW
         Return 0x00 ; CDRF_DODEFAULT
}  }  }

LV_Select(r:=1, Control:="", WinTitle:="") {																		;-- select/deselect 1 to all rows of a listview

	; Modified from http://www.autohotkey.com/board/topic/54752-listview-select-alldeselect-all/?p=343662
	; Examples: LVSel(1 , "SysListView321", "Win Title")   ; Select row 1. (or use +1)
	;           LVSel(-1, "SysListView321", "Win Title")   ; Deselect row 1
	;           LVSel(+0, "SysListView321", "Win Title")   ; Select all
	;           LVSel(-0, "SysListView321", "Win Title")   ; Deselect all
	;           LVSel(+0,                 , "ahk_id " HLV) ; Use listview's hwnd

	VarSetCapacity(LVITEM, 4*15, 0) ;Do *13 if you're not on Vista or Win 7 (see MSDN)

	state := InStr(r, "-") ? 0x00000000 : 0x00000002
	NumPut(0x00000008, LVITEM, 4*0) ;mask = LVIF_STATE
	NumPut(state,      LVITEM, 4*3) ;state = <second LSB must be 1>
	NumPut(0x0002,     LVITEM, 4*4) ;stateMask = LVIS_SELECTED

	;LVM_SETITEMSTATE = LVM_FIRST + 43
	r := RegExReplace(r, "\D") - 1
	SendMessage, 0x1000 + 43, r, &LVITEM, %Control%, %WinTitle%

}

LV_GetItemText(item_index, sub_index, ctrl_id, win_id) {												;-- read the text from an item in a TListView

		; https://autohotkey.com/board/topic/18299-reading-listview-of-another-app/
		; code from Tigerite

		/* 			Example

			F4::
			pList = ahk_class TPlayerListForm
			WinGet, active_id, ID, %pList%
			;WinGet, active_id, ID, ahk_class TPlayerListForm
			;MsgBox, The active window's ID is "%a_id%".

			p0 := LV_GetItemText((0, 2, "TListView1", active_id)
			p1 := LV_GetItemText((1, 2, "TListView1", active_id)
			p2 := LV_GetItemText((2, 2, "TListView1", active_id)
			p3 := LV_GetItemText((3, 2, "TListView1", active_id)
			p4 := LV_GetItemText((4, 2, "TListView1", active_id)
			p5 := LV_GetItemText((5, 2, "TListView1", active_id)
			MsgBox %p0%`n %p1%`n %p2%`n %p3%`n %p4%`n %p5%
			Return

		*/

        ;const
        MAX_TEXT = 260

        VarSetCapacity(szText, MAX_TEXT, 0)
        VarSetCapacity(szClass, MAX_TEXT, 0)
        ControlGet, hListView, Hwnd, , %ctrl_id%, ahk_id %win_id%
        DllCall("GetClassName", UInt,hListView, Str,szClass, Int,MAX_TEXT)
        if (DllCall("lstrcmpi", Str,szClass, Str,"SysListView32") == 0 || DllCall("lstrcmpi", Str,szClass, Str,"TListView") == 0)
        {
            LVGet_Text(hListView, item_index, sub_index, szText, MAX_TEXT)
        }

        return %szText%
    }

LV_GetText(hListView,iItem,iSubItem,ByRef lpString,nMaxCount) {									;--
        ;const
        NULL = 0
        PROCESS_ALL_ACCESS = 0x001F0FFF
        INVALID_HANDLE_VALUE = 0xFFFFFFFF
        PAGE_READWRITE = 4
        FILE_MAP_WRITE = 2
        MEM_COMMIT = 0x1000
        MEM_RELEASE = 0x8000
        LV_ITEM_mask = 0
        LV_ITEM_iItem = 4
        LV_ITEM_iSubItem = 8
        LV_ITEM_state = 12
        LV_ITEM_stateMask = 16
        LV_ITEM_pszText = 20
        LV_ITEM_cchTextMax = 24
        LVIF_TEXT = 1
        LVM_GETITEM = 0x1005
        SIZEOF_LV_ITEM = 0x28
        SIZEOF_TEXT_BUF = 0x104
        SIZEOF_BUF = 0x120
        SIZEOF_INT = 4
        SIZEOF_POINTER = 4

        ;var
        result := 0
        hProcess := NULL
        dwProcessId := 0

        if lpString <> NULL && nMaxCount > 0
        {
            DllCall("lstrcpy", Str,lpString, Str,"")
            DllCall("GetWindowThreadProcessId", UInt,hListView, UIntP,dwProcessId)
            hProcess := DllCall("OpenProcess", UInt,PROCESS_ALL_ACCESS, Int,false, UInt,dwProcessId)
            if hProcess <> NULL
            {
                ;var
                lpProcessBuf := NULL
                hMap := NULL
                hKernel := DllCall("GetModuleHandle", Str,"kernel32.dll", UInt)
                pVirtualAllocEx := DllCall("GetProcAddress", UInt,hKernel, Str,"VirtualAllocEx", UInt)

                if pVirtualAllocEx == NULL
                {
                    hMap := DllCall("CreateFileMapping", UInt,INVALID_HANDLE_VALUE, Int,NULL, UInt,PAGE_READWRITE, UInt,0, UInt,SIZEOF_BUF, UInt)
                    if hMap <> NULL
                        lpProcessBuf := DllCall("MapViewOfFile", UInt,hMap, UInt,FILE_MAP_WRITE, UInt,0, UInt,0, UInt,0, UInt)
                }
                else
                {
                    lpProcessBuf := DllCall("VirtualAllocEx", UInt,hProcess, UInt,NULL, UInt,SIZEOF_BUF, UInt,MEM_COMMIT, UInt,PAGE_READWRITE)
                }

                if lpProcessBuf <> NULL
                {
                    ;var
                    VarSetCapacity(buf, SIZEOF_BUF, 0)

                    InsertInteger(LVIF_TEXT, buf, LV_ITEM_mask, SIZEOF_INT)
                    InsertInteger(iItem, buf, LV_ITEM_iItem, SIZEOF_INT)
                    InsertInteger(iSubItem, buf, LV_ITEM_iSubItem, SIZEOF_INT)
                    InsertInteger(lpProcessBuf + SIZEOF_LV_ITEM, buf, LV_ITEM_pszText, SIZEOF_POINTER)
                    InsertInteger(SIZEOF_TEXT_BUF, buf, LV_ITEM_cchTextMax, SIZEOF_INT)

                    if DllCall("WriteProcessMemory", UInt,hProcess, UInt,lpProcessBuf, UInt,&buf, UInt,SIZEOF_BUF, UInt,NULL) <> 0
                        if DllCall("SendMessage", UInt,hListView, UInt,LVM_GETITEM, Int,0, Int,lpProcessBuf) <> 0
                            if DllCall("ReadProcessMemory", UInt,hProcess, UInt,lpProcessBuf, UInt,&buf, UInt,SIZEOF_BUF, UInt,NULL) <> 0
                            {
                                DllCall("lstrcpyn", Str,lpString, UInt,&buf + SIZEOF_LV_ITEM, Int,nMaxCount)
                                result := DllCall("lstrlen", Str,lpString)
                            }
                }

                if lpProcessBuf <> NULL
                    if pVirtualAllocEx <> NULL
                        DllCall("VirtualFreeEx", UInt,hProcess, UInt,lpProcessBuf, UInt,0, UInt,MEM_RELEASE)
                    else
                        DllCall("UnmapViewOfFile", UInt,lpProcessBuf)

                if hMap <> NULL
                    DllCall("CloseHandle", UInt,hMap)

                DllCall("CloseHandle", UInt,hProcess)
            }
        }
        return result
    }
{ ;Sub	for LV_GetItemText and LV_GetText
ExtractInteger(ByRef pSource, pOffset = 0, pIsSigned = false, pSize = 4) {

; Original versions of ExtractInteger and InsertInteger provided by Chris
; - from the AutoHotkey help file - Version 1.0.37.04

; pSource is a string (buffer) whose memory area contains a raw/binary integer at pOffset.
; The caller should pass true for pSigned to interpret the result as signed vs. unsigned.
; pSize is the size of PSource's integer in bytes (e.g. 4 bytes for a DWORD or Int).
; pSource must be ByRef to avoid corruption during the formal-to-actual copying process
; (since pSource might contain valid data beyond its first binary zero).

   SourceAddress := &pSource + pOffset  ; Get address and apply the caller's offset.
   result := 0  ; Init prior to accumulation in the loop.
   Loop %pSize%  ; For each byte in the integer:
   {
      result := result | (*SourceAddress << 8 * (A_Index - 1))  ; Build the integer from its bytes.
      SourceAddress += 1  ; Move on to the next byte.
   }
   if (!pIsSigned OR pSize > 4 OR result < 0x80000000)
      return result  ; Signed vs. unsigned doesn't matter in these cases.
   ; Otherwise, convert the value (now known to be 32-bit) to its signed counterpart:
   return -(0xFFFFFFFF - result + 1)
}
InsertInteger(pInteger, ByRef pDest, pOffset = 0, pSize = 4) {
; To preserve any existing contents in pDest, only pSize number of bytes starting at pOffset
; are altered in it. The caller must ensure that pDest has sufficient capacity.

   mask := 0xFF  ; This serves to isolate each byte, one by one.
   Loop %pSize%  ; Copy each byte in the integer into the structure as raw binary data.
   {
      DllCall("RtlFillMemory", UInt, &pDest + pOffset + A_Index - 1, UInt, 1  ; Write one byte.
         , UChar, (pInteger & mask) >> 8 * (A_Index - 1))  ; This line is auto-merged with above at load-time.
      mask := mask << 8  ; Set it up for isolation of the next byte.
   }
}
} 

LV_SetBackgroundURL(URL, ControlID) {																		;-- set a ListView's background image - please pay attention to the description

	/*											Function: LV_SetBackgroundURL

		Origin 	: https://autohotkey.com/board/topic/20588-adding-pictures-to-controls-eg-as-background/#entry135365
		Author	: Lexikos

		The function below tiles the background, since the only alternative is to attach it to the top-left of the very first item (in which
		case it scrolls with the ListView's contents.)

		Since LVM_SETBKIMAGE (internally) uses COM, CoInitialize() must be called when the script starts:

		DllCall("ole32\CoInitialize", "uint", 0)

		..and CoUninitialize() when the script exits:

		DllCall("ole32\CoUninitialize")Important: The ListView/GUI should be destroyed before calling CoUninitialize(),
		otherwise the script will crash on exit for some versions of Windows.

		LVM_SETBKIMAGE can be made to accept a bitmap handle, so it would be possible to manually stretch an image to fit the
		ListView rather than tiling it. (Search MSDN for LVM_SETBKIMAGE.)

	*/

	/*											Example

		LV_SetBackgroundURL("http://www.autohotkey.com/docs/images/AutoHotkey_logo.gif", "SysListView321")

		If the ListView has an associated variable, its name can be used in place of SysListView321.
		Don't forget CoInitialize() and CoUninitialize().

		Edit: Added line to set text background to transparent. Also added note about destroying GUI before CoUninitialize().

	*/

	; URL:          URL or file path (absolute, not relative)
	; ControlID:    ClassNN or associated variable of a ListView on the default GUI.

    GuiControlGet, hwnd, Hwnd, %ControlID%
    VarSetCapacity(bki, 24, 0)
    NumPut(0x2|0x10, bki, 0)  ; LVBKIF_SOURCE_URL | LVBKIF_STYLE_TILE
    NumPut(&URL, bki, 8)
    SendMessage, 0x1044, 0, &bki,, ahk_id %hwnd%  ; LVM_SETBKIMAGE
    SendMessage, 0x1026, 0, -1,, ahk_id %ControlID%  ; LVM_SETTEXTBKCOLOR,, CLR_NONE
}

LV_MoveRow(up=true) {																									;-- moves a listview row up or down

	if (up && LV_GetNext() == 1)
	|| (!up && LV_GetNext() == LV_GetCount())
	|| (LV_GetNext() == 0)
		return

	pos := LV_GetNext()
	, xpos := up ? pos-1 : pos+1

	Loop,% LV_GetCount("Col") {
		LV_GetText(a, pos, A_Index)
		LV_GetText(b, xpos, A_Index)
		LV_Modify(pos, "Col" A_Index, b)
		LV_Modify(xpos, "Col" A_Index, a)
	}
	LV_Modify(pos, "-Select -Focus")
	, LV_Modify(xpos, "Select Focus")
}

LV_MoveRow(moveup = true) {																						;-- the same like above, but slightly different. With integrated script example.

	/*			Example with Gui and key support

				Gui, Add, Listview, w260 h200 vmylistview, test|test2|test3|test4
			   LV_Modifycol(1, 60)
			   LV_Modifycol(2, 60)
			   LV_Modifycol(3, 60)
			   LV_Modifycol(4, 60)

			Loop, 10
			   LV_Add("", A_Index, "-" A_Index, (10 - A_Index), "x" A_Index)

			Gui, Show, Center AutoSize, TestGUI
			Return

			GuiClose:
			GuiEscape:
			ExitApp

			PgUp::LV_MoveRow()
			PgDn::LV_MoveRow(false)
	*/

   ; Original by diebagger (Guest) from:
   ; http://de.autohotkey.com/forum/viewtopic.php?p=58526#58526
   ; Slightly Modifyed by Obi-Wahn
   ; http://ahkscript.org/germans/forums/viewtopic.php?t=7285
   If moveup not in 1,0
      Return   ; If direction not up or down (true or false)
   while x := LV_GetNext(x)   ; Get selected lines
      i := A_Index, i%i% := x
   If (!i) || ((i1 < 2) && moveup) || ((i%i% = LV_GetCount()) && !moveup)
      Return   ; Break Function if: nothing selected, (first selected < 2 AND moveup = true) [header bug]
            ; OR (last selected = LV_GetCount() AND moveup = false) [delete bug]
   cc := LV_GetCount("Col"), fr := LV_GetNext(0, "Focused"), d := moveup ? -1 : 1
   ; Count Columns, Query Line Number of next selected, set direction math.
   Loop, %i% {   ; Loop selected lines
      r := moveup ? A_Index : i - A_Index + 1, ro := i%r%, rn := ro + d
      ; Calculate row up or down, ro (current row), rn (target row)
      Loop, %cc% {   ; Loop through header count
         LV_GetText(to, ro, A_Index), LV_GetText(tn, rn, A_Index)
         ; Query Text from Current and Targetrow
         LV_Modify(rn, "Col" A_Index, to), LV_Modify(ro, "Col" A_Index, tn)
         ; Modify Rows (switch text)
      }
      LV_Modify(ro, "-select -focus"), LV_Modify(rn, "select vis")
      If (ro = fr)
         LV_Modify(rn, "Focus")
   }
}

LV_Find( lvhwnd, str, start = 0 ) { 	        																		;-- I think it's usefull to find an item position a listview
	
	;Copyright © 2013 VxE. All rights reserved.
	Static LVFI_STRING := 2, LVFI_SUBSTRING := 4
	LVM_FINDITEM := A_IsUnicode = 1 ? 0x1053 : 0x100D
	oel := ErrorLevel
	start |= 0
	If ( partial := ( SubStr( str, 0 ) = "*" ? LVFI_SUBSTRING : 0 ) )
		StringTrimRight str, str, 1
	VarSetCapacity( LVFINDINFO, 12 + 3 * ( A_PtrSize = 8 ? 8 : 4 ), 0 )
	NumPut( LVFI_STRING | partial, LVFINDINFO, 0, "UInt" )
	NumPut( &str, LVFINDINFO, 4 )
	SendMessage, LVM_FINDITEM, % start < 0 ? -1 : start - 1, &LVFINDINFO,, Ahk_ID %lvhwnd%
	Return ( ErrorLevel & 0xFFFFFFFF ) + 1, ErrorLevel := oel
}

LV_GetSelectedText(FromColumns="",ColumnsDelimiter="`t",RowsDelimiter= "`n") { ;-- Returns text from selected rows in ListView (in a user friendly way IMO.)

		; by Learning one,	https://autohotkey.com/board/topic/61750-lv-getselectedtext/
		/*                                         	EXAMPLE
			Gui 1: Add, ListView, x5 y5 w250 h300, First name|Last name|Occupation
			LV_Add("","Jim","Tucker","Driver")
			LV_Add("","Jill","Lochte","Artist")
			LV_Add("","Jessica","Hickman","Student")
			LV_Add("","Mary","Jones","Teacher")
			LV_Add("","Tony","Jackman","Surfer")
			Gui 1: Show, w260 h310
			return

			F1::MsgBox % LV_GetSelectedText() ; get text from selected rows
			F2::MsgBox % LV_GetSelectedText("1|3") ; get text from selected rows, but only from 1. and 3. column
			F3::MsgBox % LV_GetSelectedText("1|3","|","#") ; same as above but use custom delimiters in returning string
		*/
		
		
		if FromColumns = ; than get text from all columns
		{
				Loop, % LV_GetCount("Column") ; total number of columns in LV
				FromColumns .= A_Index "|"
		}
		if (SubStr(FromColumns,0) = "|")
				StringTrimRight, FromColumns, FromColumns, 1
		Loop
		{
				RowNumber := LV_GetNext(RowNumber)
				if !RowNumber
						break
				
				Loop, parse, FromColumns, |
				{
						LV_GetText(FieldText, RowNumber, A_LoopField)
						Selected .= FieldText ColumnsDelimiter
				}
				
				if (SubStr(Selected,0) = ColumnsDelimiter)
						StringTrimRight, Selected, Selected, 1
						
				Selected .= RowsDelimiter
		}
		
		if (SubStr(Selected,0) = RowsDelimiter)
				StringTrimRight, Selected, Selected, 1
		
		return Selected

}

LV_Notification(WParam, LParam, msg, hwnd) {                                                         	;-- easy function for showing notifications by hovering over a listview
	
	;http://ahkscript.org/germans/forums/viewtopic.php?t=8225&sid=35ddff584bfe8d4e4c44a0789b388655
   ; this line for autoexec: OnMessage(WM_NOTIFY, "Notification")    
   
   Global lvx, toggle, HLV1, HLV2 
   Static LVN_ITEMCHANGING := -100 
   Static LVIS_STATEIMAGEMASK := 0xF000 ; checked 

   ;---THX an "ich" für diese Routine, um check/-uncheck zu verhindern 
   If (toggle = 0) ;0, dann keinen check/-Uncheck zulassen 
   If (NumGet(LParam+0) = HLV1) OR (NumGet(LParam+0) = HLV2) ; NMHDR -> hwndFrom 
      If (NumGet(LParam+0, 8, "Int") = LVN_ITEMCHANGING) ; NMHDR -> code 
         If (NumGet(LParam+0, 24) & LVIS_STATEIMAGEMASK) ; NMLISTVIEW -> uChanged 
            Return True ; True verhindert die Änderung 

    ;---from Titan für Color-Rows             
    If (NumGet(LParam + 0) == NumGet(lvx)) 
       Return, LVX_Notify(WParam, LParam, msg) 

   ;---verhindert das Ändern der Spaltenbreite 
   If (Code:=(~NumGet(LParam+0,8))+1) 
         Return,Code=306||Code=326 ? True:"" 
} 

LV_IsChecked( lvhwnd, nRow ) {                                                                                  	;-- alternate method to find out if a particular row number is checked
	;https://autohotkey.com/docs/commands/ListView.htm#ColN
	SendMessage, 4140, nRow - 1, 0xF000, ahk_id %lvhwnd%  	; 4140 is LVM_GETITEMSTATE. 0xF000 is LVIS_STATEIMAGEMASK.
	IsChecked := (ErrorLevel >> 12) - 1                                 	; This sets IsChecked to true if RowNumber is checked or false otherwise.
	return IsChecked
}

LV_HeaderFontSet(p_hwndlv="", p_fontstyle="", p_fontname="") {				         		;-- sets a different font to a Listview header (it's need CreateFont() function)
	
	;//******************* Functions *******************
	;//Sun, Jul 13, 2008 --- 7/13/08, 7:19:19pm
	;//Function: ListView_HeaderFontSet
	;//Params...
	;//		p_hwndlv    = ListView hwnd
	;//		p_fontstyle = [b[old]] [i[talic]] [u[nderline]] [s[trike]]
	;//		p_fontname  = <any single valid font name = Arial, Tahoma, Trebuchet MS>
	; dependings: no (changed 24.06.2018)
	
	static hFont1stBkp
	method:="CreateFont"
	;//method="CreateFontIndirect"
	WM_SETFONT:=0x0030
	WM_GETFONT:=0x0031

	LVM_FIRST:=0x1000
	LVM_GETHEADER:=LVM_FIRST+31

	;// /* Font Weights */
	FW_DONTCARE:=0
	FW_THIN:=100
	FW_EXTRALIGHT:=200
	FW_LIGHT:=300
	FW_NORMAL:=400
	FW_MEDIUM:=500
	FW_SEMIBOLD:=600
	FW_BOLD:=700
	FW_EXTRABOLD:=800
	FW_HEAVY:=900

	FW_ULTRALIGHT:=FW_EXTRALIGHT
	FW_REGULAR:=FW_NORMAL
	FW_DEMIBOLD:=FW_SEMIBOLD
	FW_ULTRABOLD:=FW_EXTRABOLD
	FW_BLACK:=FW_HEAVY
	/*
	parse p_fontstyle for...
		cBlue	color	*** Note *** OMG can't set ListView/SysHeader32 font/text color??? ***
		s19		size
		b		bold
		w500	weight?
	*/
	;//*** Note *** yes I will allow mixed types later!...this was quick n dirty...
	;//*** Note *** ...it now supports bold italic underline & strike-thru...all at once
	style:=p_fontstyle
	;//*** Note *** change RegExReplace to RegExMatch
	style:=RegExReplace(style, "i)\s*\b(?:I|U|S)*B(?:old)?(?:I|U|S)*\b\s*", "", style_bold)
	style:=RegExReplace(style, "i)\s*\b(?:B|U|S)*I(?:talic)?(?:B|U|S)*\b\s*", "", style_italic)
	style:=RegExReplace(style, "i)\s*\b(?:B|I|S)*U(?:nderline)?(?:B|I|S)*\b\s*", "", style_underline)
	style:=RegExReplace(style, "i)\s*\b(?:B|I|U)*S(?:trike)?(?:B|I|U)*\b\s*", "", style_strike)
	;//style:=RegExReplace(style, "i)\s*\bW(?:eight)(\d+)\b\s*", "", style_weight)
	if (style_bold)
		fnWeight:=FW_BOLD
	if (style_italic)
		fdwItalic:=1
	if (style_underline)
		fdwUnderline:=1
	if (style_strike)
		fdwStrikeOut:=1
	;//if (mweight)
	;//	fnWeight:=mweight
	lpszFace:=p_fontname

	ret:=hHeader:= DllCall("SendMessage", "UInt", p_hwndlv, "UInt", LVM_GETHEADER, "UInt", 0, "UInt", 0)
	el:=Errorlevel
	le:=A_LastError
	;//msgbox, 64, , SendMessage LVM_GETHEADER: ret(%ret%) el(%el%) le(%le%)

	ret:= hFontCurr:= DllCall("SendMessage", "UInt", hHeader, "UInt", WM_GETFont, "UInt", 0, "UInt", 0)
	el:=Errorlevel
	le:=A_LastError
	;//msgbox, 64, , SendMessage WM_GETFONT: ret(%ret%) el(%el%) le(%le%)
	if (!hFont1stBkp) {
		hFont1stBkp:=hFontCurr
	}

	if (method="CreateFont") {
		if (p_fontstyle!="" || p_fontname!="") {
			ret:=hFontHeader:=CreateFont(nHeight, nWidth, nEscapement, nOrientation
										, fnWeight, fdwItalic, fdwUnderline, fdwStrikeOut
										, fdwCharSet, fdwOutputPrecision, fdwClipPrecision
										, fdwQuality, fdwPitchAndFamily, lpszFace)
			el:=Errorlevel
			le:=A_LastError
		} else hFontHeader:=hFont1stBkp
				ret:= DllCall("SendMessage", "UInt", hHeader, "UInt", WM_SETFONT, "UInt", hFontHeader, "UInt", 1)
				el:=Errorlevel
				le:=A_LastError
		
	}
}

LV_SetCheckState(hLV,p_Item,p_Checked) {                                                                	;-- check (add check mark to) or uncheck (remove the check mark from) an item in the ListView control
	/*                              	DESCRIPTION
	
			 Function: 								LVM_SetCheckState
						
			 Description:						   Check (add check mark to) or uncheck (remove the check mark from) an item in
															the ListView control.
						
			 Parameters:						   p_Item - Zero-based index of the item.  Set to -1 to change all items.
															p_Checked - Set to TRUE to check item FALSE to uncheck.
						
			 Returns:								   TRUE if successful, otherwise FALSE.
			
			 Calls To Other Functions:		 * <LVM_SetItemState>
			
			 Remarks:									 * This function should only be used on a ListView control with the
															LVS_EX_CHECKBOXES style.
															* This function emulates the ListView_SetCheckState macro.
			
			From:										jballi
			
			Link:											https://autohotkey.com/board/topic/86149-checkuncheck-checkbox-in-listview-using-sendmessage/
	*/
	
    Static LVIS_UNCHECKED     :=0x1000
          ,LVIS_CHECKED       :=0x2000
          ,LVIS_STATEIMAGEMASK:=0xF000

    Return LVM_SetItemState(hLV,p_Item,p_Checked ? LVIS_CHECKED:LVIS_UNCHECKED,LVIS_STATEIMAGEMASK)
    }

LV_SetItemState(hLV,p_Item,p_State,p_StateMask) {                                                   	;-- with this function you can set all avaible states to a listview item
	
	/*                              	DESCRIPTION
	
			 Function: LVM_SetItemState
			
			 Description:			   	Changes the state of an item in a ListView control.
			
			 Parameters:			   	p_Item - Zero-based index of the item. If set to -1, the state change is
												applied to all items.
			
												p_State, p_StateMask - p_stateMask specifies which state bits to change and
												p_State contains the new values for those bits.  The other state membersare ignored.
			
			 Returns:					   TRUE if successful, otherwise FALSE.
			
			From:							jballi
			
			Link:								https://autohotkey.com/board/topic/86149-checkuncheck-checkbox-in-listview-using-sendmessage/
	*/
	 Static Dummy7168

          ;-- State flags
          ,LVIF_STATE         :=0x8
          ,LVIS_FOCUSED       :=0x1
          ,LVIS_SELECTED      :=0x2
          ,LVIS_CUT           :=0x4
          ,LVIS_DROPHILITED   :=0x8
          ,LVIS_OVERLAYMASK   :=0xF00
          ,LVIS_UNCHECKED     :=0x1000
          ,LVIS_CHECKED       :=0x2000
          ,LVIS_STATEIMAGEMASK:=0xF000

          ;-- Message
          ,LVM_SETITEMSTATE   :=0x102B                  ;-- LVM_FIRST + 43

    ;-- Define/Populate LVITEM Structure
    VarSetCapacity(LVITEM,20,0)
    NumPut(LVIF_STATE, LVITEM,0,"UInt")                 ;-- mask
    NumPut(p_Item,     LVITEM,4,"Int")                 	 ;-- iItem
    NumPut(p_State,    LVITEM,12,"UInt")                	;-- state
    NumPut(p_StateMask,LVITEM,16,"UInt")            ;-- stateMask

    ;-- Set state
    SendMessage LVM_SETITEMSTATE,p_Item,&LVITEM,,ahk_id %hLV%
    Return ErrorLevel
    }

LV_SubitemHitTest(HLV) {																								;-- get's clicked column in listview
	
	/*                              	EXAMPLE(s)
	
			NoEnv
			Gui, Margin, 20, 20
			Gui, Add, ListView, w400 r9 Grid HwndHLV1 gSubLV AltSubmit, Column 1|Column 2|Column 3
			Loop, 9
			   LV_Add("", A_Index, A_Index, A_Index)
			Loop, 3
			   LV_ModifyCol(A_Index, "AutoHdr")
			Gui, Show, , ListView
			Return
			; ----------------------------------------------------------------------------------------------------------------------
			GuiCLose:
			ExitApp
			; ----------------------------------------------------------------------------------------------------------------------
			SubLV:
			   If (A_GuiEvent = "Normal") 
			      Row := A_EventInfo
			      Column := LV_SubItemHitTest(HLV1)
							      SetTimer, KillToolTip, -1500
			   
			Return
			; ----------------------------------------------------------------------------------------------------------------------
			KillToolTip:
			   ToolTip
			Return
			
	*/
		
   ; To run this with AHK_Basic change all DllCall types "Ptr" to "UInt", please.
   ; HLV - ListView's HWND
   Static LVM_SUBITEMHITTEST := 0x1039
   VarSetCapacity(POINT, 8, 0)
   ; Get the current cursor position in screen coordinates
   DllCall("User32.dll\GetCursorPos", "Ptr", &POINT)
   ; Convert them to client coordinates related to the ListView
   DllCall("User32.dll\ScreenToClient", "Ptr", HLV, "Ptr", &POINT)
   ; Create a LVHITTESTINFO structure (see below)
   VarSetCapacity(LVHITTESTINFO, 24, 0)
   ; Store the relative mouse coordinates
   NumPut(NumGet(POINT, 0, "Int"), LVHITTESTINFO, 0, "Int")
   NumPut(NumGet(POINT, 4, "Int"), LVHITTESTINFO, 4, "Int")
   ; Send a LVM_SUBITEMHITTEST to the ListView
   SendMessage, LVM_SUBITEMHITTEST, 0, &LVHITTESTINFO, , ahk_id %HLV%
   ; If no item was found on this position, the return value is -1
   If (ErrorLevel = -1)
      Return 0
   ; Get the corresponding subitem (column)
   Subitem := NumGet(LVHITTESTINFO, 16, "Int") + 1
   Return Subitem
}

LV_EX_FindString(HLV, Str, Start := 0, Partial := False) {													;-- find an item in any listview , function works with ANSI and UNICODE (tested)
   ; LVM_FINDITEM -> http://msdn.microsoft.com/en-us/library/bb774903(v=vs.85).aspx
   Static LVM_FINDITEM := A_IsUnicode ? 0x1053 : 0x100D ; LVM_FINDITEMW : LVM_FINDITEMA
   Static LVFISize := 40
   VarSetCapacity(LVFI, LVFISize, 0) ; LVFINDINFO
   Flags := 0x0002 ; LVFI_STRING
   If (Partial)
      Flags |= 0x0008 ; LVFI_PARTIAL
   NumPut(Flags, LVFI, 0, "UInt")
   NumPut(&Str,  LVFI, A_PtrSize, "Ptr")
   SendMessage, % LVM_FINDITEM, % (Start - 1), % &LVFI, , % "ahk_id " . HLV
   Return (ErrorLevel > 0x7FFFFFFF ? 0 : ErrorLevel + 1)
}

LV_RemoveSelBorder(HLV, a*) {																						;-- remove the listview's selection border
	
	;https://autohotkey.com/boards/viewtopic.php?p=49507#p49507
	;https://stackoverflow.com/questions/2691726/how-can-i-remove-the-selection-border-on-a-listviewitem
	Static WM_CHANGEUISTATE := 0x127
	     , WM_UPDATEUISTATE := 0x128
	     , UIS_SET := 1
	     , UISF_HIDEFOCUS := 0x1
	     , wParam := (UIS_SET << 16) | (UISF_HIDEFOCUS & 0xffff) ; MakeLong
	     , _ := OnMessage(WM_UPDATEUISTATE, "LV_RemoveSelBorder")
	If (a.2 = WM_UPDATEUISTATE)
		Return 0 ; Prevent alt key from restoring the selection border
	PostMessage, WM_CHANGEUISTATE, wParam, 0,, % "ahk_id " . HLV
}

LV_SetExplorerTheme(HCTL) { 																						;-- set 'Explorer' theme for ListViews & TreeViews on Vista+
	; HCTL : handle of a ListView or TreeView control
   If (DllCall("GetVersion", "UChar") > 5) {
      VarSetCapacity(ClassName, 1024, 0)
      If DllCall("GetClassName", "Ptr", HCTL, "Str", ClassName, "Int", 512, "Int")
         If (ClassName = "SysListView32") || (ClassName = "SysTreeView32")
            Return !DllCall("UxTheme.dll\SetWindowTheme", "Ptr", HCTL, "WStr", "Explorer", "Ptr", 0)
   }
   Return False
}

LV_Update(hWnd, Item) {																								;-- update one listview item
	return SendMessage(hWnd, 0x1000+42, "Int", Item-1)
}

LV_RedrawItem(hWnd, ItemFirst := 0, ItemLast := "") {													;-- this one redraws on listview item
	If (ItemFirst > 0)
		ItemLast := ItemLast=""?ItemFirst:ItemLast
	else ItemLast := (ItemFirst:=SendMessage(hWnd, 0x1027))+SendMessage(hWnd, 0x1028)
	return SendMessage(hWnd, 0x1000+21, "Int", ItemFirst-1, "Int", ItemLast-1), DllCall("User32.dll\UpdateWindow", "Ptr", hWnd)
}

LV_SetExStyle(hWnd, ExStyle) {																						;-- set / remove / alternate extended styles to the listview control
	/*                              	DESCRIPTION
	
			; set / remove / alternate extended styles to the window.
			; Syntax: LV_SetExStyle ([hWnd], [ - Styles])
			; STYLES: https://msdn.microsoft.com/en-us/library/windows/desktop/bb774732(v=vs.85).aspx
			; 0x010000 = drawing via double buffer, which reduces flicker
			; 0x00000004 = activate the checkboxes for the elements (checkbox)
			; 0x00000001 = shows grid lines around the elements and sub-elements (grid)
			
	*/
		
	Key := SubStr(ExStyle:=Trim(ExStyle), 1, 1), ExStyle := (Key="+"||Key="-"||Key="^")?SubStr(ExStyle, 2):ExStyle
	if (Key="-")
		return SendMessage(hWnd, 0x1036, "UInt", ExStyle)
	if (Key="^")
		return LV_SetExStyle(hWnd, ((LV_GetExStyle(hWnd)&ExStyle)?"-":"") ExStyle)
	return SendMessage(hWnd, 0x1036, "UInt", ExStyle, "UInt", ExStyle)
} ;https://msdn.microsoft.com/en-us/library/windows/desktop/bb761165%28v=vs.85%29.aspx

LV_GetExStyle(hWnd) {																									;-- get / remove / alternate extended styles to the listview control
	return SendMessage(hWnd, 0x1037,,,,, "UInt")
}

LV_IsItemVisible(hWnd, Item) {																						;-- determines if a listview item is visible
	return SendMessage(hWnd, 0x10B6, "Int", Item-1)
}

LV_SetIconSpacing(hWnd, cx, cy) {																					;-- Sets the space between icons in the icon view
	/*                              	DESCRIPTION
	
			; Sets the space between icons in the icon view.
			; Syntax: LV_SetIconSpacing ([ID], [x-axis, distance in pixels], [y-axis, distance in pixels])
			
	*/
	
	
	cx := ((cx<4)&&(cx!=-1))?4:cx, cy := ((cy<4)&&(cy!=-1))?4:cy
	return SendMessage(hWnd, 0x1035,,,, LOWORD(cx)+HIWORD(cy, false))
}

LV_GetIconSpacing(hWnd, ByRef cx := "", ByRef cy := "") {												;-- Get the space between icons in the icon view
	/*                              	DESCRIPTION
	
			Get the space between icons in the icon view.
			; Syntax: LV_GetIconSpacing ([ID], [x-axis, distance in pixels (output)], [y-axis, distance in pixels (output)])
			
	*/
		
	IcSp := SendMessage(hWnd, 0x1033)
   return [cx:=(IcSp & 0xFFFF), cy:=(IcSp >> 16)]
}

LV_GetItemPos(hWnd, Item, ByRef x := "", ByRef y := "") {												;-- obtains the position of an item
	/*                              	DESCRIPTION
	
			; get position of an item
			; Syntax: LV_GetItemPos ([ID], [item], [x (output)], [y (output)])
			; Note: returns an Array with the position xy.
			
	*/
	
	
	VarSetCapacity(POINT, A_PtrSize*2, 0), SendMessage(hWnd, 0x1010,, Item-1,, &POINT)
	return [x:=NumGet(POINT, 0, "Int"), y:=NumGet(POINT, 4, "Int")]
} LV_GetItemPosEx(hWnd, Item, ByRef x := "", ByRef y := "", ByRef ProcessId := "") {
	ProcessId := ProcessId?ProcessId:WinGetPid(hWnd), hProcess := OpenProcess(ProcessId, 0x0008|0x0010|0x0020)
	, pAddress := VirtualAlloc(hProcess,, 0x00001000), SendMessage(hWnd, 0x1000+16, "Int", Item-1,, pAddress)
	, VarSetCapacity(RECT, 16, 0), ReadProcessMemory(hProcess, pAddress, &RECT, 16)
	return [x:=NumGet(RECT, 0, "Int"), y:=NumGet(RECT, 4, "Int")], VirtualFree(hProcess, pAddress), CloseHandle(hProcess)
} ;http://www.autohotkey.com/board/topic/9760-lvm-geticonposition/

LV_SetItemPos(hWnd, Item, x := "", y := "") {																	;-- set the position of an item
	/*                              	DESCRIPTION
	
			set the position of an item
			Syntax: LV_SetItemPos ([ID], [item], [x], [y])
			
	*/
	
	
	if (x="") || (y="")
		LV_GetItemPos(hWnd, Item, _x, _y)
	return SendMessage(hWnd, 0x100F,, Item-1,, LOWORD(x=""?_x:x)+HIWORD(y=""?_y:y, false))
} LV_SetItemPosEx(hWnd, Item, x := "", y := "", ProcessId := "") {
	if (x="") || (y="")
		LV_GetItemPosEx(hWnd, Item, _x, _y, ProcessId)
	return SendMessage(hWnd, 0x100F,, Item-1,, LOWORD(x=""?_x:x)+HIWORD(y=""?_y:y, false))
}

LV_MouseGetCellPos(ByRef LV_CurrRow, ByRef LV_CurrCol, LV_LView) {						;-- returns the number (row, col) of a cell in a listview at present mouseposition  
	
	LVIR_LABEL = 0x0002					;LVM_GETSUBITEMRECT constant - get label info
	LVM_GETITEMCOUNT = 4100			;gets total number of rows
	LVM_SCROLL = 4116						;scrolls the listview
	LVM_GETTOPINDEX = 4135			;gets the first displayed row
	LVM_GETCOUNTPERPAGE = 4136	;gets number of displayed rows
	LVM_GETSUBITEMRECT = 4152		;gets cell width,height,x,y
	ControlGetPos, LV_lx, LV_ly, LV_lw, LV_lh, , ahk_id %LV_LView%	;get info on listview

	SendMessage, LVM_GETITEMCOUNT, 0, 0, , ahk_id %LV_LView%
	LV_TotalNumOfRows := ErrorLevel	;get total number of rows
	SendMessage, LVM_GETCOUNTPERPAGE, 0, 0, , ahk_id %LV_LView%
	LV_NumOfRows := ErrorLevel	;get number of displayed rows
	SendMessage, LVM_GETTOPINDEX, 0, 0, , ahk_id %LV_LView%
	LV_topIndex := ErrorLevel	;get first displayed row

	CoordMode, MOUSE, RELATIVE
	MouseGetPos, LV_mx, LV_my
	LV_mx -= LV_lx, LV_my -= LV_ly

	VarSetCapacity(LV_XYstruct, 16, 0)	;create struct
	Loop,% LV_NumOfRows + 1	;gets the current row and cell Y,H
	{	LV_which := LV_topIndex + A_Index - 1	;loop through each displayed row
		NumPut(LVIR_LABEL, LV_XYstruct, 0)	;get label info constant
		NumPut(A_Index - 1, LV_XYstruct, 4)	;subitem index
		SendMessage, LVM_GETSUBITEMRECT, %LV_which%, &LV_XYstruct, , ahk_id %LV_LView%	;get cell coords
		LV_RowY := NumGet(LV_XYstruct,4)	;row upperleft y
		LV_RowY2 := NumGet(LV_XYstruct,12)	;row bottomright y2
		LV_currColHeight := LV_RowY2 - LV_RowY ;get cell height
		if (LV_my <= LV_RowY + LV_currColHeight)	;if mouse Y pos less than row pos + height
		{	LV_currRow  := LV_which + 1	;1-based current row
			LV_currRow0 := LV_which		;0-based current row, if needed
			;LV_currCol is not needed here, so I didn't do it! It will always be 0. See my ListviewInCellEditing function for details on finding LV_currCol if needed.
			LV_currCol=0
			Break
		}
	}
}

LV_GetColOrderLocal(hCtl, vSep:="") {																			;-- returns the order of listview columns for a local listview
	
	/*                              	DESCRIPTION
	
			warning: such functions can potentially crash programs, save any work before testing
			
			[need functions from here:]
			GUIs via DllCall: get/set internal/external control text - AutoHotkey Community
			https://autohotkey.com/boards/viewtopic.php?f=6&t=40514
			https://autohotkey.com/boards/viewtopic.php?t=52945
			
			pass listview hWnd (not listview header hWnd)
			for local controls only
			
	*/
	
	
	hLVH := SendMessage(0x101F,,,, "ahk_id " hCtl) ;LVM_GETHEADER := 0x101F
	vCountCol := SendMessage(0x1200,,,, "ahk_id " hLVH) ;HDM_GETITEMCOUNT := 0x1200
	vData := ""
	VarSetCapacity(vData, vCountCol*4, 0)
	SendMessage(0x103B, vCountCol, &vData,, "ahk_id " hCtl) ;LVM_GETCOLUMNORDERARRAY := 0x103B
	if (vSep = "")
	{
		oOutput := []
		Loop, % vCountCol
			oOutput.Push(NumGet(&vData, A_Index*4-4, "Int")+1)
		return oOutput
	}
	else
	{
		vOutput := ""
		Loop, % vCountCol
			vOutput .= NumGet(&vData, A_Index*4-4, "Int")+1 vSep
		return SubStr(vOutput, 1, -StrLen(vSep))
	}
}

LV_GetColOrder(hCtl, vSep:="") {																					;-- returns the order of listview columns for a listview
	;pass listview hWnd (not listview header hWnd)
	vErr := A_PtrSize=8 && JEE_WinIs64Bit(hCtl) ? -1 : 0xFFFFFFFF
	vScriptPID := DllCall("kernel32\GetCurrentProcessId", UInt)
	vPID := WinGetPID("ahk_id " hCtl)
	if (vPID = vScriptPID)
		vIsLocal := 1, vPIs64 := (A_PtrSize=8)

	if !hLVH := SendMessage(0x101F,,,, "ahk_id " hCtl) ;LVM_GETHEADER := 0x101F
		return
	if !vCountCol := SendMessage(0x1200,,,, "ahk_id " hLVH) ;HDM_GETITEMCOUNT := 0x1200
		return
	if (vCountCol = vErr) ;-1
		return

	if !vIsLocal
	{
		if !hProc := JEE_DCOpenProcess(0x438, 0, vPID)
			return
		if A_Is64bitOS && !DllCall("kernel32\IsWow64Process", Ptr,hProc, PtrP,vIsWow64Process)
			return
		vPIs64 := !vIsWow64Process
	}

	vPtrType := vPIs64?"Int64":"Int"
	vSize := vCountCol*4
	VarSetCapacity(vData, vSize, 0)

	if !vIsLocal
	{
		if !pBuf := JEE_DCVirtualAllocEx(hProc, 0, vSize, 0x3000, 0x4)
			return
	}
	else
		pBuf := &vData

	SendMessage(0x103B, vCountCol, pBuf,, "ahk_id " hCtl) ;LVM_GETCOLUMNORDERARRAY := 0x103B
	if !vIsLocal
	{
		JEE_DCReadProcessMemory(hProc, pBuf, &vData, vSize, 0)
		JEE_DCVirtualFreeEx(hProc, pBuf, 0, 0x8000)
		JEE_DCCloseHandle(hProc)
	}
	if (vSep = "")
	{
		oOutput := []
		Loop, % vCountCol
			oOutput.Push(NumGet(&vData, A_Index*4-4, "Int")+1)
		return oOutput
	}
	else
	{
		vOutput := ""
		Loop, % vCountCol
			vOutput .= NumGet(&vData, A_Index*4-4, "Int")+1 vSep
		return SubStr(vOutput, 1, -StrLen(vSep))
	}
}

LV_SetColOrderLocal(hCtl, oList, vSep:="") {																	;-- pass listview hWnd (not listview header hWnd)
	
	;for local controls only
	if !IsObject(oList)
		oList := StrSplit(oList, vSep)
	if !(vCountCol := oList.Length())
		return
	VarSetCapacity(vData, vCountCol*4)
	for _, vValue in oList
		NumPut(vValue-1, &vData, A_Index*4-4, "Int")
	SendMessage(0x103A, vCountCol, &vArray,, "ahk_id " hCtl) ;LVM_SETCOLUMNORDERARRAY := 0x103A
}

LV_SetColOrder(hCtl, oList, vSep:="") {																			;-- pass listview hWnd (not listview header hWnd)
	if !IsObject(oList)
		oList := StrSplit(oList, vSep)
	if !(vCountCol := oList.Length())
		return

	vErr := A_PtrSize=8 && JEE_WinIs64Bit(hCtl) ? -1 : 0xFFFFFFFF
	vScriptPID := DllCall("kernel32\GetCurrentProcessId", UInt)
	vPID := WinGetPID("ahk_id " hCtl)
	if (vPID = vScriptPID)
		vIsLocal := 1, vPIs64 := (A_PtrSize=8)

	if !hLVH := SendMessage(0x101F,,,, "ahk_id " hCtl) ;LVM_GETHEADER := 0x101F
		return
	if !vCountCol := SendMessage(0x1200,,,, "ahk_id " hLVH) ;HDM_GETITEMCOUNT := 0x1200
		return
	if (vCountCol = vErr) ;-1
		return

	if !vIsLocal
	{
		if !hProc := JEE_DCOpenProcess(0x438, 0, vPID)
			return
		if A_Is64bitOS && !DllCall("kernel32\IsWow64Process", Ptr,hProc, PtrP,vIsWow64Process)
			return
		vPIs64 := !vIsWow64Process
	}

	vPtrType := vPIs64?"Int64":"Int"
	vSize := vCountCol*4
	VarSetCapacity(vData, vCountCol*4)
	for _, vValue in oList
		NumPut(vValue-1, &vData, A_Index*4-4, "Int")

	if !vIsLocal
	{
		if !pBuf := JEE_DCVirtualAllocEx(hProc, 0, vSize, 0x3000, 0x4)
			return
		JEE_DCWriteProcessMemory(hProc, pBuf, &vData, vSize, 0)
	}
	else
		pBuf := &vData

	SendMessage(0x103A, vCountCol, pBuf,, "ahk_id " hCtl) ;LVM_SETCOLUMNORDERARRAY := 0x103A

	if !vIsLocal
	{
		JEE_DCVirtualFreeEx(hProc, pBuf, 0, 0x8000)
		JEE_DCCloseHandle(hProc)
	}
}

LV_GetCheckedItems(cN,wN) {																						;-- Returns a list of checked items from a standard ListView Control
    ;https://gist.github.com/TLMcode/4757894
	ControlGet, LVItems, List,, % cN, % wN
    Item:=Object()
    While Pos
        Pos:=RegExMatch(LVItems,"`am)(^.*?$)",_,!Pos?(Pos:=1):Pos+StrLen(_)),mCnt:=A_Index-1,Item[mCnt]:=_1
    Loop % mCnt {
        SendMessage, 0x102c, A_Index-1, 0x2000, % cN, % wN
        ChkItems.=(ErrorLevel ? Item[A_Index-1] "`n" : "")
    }
    Return ChkItems
}

LV_ClickRow(HLV, Row) { 																								;-- simulates a left mousebutton click on a specific row in a listview

	; just me -> http://www.autohotkey.com/board/topic/86490-click-listview-row/#entry550767
   ; HLV : ListView's HWND, Row : 1-based row number

   VarSetCapacity(RECT, 16, 0)
   SendMessage, 0x100E, Row - 1, &RECT, , ahk_id %HLV% ; LVM_GETITEMRECT
   POINT := NumGet(RECT, 0, "Short") | (NumGet(RECT, 4, "Short") << 16)
   PostMessage, 0x0201, 0, POINT, , ahk_id %HLV% ; WM_LBUTTONDOWN
   PostMessage, 0x0202, 0, POINT, , ahk_id %HLV% ; WM_LBUTTONUP

}

		}

		{ ;TabControl functions (2)

TabCtrl_GetCurSel(HWND) { 																						;-- Indexnumber of active tab in a gui
	; a function by: "just me" found on https://autohotkey.com/board/topic/79783-how-to-get-the-current-tab-name/
   ; Returns the 1-based index of the currently selected tab
   Static TCM_GETCURSEL := 0x130B
   SendMessage, TCM_GETCURSEL, 0, 0, , ahk_id %HWND%
   Return (ErrorLevel + 1)
}

TabCtrl_GetItemText(HWND, Index = 0) {																	;-- returns text of a tab
	; a function by: "just me" found on https://autohotkey.com/board/topic/79783-how-to-get-the-current-tab-name/

   Static TCM_GETITEM  := A_IsUnicode ? 0x133C : 0x1305 ; TCM_GETITEMW : TCM_GETITEMA
   Static TCIF_TEXT := 0x0001
   Static TCTXTP := (3 * 4) + (A_PtrSize - 4)
   Static TCTXLP := TCTXTP + A_PtrSize
   ErrorLevel := 0
   If (Index = 0)
      Index := TabCtrl_GetCurSel(HWND)
   If (Index = 0)
      Return SetError(1, "")
   VarSetCapacity(TCTEXT, 256 * SizeT, 0)
   ; typedef struct {
   ;   UINT   mask;           4
   ;   DWORD  dwState;        4
   ;   DWORD  dwStateMask;    4 + 4 bytes padding on 64-bit systems
   ;   LPTSTR pszText;        4 / 8 (32-bit / 64-bit)
   ;   int    cchTextMax;     4
   ;   int    iImage;         4
   ;   LPARAM lParam;         4 / 8
   ; } TCITEM, *LPTCITEM;
   VarSetCapacity(TCITEM, (5 * 4) + (2 * A_PtrSize) + (A_PtrSize - 4), 0)
   NumPut(TCIF_TEXT, TCITEM, 0, "UInt")
   NumPut(&TCTEXT, TCITEM, TCTXTP, "Ptr")
   NumPut(256, TCITEM, TCTXLP, "Int")
   SendMessage, TCM_GETITEM, --Index, &TCITEM, , ahk_id %HWND%
   If !(ErrorLevel)
      Return SetError(1, "")
   Else
      Return SetError(0, StrGet(NumGet(TCITEM, TCTXTP, "UPtr")))
}
{ ;sub of TabCtrl functions
SetError(ErrorValue, ReturnValue) {

	;; a function by: "just me" found on https://autohotkey.com/board/topic/79783-how-to-get-the-current-tab-name/
   ErrorLevel := ErrorValue
   Return ReturnValue
}
} 

		} 

		{ ;Treeview functions (2)

TV_Find(VarText) {																										;-- returns the ID of an item based on the text of the item

	Loop {
		ItemID := TV_GetNext(ItemID, "Full")
		if not ItemID
			break
		TV_GetText(ItemText, ItemID)
		If (ItemText=VarText)
			Return ItemID
	}

Return
}

TV_Load(src, p:=0, recurse:=false) {																			;-- loads TreeView items from an XML string

	/*	Description

	a function by Coco found at https://autohotkey.com/boards/viewtopic.php?t=91

	This function loads TreeView items from an XML string. By using XPath expressions, the user can instruct the function on how to process/parse
	the XML source and on how the items are to be added.

	--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	A. The XML structure

	This function is versatile enough to accept any user-defined XML string. Parsing instructions are defined as XPath expressions assigned as values
	to the root element's attribute(s). The following attribute names should be used(strictly applies to the root element only):

	name - 		specify an XPath expression, query must resolve to either of the following nodeTypes: element, attribute, text, cdatasection, comment.
					The selection is applied to the element node that is defined as a TreeView item. If not defined, the element node's tagName property
					is used as the TreeView's item's name.

	options - 	same as above

	global - 	An XPath expression. This attribute defines global TreeView item options to be applied to all TreeView items that are to be added.
					Selection is applied to the root node.

	exclude - An XPath expression. Specifies which nodes(element) are not to be added as TreeView items. Selection is applied to the root node.

	match - An XPath expression. Specifies which element nodes are to be added as TreeView items. By default all element nodes(except the root
				node) are added as items to the TreeView. Selection is applied to the root node.

	Note: Only element nodes are added as TreeView items.

	--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	B. Function parameters

		src - an XML string
		p - parentItem's ID. Defaults to '0' - top item of the TreeView

	*/

	/* Example

		#Include TV_Load.ahk ;or Copy-Paste fucntion in script

		tv1 := "
		(Join
		<TREEVIEW name='@n' options='@o' match='//i' global='bold'>
		 <i n='AutoHotkey' o='expand'>
		  <i n='Hello World'/>
		 </i>
		 <i n='TreeView Item'/>
		 <i n='Another Item' o='-bold expand'>
		  <excluded>
		   <i n='The quick brown fox'/>
		  </excluded>
		  <i n='Child Item'>
		   <i n='Descendant'/>
		  </i>
		  <i n='Sibling Item' o='-bold'/>
		 </i>
		</TREEVIEW>
		)"

		tv2 := "
		(Join
		<TREEVIEW name='name/text()' options='options/text()' match='//i' global='expand'>
		 <i>
		  <name><![CDATA[AutoHotkey]]></name>
		  <options>bold</options>
		  <i>
		   <name><![CDATA[Child Item]]></name>
		   <options/>
		  </i>
		 </i>
		 <i>
		  <name><![CDATA[<XML STRING/>]]></name>
		  <options/>
		 </i>
		 <i>
		  <name><![CDATA[Sibling Item]]></name>
		  <options>check</options>
		  <i>
		   <name><![CDATA[Hello World]]></name>
		   <options/>
		   <i>
			<name><![CDATA[Descendant]]></name>
			<options>check</options>
		   </i>
		  </i>
		 </i>
		 <i>
		  <name><![CDATA[Items automatcially expanded]]></name>
		  <options/>
		 </i>
		</TREEVIEW>
		)"

		Gui, Margin, 0, 0
		Gui, Font, s9, Consolas
		Gui, Add, TreeView, w250 r15
		TV_Load(tv1)
		Gui, Add, TreeView, x+5 yp w250 r15 Checked
		TV_Load(tv2)
		Gui, Show
		return
		GuiClose:
		ExitApp

	*/

	;recurse is an internal parameter
	static xpr , root
	static TVL_NAME , TVL_OPTIONS , TVL_GLOBAL , TVL_EXCLUDE , TVL_MATCH

	if !xpr
		xpr := {TVL_NAME:"@*[translate(name(), 'NAME', 'name')='name']"
		    ,   TVL_OPTIONS:"@*[translate(name(), 'OPTIONS', 'options')='options']"
		    ,   TVL_GLOBAL:"@*[translate(name(), 'GLOBAL', 'global')='global']"
		    ,   TVL_EXCLUDE:"@*[translate(name(), 'EXCLUDE', 'exclude')='exclude']"
		    ,   TVL_MATCH:"@*[translate(name(), 'MATCH', 'match')='match']"}

	if !IsObject(src)
		x := ComObjCreate("MSXML2.DOMDocument.6.0")
		, x.setProperty("SelectionLanguage", "XPath") ;redundant
		, x.async := false , x.loadXML(src)
		, src := x.documentElement

	if !recurse {
		root := src.selectSingleNode("/*") ;src.ownerDocument.documentElement

		for var, xp in xpr
			if (var ~= "^TVL_(NAME|OPTIONS|GLOBAL)$")
				%var% := (_:=root.selectSingleNode(xp))
				      ? _.value
				      : (var="TVL_NAME" ? "." : "")

			else if (var ~= "^TVL_(EXCLUDE|MATCH)$")
				%var% := (_:=root.selectSingleNode(xp))
				      ? (_.value<>"" ? root.selectNodes(_.value) : "")
				      : ""
	}

	for e in src.childNodes {
		if (e.nodeTypeString <> "element")
			continue
		if (TVL_EXCLUDE && TVL_EXCLUDE.matches(e))
			continue
		if (TVL_MATCH && !TVL_MATCH.matches(e))
			continue

		for k, v in {name:TVL_NAME, options:TVL_OPTIONS}
			%k% := (n:=e.selectSingleNode(v))[(n.nodeType>1 ? "nodeValue" : "nodeName")]

		if (TVL_GLOBAL <> "") {
			go := TVL_GLOBAL
			Loop, Parse, options, % " `t", % " `t"
			{
				if ((alf:=A_LoopField) == "")
					continue
				if InStr(go, m:=RegExReplace(alf, "i)[^a-z]+", ""))
					go := RegExReplace(go, "i)\S*" m "\S*", alf)
				else (go .=  " " . alf)
			}

		} else go := options

		id := TV_Add(name, p, go)
		if e.hasChildNodes()
			TV_Load(e, id, true)
	}
	;Empty/reset static vars
	if !recurse
		root := ""
		, TVL_NAME := ""
		, TVL_OPTIONS := ""
		, TVL_GLOBAL := ""
		, TVL_EXCLUDE := ""
		, TVL_MATCH := ""

}

		} 

		{ ;GDI Control functions (2)

ControlCreateGradient(Handle, Colors*) {																	;-- draws a gradient as background picture

   GuiControlGet, C, Pos, %Handle%
   ColorCnt := Colors.Length()
   Size := ColorCnt * 2 * 4
   VarSetCapacity(Bits, Size, 0)
   Addr := &Bits
   For Each, Color In Colors
      Addr := Numput(Color, NumPut(Color, Addr + 0, "UInt"), "UInt")
    HBMP := DllCall("CreateBitmap", "Int", 2, "Int", ColorCnt, "UInt", 1, "UInt", 32, "Ptr", 0, "Ptr")
    HBMP := DllCall("CopyImage", "Ptr", HBMP, "UInt", 0, "Int", 0, "Int", 0, "UInt", 0x2008, "Ptr")
    DllCall("SetBitmapBits", "Ptr", HBMP, "UInt", Size, "Ptr", &Bits)
    HBMP := DllCall("CopyImage", "Ptr", HBMP, "UInt", 0, "Int", CW, "Int", CH, "UInt", 0x2008, "Ptr")
    DllCall("SendMessage", "Ptr", Handle, "UInt", 0x0172, "Ptr", 0, "Ptr", HBMP, "Ptr")
    Return True

}

AddGraphicButtonPlus(ImgPath, Options="", Text="") {												;-- GDI+ add a graphic button to a gui

    hGdiPlus := DllCall("LoadLibrary", "Str", "gdiplus.dll")
    VarSetCapacity(si, 16, 0), si := Chr(1)
    DllCall("gdiplus\GdiplusStartup", "UIntP", pToken, "UInt", &si, "UInt", 0)
    VarSetCapacity(wFile, StrLen(ImgPath)*2+2)
    DllCall("kernel32\MultiByteToWideChar", "UInt", 0, "UInt", 0, "Str", ImgPath, "Int", -1, "UInt", &wFile, "Int", VarSetCapacity(wFile)//2)
    DllCall("gdiplus\GdipCreateBitmapFromFile", "UInt", &wFile, "UIntP", pBitmap)
    if (pBitmap) {
        DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "UInt", pBitmap, "UIntP", hBM, "UInt", 0)
        DllCall("gdiplus\GdipDisposeImage", "Uint", pBitmap)
    }
    DllCall("gdiplus\GdiplusShutdown" , "UInt", pToken)
    DllCall("FreeLibrary", "UInt", hGdiPlus)

    if Text =
    {
        VarSetCapacity(oBM, 24)
        DllCall("GetObject","uint",hBM,"int",24,"uint",&oBM)
        Options := "W" NumGet(oBM,4,"int") " H" NumGet(oBM,8,"int") " +128 " Options
    }

    Gui, Add, Button, %Options% hwndhwnd, %Text%

    SendMessage, 0xF7, 0, hBM,, ahk_id %hwnd%  ; BM_SETIMAGE
    if ErrorLevel ; delete previous image
        DllCall("DeleteObject", "uint", ErrorLevel)

    return hBM
}

		} 
	}

{ ;Gui/Window/Screen - functions for retreaving informations (67)

{ ; SCREEN-------get (2)
screenDims() {																											;-- returns informations of active screen (size, DPI and orientation)

	W := A_ScreenWidth
	H := A_ScreenHeight
	DPI := A_ScreenDPI
	Orient := (W>H)?"L":"P"
	;MsgBox % "W: "W "`nH: "H "`nDPI: "DPI
	return {W:W, H:H, DPI:DPI, OR:Orient}

}

DPIFactor() {																												;-- determines the Windows setting to the current DPI factor

	RegRead, DPI_value, HKEY_CURRENT_USER, Control Panel\Desktop\WindowMetrics, AppliedDPI
	; the reg key was not found - it means default settings
	; 96 is the default font size setting
	if (errorlevel=1) OR (DPI_value=96 )
		return 1
	else
		Return  DPI_Value/96

}

} 

{ ; CONTROL type - get (not control specific functions) (18)

ControlExists(class) {																									;-- true/false for ControlClass
  WinGet, WinList, List  ;gets a list of all windows
  Loop, % WinList
  {
    temp := "ahk_id " WinList%A_Index%
    ControlGet, temp, Hwnd,, %class%, %temp%
    if !ErrorLevel  ;errorlevel is set to 1 if control doesn't exist
      return temp
  }
  return 0
}

GetFocusedControl()  {   																								;-- retrieves the ahk_id (HWND) of the active window's focused control.

        ; This script requires Windows 98+ or NT 4.0 SP3+.
        /*
        typedef struct tagGUITHREADINFO {
        DWORD cbSize;
        DWORD flags;
        HWND  hwndActive;
        HWND  hwndFocus;
        HWND  hwndCapture;
        HWND  hwndMenuOwner;
        HWND  hwndMoveSize;
        HWND  hwndCaret;
        RECT  rcCaret;
        } GUITHREADINFO, *PGUITHREADINFO;
        */

    guiThreadInfoSize := 8 + 6 * A_PtrSize + 16
   VarSetCapacity(guiThreadInfo, guiThreadInfoSize, 0)
   NumPut(GuiThreadInfoSize, GuiThreadInfo, 0)
   ; DllCall("RtlFillMemory" , "PTR", &guiThreadInfo, "UInt", 1 , "UChar", guiThreadInfoSize)   ; Below 0xFF, one call only is needed
   if (DllCall("GetGUIThreadInfo" , "UInt", 0   ; Foreground thread
         , "PTR", &guiThreadInfo) = 0)
   {
      ErrorLevel := A_LastError   ; Failure
      Return 0
   }
   focusedHwnd := NumGet(guiThreadInfo,8+A_PtrSize, "Ptr") ; *(addr + 12) + (*(addr + 13) << 8) +  (*(addr + 14) << 16) + (*(addr + 15) << 24)

	Return focusedHwnd
}

GetControls(hwnd, controls="") {																				;-- returns an array with ClassNN, Hwnd and text of all controls of a window

	if !isobject(controls)
		controls:=[]

	if isobject(hwnd){
		for k,v in hwnd
			controls:=GetControls(v, controls)
		return controls
	}

	winget,classnn,ControlList,ahk_id %hwnd%
	winget,controlId,controllisthwnd,ahk_id %hwnd%
	loop,parse,classnn,`n
	{
		controls[a_index]:=[]
		controls[a_index]["ClassNN"]:=a_loopfield
	}

	loop,parse,controlId,`n
	{
		controls[a_index]["Hwnd"]:=a_loopfield
		controlgetText,txt,,ahk_id %a_loopfield%
		controls[a_index]["text"]:=txt
	}
	return controls

}

GetOtherControl(refHwnd,shift,controls,type="hwnd") {											;--
	for k,v in controls
		if v[type]=refHwnd
			return controls[k+shift].hwnd
}

ListControls(hwnd, obj=0, arr="") {																				;-- similar function to GetControls but returns a comma seperated list

	if !isobject(arr)
		arr:=[]

	if isobject(hwnd){
		for k,v in hwnd
			arr:=ListControls(v, 1, arr)
		goto ListControlsReturn
	}

	str=
	arr:=GetControls(hwnd)
ListControlsReturn:
	if obj
		return arr

	for k,v in arr
		str.="""" v["Hwnd"] """,""" v["ClassNN"] """,""" v["text"] """`n"
	return str

}

Control_GetClassNN( hWnd, hCtrl ) {  																		;-- no-loop

	; SKAN: www.autohotkey.com/forum/viewtopic.php?t=49471
	 WinGet, CH, ControlListHwnd, ahk_id %hWnd%
	 WinGet, CN, ControlList, ahk_id %hWnd%
	 LF:= "`n",  CH:= LF CH LF, CN:= LF CN LF,  S:= SubStr( CH, 1, InStr( CH, LF hCtrl LF ) )
	 StringReplace, S, S,`n,`n, UseErrorLevel
	 StringGetPos, P, CN, `n, L%ErrorLevel%
	 Return SubStr( CN, P+2, InStr( CN, LF, 0, P+2 ) -P-2 )

}

ControlGetClassNN(hWndWindow,hWndControl) {													;-- with loop

	; https://autohotkey.com/board/topic/45627-function-control-getclassnn-get-a-control-classnn/
	DetectHiddenWindows, On
	WinGet, ClassNNList, ControlList, ahk_id %hWndWindow%
	Loop, PARSE, ClassNNList, `n
	{
		ControlGet, hwnd, hwnd,,%A_LoopField%,ahk_id %hWndWindow%
		if (hWnd = hWndControl)
			return A_LoopField
	}

}

ControlGetClassNN( control="", Window="", Text="", ExWin="", ExText="" ) {	    	;-- different method is used here in compare to the already existing functions in this collection
	
	WinGet, cl, ControlList, % Window, % Text, % ExWin, % ExText
	WinGet, hl, ControlListHWND, % Window, % Text, % ExWin, % ExText
	ControlGet, ch, hwnd,, % control, % Window, % Text, % ExWin, % ExText
	If ErrorLevel
		return
	StringSplit, cl, cl, `n
	Loop, Parse, hl, `n
		If (A_LoopField = ch)
			return cl%A_Index%
	return 0
}

GetClassName( hwnd ) { 																						    	;-- returns HWND's class name without its instance number, e.g. "Edit" or "SysListView32"
	
		;https://autohotkey.com/board/topic/45515-remap-hjkl-to-act-like-left-up-down-right-arrow-keys/#entry283368
			VarSetCapacity( buff, 256, 0 )
			DllCall("GetClassName", "uint", hwnd, "str", buff, "int", 255 )
			return buff
}

Control_GetFont(hWnd, ByRef Name, ByRef Size, ByRef Style, 									;-- get the currently used font of a control
IsGDIFontSize := 0) {

    SendMessage 0x31, 0, 0, , ahk_id %hWnd% ; WM_GETFONT
    If (ErrorLevel == "FAIL") {
        Return
    }

    hFont := Errorlevel
    VarSetCapacity(LOGFONT, LOGFONTSize := 60 * (A_IsUnicode ? 2 : 1 ))
    DllCall("GetObject", "UInt", hFont, "Int", LOGFONTSize, "UInt", &LOGFONT)

    Name := DllCall("MulDiv", "Int", &LOGFONT + 28, "Int", 1, "Int", 1, "Str")

    Style := Trim((Weight := NumGet(LOGFONT, 16, "Int")) == 700 ? "Bold" : (Weight == 400) ? "" : " w" . Weight
    . (NumGet(LOGFONT, 20, "UChar") ? " Italic" : "")
    . (NumGet(LOGFONT, 21, "UChar") ? " Underline" : "")
    . (NumGet(LOGFONT, 22, "UChar") ? " Strikeout" : ""))

    Size := IsGDIFontSize ? -NumGet(LOGFONT, 0, "Int") : Round((-NumGet(LOGFONT, 0, "Int") * 72) / A_ScreenDPI)
}

IsControlFocused(hwnd) {																							;-- true/false if a specific control is focused
    VarSetCapacity(GuiThreadInfo, 48) , NumPut(48, GuiThreadInfo, 0)
    Return DllCall("GetGUIThreadInfo", uint, 0, str, GuiThreadInfo) ? (hwnd = NumGet(GuiThreadInfo, 12)) ? True : False : False
}

getControlNameByHwnd(winHwnd,controlHwnd) {													;-- self explaining
	
	bufSize=1024
	winget,processID,pid,ahk_id %winHwnd%
	VarSetCapacity(var1,bufSize)
	getName:=DllCall( "RegisterWindowMessage", "str", "WM_GETCONTROLNAME" )
	dwResult:=DllCall("GetWindowThreadProcessId", "UInt", winHwnd)
	hProcess:=DllCall("OpenProcess", "UInt", 0x8 | 0x10 | 0x20, "Uint", 0, "UInt", processID)
	otherMem:=DllCall("VirtualAllocEx", "Ptr", hProcess, "Ptr", 0, "PTR", bufSize, "UInt", 0x3000, "UInt", 0x0004, "Ptr")

	SendMessage,%getName%,%bufSize%,%otherMem%,,ahk_id %controlHwnd%
	DllCall("ReadProcessMemory","UInt",hProcess,"UInt",otherMem,"Str",var1,"UInt",bufSize,"UInt *",0)
	DllCall("CloseHandle","Ptr",hProcess)
	DllCall("VirtualFreeEx","Ptr", hProcess,"UInt",otherMem,"UInt", 0, "UInt", 0x8000)
	return var1

}

getByControlName(winHwnd,name) {																		;-- search by control name return hwnd
	
	winget,controlList,controlListhwnd,ahk_id %winHwnd%
    arr:=[]
    ,bufSize=1024
	winget,processID,pid,ahk_id %winHwnd%
	VarSetCapacity(var1,bufSize)
	if !(getName:=DllCall( "RegisterWindowMessage", "str", "WM_GETCONTROLNAME" ))
        return []
	if !(dwResult:=DllCall("GetWindowThreadProcessId", "UInt", winHwnd))
        return []
	if !(hProcess:=DllCall("OpenProcess", "UInt", 0x8 | 0x10 | 0x20, "Uint", 0, "UInt", processID))
        return []
    if !(otherMem:=DllCall("VirtualAllocEx", "Ptr", hProcess, "Ptr", 0, "PTR", bufSize, "UInt", 0x3000, "UInt", 0x0004, "Ptr"))
        return []

	loop,parse,controlList,`n
	{
        SendMessage,%getName%,%bufSize%,%otherMem%,,ahk_id %a_loopfield%
        if errorlevel=FAIL
            return []
        if !DllCall("ReadProcessMemory","UInt",hProcess,"UInt",otherMem,"Str",var1,"UInt",bufSize,"UInt *",0)
            return []
        if (var1==name)
            arr.insert(a_loopfield)
            ,var1:=""
	}

    DllCall("VirtualFreeEx","Ptr", hProcess,"UInt",otherMem,"UInt", 0, "UInt", 0x8000)
	DllCall("CloseHandle","Ptr",hProcess)
    return arr
	
}

getNextControl(winHwnd, controlName="", accName="", classNN="", accHelp="") {	;-- I'm not sure if this feature works could be an AHK code for the Control.GetNextControl method for System.Windows.Forms

	winget, list, controllisthwnd, ahk_id %winHwnd%

	bufSize=1024
	winget, processID, pid, ahk_id %winHwnd%
	VarSetCapacity(var1,bufSize)
	getName:=DllCall( "RegisterWindowMessage", "str", "WM_GETCONTROLNAME" )
	dwResult:=DllCall("GetWindowThreadProcessId", "UInt", winHwnd)
	hProcess:=DllCall("OpenProcess", "UInt", 0x8 | 0x10 | 0x20, "Uint", 0, "UInt", processID)
	otherMem:=DllCall("VirtualAllocEx", "Ptr", hProcess, "Ptr", 0, "PTR", bufSize, "UInt", 0x3000, "UInt", 0x0004, "Ptr")

	count=0
	;~ static hModule := DllCall("LoadLibrary", "Str", "oleacc", "Ptr")
	;~ static hModule2 := DllCall("LoadLibrary", "Str", "Kernel32", "Ptr")
	;~ static AccessibleObjectFromWindowProc := DllCall("GetProcAddress", Ptr, DllCall("GetModuleHandle", Str, "oleacc", "Ptr"), AStr, "AccessibleObjectFromWindow", "Ptr")
	;~ static ReadProcessMemoryProc:=DllCall("ReadProcessMemory", Ptr, DllCall("GetModuleHandle", Str, "Kernel32", "Ptr"), AStr, "AccessibleChildren", "Ptr")
	;~ msgbox % AccessibleObjectFromWindowProc
	;~ static idObject:=-4
	loop,parse,list,`n
	{
		SendMessage,%getName%,%bufSize%,%otherMem%,,ahk_id %a_loopfield%
        DllCall("ReadProcessMemory","UInt",hProcess,"UInt",otherMem,"Str",var1,"UInt",bufSize,"UInt *",0)

		;~ acc:=acc_objectfromwindow2(a_loopfield)

		;~ if !DllCall(AccessibleObjectFromWindowProc, "Ptr", a_loopfield, "UInt", idObject&=0xFFFFFFFF, "Ptr", -VarSetCapacity(IID,16)+NumPut(idObject==0xFFFFFFF0?0x46000000000000C0:0x719B3800AA000C81,NumPut(idObject==0xFFFFFFF0?0x0000000000020400:0x11CF3C3D618736E0,IID,"Int64"),"Int64"), "Ptr*", pacc)
			;~ acc:=ComObjEnwrap(9,pacc,1)
		;~ else
			;~ acc:=""


	;&&(accParentHwnd=""||acc_windowfromobject(acc.accParent)=accParentHwnd)
		if ((var1&&var1=controlName)&&(accName=""||(acc:=Acc_ObjectFromWindow(a_loopfield)).accName=accName)){
			WinGetClass,cl,ahk_id %a_loopfield%
			if (instr(cl,classNN)=1&&(accHelp=""||acc.accHelp=accHelp)) {
				ret:=a_loopfield
				break
			}
		}

		var1:=""
	}

    DllCall("VirtualFreeEx","Ptr", hProcess,"UInt",otherMem,"UInt", 0, "UInt", 0x8000)
	DllCall("CloseHandle","Ptr",hProcess)
	DllCall("FreeLibrary", "Ptr", hModule)
	return ret

}

IsControlUnderCursor(ControlClass) {																			;-- Checks if a specific control is under the cursor and returns its ClassNN if it is.
	MouseGetPos, , , , control
	if (InStr(Control, ControlClass))
		return control
	return false
}

GetFocusedControl(Option := "") {																				;-- get focused control from active window -multi Options[ClassNN \ Hwnd \ Text \ List \ All] available 

	; https://autohotkey.com/boards/viewtopic.php?f=6&t=23987 from V for Vendetta
	;"Options": ClassNN \ Hwnd \ Text \ List \ All or Nothing

	GuiWindowHwnd := WinExist("A")		;stores the current Active Window Hwnd id number in "GuiWindowHwnd" variable
					;"A" for Active Window

	ControlGetFocus, FocusedControl, ahk_id %GuiWindowHwnd%	;stores the  classname "ClassNN" of the current focused control from the window above in "FocusedControl" variable
							;"ahk_id" searches windows by Hwnd Id number

	if Option = ClassNN
		return, FocusedControl

	ControlGet, FocusedControlId, Hwnd,, %FocusedControl%, ahk_id %GuiWindowHwnd%	;stores the Hwnd Id number of the focused control found above in "FocusedControlId" variable

	if Option = Hwnd
		return, FocusedControlId

	if (Option = "Text") or (Option = "All")
	ControlGetText, FocusedControlText, , ahk_id %FocusedControlId%		;stores the focused control texts in "FocusedControlText" variable
								;"ahk_id" searches control by Hwnd id number

	if Option = Text	
		return, FocusedControlText

	if (Option = "List") or (Option = "All")
		ControlGet, FocusedControlList, List, , , ahk_id %FocusedControlId%	;"List", retrieves  all the text from a ListView, ListBox, or ComboBox controls

	if Option = List	
		return, FocusedControlList

	return, FocusedControl " - " FocusedControlId "`n`n____Text____`n`n" FocusedControlText "`n`n____List____`n`n" FocusedControlList
}

ControlGetTextExt(hControl, hWinTitle)  {                                                       			;-- 3 different variants are tried to determine the text of a control

	/*                                                   	DESCRIPTION
	
				;Replaces the AHK function ControlGetText, which sometimes does not work.
				; cf.: http://de.autohotkey.com/forum/viewtopic.php?t=7366&postdays=0&postorder=asc&start=0 
				;SYNTAX: VText := ControlGetTextExt("Static8", "StarMoney Business 4.0") 
				;SYNTAX: Erg := ControlGetTextExt("#327701", "Date and Time") 
	
	*/
	
	DetectHiddenText, on 
   ; 1. Step. Normal ControlGetText with AHK:
   ControlGetText, ControlText, %hControl%, %hWinTitle% 
   If (StrLen(Controltext)=0) { 
      ; 2. Step. DllCall with "GetWindowText":
      ControlGet, ControlHWND, Hwnd,, %hControl%, %hWinTitle% 
      ControlTextSize = 512 
      VarSetCapacity(ControlText, ControlTextSize) 
      Result := DllCall("GetWindowText", "uint", ControlHWND, "str", ControlText, "int", ControlTextSize) 
      If (StrLen(Controltext)=0) 
         ; 3. Step. SendMessage with WM_GETTEXT (0xD):
         SendMessage, 0xD, ControlTextSize, &ControlText, %hControl%, %hWinTitle% 
   } 
   Return ControlText 
}

getControlInfo(type="button", text="", ret="w", fontsize="", fontmore="") {			;-- get width and heights of controls
	static test
	Gui, wasteGUI:New
	Gui, wasteGUI:Font, % fontsize, % fontmore
	Gui, wasteGUI:Add, % type, vtest, % text
	GuiControlGet, test, wasteGUI:pos
	Gui, wasteGUI:Destroy
	if ret=w
		return testw
	if ret=h
		return testh
}

FocusedControl() { 																								    	;-- returns the HWND of the currently focused control, or 0 if there was a problem
	;https://autohotkey.com/board/topic/45515-remap-hjkl-to-act-like-left-up-down-right-arrow-keys/#entry283368
	NumPut(VarSetCapacity( gti, 48, 0 ), gti, 0, "int")
	if DllCall("GetGUIThreadInfo", "uint", 0, "str", gti)
		return NumGet(gti, 12, "uint")
	return 0

}

Control_GetFont( hwnd ,ByRef Name,ByRef Style,ByRef Size) { 									;-- retrieves the used font of a control
; www.autohotkey.com/forum/viewtopic.php?p=465438#465438  
; https://autohotkey.com/board/topic/7984-ahk-functions-incache-cache-list-of-recent-items/page-11
; Mod by nothing
 SendMessage 0x31, 0, 0, , ahk_id %hwnd% ; WM_GETFONT                 
 IfEqual,ErrorLevel,FAIL, Return 
 hFont := Errorlevel, VarSetCapacity( LF, szLF := 60*( A_IsUnicode ? 2:1 ) ), DllCall("GetObject", UInt,hFont, Int,szLF, UInt,&LF ) , hDC := DllCall( "GetDC", UInt,hwnd ), DPI := DllCall( "GetDeviceCaps", UInt,hDC, Int,90 ) , DllCall( "ReleaseDC", Int,0, UInt,hDC )
 Name := DllCall( "MulDiv",Int,&LF+28, Int,1,Int,1, Str )
 Style := Trim(((W:=NumGet(LF,16,"Int"))=700 ? " Bold" : W=400 ? "" : " w" W ) . (NumGet(LF,20,"UChar") ? " Italic" : "") . (NumGet(LF,21,"UChar") ? " Underline" : "") . (NumGet(LF,22,"UChar") ? " StrikeOut" : ""))
 Size := Round( ( -NumGet( LF,0,"Int" )*72 ) / DPI ) 
}


} 

{ ; GUI / window - get/find (45)

IsOverTitleBar(x, y, hWnd) { 																						;-- WM_NCHITTEST wrapping: what's under a screen point?

	; This function is from http://www.autohotkey.com/forum/topic22178.html
   SendMessage, 0x84,, (x & 0xFFFF) | (y & 0xFFFF) << 16,, ahk_id %hWnd%
   if ErrorLevel in 2,3,8,9,20,21
      return true
   else
      return false
}

WinGetPosEx(hWindow,ByRef X="",ByRef Y="",ByRef Width="", 								;-- gets the position, size, and offset of a window
ByRef Height="", ByRef Offset_X="",ByRef Offset_Y="")  {

	/*								Function: WinGetPosEx
	;
	; Description:
	;
	;   Gets the position, size, and offset of a window. See the *Remarks* section
	;   for more information.
	;
	; Parameters:
	;
	;   hWindow - Handle to the window.
	;
	;   X, Y, Width, Height - Output variables. [Optional] If defined, these
	;       variables contain the coordinates of the window relative to the
	;       upper-left corner of the screen (X and Y), and the Width and Height of
	;       the window.
	;
	;   Offset_X, Offset_Y - Output variables. [Optional] Offset, in pixels, of the
	;       actual position of the window versus the position of the window as
	;       reported by GetWindowRect.  If moving the window to specific
	;       coordinates, add these offset values to the appropriate coordinate
	;       (X and/or Y) to reflect the true size of the window.
	;
	; Returns:
	;
	;   If successful, the address of a RECTPlus structure is returned.  The first
	;   16 bytes contains a RECT structure that contains the dimensions of the
	;   bounding rectangle of the specified window.  The dimensions are given in
	;   screen coordinates that are relative to the upper-left corner of the screen.
	;   The next 8 bytes contain the X and Y offsets (4-byte integer for X and
	;   4-byte integer for Y).
	;
	;   Also if successful (and if defined), the output variables (X, Y, Width,
	;   Height, Offset_X, and Offset_Y) are updated.  See the *Parameters* section
	;   for more more information.
	;
	;   If not successful, FALSE is returned.
	;
	; Requirement:
	;
	;   Windows 2000+
	;
	; Remarks, Observations, and Changes:
	;
	; * Starting with Windows Vista, Microsoft includes the Desktop Window Manager
	;   (DWM) along with Aero-based themes that use DWM.  Aero themes provide new
	;   features like a translucent glass design with subtle window animations.
	;   Unfortunately, the DWM doesn't always conform to the OS rules for size and
	;   positioning of windows.  If using an Aero theme, many of the windows are
	;   actually larger than reported by Windows when using standard commands (Ex:
	;   WinGetPos, GetWindowRect, etc.) and because of that, are not positioned
	;   correctly when using standard commands (Ex: gui Show, WinMove, etc.).  This
	;   function was created to 1) identify the true position and size of all
	;   windows regardless of the window attributes, desktop theme, or version of
	;   Windows and to 2) identify the appropriate offset that is needed to position
	;   the window if the window is a different size than reported.
	;
	; * The true size, position, and offset of a window cannot be determined until
	;   the window has been rendered.  See the example script for an example of how
	;   to use this function to position a new window.
	;
	; * 20150906: The "dwmapi\DwmGetWindowAttribute" function can return odd errors
	;   if DWM is not enabled.  One error I've discovered is a return code of
	;   0x80070006 with a last error code of 6, i.e. ERROR_INVALID_HANDLE or "The
	;   handle is invalid."  To keep the function operational during this types of
	;   conditions, the function has been modified to assume that all unexpected
	;   return codes mean that DWM is not available and continue to process without
	;   it.  When DWM is a possibility (i.e. Vista+), a developer-friendly messsage
	;   will be dumped to the debugger when these errors occur.
	;
	; * 20160105 (Ben Allred): Adjust width and height for offset calculations if
	;   DPI is in play.
	;
	; Credit:
	;
	;   Idea and some code from *KaFu* (AutoIt forum)
	;
	;-------------------------------------------------------------------------------
		*/

    Static Dummy5693
          ,RECTPlus
          ,S_OK:=0x0
          ,DWMWA_EXTENDED_FRAME_BOUNDS:=9

    ;-- Workaround for AutoHotkey Basic
    PtrType:=(A_PtrSize=8) ? "Ptr":"UInt"

    ;-- Get the window's dimensions
    ;   Note: Only the first 16 bytes of the RECTPlus structure are used by the
    ;   DwmGetWindowAttribute and GetWindowRect functions.
    VarSetCapacity(RECTPlus,24,0)
    DWMRC:=DllCall("dwmapi\DwmGetWindowAttribute"
        ,PtrType,hWindow                                ;-- hwnd
        ,"UInt",DWMWA_EXTENDED_FRAME_BOUNDS             ;-- dwAttribute
        ,PtrType,&RECTPlus                              ;-- pvAttribute
        ,"UInt",16)                                     ;-- cbAttribute

    if (DWMRC<>S_OK)
        {
        if ErrorLevel in -3,-4  ;-- Dll or function not found (older than Vista)
            {
            ;-- Do nothing else (for now)
            }
         else
            outputdebug,
               (ltrim join`s
                Function: %A_ThisFunc% -
                Unknown error calling "dwmapi\DwmGetWindowAttribute".
                RC=%DWMRC%,
                ErrorLevel=%ErrorLevel%,
                A_LastError=%A_LastError%.
                "GetWindowRect" used instead.
               )

        ;-- Collect the position and size from "GetWindowRect"
        DllCall("GetWindowRect",PtrType,hWindow,PtrType,&RECTPlus)
        }

    ;-- Populate the output variables
    X:=Left :=NumGet(RECTPlus,0,"Int")
    Y:=Top  :=NumGet(RECTPlus,4,"Int")
    Right   :=NumGet(RECTPlus,8,"Int")
    Bottom  :=NumGet(RECTPlus,12,"Int")
    Width   :=Right-Left
    Height  :=Bottom-Top
    OffSet_X:=0
    OffSet_Y:=0

    ;-- If DWM is not used (older than Vista or DWM not enabled), we're done
    if (DWMRC<>S_OK)
        Return &RECTPlus

    ;-- Collect dimensions via GetWindowRect
    VarSetCapacity(RECT,16,0)
    DllCall("GetWindowRect",PtrType,hWindow,PtrType,&RECT)
    GWR_Width :=NumGet(RECT,8,"Int")-NumGet(RECT,0,"Int")
        ;-- Right minus Left
    GWR_Height:=NumGet(RECT,12,"Int")-NumGet(RECT,4,"Int")
        ;-- Bottom minus Top

    ;-- Adjust width and height for offset calculations if DPI is in play
    ;   See https://msdn.microsoft.com/en-us/library/windows/desktop/dn280512(v=vs.85).aspx
    ;   The current version of AutoHotkey is PROCESS_SYSTEM_DPI_AWARE (contains "<dpiAware>true</dpiAware>" in its manifest)
    ;   DwmGetWindowAttribute returns DPI scaled sizes
    ;   GetWindowRect does not
    ; get monitor handle where the window is at so we can get the monitor name
    hMonitor := DllCall("MonitorFromRect",PtrType,&RECT,UInt,2) ; MONITOR_DEFAULTTONEAREST = 2 (Returns a handle to the display monitor that is nearest to the rectangle)
    ; get monitor name so we can get a handle to the monitor device context
    VarSetCapacity(MONITORINFOEX,104)
    NumPut(104,MONITORINFOEX)
    DllCall("GetMonitorInfo",PtrType,hMonitor,PtrType,&MONITORINFOEX)
    monitorName := StrGet(&MONITORINFOEX+40)
    ; get handle to monitor device context so we can get the dpi adjusted and actual screen sizes
    hdc := DllCall("CreateDC",Str,monitorName,PtrType,0,PtrType,0,PtrType,0)
    ; get dpi adjusted and actual screen sizes
    dpiAdjustedScreenHeight := DllCall("GetDeviceCaps",PtrType,hdc,Int,10) ; VERTRES = 10 (Height, in raster lines, of the screen)
    actualScreenHeight := DllCall("GetDeviceCaps",PtrType,hdc,Int,117) ; DESKTOPVERTRES = 117
    ; delete hdc as instructed
    DllCall("DeleteDC",PtrType,hdc)
    ; calculate dpi adjusted width and height
    dpiFactor := actualScreenHeight/dpiAdjustedScreenHeight ; this will be 1.0 if DPI is 100%
    dpiAdjusted_Width := Ceil(Width/dpiFactor)
    dpiAdjusted_Height := Ceil(Height/dpiFactor)

    ;-- Calculate offsets and update output variables
    NumPut(Offset_X:=(dpiAdjusted_Width-GWR_Width)//2,RECTPlus,16,"Int")
    NumPut(Offset_Y:=(dpiAdjusted_Height-GWR_Height)//2,RECTPlus,20,"Int")
    Return &RECTPlus
    }

GetParent(hWnd) {																										;-- get parent win handle of a window

	return DllCall("GetParent", "Ptr", hWnd, "Ptr")

}

GetWindow(hWnd,uCmd) {																							;-- DllCall wrapper for GetWindow function

	return DllCall( "GetWindow", "Ptr", hWnd, "uint", uCmd, "Ptr")

}

GetForegroundWindow() {																							;-- returns handle of the foreground window

	return DllCall("GetForeGroundWindow", "Ptr")

}

IsWindowVisible(hWnd) {																							;-- self explaining

	return DllCall("IsWindowVisible", "Ptr", hWnd)

}

IsFullScreen(hwnd) {																									;-- specific window is a fullscreen window?

  WinGet, Style, Style, ahk_id %hwnd%
  return !(Style & 0x40000) ; 0x40000 = WS_SIZEBOX

}

IsClosed(win, wait) {																										;-- AHK function (WinWaitClose) wrapper

	WinWaitClose, ahk_id %win%,, %wait%
	return ((ErrorLevel = 1) ? False : True)

}

GetClassLong(hWnd, Param) {																					;--

    Static GetClassLong := A_PtrSize == 8 ? "GetClassLongPtr" : "GetClassLong"
    Return DllCall(GetClassLong, "Ptr", hWnd, "int", Param)

}

GetWindowLong(hWnd, Param) {																				;--

    ;GetWindowLong := A_PtrSize == 8 ? "GetWindowLongPtr" : "GetWindowLong"
    Return DllCall("GetWindowLong", "Ptr", hWnd, "int", Param)

}

GetClassStyles(Style) {																									;--

    Static CS := {0x1: "CS_VREDRAW"
    , 0x2: "CS_HREDRAW"
    , 0x8: "CS_DBLCLKS"
    , 0x20: "CS_OWNDC"
    , 0x40: "CS_CLASSDC"
    , 0x80: "CS_PARENTDC"
    , 0x200: "CS_NOCLOSE"
    , 0x800: "CS_SAVEBITS"
    , 0x1000: "CS_BYTEALIGNCLIENT"
    , 0x2000: "CS_BYTEALIGNWINDOW"
    , 0x4000: "CS_GLOBALCLASS"
    , 0x10000: "CS_IME"
    , 0x20000: "CS_DROPSHADOW"}

    Styles := " ("
    For k, v in CS {
        If (Style & k) {
            Styles .= v ", "
        }
    }

    Return RTrim(Styles, ", ") . ")"

}

GetTabOrderIndex(hWnd) {																							;--

    hParent := GetAncestor(hWnd)

    WinGet ControlList, ControlListHwnd, ahk_id %hParent%
    Index := 1
    Loop Parse, ControlList, `n
    {
        If (!IsWindowVisible(A_LoopField)) {
            Continue
        }

        WinGet Style, Style, ahk_id %A_LoopField%
        If !(Style & 0x10000) { ; WS_TABSTOP
            Continue
        }

        If (A_LoopField == hWnd) {
            Return Index
        }

        Index++
    }

    Return 0
}

GetCursor(CursorHandle) {																							;--

    Cursor := Cursors[CursorHandle]
    Return (Cursor != "") ? Cursor : CursorHandle

}

GetExtraStyle(hWnd) {																									;-- get Extra Styles from a gui/window

    WinGetClass Class, ahk_id %hWnd%

    If (Class == "SysListView32") {
        Message := 0x1037 ; LVM_GETEXTENDEDLISTVIEWSTYLE
    } Else If (Class == "SysTreeView32") {
        Message := 0x112D ; TVM_GETEXTENDEDSTYLE
    } Else If (Class == "SysTabControl32") {
        Message := 0x1335 ; TCM_GETEXTENDEDSTYLE
    } Else If (Class == "ToolbarWindow32") {
        Message := 0x455 ; TB_GETEXTENDEDSTYLE
    } Else If (Class == "ComboBox" && g_Style & 0x10) {
        Message := 0x409 ; CBEM_GETEXTENDEDSTYLE
    }

    SendMessage %Message%, 0, 0,, ahk_id %hWnd%
    Return Format("0x{:08X}", ErrorLevel)

}

GetToolbarItems(hToolbar) {																						;-- retrieves the text/names of all items of a toolbar

    WinGet PID, PID, ahk_id %hToolbar%

    If !(hProc := DllCall("OpenProcess", "UInt", 0x438, "Int", False, "UInt", PID, "Ptr")) {
        Return
    }

    If (A_Is64bitOS) {
        Try DllCall("IsWow64Process", "Ptr", hProc, "int*", Is32bit := true)
    } Else {
        Is32bit := True
    }

    RPtrSize := Is32bit ? 4 : 8
    TBBUTTON_SIZE := 8 + (RPtrSize * 3)

    SendMessage 0x418, 0, 0,, ahk_id %hToolbar% ; TB_BUTTONCOUNT
    ButtonCount := ErrorLevel

    IDs := [] ; Command IDs
    Loop %ButtonCount% {
        Address := DllCall("VirtualAllocEx", "Ptr", hProc, "Ptr", 0, "uPtr", TBBUTTON_SIZE, "UInt", 0x1000, "UInt", 4, "Ptr")

        SendMessage 0x417, % A_Index - 1, Address,, ahk_id %hToolbar% ; TB_GETBUTTON
        If (ErrorLevel == 1) {
            VarSetCapacity(TBBUTTON, TBBUTTON_SIZE, 0)
            DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", Address, "Ptr", &TBBUTTON, "uPtr", TBBUTTON_SIZE, "Ptr", 0)
            IDs.Push(NumGet(&TBBUTTON, 4, "Int"))
        }

        DllCall("VirtualFreeEx", "Ptr", hProc, "Ptr", Address, "UPtr", 0, "UInt", 0x8000) ; MEM_RELEASE
    }

    ToolbarItems := []
    Loop % IDs.Length() {
        ButtonID := IDs[A_Index]
        ;SendMessage 0x44B, %ButtonID% , 0,, ahk_id %hToolbar% ; TB_GETBUTTONTEXTW
        ;BufferSize := ErrorLevel * 2
        BufferSize := 128

        Address := DllCall("VirtualAllocEx", "Ptr", hProc, "Ptr", 0, "uPtr", BufferSize, "UInt", 0x1000, "UInt", 4, "Ptr")

        SendMessage 0x44B, %ButtonID%, Address,, ahk_id %hToolbar% ; TB_GETBUTTONTEXTW

        VarSetCapacity(Buffer, BufferSize, 0)
        DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", Address, "Ptr", &Buffer, "uPtr", BufferSize, "Ptr", 0)

        ToolbarItems.Push({"ID": IDs[A_Index], "String": Buffer})

        DllCall("VirtualFreeEx", "Ptr", hProc, "Ptr", Address, "UPtr", 0, "UInt", 0x8000) ; MEM_RELEASE
    }

    DllCall("CloseHandle", "Ptr", hProc)

    Return ToolbarItems
}

ControlGetTabs(hTab) {																								;-- retrieves the text of tabs in a tab control

    ; https://autohotkey.com/board/topic/70727-ahk-l-controlgettabs/
	; a Lexikos function

	; Parameters:
	; Control - the HWND, ClassNN or text of the control.
	;WinTitle - same as ControlGet, but unused if Control is a HWND.
	; WinText - as above.

	; Returns:
	; An array of strings on success.
	;An empty string on failure.

	; Requirements:
	; AutoHotkey v1.1.
	; A compatible tab control

    Static MAX_TEXT_LENGTH := 260
         , MAX_TEXT_SIZE := MAX_TEXT_LENGTH * (A_IsUnicode ? 2 : 1)

    WinGet PID, PID, ahk_id %hTab%

    ; Open the process for read/write and query info.
    ; PROCESS_VM_READ | PROCESS_VM_WRITE | PROCESS_VM_OPERATION | PROCESS_QUERY_INFORMATION
    If !(hProc := DllCall("OpenProcess", "UInt", 0x438, "Int", False, "UInt", PID, "Ptr")) {
        Return
    }

    ; Should we use the 32-bit struct or the 64-bit struct?
    If (A_Is64bitOS) {
        Try DllCall("IsWow64Process", "Ptr", hProc, "int*", Is32bit := true)
    } Else {
        Is32bit := True
    }

    RPtrSize := Is32bit ? 4 : 8
    TCITEM_SIZE := 16 + RPtrSize * 3

    ; Allocate a buffer in the (presumably) remote process.
    remote_item := DllCall("VirtualAllocEx", "Ptr", hProc, "Ptr", 0
                         , "uPtr", TCITEM_SIZE + MAX_TEXT_SIZE
                         , "UInt", 0x1000, "UInt", 4, "Ptr") ; MEM_COMMIT, PAGE_READWRITE
    remote_text := remote_item + TCITEM_SIZE

    ; Prepare the TCITEM structure locally.
    VarSetCapacity(TCITEM, TCITEM_SIZE, 0)
    NumPut(1, TCITEM, 0, "UInt") ; mask (TCIF_TEXT)
    NumPut(remote_text, TCITEM, 8 + RPtrSize) ; pszText
    NumPut(MAX_TEXT_LENGTH, TCITEM, 8 + RPtrSize * 2, "Int") ; cchTextMax

    ; Write the local structure into the remote buffer.
    DllCall("WriteProcessMemory", "Ptr", hProc, "Ptr", remote_item, "Ptr", &TCITEM, "uPtr", TCITEM_SIZE, "Ptr", 0)

    Tabs := []
    VarSetCapacity(TabText, MAX_TEXT_SIZE)

    SendMessage 0x1304, 0, 0,, ahk_id %hTab% ; TCM_GETITEMCOUNT
    Loop % (ErrorLevel != "FAIL") ? ErrorLevel : 0 {
        ; Retrieve the item text.
        SendMessage, % (A_IsUnicode) ? 0x133C : 0x1305, A_Index - 1, remote_item,, ahk_id %hTab% ; TCM_GETITEM
        If (ErrorLevel == 1) { ; Success
            DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", remote_text, "Ptr", &TabText, "uPtr", MAX_TEXT_SIZE, "Ptr", 0)
        } Else {
            TabText := ""
        }

        Tabs[A_Index] := TabText
    }

    ; Release the remote memory and handle.
    DllCall("VirtualFreeEx", "Ptr", hProc, "Ptr", remote_item, "UPtr", 0, "UInt", 0x8000) ; MEM_RELEASE
    DllCall("CloseHandle", "Ptr", hProc)

    Return Tabs
}

GetHeaderInfo(hHeader) {																							;--
    ; Returns an object containing width and text for each item of a remote header control
    Static MAX_TEXT_LENGTH := 260
         , MAX_TEXT_SIZE := MAX_TEXT_LENGTH * (A_IsUnicode ? 2 : 1)

    WinGet PID, PID, ahk_id %hHeader%

    ; Open the process for read/write and query info.
    ; PROCESS_VM_READ | PROCESS_VM_WRITE | PROCESS_VM_OPERATION | PROCESS_QUERY_INFORMATION
    If !(hProc := DllCall("OpenProcess", "UInt", 0x438, "Int", False, "UInt", PID, "Ptr")) {
        Return
    }

    ; Should we use the 32-bit struct or the 64-bit struct?
    If (A_Is64bitOS) {
        Try DllCall("IsWow64Process", "Ptr", hProc, "int*", Is32bit := true)
    } Else {
        Is32bit := True
    }

    RPtrSize := Is32bit ? 4 : 8
    cbHDITEM := (4 * 6) + (RPtrSize * 6)

    ; Allocate a buffer in the (presumably) remote process.
    remote_item := DllCall("VirtualAllocEx", "Ptr", hProc, "Ptr", 0
                         , "uPtr", cbHDITEM + MAX_TEXT_SIZE
                         , "UInt", 0x1000, "UInt", 4, "Ptr") ; MEM_COMMIT, PAGE_READWRITE
    remote_text := remote_item + cbHDITEM

    ; Prepare the HDITEM structure locally.
    VarSetCapacity(HDITEM, cbHDITEM, 0)
    NumPut(0x3, HDITEM, 0, "UInt") ; mask (HDI_WIDTH | HDI_TEXT)
    NumPut(remote_text, HDITEM, 8, "Ptr") ; pszText
    NumPut(MAX_TEXT_LENGTH, HDITEM, 8 + RPtrSize * 2, "Int") ; cchTextMax

    ; Write the local structure into the remote buffer.
    DllCall("WriteProcessMemory", "Ptr", hProc, "Ptr", remote_item, "Ptr", &HDITEM, "uPtr", cbHDITEM, "Ptr", 0)

    HDInfo := {}
    VarSetCapacity(HDText, MAX_TEXT_SIZE)

    SendMessage 0x1200, 0, 0,, ahk_id %hHeader% ; HDM_GETITEMCOUNT
    Loop % (ErrorLevel != "FAIL") ? ErrorLevel : 0 {
        ; Retrieve the item text.
        SendMessage, % (A_IsUnicode) ? 0x120B : 0x1203, A_Index - 1, remote_item,, ahk_id %hHeader% ; HDM_GETITEMW
        If (ErrorLevel == 1) { ; Success
            DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", remote_item, "Ptr", &HDITEM, "uPtr", MAX_TEXT_SIZE, "Ptr", 0)
            DllCall("ReadProcessMemory", "Ptr", hProc, "Ptr", remote_text, "Ptr", &HDText, "uPtr", MAX_TEXT_SIZE, "Ptr", 0)
        } Else {
            TabText := ""
        }

        HDInfo.Push({"Width": NumGet(HDITEM, 4, "UInt"), "Text": HDText})
    }

    ; Release the remote memory and handle.
    DllCall("VirtualFreeEx", "Ptr", hProc, "Ptr", remote_item, "UPtr", 0, "UInt", 0x8000) ; MEM_RELEASE
    DllCall("CloseHandle", "Ptr", hProc)

    Return HDInfo
}

GetClientCoords(hWnd, ByRef x, ByRef y) {																	;--
    VarSetCapacity(POINT, 8, 0)
    NumPut(x, POINT, 0, "Int")
    NumPut(y, POINT, 4, "Int")
    hParent := GetParent(hWnd)
    DllCall("ScreenToClient", "Ptr", (hParent == 0 ? hWnd : hParent), "Ptr", &POINT)
    x := NumGet(POINT, 0, "Int")
    y := NumGet(POINT, 4, "Int")
}

GetClientSize(hwnd, ByRef w, ByRef h) {																		;-- get size of window without border
	; https://autohotkey.com/board/topic/91733-command-to-get-gui-client-areas-sizes/
    VarSetCapacity(rc, 16)
    DllCall("GetClientRect", "uint", hwnd, "uint", &rc)
    w := NumGet(rc, 8, "int")
    h := NumGet(rc, 12, "int")
}

GetWindowCoords(hWnd, ByRef x, ByRef y) {																;--
    hParent := GetParent(hWnd)
    WinGetPos px, py,,, % "ahk_id" . (hParent == 0 ? hWnd : hParent)
    x := x - px
    y := y - py
}

GetWindowPos(hWnd, ByRef X, ByRef Y, ByRef W, ByRef H) {										;--
    VarSetCapacity(RECT, 16, 0)
    DllCall("GetWindowRect", "Ptr", hWnd, "Ptr", &RECT)
    DllCall("MapWindowPoints", "Ptr", 0, "Ptr", GetParent(hWnd), "Ptr", &RECT, "UInt", 2)
    X := NumGet(RECT, 0, "Int")
    Y := NumGet(RECT, 4, "Int")
    w := NumGet(RECT, 8, "Int") - X
    H := NumGet(RECT, 12, "Int") - Y
}

GetWindowPlacement(hWnd) {																					;-- Gets window position using workspace coordinates (-> no taskbar), returns an object
    VarSetCapacity(WINDOWPLACEMENT, 44, 0)
    NumPut(44, WINDOWPLACEMENT)
    DllCall("GetWindowPlacement", "Ptr", hWnd, "Ptr", &WINDOWPLACEMENT)
    Result := {}
    Result.x := NumGet(WINDOWPLACEMENT, 7 * 4, "UInt")
    Result.y := NumGet(WINDOWPLACEMENT, 8 * 4, "UInt")
    Result.w := NumGet(WINDOWPLACEMENT, 9 * 4, "UInt") - Result.x
    Result.h := NumGet(WINDOWPLACEMENT, 10 * 4, "UInt") - Result.y
    Result.showCmd := NumGet(WINDOWPLACEMENT, 8, "UInt")
    ; 1 = normal, 2 = minimized, 3 = maximized
    Return Result
}

GetWindowInfo(hWnd) {                                                                                         	;-- returns an Key:Val Object with the most informations about a window (Pos, Client Size, Style, ExStyle, Border size...)
    NumPut(VarSetCapacity(WINDOWINFO, 60, 0), WINDOWINFO)
    DllCall("GetWindowInfo", "Ptr", hWnd, "Ptr", &WINDOWINFO)
    wi := Object()
    wi.WinX := NumGet(WINDOWINFO, 4, "Int")
    wi.WinY := NumGet(WINDOWINFO, 8, "Int")
    wi.WinW := NumGet(WINDOWINFO, 12, "Int") - wi.WindowX
    wi.WinH := NumGet(WINDOWINFO, 16, "Int") - wi.WindowY
    wi.cX := NumGet(WINDOWINFO, 20, "Int")
    wi.cY := NumGet(WINDOWINFO, 24, "Int")
    wi.cW := NumGet(WINDOWINFO, 28, "Int") - wi.ClientX
    wi.cH := NumGet(WINDOWINFO, 32, "Int") - wi.ClientY
    wi.Style   := NumGet(WINDOWINFO, 36, "UInt")
    wi.ExStyle := NumGet(WINDOWINFO, 40, "UInt")
    wi.Active  := NumGet(WINDOWINFO, 44, "UInt")
    wi.BorderW := NumGet(WINDOWINFO, 48, "UInt")
    wi.BorderH := NumGet(WINDOWINFO, 52, "UInt")
    wi.Atom    := NumGet(WINDOWINFO, 56, "UShort")
    wi.Version := NumGet(WINDOWINFO, 58, "UShort")
    Return wi
}

GetOwner(hWnd) {                                                                                                  	;--
    Return DllCall("GetWindow", "Ptr", hWnd, "UInt", 4) ; GW_OWNER
}

FindWindow(WinTitle, WinClass:="", WinText:="", ParentTitle:="",                        	;-- Finds the requested window,and return it's ID
ParentClass:="", DetectHiddenWins:="off", DectectHiddenTexts:="off") {

	; 0 if it wasn't found or chosen from a list
	; originally from Evan Casey Copyright (c) under MIT License.
	; changed for my purposes for Addendum for AlbisOnWindows by Ixiko on 04-06-2018
	; this version searches for ParentWindows if there is no WinText to check changed on 04-27-2018

	HWins:= A_DetectHiddenWindows
	HText:= A_DetectHiddenText
	DetectHiddenWindows, %DetectHiddenWins%
	DetectHiddenText, %DetectHiddenTexts%

		If Instr(WinClass, "Afx:") {
				SetTitleMatchMode, RegEx
		} else {
				SetTitleMatchMode, RegEx
		}

	if (WinClass = "")
		sSearchWindow := WinTitle
	else
		sSearchWindow := WinTitle . " ahk_class " . WinClass

	WinGet, nWindowArray, List, %sSearchWindow%, %WinText%

	;Loop for more windows - this is looks for ParentWindow
	if (nWindowArray > 1) {

		Loop %nWindowArray% {

			prev := DllCall("GetWindow", "ptr", hwnd, "uint", GW_HWNDPREV:=3, "ptr")			;GetParentWindowID
					if prev {
									DetectHiddenWindows On
									WinGetTitle title, ahk_id %prev%
									WinGetClass class, ahk_id %prev%
									If (titel == ParentTitle) AND (class == ParentClass) {
										sSelectedWinID := % nWindowArray%A_Index%
										break
									}

						}
		}

	} else if (nWindowArray == 1) {
		sSelectedWinID := nWindowArray1
	} else if (nWindowArray == 0) {
		sSelectedWinID := 0
	}

	DetectHiddenWindows, %HWins%
	DetectHiddenText, %HTexts%

	return sSelectedWinID
}

FindWindow(title, class="", style="", exstyle="", processname="",                          	;-- Finds the first window matching specific criterias.
allowempty = false) {									
	
	WinGet, id, list,,, Program Manager
	Loop, %id%
	{
		this_id := id%A_Index%
		WinGetClass, this_class, ahk_id %this_id%
		if (class && class!=this_class)
			Continue
		WinGetTitle, this_title, ahk_id %this_id%
		if (title && title!=this_title)
			Continue
		WinGet, this_style, style, ahk_id %this_id%
		if (style && style!=this_style)
			Continue
		WinGet, this_exstyle, exstyle, ahk_id %this_id%
		if (exstyle && exstyle!=this_exstyle)
			Continue			
		WinGetPos ,,,w,h,ahk_id %this_id%
		if (!allowempty && (w=0 || h=0))
			Continue		
		WinGet, this_processname, processname, ahk_id %this_id%
		if (processname && processname!=this_processname)
			Continue
		return this_id
	}
	return 0
}

ShowWindow(hWnd, nCmdShow := 1) {	                                                                	;-- uses a DllCall to show a window
    DllCall("ShowWindow", "Ptr", hWnd, "Int", nCmdShow)
}

IsWindow(hWnd) {																										;-- wrapper for IsWindow DllCall
    Return DllCall("IsWindow", "Ptr", hWnd)
}

IsWindowVisible(hWnd) {																							;--
    Return DllCall("IsWindowVisible", "Ptr", hWnd)
}

GetClassName(hWnd) {																								;-- wrapper for AHK WinGetClass function

	WinGetClass Class, ahk_id %hWnd%
    Return Class
}

WinForms_GetClassNN(WinID, fromElement, ElementName) {									;-- Check which ClassNN an element has

	; function by Ixiko 2018 last_change 28.01.2018
	/* Funktionsinfo: Deutsch
		;Achtung: da manchmal 2 verschiedene Elemente den gleichen Namen enthalten können hat die Funktion einen zusätzlichen Parameter: "fromElement"
		;die Funktion untersucht ob das hier angebene Element im ClassNN enthalten ist zb. Button in WindowsForms10.BUTTON.app.0.378734a2
		;die Groß- und Kleinschreibung ist nicht zu beachten
	*/

	/* function info: english
		;Caution: sometimes 2 and more different elements in a gui can contain the same name, therefore the function has an additional parameter: "fromElement"
		;it examines whether the element specified here is contained in the ClassNN, eg. Button in WindowsForms10.BUTTON.app.0.378734a2
		;this function is: case-insensitive
	*/

	WinGet, CtrlList, ControlList, ahk_id %WinID%

	Loop, Parse, CtrlList, `n
	{
			classnn:= A_LoopField
			ControlGetText, Name, %classnn% , ahk_id %WinID%
			If Instr(Name, ElementName, false) and Instr(classnn, fromElement, false)
																				break
			;sleep, 2000
		}


return classNN
}

FindChildWindow(Parent, ChildWinTitle, DetectHiddenWindow="On") {              	;-- finds child window hwnds of the parent window

/* 																						READ THIS FOR MORE INFORMATIONS																														|
												a function from AHK-Forum : https://autohotkey.com/board/topic/46786-enumchildwindows/																					|
																			it has been modified by IXIKO last change on May 10, 2018																										|
																																																																			|
	-finds childWindow handles from a parent window by using Name and/or class or only the WinID of the parentWindow																					   		|
	-it returns a comma separated list of hwnds or nothing if there's no match																																								|
																																																																			|
	-Parent parameter is an array. Pass the following {Key:Value} pairs like this - WinTitle: "Name of window", WinClass: "Class (NN) Name", WinID: ParentWinID									|
																																																																			*/

		detect:= A_DetectHiddenWindows
		global SearchChildTitle
		global ChildHwnds =

		;build ParentWinTitle parameter from ParentObject
		If Parent.WinID {
				id:= Parent.WinID
				ParentWinTitle:= "ahk_id " . id
		} else {
			ParentWinTitle:= Parent.WinTitle
			If Parent.WinClass
					ParentWinTitle.= " ahk_class " Parent.WinClass
		}

		WinGet, active_id, ID, %ParentWinTitle%

		DetectHiddenWindows %DetectHiddenWindows%  ; Due to fast-mode, this setting will go into effect for the callback too.

		; For performance and memory conservation, call RegisterCallback() only once for a given callback:
		if not EnumAddress  ; Fast-mode is okay because it will be called only from this thread:
			EnumAddress := RegisterCallback("EnumChildWindow") ; , "Fast")

		; Pass control to EnumWindows(), which calls the callback repeatedly:
		SearchChildTitle = %ChildWinTitle%

		result:= DllCall("EnumChildWindows", UInt, active_id, UInt, EnumAddress, UInt, 0)

		DetectHiddenWindows %detect%

		ChildHwnds:= SubStr(ChildHwnds, 1, StrLen(ChildHwnds)-1)

		return ChildHwnds
}
EnumChildWindow(hwnd, lParam) { 																			;-- sub function of FindChildWindow

	global ChildHwnds
	global SearchChildTitle

	WinGetTitle, childtitle, ahk_id %hwnd%
	If InStr(childtitle, SearchChildTitle) {
			ChildHwnds.= hwnd . "`;"
		}

    return true  ; Tell EnumWindows() to continue until all windows have been enumerated.
}

WinGetMinMaxState(hwnd) {																						;-- get state if window ist maximized or minimized

	;; this function is from AHK-Forum: https://autohotkey.com/board/topic/13020-how-to-maximize-a-childdocument-window/
	;; it returns z for maximized("zoomed") or i for minimized("iconic")
	;; it's also work on MDI Windows - use hwnd you can get from FindChildWindow()

	; Check if maximized
	zoomed := DllCall("IsZoomed", "UInt", hwnd)
	; Check if minimized
	iconic := DllCall("IsIconic", "UInt", hwnd)

	return (zoomed>iconic) ? "z":"i"
}

GetBgBitMapHandle(hPic)	{																						;-- returns the handle of a background bitmap in a gui

	;found at: https://autohotkey.com/boards/viewtopic.php?t=27128
	SendMessage, 0x173, 0, 0,, ahk_id %hPic%
	return ErrorLevel

}

GetLastActivePopup(hwnd) {																						;-- passes the handle of the last active pop-up window of a parent window
	return DLLCall("GetLastActivePopup", "uint", AlbisWinID)
}

GetFreeGuiNum(start, prefix = "") {																				;-- gets a free gui number.
	/* Group: About
	o v0.81 by majkinetor.
	o Licenced under BSD <http://creativecommons.org/licenses/BSD/> 
*/
	loop {
		Gui %prefix%%start%:+LastFoundExist
		IfWinNotExist
			return prefix start
		start++
		if (start = 100)
			return 0
	}
	return 0
}

IsWindowUnderCursor(hwnd) {                                                                               	;-- Checks if a specific window is under the cursor.
	MouseGetPos, , , win
	if hwnd is number
		return win = hwnd
	else
		return InStr(WinGetClass("ahk_class " win), hwnd)
}

GetCenterCoords(guiW) {                                                                                        	;-- ?center a gui between 2 monitors?

	;https://github.com/number1nub/CreoWindows

	SysGet, numMons, MonitorCount
	SysGet, leftMon1, Monitor, 1
	leftMon := round(leftMon1Right)
	bottomMon := round(leftmon1bottom)
	If (numMons>1)
	{
		SysGet, totalMon, Monitor, 2
		rightMon := round(totalMonRight - leftMon)
		If (rightMon < 0)
		{
			leftMon  := round(leftMon+rightMon)
			rightMon := round(rightmon*-1)
		}
	}
	return { limit: leftMon, left: round((leftMon/2)-(guiW/2)), right: round((leftMon + (rightMon/2))-(guiW/2)) }
}

RMApp_NCHITTEST() {                                                                                            	;-- Determines what part of a window the mouse is currently over
	
	/*                                      	DESCRIPTON
	Function: RMApp_NCHITTEST()
		Determines what part of a window the mouse is currently over.
	*/
	
	CoordMode, Mouse, Screen
	MouseGetPos, x, y, z
	SendMessage, 0x84, 0, (x&0xFFFF)|(y&0xFFFF)<<16,, ahk_id %z%
	RegExMatch("ERROR TRANSPARENT NOWHERE CLIENT CAPTION SYSMENU SIZE MENU HSCROLL VSCROLL MINBUTTON MAXBUTTON LEFT RIGHT TOP TOPLEFT TOPRIGHT BOTTOM BOTTOMLEFT BOTTOMRIGHT BORDER OBJECT CLOSE HELP", "(?:\w+\s+){" ErrorLevel+2&0xFFFFFFFF "}(?<AREA>\w+\b)", HT)
	Return HTAREA
}

GetCPA_file_name( p_hw_target ) {                                                                         	;-- retrieves Control Panel applet icon
	
   WinGet, pid_target, PID, ahk_id %p_hw_target%
   hp_target := DllCall( "OpenProcess", "uint", 0x18, "int", false, "uint", pid_target, "Ptr")
   hm_kernel32 := GetModuleHandle("kernel32.dll")
   pGetCommandLine := DllCall( "GetProcAddress", "Ptr", hm_kernel32, "Astr", A_IsUnicode ? "GetCommandLineW"  : "GetCommandLineA")
   buffer_size := 6
   VarSetCapacity( buffer, buffer_size )
   DllCall( "ReadProcessMemory", "Ptr", hp_target, "uint", pGetCommandLine, "uint", &buffer, "uint", buffer_size, "uint", 0 )
   loop, 4
      ppCommandLine += ( ( *( &buffer+A_Index ) ) << ( 8*( A_Index-1 ) ) )
   buffer_size := 4
   VarSetCapacity( buffer, buffer_size, 0 )
   DllCall( "ReadProcessMemory", "Ptr", hp_target, "uint", ppCommandLine, "uint", &buffer, "uint", buffer_size, "uint", 0 )
   loop, 4
      pCommandLine += ( ( *( &buffer+A_Index-1 ) ) << ( 8*( A_Index-1 ) ) )
   buffer_size := 260
   VarSetCapacity( buffer, buffer_size, 1 )
   DllCall( "ReadProcessMemory", "Ptr", hp_target, "uint", pCommandLine, "uint", &buffer, "uint", buffer_size, "uint", 0 )
   DllCall( "CloseHandle", "Ptr", hp_target )
   IfInString, buffer, desk.cpl ; exception to usual string format
     return, "C:\WINDOWS\system32\desk.cpl"

   ix_b := InStr( buffer, "Control_RunDLL" )+16
   ix_e := InStr( buffer, ".cpl", false, ix_b )+3
   StringMid, CPA_file_name, buffer, ix_b, ix_e-ix_b+1
   if ( ix_e )
      return, CPA_file_name
   else
      return, false
}

WinGetClientPos( Hwnd ) {												        									;-- gives back the coordinates of client area inside a gui/window - with DpiFactor correction
	
	/*                         EXAMPLE
			global dpifactor:=DPIFactor() 

			Gui New, +HwndhGUI +LabelGui_ +Resize
			Gui %hGUI%:Show, w500 h500
			MsgBox The Gui client area will now be covered with a new black gui
			Gui New, +HwndhGUI2 -Caption +ToolWindow +AlwaysOnTop
			Gui %hGUI2%:Color, 000000
			Client := WinGetClientPos( hGUI )
			Gui %hGUI2%:Show, % "x" Client.X " y" Client.Y " w" Client.W " h" Client.H
			OnMessage( 0x03, "GuiChanged" )
			OnMessage( 0x05, "GuiChanged" )
			return

			Gui_Close:
				ExitApp
				
			GuiChanged() {
					global hGUI,hGUI2
					Client := WinGetClientPos( hGUI )
					Gui %hGUI2%:Show, % "x" Client.X " y" Client.Y " w" Client.W " h" Client.H
			}

	*/
	
	; https://autohotkey.com/boards/viewtopic.php?f=6&t=484
	VarSetCapacity( size, 16, 0 )
	DllCall( "GetClientRect", UInt, Hwnd, Ptr, &size )
	DllCall( "ClientToScreen", UInt, Hwnd, Ptr, &size )
	x := NumGet(size, 0, "Int")
	y := NumGet(size, 4, "Int")
	w := NumGet( size, 8, "Int" ) // dpifactor
	h := NumGet( size, 12, "Int" ) // dpifactor
	return { X: x, Y: y, W: w, H: h }
}

CheckWindowStatus(hwnd, timeout=100) {																;-- check's if a window is responding or not responding (hung or crashed) - 

 /* 									Description
					
					check's if a window is responding or not responding (hung or crashed)			
					 timeout milliseconds to wait before deciding it is not responding - 100 ms seems reliable under 100% usage
					 WM_NULL =0x0000
					 SMTO_ABORTIFHUNG =0x0002
			
					
					;  * SendMessageTimeout values
					; 
					; #define SMTO_NORMAL         0x0000
					; #define SMTO_BLOCK          0x0001
					; #define SMTO_ABORTIFHUNG    0x0002
					; #if (WINVER >= 0x0500)
					; #define SMTO_NOTIMEOUTIFNOTHUNG 0x0008
					; #endif /* WINVER >= 0x0500 */
					; #endif /* !NONCMESSAGES */
					; 
					; 
					; SendMessageTimeout(
					;     __in HWND hWnd,
					;     __in UINT Msg,
					;     __in WPARAM wParam,
					;     __in LPARAM lParam,
					;     __in UINT fuFlags,
					;     __in UINT uTimeout,
					;     __out_opt PDWORD_PTR lpdwResult);
*/

	NR_temp =0 ; init
	return DllCall("SendMessageTimeout", "UInt", hwnd, "UInt", 0x0000, "Int", 0, "Int", 0, "UInt", 0x0002, "UInt", TimeOut, "UInt *", NR_temp)
}

GetWindowOrder(hwnd="",visibleWin=1) {												            	;-- determines the window order for a given (parent-)hwnd 
	if !hwnd
		hwnd:=winexist("ahk_pid " DllCall("GetCurrentProcessId"))
	
	arr1:=[]
	arr2:=[]
	
	hwndP:=hwnd
	loop {
		hwndP:=GetNextWindow(hwndP,1,visibleWin)
		if(hwndP=hwnd || !hwndP)
			break
		else
			arr1.insert(hwndP)
	}
	
	hwndN:=hwnd
	loop {
		hwndN:=GetNextWindow(hwndN,1,visibleWin)
		if(hwndN=hwnd || !hwndP)
			break
		else
			arr2.insert(hwndN)
	}
	
	arr:=[],max:=arr1.maxIndex()
	loop % max
		arr.insert(arr1[max+1-a_index])
	for k,v in arr2
		arr.insert(v)
	
	return {array: arr, index: max+1}
	
}
;44
EnumWindows(hWnd := 0, HiddenWindows := true, Flags := "") {								;-- Get a list with all the top-level windows on the screen or controls in the window
	
	/*                              	DESCRIPTION
	
			Get a list with all the top-level windows on the screen or controls in the window
			Syntax: 						EnumWindows ([hWnd], [HiddenWindows], [Flags])
			---------------------------- Parameters -------------------------
			hWnd:	 						specify the hWnd of a window to get a list with all its controls
			HiddenWindows: 		set false to not recover hidden windows. by default it obtains all the windows.
			Flags: 							additional filter options. Specify an object with one or more of the following keys and their respective value.
												ProcessPath = 			specify the path of the file to which the process belongs.
												ProcessName = 			specify the name of the file to which the process belongs.
												WindowClass = 			class of the window.
												WindowTitle = 			title of the window.
												ProcessId = 				PID of the window process.
			 Return: 						returns an array with all hWnds
			------------------------------ Notes -----------------------------
			in WIN_8  only the top-level windows of desktop applications are retrieved.
			When using the 3rd parameter, when checking strings such as WindowClass, WindowTitle, it is not case sensitive, use StringCaseSense to change this.
			Example: get a list with all the windows whose path of the executable file matches explorer.exe
	       	-------------------------------------------------------------------
			EXAMPLE(s) 
			for k, v in EnumWindows(0x0, false, )
					MsgBox % GetWindowClass(v) "`n" GetWindowTitle(v)
					
	*/
	
	EnumAddress := RegisterCallback("EnumWindowsProc", "Fast", 2)
	, _gethwnd(hWnd), Data := {List: [], HiddenWindows: HiddenWindows, Flags: Flags}
	, DllCall("User32.dll\EnumChildWindows", "Ptr", hWnd, "Ptr", EnumAddress, "Ptr", &Data)
	return Data.List, GlobalFree(EnumAddress)
} EnumWindowsProc(hWnd, Data) { ;https://msdn.microsoft.com/en-us/library/windows/desktop/ms633494(v=vs.85).aspx
	if !(Data := Object(Data)) || ((Data.HiddenWindows = 0) && !WinVisible(hWnd))
		return true
	if IsObject(Data.Flags) {
		if Data.Flags.HasKey("WindowTitle") && (GetWindowTitle(hWnd) != Data.Flags.WindowTitle)
			return true
		if Data.Flags.HasKey("WindowClass") && (GetWindowClass(hWnd) != Data.Flags.WindowClass)
			return true
		if Data.Flags.HasKey("ProcessPath") || Data.Flags.HasKey("ProcessId") || Data.Flags.HasKey("ProcessName") {
			GetWindowThreadProcessId(hWnd, ProcessId)
			if Data.Flags.HasKey("ProcessPath") || Data.Flags.HasKey("ProcessName") {
				ProcessPath := GetModuleFileName("/" ProcessId)
				if Data.Flags.HasKey("ProcessPath") && (ProcessPath != Data.Flags.ProcessPath)
					return true
				if Data.Flags.HasKey("ProcessName") {
					SplitPath, ProcessPath, ProcessName
					if (ProcessName != Data.Flags.ProcessName)
						return true
			}	} if Data.Flags.HasKey("ProcessId") && (ProcessId != Data.Flags.ProcessId)
				return true
	}	} return true, Data.List.Push(hWnd)
} ;https://msdn.microsoft.com/en-us/library/windows/desktop/ms633493(v=vs.85).aspx
;45

} 

{ ; MISC (6)

ChooseColor(ByRef Color, hOwner := 0) {																	;--		what is this for?
    rgbResult := ((Color & 0xFF) << 16) + (Color & 0xFF00) + ((Color >> 16) & 0xFF)

    VarSetCapacity(CUSTOM, 64, 0)
    NumPut(VarSetCapacity(CHOOSECOLOR, A_PtrSize * 9, 0), CHOOSECOLOR, 0)
    NumPut(hOwner, CHOOSECOLOR, A_PtrSize)
    NumPut(rgbResult, CHOOSECOLOR, A_PtrSize * 3)
    NumPut(&CUSTOM, CHOOSECOLOR, A_PtrSize * 4) ; COLORREF *lpCustColors
    NumPut(0x103, CHOOSECOLOR, A_PtrSize * 5) ; Flags: CC_ANYCOLOR | CC_RGBINIT | CC_FULLOPEN

    RetVal := DllCall("comdlg32\ChooseColorA", "Str", CHOOSECOLOR)
    If (ErrorLevel != 0 || RetVal == 0) {
        Return False
    }

    rgbResult := NumGet(CHOOSECOLOR, A_PtrSize * 3)
    Color := (rgbResult & 0xFF00) + ((rgbResult & 0xFF0000) >> 16) + ((rgbResult & 0xFF) << 16)
    Color := Format("0x{:06X}", Color)
    Return True
}

GetWindowIcon(hWnd, Class, TopLevel := False) {														;--

	Static Classes := {0:0
    , "#32770": 3
    , "Button": 4
    , "CheckBox": 5
    , "ComboBox": 6
    , "SysDateTimePick32": 7
    , "Edit": 8
    , "GroupBox": 9
    , "msctls_hotkey32": 10
    , "Icon": 11
    , "SysLink": 12
    , "ListBox": 13
    , "SysListView32": 14
    , "SysMonthCal32": 15
    , "Picture": 16
    , "msctls_progress32": 17
    , "Radio": 18
    , "RebarWindow32": 25
    , "RichEdit": 19
    , "Separator": 20
    , "msctls_trackbar32": 21
    , "msctls_statusbar32": 22
    , "SysTabControl32": 23
    , "Static": 24
    , "ToolbarWindow32": 25
    , "tooltips_class32": 26
    , "SysTreeView32": 27
    , "msctls_updown32": 28
    , "Internet Explorer_Server": 29
    , "Scintilla": 30
    , "ScrollBar": 31
    , "SysHeader32": 32}

    If (Class == "Button") {
        WinGet Style, Style, ahk_id %hWnd%
        Type := Style & 0xF
        If (Type == 7) {
            Class := "GroupBox"
        } Else If (Type ~= "2|3|5|6") {
            Class := "CheckBox"
        } Else If (Type ~= "4|9") {
            Class := "Radio"
        } Else {
            Class := "Button"
        }
    } Else If (Class == "Static") {
        WinGet Style, Style, ahk_id %hWnd%
        Type := Style & 0x1F ; SS_TYPEMASK
        If (Type == 3) {
            Class := "Icon"
        } Else If (Type == 14) {
            Class := "Picture"
        } Else If (Type == 0x10) {
            Class := "Separator"
        } Else {
            Class := "Static"
        }
    } Else If (InStr(Class, "RICHED", True) == 1) {
        Class := "RichEdit" ; RICHEDIT50W
    }

    Icon := Classes[Class]
    If (Icon != "") {
        Return Icon
    }

    SendMessage 0x7F, 2, 0,, ahk_id %hWnd% ; WM_GETICON, ICON_SMALL2
    hIcon := ErrorLevel

    If (hIcon == 0 && TopLevel) {
        WinGet ProcessPath, ProcessPath, ahk_id %hWnd%
        hIcon := GetFileIcon(ProcessPath)
    }

    IconIndex := (hIcon) ? IL_Add(ImageList, "HICON: " . hIcon) : 1
    Return IconIndex
}

GetStatusBarText(hWnd) {																							;--
    SB_Text := ""
    hParentWnd := GetParent(hWnd)

    SendMessage 0x406, 0, 0,, ahk_id %hWnd% ; SB_GETPARTS
    Count := ErrorLevel
    If (Count != "FAIL") {
        Loop %Count% {
            StatusBarGetText PartText, %A_Index%, ahk_id %hParentWnd%
            SB_Text .= PartText . "|"
        }
    }

    Return SubStr(SB_Text, 1, -1)
}

GetAncestor(hWnd, Flag := 2) {																					;--
    Return DllCall("GetAncestor", "Ptr", hWnd, "UInt", Flag)
}

OnMessage(0x24, "MinMaxInfo")
MinMaxInfo(W, L, M, H) {																							;--
	Static MIEX := 0, Dummy := NumPut(VarSetCapacity(MIEX, 40 + (32 << !!A_IsUnicode)), MIEX, 0, "UInt")
	Critical
	If (HMON := DllCall("User32.dll\MonitorFromWindow", "Ptr", H, "UInt", 0, "UPtr")) {
		If DllCall("User32.dll\GetMonitorInfo", "Ptr", HMON, "Ptr", &MIEX) {
			W := NumGet(MIEX, 28, "Int") - NumGet(MIEX, 20, "Int")
			H := NumGet(MIEX, 32, "Int") - NumGet(MIEX, 24, "Int")
			NumPut(W - NumGet(L + 16, "Int"), L + 8, "Int")
			NumPut(H - NumGet(L + 20, "Int"), L + 12, "Int")
		}
	}
}

} 

} 

{ ;Gui/Window - interacting and other functions for gui or windows (43)
		
;01		
SureControlClick(CName, WinTitle, WinText="") { 														;--Window Activation + ControlDelay to -1 + checked if control received the click
		;by Ixiko 2018
		Critical
		WinActivate, %WTitle%, %WinText%
			WinWaitActive, %WTitle%, %WinText%, 3

		SetControlDelay -1
			ControlClick, %CName%, %WinTitle%, %WinText%,,, NA		;If the click does not work then he tries a little differently
				If ErrorLevel
					ControlClick, %CName%, %WinTitle%, %WinText%

		SetControlDelay 20


	return ErrorLevel
}
;02
SureControlCheck(CName, WinTitle, WinText="") { 													;-- Window Activation + ControlDelay to -1 + Check if the control is really checked now
	;by Ixiko 2018
	;BlockInput, On
		Critical
		WinActivate, %WTitle%, %WinText%
			WinWaitActive, %WTitle%, %WinText%, 1

		SetControlDelay -1
			Loop {
				Control, Check, , %CName%, %WinTitle%, %WinText%
					sleep, 10
				ControlGet, isornot, checked, ,  %CName%, %WinTitle%, %WinText%
			} until (isornot = 1)

		SetControlDelay 20

	;BlockInput, Off

	return ErrorLevel
}
;03
ControlClick2(X, Y, WinTitle="", WinText="", ExcludeTitle="", ExcludeText="")  {		;-- ControlClick Double Click
	
  hwnd:=ControlFromPoint(X, Y, WinTitle, WinText, cX, cY
                             , ExcludeTitle, ExcludeText)
  PostMessage, 0x201, 0, cX&0xFFFF | cY<<16,, ahk_id %hwnd% ; WM_LBUTTONDOWN
  PostMessage, 0x202, 0, cX&0xFFFF | cY<<16,, ahk_id %hwnd% ; WM_LBUTTONUP
  PostMessage, 0x203, 0, cX&0xFFFF | cY<<16,, ahk_id %hwnd% ; WM_LBUTTONDBLCLCK
  PostMessage, 0x202, 0, cX&0xFFFF | cY<<16,, ahk_id %hwnd% ; WM_LBUTTONUP
}
;04
ControlFromPoint(X, Y, WinTitle="", WinText="", ByRef cX="", ByRef cY="",           	;--  returns the hwnd of a control at a specific point on the screen
ExcludeTitle="", ExcludeText="") {	
	
	/*                              	DESCRIPTION
	
			 https://autohotkey.com/board/topic/71988-simulating-a-double-click/
			 
			 Retrieves the control at the specified point.
			 X         [in]    X-coordinate relative to the top-left of the window.
			 Y         [in]    Y-coordinate relative to the top-left of the window.
			 WinTitle  [in]    Title of the window whose controls will be searched.
			 WinText   [in]
			 cX        [out]   X-coordinate relative to the top-left of the control.
			 cY        [out]   Y-coordinate relative to the top-left of the control.
			 ExcludeTitle [in]
			 ExcludeText  [in]
			 Return Value:     The hwnd of the control if found, otherwise the hwnd of the window.
			
	*/
	
	
    static EnumChildFindPointProc=0
    if !EnumChildFindPointProc
        EnumChildFindPointProc := RegisterCallback("EnumChildFindPoint","Fast")

    if !(target_window := WinExist(WinTitle, WinText, ExcludeTitle, ExcludeText))
        return false

    VarSetCapacity(rect, 16)
    DllCall("GetWindowRect","uint",target_window,"uint",&rect)
    VarSetCapacity(pah, 36, 0)
    NumPut(X + NumGet(rect,0,"int"), pah,0,"int")
    NumPut(Y + NumGet(rect,4,"int"), pah,4,"int")
    DllCall("EnumChildWindows","uint",target_window,"uint",EnumChildFindPointProc,"uint",&pah)
    control_window := NumGet(pah,24) ? NumGet(pah,24) : target_window
    DllCall("ScreenToClient","uint",control_window,"uint",&pah)
    cX:=NumGet(pah,0,"int"), cY:=NumGet(pah,4,"int")
    return control_window
}
;05
EnumChildFindPoint(aWnd, lParam) {																			;-- this function is required by ControlFromPoint
	
	; this was ported from AutoHotkey::script2.cpp::EnumChildFindPoint()
    if !DllCall("IsWindowVisible","uint",aWnd)
        return true
    VarSetCapacity(rect, 16)
    if !DllCall("GetWindowRect","uint",aWnd,"uint",&rect)
        return true
    pt_x:=NumGet(lParam+0,0,"int"), pt_y:=NumGet(lParam+0,4,"int")
    rect_left:=NumGet(rect,0,"int"), rect_right:=NumGet(rect,8,"int")
    rect_top:=NumGet(rect,4,"int"), rect_bottom:=NumGet(rect,12,"int")
    if (pt_x >= rect_left && pt_x <= rect_right && pt_y >= rect_top && pt_y <= rect_bottom)
    {
        center_x := rect_left + (rect_right - rect_left) / 2
        center_y := rect_top + (rect_bottom - rect_top) / 2
        distance := Sqrt((pt_x-center_x)**2 + (pt_y-center_y)**2)
        update_it := !NumGet(lParam+24)
        if (!update_it)
        {
            rect_found_left:=NumGet(lParam+8,0,"int"), rect_found_right:=NumGet(lParam+8,8,"int")
            rect_found_top:=NumGet(lParam+8,4,"int"), rect_found_bottom:=NumGet(lParam+8,12,"int")
            if (rect_left >= rect_found_left && rect_right <= rect_found_right
                && rect_top >= rect_found_top && rect_bottom <= rect_found_bottom)
                update_it := true
            else if (distance < NumGet(lParam+28,0,"double")
                && (rect_found_left < rect_left || rect_found_right > rect_right
                 || rect_found_top < rect_top || rect_found_bottom > rect_bottom))
                 update_it := true
        }
        if (update_it)
        {
            NumPut(aWnd, lParam+24)
            DllCall("RtlMoveMemory","uint",lParam+8,"uint",&rect,"uint",16)
            NumPut(distance, lParam+28, 0, "double")
        }
    }
    return true
}
;06
ControlDoubleClick(ctrl,win,bttn:="Left",x:=1,y:=1) {                                                 	;-- simulates a double click on a control with left/middle or right mousebutton
	
	;https://github.com/Lateralus138/Task-Lister/blob/master/TLLib.ahk
    id:=WinExist(win)?WinExist(win):0
	If bttn IN Left,left,l,L
		a.="0x201",b.="0x202",c.="0x203"
	If bttn IN Right,right,r,R
		a.="0x204",b.="0x205",c.="0x206"
	If bttn IN Middle,middle,m,M
		a.="0x207",b.="0x208",c.="0x209"
    If !(id && a && b && c)
        Return 0
    lParam:=x & 0xFFFF | (y & 0xFFFF) << 16
	WinActivate,ahk_id %id%
	PostMessage,%a%,1,%lParam%,%ctrl%,ahk_id %id%
	PostMessage,%b%, ,%lParam%,%ctrl%,ahk_id %id%
    PostMessage,%c%,1,%lParam%,%ctrl%,ahk_id %id%
    Return id
}
;07
WinWaitForMinimized(ByRef winID, timeOut = 1000) {												;--
  ; Function:  WinWaitForMinimized
;              waits for the window winID to minimize or until timeout,
;              whichever comes first (used to delay other actions until a
;              minimize message is handled and completed)
; Parm1:     winID - ID of window to wait for minimization
; Parm2:     timeOut - optional - timeout in milliseconds to wait
; wait until minimized (or timeOut)
   iterations := timeOut/10
   loop,%iterations%
   {
      WinGet,winMinMax,MinMax,ahk_id %winID%
      if (winMinMax = -1)
         break
      sleep 10
   }
}
;08
CenterWindow(aWidth,aHeight) {																				;-- Given a the window's width and height, calculates where to position its upper-left corner so that it is centered EVEN IF the task bar is on the left side or top side of the window
  ; Given a the window's width and height, calculates where to position its upper-left corner
  ; so that it is centered EVEN IF the task bar is on the left side or top side of the window.
  ; This does not currently handle multi-monitor systems explicitly, since those calculations
  ; require API functions that don't exist in Win95/NT (and thus would have to be loaded
  ; dynamically to allow the program to launch).  Therefore, windows will likely wind up
  ; being centered across the total dimensions of all monitors, which usually results in
  ; half being on one monitor and half in the other.  This doesn't seem too terrible and
  ; might even be what the user wants in some cases (i.e. for really big windows).

	static rect:=Struct("left,top,right,bottom"),SPI_GETWORKAREA:=48,pt:=Struct("x,y")
	DllCall("SystemParametersInfo","Int",SPI_GETWORKAREA,"Int", 0,"PTR", rect[],"Int", 0)  ; Get desktop rect excluding task bar.
	; Note that rect.left will NOT be zero if the taskbar is on docked on the left.
	; Similarly, rect.top will NOT be zero if the taskbar is on docked at the top of the screen.
	pt.x := rect.left + (((rect.right - rect.left) - aWidth) / 2)
	pt.y := rect.top + (((rect.bottom - rect.top) - aHeight) / 2)
	return pt
}
;09
GuiCenterButtons(strWindow, intInsideHorizontalMargin := 10, 								;-- Center and resize a row of buttons automatically
intInsideVerticalMargin := 0, intDistanceBetweenButtons := 20, arrControls*) {
; This is a variadic function. See: http://ahkscript.org/docs/Functions.htm#Variadic
; https://autohotkey.com/boards/viewtopic.php?t=3963 from JnLlnd

	/*				EXAMPLE
	
		Gui, New, , MyWindow

		Gui, Add, Text, , Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras rutrum nisi et metus porttitor non tristique est euismod. Maecenas accumsan, ante at tempus tempor, lorem elit mollis mauris, vitae tempor massa odio eget libero.

		Gui, Font
		Gui, Add, Button, y+20 vMyButton1 gGuiClose, Close
		Gui, Add, Button, yp vMyButton2 gGuiClose, Lonnger Button Name
		GuiCenterButtons("MyWindow", 10, 5, 30, "MyButton1", "MyButton2")

		Gui, Show, Autosize Center

		return


		GuiClose:
		ExitApp
	
	*/

	DetectHiddenWindows, On
	Gui, Show, Hide
	WinGetPos, , , intWidth, , %strWindow%

	intMaxControlWidth := 0
	intMaxControlHeight := 0
	for intIndex, strControl in arrControls
	{
		GuiControlGet, arrControlPos, Pos, %strControl%
		if (arrControlPosW > intMaxControlWidth)
			intMaxControlWidth := arrControlPosW
		if (arrControlPosH > intMaxControlHeight)
			intMaxControlHeight := arrControlPosH
	}

	intMaxControlWidth := intMaxControlWidth + intInsideHorizontalMargin
	intButtonsWidth := (arrControls.MaxIndex() * intMaxControlWidth) + ((arrControls.MaxIndex()  - 1) * intDistanceBetweenButtons)
	intLeftMargin := (intWidth - intButtonsWidth) // 2

	for intIndex, strControl in arrControls
		GuiControl, Move, %strControl%
			, % "x" . intLeftMargin + ((intIndex - 1) * intMaxControlWidth) + ((intIndex - 1) * intDistanceBetweenButtons)
			. " w" . intMaxControlWidth
			. " h" . intMaxControlHeight + intInsideVerticalMargin
}
;10
CenterControl(hWnd,hCtrl,X=1,Y=1) {																		;-- Centers one control
;------------------------------------------------------------------------------------------------------------------------
;Function:    CenterControl (by Banane: http://de.autohotkey.com/forum/viewtopic.php?p=67802#67802)
;Parameters:  hWnd  = Handle of a Window (can be obtained using "WinExist()")
;             hCtrl = Handle of a Control (can be obtained using the "Hwnd" option when creating the control)
;             X     = Center the Control horizontally if X is 1
;             Y     = Center the Control vertically if Y is 1
;Description: Moves the specified control within the center of the specified window
;Returnvalue: 0 - Invalid Window / Control Handle, or the Window / Control has a size of 0
;------------------------------------------------------------------------------------------------------------------------

 static Border,CaptionSmall,CaptionNormal

  ;Retrieve Size of Border and Caption, if this is the first time this function is called
  If (!CaptionNormal) {
    SysGet, Border, 5        ;Border Width
    SysGet, CaptionNormal, 4 ;Window Caption
    SysGet, CaptionSmall, 51 ;Window Caption with Toolwindow Style
  }

  ;Only continue if valid handles passed
  If (!hWnd || !hCtrl)
    Return 0

  ;Retrieve the size of the control and window
  ControlGetPos,,, cW, cH,, % "ahk_id " hCtrl
  WinGetPos,,, wW, wH, % "ahk_id " hWnd
  ;Only continue if the control and window are visible (and don't have a size of 0)
  If ((cW = "" || cH = "") || (wW = "" || wH = ""))
    Return 0

  ;Retrieve the window styles
  WinGet, Styles, Style, % "ahk_id " hWnd
  WinGet, ExStyles, ExStyle, % "ahk_id " hWnd

  ;Calculate the offset
  If (Styles & 0xC00000) ;If window has the "Caption" flag
    If (ExStyles & 0x00000080) ;If window has the "Toolwindow" flag
      Caption := CaptionSmall
    Else Caption := CaptionNormal
  Else Caption := 1

  ;Calculate the new position and apply it to the control
  ControlMove,, % (X = 1) ? Round((wW - cW + Border) / 2) : "", % (Y = 1) ? Round((wH - cH + Caption) / 2) : "",,, % "ahk_id " hCtrl

  ;Redraw the windows content
  WinSet, Redraw,, % "ahk_id " hWnd

  Return 1
}

Result := DllCall("SetWindowPos", "UInt", Gui2, "UInt", Gui1, "Int", Gui1X + 300, "Int", Gui1Y, "Int", "", "Int", "", "Int", 0x01)
;11
SetWindowIcon(hWnd, Filename, Index := 1) {															;--
    Local hIcon := LoadPicture(Filename, "w16 Icon" . Index, ErrorLevel)
    SendMessage 0x80, 0, hIcon,, ahk_id %hWnd% ; WM_SETICON
    Return ErrorLevel
}
;12
SetWindowPos(hWnd, x, y, w, h, hWndInsertAfter := 0, uFlags := 0x40) {					;--
    Return DllCall("SetWindowPos", "Ptr", hWnd, "Ptr", hWndInsertAfter, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", uFlags)
}
;13
TryKillWin(win) {																											;--
	static funcs := ["Win32_SendMessage", "Win32_TaskKill", "Win32_Terminate"]

	if (IsClosed(win, 0.5)) {
		IdleGui("Window is already closed", "", 3, true)
		return
	}

	for i, v in funcs {
		IdleGui("Trying " . v . "...", "Closing...", 10, false)
		if (%v%(win)) {
			IdleGuiClose()
			return true
		}
	}
	return false
}
;14
Win32_SendMessage(win) {																						;-- Closing a window through sendmessage command
	static wm_msgs := {"WM_CLOSE":0x0010, "WM_QUIT":0x0012, "WM_DESTROY":0x0002}
	for k, v in wm_msgs {
		SendMessage, %v%, 0, 0,, ahk_id %win%
		if (IsClosed(win, 1))
			break
	}
	if (IsClosed(win, 1))
		return true
	return false
}
;15
Win32_TaskKill(win) {																									;--
	WinGet, win_pid, PID, ahk_id %win%
	cmdline := "taskkill /pid " . win_pid . " /f"
	Run, %cmdline%,, Hide UseErrorLevel
	if (ErrorLevel != 0 or !IsClosed(win, 5))
		return false
	return true
}
;16
Win32_Terminate(win) {																								;--
	WinGet, win_pid, PID, ahk_id %win%
	handle := DllCall("Kernel32\OpenProcess", UInt, 0x0001, UInt, 0, UInt, win_pid)
	if (!handle)
		return false
	result := DllCall("Kernel32\TerminateProcess", UInt, handle, Int, 0)
	if (!result)
		return false
	return IsClosed(win, 5)
}
;17
TabActivate(no) {																											;--
	global GuiWinTitle
	SendMessage, 0x1330, %no%,, SysTabControl321, %GuiWinTitle%
	Sleep 50
	SendMessage, 0x130C, %no%,, SysTabControl321, %GuiWinTitle%
	return
}
;18
FocuslessScroll(Function inside) {																				;--
;Directives
#NoEnv
#SingleInstance Force
#MaxHotkeysPerInterval 100 ;Avoid warning when mouse wheel turned very fast
;Autoexecute code
MinLinesPerNotch := 1
MaxLinesPerNotch := 5
AccelerationThreshold := 100
AccelerationType := "L" ;Change to "P" for parabolic acceleration
StutterThreshold := 10
;Function definitions
;See above for details
FocuslessScroll(MinLinesPerNotch, MaxLinesPerNotch, AccelerationThreshold, AccelerationType, StutterThreshold) {
	SetBatchLines, -1 ;Run as fast as possible
	CoordMode, Mouse, Screen ;All coords relative to screen

	;Stutter filter: Prevent stutter caused by cheap mice by ignoring successive WheelUp/WheelDown events that occur to close together.
	if (A_TimeSincePriorHotkey < StutterThreshold) ;Quickest succession time in ms
		if (A_PriorHotkey = "WheelUp" Or A_PriorHotkey ="WheelDown")
			Return

	MouseGetPos, m_x, m_y,, ControlClass2, 2
	ControlClass1 := DllCall( "WindowFromPoint", "int64", (m_y << 32) | (m_x & 0xFFFFFFFF), "Ptr") ;32-bit and 64-bit support

	lParam := (m_y << 16) | (m_x & 0x0000FFFF)
	wParam := (120 << 16) ;Wheel delta is 120, as defined by MicroSoft

	;Detect WheelDown event
	if (A_ThisHotkey = "WheelDown" Or A_ThisHotkey = "^WheelDown" Or A_ThisHotkey = "+WheelDown" Or A_ThisHotkey = "*WheelDown")
		wParam := -wParam ;If scrolling down, invert scroll direction

	;Detect modifer keys held down (only Shift and Control work)
	if (GetKeyState("Shift","p"))
		wParam := wParam | 0x4
	if (GetKeyState("Ctrl","p"))
		wParam := wParam | 0x8

	;Adjust lines per notch according to scrolling speed
	Lines := LinesPerNotch(MinLinesPerNotch, MaxLinesPerNotch, AccelerationThreshold, AccelerationType)

	if (ControlClass1 != ControlClass2)
	{
		Loop %Lines%
		{
			SendMessage, 0x20A, wParam, lParam,, ahk_id %ControlClass1%
			SendMessage, 0x20A, wParam, lParam,, ahk_id %ControlClass2%
		}
	}
	Else ;Avoid using Loop when not needed (most normal controls). Greately improves momentum problem!
	{
		SendMessage, 0x20A, wParam * Lines, lParam,, ahk_id %ControlClass1%
	}
}
LinesPerNotch(MinLinesPerNotch, MaxLinesPerNotch, AccelerationThreshold, AccelerationType) {
	T := A_TimeSincePriorHotkey
	;All parameters are the same as the parameters of FocuslessScroll()
	;Return value: Returns the number of lines to be scrolled calculated from the current scroll speed.
	;Normal slow scrolling, separationg between scroll events is greater than AccelerationThreshold miliseconds.
	if ((T > AccelerationThreshold) Or (T = -1)) ;T = -1 if this is the first hotkey ever run
	{
		Lines := MinLinesPerNotch
	}
	;Fast scrolling, use acceleration
	Else
	{
		if (AccelerationType = "P")
		{
			;Parabolic scroll speed curve
			;f(t) = At^2 + Bt + C
			A := (MaxLinesPerNotch-MinLinesPerNotch)/(AccelerationThreshold**2)
			B := -2 * (MaxLinesPerNotch - MinLinesPerNotch)/AccelerationThreshold
			C := MaxLinesPerNotch
			Lines := Round(A*(T**2) + B*T + C)
		}
		Else
		{
			;Linear scroll speed curve
			;f(t) = Bt + C
			B := (MinLinesPerNotch-MaxLinesPerNotch)/AccelerationThreshold
			C := MaxLinesPerNotch
			Lines := Round(B*T + C)
		}
	}
	Return Lines
}
;All hotkeys with the same parameters can use the same instance of FocuslessScroll(). No need to have separate calls unless each hotkey requires different parameters (e.g. you want to disable acceleration for Ctrl-WheelUp and Ctrl-WheelDown).
;If you want a single set of parameters for all scrollwheel actions, you can simply use *WheelUp:: and *WheelDown:: instead.
#MaxThreadsPerHotkey 6 ;Adjust to taste. The lower the value, the lesser the momentum problem on certain smooth-scrolling GUI controls (e.g. AHK helpfile main pane, WordPad...), but also the lesser the acceleration feel. The good news is that this setting does no affect most controls, only those that exhibit the momentum problem. Nice.
;Scroll with acceleration
WheelUp::
WheelDown::FocuslessScroll(MinLinesPerNotch, MaxLinesPerNotch, AccelerationThreshold, AccelerationType, StutterThreshold)
;Ctrl-Scroll zoom with no acceleration (MaxLinesPerNotch = MinLinesPerNotch).
^WheelUp::
^WheelDown::FocuslessScroll(MinLinesPerNotch, MinLinesPerNotch, AccelerationThreshold, AccelerationType, StutterThreshold)
;If you want zoom acceleration, replace above line with this:
;FocuslessScroll(MinLinesPerNotch, MaxLinesPerNotch, AccelerationThreshold, AccelerationType, StutterThreshold)
#MaxThreadsPerHotkey 1 ;Restore AHK's default  value i.e. 1
;End: Focusless Scroll
}
;19
FocuslessScrollHorizontal(MinLinesPerNotch, MaxLinesPerNotch, 							;--
AccelerationThreshold, AccelerationType, StutterThreshold) {

	;https://autohotkey.com/board/topic/99405-hoverscroll-verticalhorizontal-scroll-without-focus-scrollwheel-acceleration/page-5

    SetBatchLines, -1 ;Run as fast as possible
    CoordMode, Mouse, Screen ;All coords relative to screen

    ;Stutter filter: Prevent stutter caused by cheap mice by ignoring successive WheelUp/WheelDown events that occur to close together.
    if (A_TimeSincePriorHotkey < StutterThreshold) ;Quickest succession time in ms
        if (A_PriorHotkey = "WheelUp" Or A_PriorHotkey ="WheelDown")
            Return

    MouseGetPos, m_x, m_y,, ControlClass2, 2
    ControlClass1 := DllCall( "WindowFromPoint", "int64", (m_y << 32) | (m_x & 0xFFFFFFFF), "Ptr") ;32-bit and 64-bit support

    ctrlMsg := 0x114    ; WM_HSCROLL
    wParam := 0         ; Left

    ;Detect WheelDown event
    if (A_ThisHotkey = "WheelDown" Or A_ThisHotkey = "^WheelDown" Or A_ThisHotkey = "+WheelDown" Or A_ThisHotkey = "*WheelDown")
        wParam := 1 ; Right

    ;Adjust lines per notch according to scrolling speed
    Lines := LinesPerNotch(MinLinesPerNotch, MaxLinesPerNotch, AccelerationThreshold, AccelerationType)

    Loop %Lines%
    {
        SendMessage, ctrlMsg, wParam, 0,, ahk_id %ControlClass1%
        if (ControlClass1 != ControlClass2)
            SendMessage, ctrlMsg, wParam, 0,, ahk_id %ControlClass2%
    }
}
;20
Menu_Show( hMenu, hWnd=0, mX="", mY="", Flags=0x1 ) {									;-- alternate to Menu, Show , which can display menu without blocking monitored messages...
 ; http://ahkscript.org/boards/viewtopic.php?p=7088#p7088
 ; Flags: TPM_RECURSE := 0x1, TPM_RETURNCMD := 0x100, TPM_NONOTIFY := 0x80
 VarSetCapacity( POINT, 8, 0 ), DllCall( "GetCursorPos", UInt,&Point )
 mX := ( mX <> "" ) ? mX : NumGet( Point,0 )
 mY := ( mY <> "" ) ? mY : NumGet( Point,4 )
Return DllCall( "TrackPopupMenu", UInt,hMenu, UInt,Flags ; TrackPopupMenu()  goo.gl/CosNig
               , Int,mX, Int,mY, UInt,0, UInt,hWnd ? hWnd : WinActive("A"), UInt,0 )

/*
..but the catch is: To get handle ( hMenu ) for a Menuname, it has to be attached to a MenuBar.
There already is a function from lexikos, which does this: MI_GetMenuHandle(), and can be used as follows:

hViewmenu := MI_GetMenuHandle( "view" ) ; Get it from: http://www.autohotkey.net/~Lexikos/lib/MI.ahk
...
...
GuiContextMenu:
 Menu_Show( hViewMenu )
Return
*/
}
;21
CatMull_ControlMove( px0, py0, px1, py1, px2, py2, 													;-- Moves the mouse through 4 points (without control point "gaps")
px3, py3, Segments=8, Rel=0, Speed=2 ) {
; Function by [evandevon]. Moves the mouse through 4 points (without control point "gaps"). Inspired by VXe's
;cubic bezier curve function (with some borrowed code).
   MouseGetPos, px0, py0
   If Rel
      px1 += px0, px2 += px0, px3 += px0, py1 += py0, py2 += py0, py3 += py0
   Loop % Segments - 1
   {
	;CatMull Rom Spline - Working
	  u := 1 - t := A_Index / Segments
	  cmx := Round(0.5*((2*px1) + (-px0+px2)*t + (2*px0 - 5*px1 +4*px2 - px3)*t**2 + (-px0 + 3*px1 - 3*px2 + px3)*t**3) )
	  cmy := Round(0.5*((2*py1) + (-py0+py2)*t + (2*py0 - 5*py1 +4*py2 - py3)*t**2 + (-py0 + 3*py1 - 3*py2 + py3)*t**3) )

	  MouseMove, cmx, cmy, Speed,

   }
   MouseMove, px3, py3, Speed
} ; CatMull_MouseMove( px1, py1, px2, py2, px3, py3, Segments=5, Rel=0, Speed=2 ) -------------------
;22
GUI_AutoHide(Hide_Direction, Gui_Num_To_Hide_Clone=1, 									;-- Autohide the GUI function
Delay_Before_Hide=3000, Number_Of_Offset_Pixels=5, Enabled_Disabled_Flag=1) {


	;                   Original Author: jpjazzy            Link: http://www.autohotkey.com/forum/viewtopic.php?p=485853#485853
	; =====================================================================================================================================================
	;   GUI_AutoHide(Hide direction, [Gui # to hide, Delay in milliseconds before hiding, Number of pixels to display while hidden (offset), Enabled/Disabled Flag])
	; =====================================================================================================================================================
	; Required parameters: Hide direction (LEFT="L", RIGHT="R", UP="U", DOWN="D")
	; Defaults for optional parameters: GUI # = 1, Delay in ms = 3000 = 3 seconds, Number of pixels to display while hidden = 5, Enabled/Disabled Flag = 1 (Enabled=1 Disabled=0)
	; =====================================================================================================================================================
	; NOTES:
	; * Functions work with expressions, so make sure you use quotes when inputting settings unless the setting is contained within a variable
	; * Function must be placed directly after the GUI you are using it for
	; * Function will make the GUI AlwaysOnTop so the user can activate it from the autohide
	; * Specifying 0 for the Enabled/Disabled Flag will return the GUI to it's original position before deactivating autohide
	; * The window must be hidden and docked to the side of the screen before the effects of the autohide take place
	; * The titlebar sometimes gets in the way of reactivating the hidden GUI if there is one... To get around this either remove the caption/border or Set a higher pixel offset
	; =====================================================================================================================================================
	; LIMITATIONS:
	; - Using this on multiple GUIs most likely will cause problems due to the hide overlapping
	; =====================================================================================================================================================

	; ========================================= (AUTOHIDE FUNCTIONS) ==========================================

	SetBatchLines, -1

   global ; Assume global
   Gui_Num_To_Hide := Gui_Num_To_Hide_Clone
   Gui, %Gui_Num_To_Hide%: +LastFound +AlwaysOnTop ; Set GUI settings so we can obtain it's settings and give it an alwaysontop attribute to make the user be able to unhide it

   ; ** OBTAIN  AND SET VARIABLES **
   StringUpper, Hide_Direction, Hide_Direction ; Capitalize it just in case the user didn't for the label
   If ( Enabled_Disabled_Flag = 0 )
   {
   %Gui_Num_To_Hide%_Enabled_Disabled_Flag := 0
    WinMove, % %Gui_Num_To_Hide%_Gui_Title,, % %Gui_Num_To_Hide%_GUIX, % %Gui_Num_To_Hide%_GUIY
    return
   }

   WinGetPos, %Gui_Num_To_Hide%_GUIX, %Gui_Num_To_Hide%_GUIY, %Gui_Num_To_Hide%_GUIW, %Gui_Num_To_Hide%_GUIH, A
   WinGetTitle, %Gui_Num_To_Hide%_Gui_Title, A
   %Gui_Num_To_Hide%_TimeLapse := A_TickCount                           ; Set the specified variables with respect to which GUI the settings go to
   %Gui_Num_To_Hide%_Enabled_Disabled_Flag := Enabled_Disabled_Flag
   %Gui_Num_To_Hide%_Number_Of_Offset_Pixels := Number_Of_Offset_Pixels
   %Gui_Num_To_Hide%_Delay_Before_Hide := Delay_Before_Hide
   %Gui_Num_To_Hide%_Hide_Direction := Hide_Direction
    ;MsgBox % %Gui_Num_To_Hide%_Gui_Title


   ; ** Place message for GUI **
   OnMessage(0x200,"WM_MOUSEMOVE") ; Message to send when the mouse is over the GUI
   SetTimer, HideGUI%Hide_Direction%, 500 ; Set timer to hide the GUI in whatever direction you chose
   return

      ; ** HideGUI Settings **
   HideGUIU:
   ;~ ;MsgBox % "If (" A_TickCount - %Gui_Num_To_Hide%_TimeLapse " < " %Gui_Num_To_Hide%_Delay_Before_Hide ") "
   If (%Gui_Num_To_Hide%_Enabled_Disabled_Flag != 1)
      return
   If (A_TickCount - %Gui_Num_To_Hide%_TimeLapse < %Gui_Num_To_Hide%_Delay_Before_Hide)         ; If the mouse was over the GUI within the last 3 seconds, don't hide it
      return

      WinGetPos,  GUIX, GUIY,,, % %Gui_Num_To_Hide%_Gui_Title ; Get the position of the GUI
      Loop
      {
         ; MsgBox % "If (" %Gui_Num_To_Hide%_GUIY+%Gui_Num_To_Hide%_GUIH " > " %Gui_Num_To_Hide%_Number_Of_Offset_Pixels ")"
         If (GUIY + %Gui_Num_To_Hide%_GUIH > %Gui_Num_To_Hide%_Number_Of_Offset_Pixels)     ; If the GUI is not hidden hide it then break
         {
            ;~ ;MsgBox % "WinMove,"  %Gui_Num_To_Hide%_Gui_Title ",, " GUIX ", " GUIY-(A_Index)
            WinMove, % %Gui_Num_To_Hide%_Gui_Title,, %GUIX%, % GUIY-(A_Index)
            WinGetPos,  GUIX, GUIY,,, % %Gui_Num_To_Hide%_Gui_Title
            ;MsgBox % "WinGetPos,  " GUIX ", " GUIY ",,, "  %Gui_Num_To_Hide%_Gui_Title
         }
         else
            break
      }

   If ((GUIY + %Gui_Num_To_Hide%_GUIH) < (%Gui_Num_To_Hide%_Number_Of_Offset_Pixels-1)) ; Failsafe if the GUI moves too far
   {
      WinMove, % %Gui_Num_To_Hide%_Gui_Title,, %GUIX%, % (-%Gui_Num_To_Hide%_GUIH+%Gui_Num_To_Hide%_Number_Of_Offset_Pixels)
   }
   SetTimer, HideGUIU, OFF
   return

      HideGUID:
   ;~ ;MsgBox % "If (" A_TickCount - %Gui_Num_To_Hide%_TimeLapse " < " %Gui_Num_To_Hide%_Delay_Before_Hide ") "
      If (%Gui_Num_To_Hide%_Enabled_Disabled_Flag != 1)
      return
   If (A_TickCount - %Gui_Num_To_Hide%_TimeLapse < %Gui_Num_To_Hide%_Delay_Before_Hide)         ; If the mouse was over the GUI within the last 3 seconds, don't hide it
      return

      WinGetPos,  GUIX, GUIY,,, % %Gui_Num_To_Hide%_Gui_Title ; Get the position of the GUI
      Loop
      {
         ; MsgBox % "If (" %Gui_Num_To_Hide%_GUIY+%Gui_Num_To_Hide%_GUIH " > " %Gui_Num_To_Hide%_Number_Of_Offset_Pixels ")"
         If (GUIY < A_ScreenHeight-%Gui_Num_To_Hide%_Number_Of_Offset_Pixels)     ; If the GUI is not hidden hide it then break
         {
            ;~ ;MsgBox % "WinMove,"  %Gui_Num_To_Hide%_Gui_Title ",, " GUIX ", " GUIY-(A_Index)
            WinMove, % %Gui_Num_To_Hide%_Gui_Title,, %GUIX%, % GUIY+(A_Index)
            WinGetPos,  GUIX, GUIY,,, % %Gui_Num_To_Hide%_Gui_Title
            ;MsgBox % "WinGetPos,  " GUIX ", " GUIY ",,, "  %Gui_Num_To_Hide%_Gui_Title
         }
         else
            break
      }

   If (GUIY > A_ScreenHeight-(%Gui_Num_To_Hide%_Number_Of_Offset_Pixels-1)) ; Failsafe if the GUI moves too far
   {
      WinMove, % %Gui_Num_To_Hide%_Gui_Title,, %GUIX%, % (A_ScreenHeight - %Gui_Num_To_Hide%_Number_Of_Offset_Pixels)
   }
   SetTimer, HideGUID, OFF
   return

   HideGUIR:
      If (%Gui_Num_To_Hide%_Enabled_Disabled_Flag != 1)
      return
   ;~ ;MsgBox % "If (" A_TickCount - %Gui_Num_To_Hide%_TimeLapse " < " %Gui_Num_To_Hide%_Delay_Before_Hide ") "
   If (A_TickCount - %Gui_Num_To_Hide%_TimeLapse < %Gui_Num_To_Hide%_Delay_Before_Hide)         ; If the mouse was over the GUI within the last 3 seconds, don't hide it
      return

      WinGetPos,  GUIX, GUIY,,, % %Gui_Num_To_Hide%_Gui_Title ; Get the position of the GUI
      Loop
      {
         ; MsgBox % "If (" %Gui_Num_To_Hide%_GUIY+%Gui_Num_To_Hide%_GUIH " > " %Gui_Num_To_Hide%_Number_Of_Offset_Pixels ")"
         If (GUIX < A_ScreenWidth-%Gui_Num_To_Hide%_Number_Of_Offset_Pixels)     ; If the GUI is not hidden hide it then break
         {
            ;~ ;MsgBox % "WinMove,"  %Gui_Num_To_Hide%_Gui_Title ",, " GUIX ", " GUIY-(A_Index)
            WinMove, % %Gui_Num_To_Hide%_Gui_Title,, % GUIX+A_Index, %GUIY%
            WinGetPos,  GUIX, GUIY,,, % %Gui_Num_To_Hide%_Gui_Title
            ;MsgBox % "WinGetPos,  " GUIX ", " GUIY ",,, "  %Gui_Num_To_Hide%_Gui_Title
         }
         else
            break
      }

   If (GUIX > A_ScreenWidth-%Gui_Num_To_Hide%_Number_Of_Offset_Pixels) ; Failsafe if the GUI moves too far
   {
      WinMove, % %Gui_Num_To_Hide%_Gui_Title,, % A_ScreenWidth-%Gui_Num_To_Hide%_Number_Of_Offset_Pixels, %GUIY%
   }
   SetTimer, HideGUIR, OFF
   return

      HideGUIL:
   ;~ ;MsgBox % "If (" A_TickCount - %Gui_Num_To_Hide%_TimeLapse " < " %Gui_Num_To_Hide%_Delay_Before_Hide ") "
      If (%Gui_Num_To_Hide%_Enabled_Disabled_Flag != 1)
      return
   If (A_TickCount - %Gui_Num_To_Hide%_TimeLapse < %Gui_Num_To_Hide%_Delay_Before_Hide)         ; If the mouse was over the GUI within the last 3 seconds, don't hide it
      return

      WinGetPos,  GUIX, GUIY,,, % %Gui_Num_To_Hide%_Gui_Title ; Get the position of the GUI
      Loop
      {
         ; MsgBox % "If (" %Gui_Num_To_Hide%_GUIY+%Gui_Num_To_Hide%_GUIH " > " %Gui_Num_To_Hide%_Number_Of_Offset_Pixels ")"
         If (GUIX+%Gui_Num_To_Hide%_GUIW > %Gui_Num_To_Hide%_Number_Of_Offset_Pixels)     ; If the GUI is not hidden hide it then break
         {
            ;~ ;MsgBox % "WinMove,"  %Gui_Num_To_Hide%_Gui_Title ",, " GUIX ", " GUIY-(A_Index)
            WinMove, % %Gui_Num_To_Hide%_Gui_Title,, % GUIX-A_Index, %GUIY%
            WinGetPos,  GUIX, GUIY,,, % %Gui_Num_To_Hide%_Gui_Title
            ;MsgBox % "WinGetPos,  " GUIX ", " GUIY ",,, "  %Gui_Num_To_Hide%_Gui_Title
         }
         else
            break
      }

   If (GUIX+%Gui_Num_To_Hide%_GUIW < %Gui_Num_To_Hide%_Number_Of_Offset_Pixels) ; Failsafe if the GUI moves too far
   {
      WinMove, % %Gui_Num_To_Hide%_Gui_Title,, % -%Gui_Num_To_Hide%_GUIW+%Gui_Num_To_Hide%_Number_Of_Offset_Pixels, %GUIY%
   }
   SetTimer, HideGUIL, OFF
   return

}
{ ; sub
WM_MOUSEMOVE(wParam,lParam) { ; Action to take if the mouse moves over the GUI

   If (%A_Gui%_Enabled_Disabled_Flag = 1)
   {
      RestartGUIActivate:
      LabelDir := %A_Gui%_Hide_Direction
      SetTimer, HideGUI%LabelDir%, Off ; Turn off the label while the mouse is over the GUI
      WinGetPos,  GUIX, GUIY,,, % %A_Gui%_Gui_Title ; Get the position of the GUI if your cursor is over it.

      ; DO ACTION BASED ON WHAT DIRECTION THE GUI IS SET TO
      If (%A_Gui%_Hide_Direction == "U")
      {
         Loop
         {
            If (GUIY+%A_Gui%_GUIH < %A_Gui%_GUIH) ; If the GUI is hidden, show it then break
            {
               WinMove, % %A_Gui%_Gui_Title,, %GUIX%, % GUIY+(A_Index)
               WinGetPos,  GUIX, GUIY,,, % %A_Gui%_Gui_Title
            }
            else
               break
         }
      }
      Else If (%A_Gui%_Hide_Direction == "D")
      {
         Loop
         {
            If (GUIY > A_ScreenHeight-%A_Gui%_GUIH) ; If the GUI is hidden, show it then break
            {
               WinMove, % %A_Gui%_Gui_Title,, %GUIX%, % GUIY-(A_Index)
               WinGetPos,  GUIX, GUIY,,, % %A_Gui%_Gui_Title
            }
            else
               break
         }
      }
      Else If (%A_Gui%_Hide_Direction == "R")
      {
         Loop
         {
            If (GUIX+%A_Gui%_GUIW > A_ScreenWidth+%A_Gui%_Number_Of_Offset_Pixels) ; If the GUI is hidden, show it then break
            {
               WinMove, % %A_Gui%_Gui_Title,, GUIX-A_Index, %GUIY%
               WinGetPos,  GUIX, GUIY,,, % %A_Gui%_Gui_Title
            }
            else
               break
         }
      }
      Else If (%A_Gui%_Hide_Direction == "L")
      {
         Loop
         {
            If (GUIX+%A_Gui%_Number_Of_Offset_Pixels < 0) ; If the GUI is hidden, show it then break
            {
               WinMove, % %A_Gui%_Gui_Title,, GUIX+A_Index, %GUIY%
               WinGetPos,  GUIX, GUIY,,, % %A_Gui%_Gui_Title
            }
            else
               break
         }
      }

      CoordMode, Mouse, Screen         ;get the mouse position in SCREEN MODE because your GUI is relative to the screen
      MouseGetPos, MX, MY
      CoordMode, Mouse, Relative
      If (%A_Gui%_Hide_Direction == "U" && MX >= %A_Gui%_GUIX && MX <= %A_Gui%_GUIX+%A_Gui%_GUIW && MY >= 0 && MY <= %A_Gui%_GUIH) ; Check if your mouse is still over the GUI (U)
      {
       goto, RestartGUIActivate  ;Restart if it is
      }
      Else If (%A_Gui%_Hide_Direction == "D" && MX >= %A_Gui%_GUIX && MX <= %A_Gui%_GUIX+%A_Gui%_GUIW && MY >= A_ScreenHeight-%A_Gui%_GUIH && MY-%A_Gui%_GUIH <= A_ScreenHeight) ; Check if your mouse is still over the GUI (D)
      {
       goto, RestartGUIActivate  ;Restart if it is
      }
      Else If (%A_Gui%_Hide_Direction == "R" && MX >= A_ScreenWidth-%A_Gui%_GUIW && MX <= A_ScreenWidth && MY >= %A_Gui%_GUIY && MY <= %A_Gui%_GUIY+%A_Gui%_GUIH) ; Check if your mouse is still over the GUI (R)
      {
       goto, RestartGUIActivate  ;Restart if it is
      }
      Else If (%A_Gui%_Hide_Direction == "L" && MX >= 0 && MX <= %A_Gui%_GUIW && MY >= %A_Gui%_GUIY && MY <= %A_Gui%_GUIY+%A_Gui%_GUIH) ; Check if your mouse is still over the GUI (L)
      {
       goto, RestartGUIActivate  ;Restart if it is
      }

      else ; If your mouse is not over the GUI, prepare to hide it.
      {
      %A_Gui%_TimeLapse := A_TickCount
      SetTimer, HideGUI%LabelDir%, 1000
      }
   }
}

} 
;23
SetButtonF(p*) {																											;-- Set a button control to call a function instead of a label subroutine

	/*			FUNCTION: SetButtonF
		_________________________________________________________________________________________

		FUNCTION: SetButtonF
		DESCRIPTION: Set a button control to call a function instead of a label subroutine
		PARAMETER(s):
			hButton := Button control's handle
			FunctionName := Name of fucntion to associate with button
		USAGE:
			Setting a button:
				SetButtonF(hButton, FunctionName)

			Retrieving the function name associated with a particular button:
				Func := SetButtonF(hButton) ; note: 2nd parameter omitted

			Disabling a function for a particular button(similar to "GuiControl , -G" option):
				SetButtonF(hButton, "") ; note: 2nd parameter not omitted but explicitly blank

			Disabling all functions for all buttons:
				SetButtonF() ; No parameters
		NOTES:
			The function/handler must have atleast two parameters, this function passes the
			GUI's hwndas the 1st parameter and the button's hwnd as the 2nd.
			Forum: http://www.autohotkey.com/board/topic/88553-setbuttonf-set-button-to-call-function/
		_________________________________________________________________________________________

	*/

	static WM_COMMAND := 0x0111 , BN_CLICKED := 0x0000
	static IsRegCB := false , oldNotify := {CBA: "", FN: ""} , B := [] , tmr := []
	if (A_EventInfo == tmr.CBA) { ; Call from timer
		DllCall("KillTimer", "UInt", 0, "UInt", tmr.tmr) ; Kill timer, one time only
		, tmr.func.(tmr.params*) ; Call function
		return DllCall("GlobalFree", "Ptr", tmr.CBA, "Ptr") , tmr := []
	}
	if (p.3 <> WM_COMMAND) { ; Not a Windows message ; call from user
		if !ObjHasKey(p, 1) { ; No passed parameter ; Clear all button-function association
			if IsRegCB {
				if B.MinIndex()
					B.Remove(B.MinIndex(), B.MaxIndex())
				, IsRegCB := false
				, OnMessage(WM_COMMAND, oldNotify.FN) ; reset to previous handler(if any)
				, oldNotify.CBA := "" , oldNotify.FN := "" ; reset
				return true
			}
		}
		if !WinExist("ahk_id " p.1) ; or !DllCall("IsWindow", "Ptr", p.1) ; Check if handle is valid
			return false ; Not a valid handle, control does not exist
		WinGetClass, c, % "ahk_id " p.1 ; Check if it's a button control
		if (c == "Button") {
			if p.2 { ; function name/reference has been specified, store/associate it
				if IsFunc(p.2) ; Function name is specified
					B[p.1, "F"] := Func(p.2)
				if (IsObject(p.2) && IsFunc(p.2.Name)) ; Function reference/object is specified
					B[p.1, "F"] := p.2
				if !IsRegCB { ; No button(s) has been set yet , callback has not been registered
					fn := OnMessage(WM_COMMAND, A_ThisFunc)
					if (fn <> A_ThisFunc) ; if there's another handler
						oldNotify.CBA := RegisterCallback((oldNotify.FN := fn)) ; store it
					IsRegCB := true
				}
			} else { ; if 2nd parameter(Function name) is explicitly blank or omitted
				if ObjHasKey(B, p.1) { ; check if button is in the list
					if !ObjHasKey(p, 2) ; Omitted
						return B[p.1].F.Name ; return Funtion Name associated with button
					else { ; Explicitly blank
						B.Remove(p.1, "") ; Disassociate button with function, remove from internal array
						if !B.MinIndex() ; if last button in array
							SetButtonF() ; Reset everything
					}
				}
			}
			return true ; successful
		} else
			return false ; not a button control
	} else { ; WM_COMMAND
		if ObjHasKey(B, p.2) { ; Check if control is in internal array
			lo := p.1 & 0xFFFF ; Control identifier
			hi := p.1 >> 16 ; notification code
			if (hi == BN_CLICKED) { ; Normal, left button
				tmr := {func: B[p.2].F, params: [p.4, p.2]} ; store button's associated function ref and params
				, tmr.CBA := RegisterCallback(A_ThisFunc, "F", 4) ; create callback address
				; Create timer, this allows the function to finish processing the message immediately
				, tmr.tmr := DllCall("SetTimer", "UInt", 0, "UInt", 0, "Uint", 120, "UInt", tmr.CBA)
			}
		} else { ; Other control(s)
			if (oldNotify.CBA <> "") ; if there is a previous handler for WM_COMMAND, call it
				DllCall(oldNotify.CBA, "UInt", p.1, "UInt", p.2, "UInt", p.3, "UInt", p.4)
		}
	}
}
;24
AddToolTip(hControl,p_Text)  {                                                                              		;-- Add/Update tooltips to GUI controls.


    /*      Description

        Function: AddToolTip

        Description:

          Add/Update tooltips to GUI controls.

        Parameters:

          hControl - Handle to a GUI control.

          p_Text - Tooltip text.

        Returns:

          Handle to the tooltip control.

        Remarks:

        * This function accomplishes this task by creating a single Tooltip control
          and then creates, updates, or delete tools which are/were attached to the
          individual GUI controls.

        * This function returns the handle to the Tooltip control so that, if desired,
          additional actions can be performed on the Tooltip control outside of this
          function.  Once created, this function reuses the same Tooltip control.
          If the tooltip control is destroyed outside of this function, subsequent
          calls to this function will fail.  If desired, the tooltip control can be
          destroyed just before the script ends.

        Credit and History:

        * Original author: Superfraggle
          Post: <http://www.autohotkey.com/board/topic/27670-add-tooltips-to-controls/>

        * Updated to support Unicode: art
          Post: <http://www.autohotkey.com/board/topic/27670-add-tooltips-to-controls/page-2#entry431059>

        * Additional: jballi
          Bug fixes.  Added support for x64.  Removed Modify parameter.  Added
          additional functionality, documentation, and constants.

*/

    Static hTT

          ;-- Misc. constants
          ,CW_USEDEFAULT:=0x80000000
          ,HWND_DESKTOP :=0
          ,WS_EX_TOPMOST:=0x8

          ;-- Tooltip styles
          ,TTS_ALWAYSTIP:=0x1
                ;-- Indicates that the ToolTip control appears when the cursor
                ;   is on a tool, even if the ToolTip control's owner window is
                ;   inactive. Without this style, the ToolTip appears only when
                ;   the tool's owner window is active.

          ,TTS_NOPREFIX:=0x2
                ;-- Prevents the system from stripping ampersand characters from
                ;   a string or terminating a string at a tab character. Without
                ;   this style, the system automatically strips ampersand
                ;   characters and terminates a string at the first tab
                ;   character. This allows an application to use the same string
                ;   as both a menu item and as text in a ToolTip control.

          ;-- TOOLINFO uFlags
          ,TTF_IDISHWND:=0x1
                ;-- Indicates that the uId member is the window handle to the
                ;   tool.  If this flag is not set, uId is the identifier of the
                ;   tool.

          ,TTF_SUBCLASS:=0x10
                ;-- Indicates that the ToolTip control should subclass the
                ;   window for the tool in order to intercept messages, such
                ;   as WM_MOUSEMOVE. If you do not set this flag, you must use
                ;   the TTM_RELAYEVENT message to forward messages to the
                ;   ToolTip control.  For a list of messages that a ToolTip
                ;   control processes, see TTM_RELAYEVENT.

          ;-- Messages
          ,TTM_ADDTOOLA      :=0x404                    ;-- WM_USER + 4
          ,TTM_ADDTOOLW      :=0x432                    ;-- WM_USER + 50
          ,TTM_DELTOOLA      :=0x405                    ;-- WM_USER + 5
          ,TTM_DELTOOLW      :=0x433                    ;-- WM_USER + 51
          ,TTM_GETTOOLINFOA  :=0x408                    ;-- WM_USER + 8
          ,TTM_GETTOOLINFOW  :=0x435                    ;-- WM_USER + 53
          ,TTM_SETMAXTIPWIDTH:=0x418                    ;-- WM_USER + 24
          ,TTM_UPDATETIPTEXTA:=0x40C                    ;-- WM_USER + 12
          ,TTM_UPDATETIPTEXTW:=0x439                    ;-- WM_USER + 57

    ;-- Workarounds for AutoHotkey Basic and x64
    PtrType:=(A_PtrSize=8) ? "Ptr":"UInt"
    PtrSize:=A_PtrSize ? A_PtrSize:4

    ;-- Save/Set DetectHiddenWindows
    l_DetectHiddenWindows:=A_DetectHiddenWindows
    DetectHiddenWindows On

    ;-- Tooltip control exists?
    if not hTT
        {
        ;-- Create Tooltip window
        hTT:=DllCall("CreateWindowEx"
            ,"UInt",WS_EX_TOPMOST                       ;-- dwExStyle
            ,"Str","TOOLTIPS_CLASS32"                   ;-- lpClassName
            ,"UInt",0                                   ;-- lpWindowName
            ,"UInt",TTS_ALWAYSTIP|TTS_NOPREFIX          ;-- dwStyle
            ,"UInt",CW_USEDEFAULT                       ;-- x
            ,"UInt",CW_USEDEFAULT                       ;-- y
            ,"UInt",CW_USEDEFAULT                       ;-- nWidth
            ,"UInt",CW_USEDEFAULT                       ;-- nHeight
            ,"UInt",HWND_DESKTOP                        ;-- hWndParent
            ,"UInt",0                                   ;-- hMenu
            ,"UInt",0                                   ;-- hInstance
            ,"UInt",0                                   ;-- lpParam
            ,PtrType)                                   ;-- Return type

        ;-- Disable visual style
        DllCall("uxtheme\SetWindowTheme",PtrType,hTT,PtrType,0,"UIntP",0)

        ;-- Set the maximum width for the tooltip window
        ;   Note: This message makes multi-line tooltips possible
        SendMessage TTM_SETMAXTIPWIDTH,0,A_ScreenWidth,,ahk_id %hTT%
        }

    ;-- Create/Populate TOOLINFO structure
    uFlags:=TTF_IDISHWND|TTF_SUBCLASS
    cbSize:=VarSetCapacity(TOOLINFO,8+(PtrSize*2)+16+(PtrSize*3),0)
    NumPut(cbSize,      TOOLINFO,0,"UInt")              ;-- cbSize
    NumPut(uFlags,      TOOLINFO,4,"UInt")              ;-- uFlags
    NumPut(HWND_DESKTOP,TOOLINFO,8,PtrType)             ;-- hwnd
    NumPut(hControl,    TOOLINFO,8+PtrSize,PtrType)     ;-- uId

    VarSetCapacity(l_Text,4096,0)
    NumPut(&l_Text,     TOOLINFO,8+(PtrSize*2)+16+PtrSize,PtrType)
        ;-- lpszText

    ;-- Check to see if tool has already been registered for the control
    SendMessage
        ,A_IsUnicode ? TTM_GETTOOLINFOW:TTM_GETTOOLINFOA
        ,0
        ,&TOOLINFO
        ,,ahk_id %hTT%

    RegisteredTool:=ErrorLevel

    ;-- Update TOOLTIP structure
    NumPut(&p_Text,TOOLINFO,8+(PtrSize*2)+16+PtrSize,PtrType)
        ;-- lpszText

    ;-- Add, Update, or Delete tool
    if RegisteredTool
        {
        if StrLen(p_Text)
            SendMessage
                ,A_IsUnicode ? TTM_UPDATETIPTEXTW:TTM_UPDATETIPTEXTA
                ,0
                ,&TOOLINFO
                ,,ahk_id %hTT%
         else
            SendMessage
                ,A_IsUnicode ? TTM_DELTOOLW:TTM_DELTOOLA
                ,0
                ,&TOOLINFO
                ,,ahk_id %hTT%
        }
    else
        if StrLen(p_Text)
            SendMessage
                ,A_IsUnicode ? TTM_ADDTOOLW:TTM_ADDTOOLA
                ,0
                ,&TOOLINFO
                ,,ahk_id %hTT%

    ;-- Restore DetectHiddenWindows
    DetectHiddenWindows %l_DetectHiddenWindows%

    ;-- Return the handle to the tooltip control
    Return hTT
}
;24
HelpToolTips( _Delay = 300, _Duration = 0 ) {                                                       		;--  To show defined GUI control help tooltips on hover.
    _fn := Func( "WM_MOUSEMOVE" ).Bind( _Delay, _Duration )
    OnMessage( 0x200, _fn )
}
{ ;sub
WM_MOUSEMOVE( _Delay = 300, _Duration = 0 ) {
    static CurrControl, PrevControl, _TT
    CurrControl := A_GuiControl
    if ( CurrControl != PrevControl ) {
        SetTimer, DisplayToolTip, % _Delay
        if ( _Duration )
            SetTimer, RemoveToolTip, % _Delay + _Duration
        PrevControl := CurrControl
    }
    return

    DisplayToolTip:
        SetTimer, DisplayToolTip, Off
        try
            ToolTip % %CurrControl%_TT
        catch
            ToolTip
    return

    RemoveToolTip:
        SetTimer, RemoveToolTip, Off
        ToolTip
    return
}
} 
;25
DisableFadeEffect() {																									;-- disabling fade effect on gui animations

	/*				DESCRIPTION
	
		You can put that code top of your script and you dont need to call that again...
		It removes bad fade effect on gui when we use Imaged Button Class/imaged buttons/checks/radios/progress bars....

		Source : https://autohotkey.com/boards/viewtopic ... 23#p129823
	
	*/

	; SPI_GETCLIENTAREAANIMATION = 0x1042
	DllCall("SystemParametersInfo", "UInt", 0x1042, "UInt", 0, "UInt*", isEnabled, "UInt", 0)

	if isEnabled {
		; SPI_SETCLIENTAREAANIMATION = 0x1043
		DllCall("SystemParametersInfo", "UInt", 0x1043, "UInt", 0, "UInt", 0, "UInt", 0)
		Progress, 10:P100 Hide
		Progress, 10:Off
		DllCall("SystemParametersInfo", "UInt", 0x1043, "UInt", 0, "UInt", 1, "UInt", 0)
	}

}
;26
SetWindowTransistionDisable(hwnd,onOff) {																;-- disabling fade effect only the window of choice 
	
	/*				DESCRIPTION
	
		DWMWA_TRANSITIONS_FORCEDISABLED=3
		Use with DwmSetWindowAttribute. Enables or forcibly disables DWM transitions.
		The pvAttribute parameter points to a value of TRUE to disable transitions or FALSE to enable transitions.
		
		This only affects the windows of choise, while
			SystemParametersInfo wrote:
			Retrieves or sets the value of one of the system-wide parameters. 
		
	*/
	
	/*				EXAMPLE
	
			#SingleInstance, force
			Gui, new, +hwndguiId
			Dwm_SetWindowAttributeTransistionDisable(guiId,1)
			Gui, show, w300 h200
			Sleep,2000
			Gui,destroy
			Exitapp
	
	*/
	
	dwAttribute:=3
	cbAttribute:=4
	VarSetCapacity(pvAttribute,4,0)
	NumPut(onOff,pvAttribute,0,"Int")
	hr:=DllCall("Dwmapi.dll\DwmSetWindowAttribute", "Uint", hwnd, "Uint", dwAttribute, "Uint", &pvAttribute, "Uint", cbAttribute)
	return hr
}
;27
DisableMinimizeAnim(disable) {                                                                              	;-- disables or restores original minimize anim setting
	
	static original,lastcall	
	if (disable && !lastcall) ;Backup original value if disabled is called the first time after a restore call
	{
		lastcall := 1
		RegRead, original, HKCU, Control Panel\Desktop\WindowMetrics , MinAnimate
	}
	else if (!disable) ;this is a restore call, on next disable backup may be created again
		lastcall := 0
	;Disable Minimize/Restore animation
	VarSetCapacity(struct, 8, 0)	
	NumPut(8, struct, 0, "UInt")
	if (disable || !original)
		NumPut(0, struct, 4, "Int")
	else
		NumPut(1, struct, 4, "UInt")
	DllCall("SystemParametersInfo", "UINT", 0x0049,"UINT", 8,"Ptr", &struct,"UINT", 0x0003) ;SPI_SETANIMATION            0x0049 SPIF_SENDWININICHANGE 0x0002
}
;28
DisableCloseButton(hWnd) {																						;-- to disable/grey out the close button
	; Skan (https://autohotkey.com/board/topic/80593-how-to-disable-grey-out-the-close-button/)
	hSysMenu:=DllCall("GetSystemMenu","Int",hWnd,"Int",FALSE)
	nCnt:=DllCall("GetMenuItemCount","Int",hSysMenu)
	DllCall("RemoveMenu","Int",hSysMenu,"UInt",nCnt-1,"Uint","0x400")
	DllCall("RemoveMenu","Int",hSysMenu,"UInt",nCnt-2,"Uint","0x400")
	DllCall("DrawMenuBar","Int",hWnd)
}
;29
AutoCloseBlockingWindows(WinID, autoclose:=2) {													;-- close all open popup (childwindows), without knowing their names, of a parent window

	;by Ixiko 2018 - https://autohotkey.com/boards/viewtopic.php?f=6&t=52418

/* 								Beschreibung                                                                           	                                                                                                 				
																																											
		Parameterliste                                                                                                                        			
		1. autoclose = 0                                                                                                                                                                                      		
			ausschließlich Rückgabe eines Objektes mit zwei Key:Value Paaren, a) true/false für ist blockiert und b) Name des blockierenden Fensters	
		2. autoclose = 1 																																				
			Rückgabe des oben genannten Objektes und sendet eine Nachfrage an den User ob die blockierenden Fenster geschlossen werden dürfen				  	
        3. autoclose = 2                                                                                                                                                                                      		
			alle blockierenden Fenster werden ohne Rückfrage geschlossen, es werden keine Werte zurück gegeben											
																																											
 		von der Funktion AutoCloseBlockingWindows() bekommt sie den Rückgabewert (errorStr), den sie an die aufrufende Prozeß weiter reicht.  			
		Dieser String gibt den Erfolg oder Mißerfolg zurück , damit der Prozeß Fehler erkennen kann um sich wenn notwendig zu beenden oder       		
        andere Maßnahmen einzuleiten die zum Erfolg führen könnten                                                                                                                   		
*/
																																											
/*                              	DESCRIPTION
																																												
			The function offers 3 possibilities
			1. autoclose = 0
				only returning an object with two Key: Value pairs, "isblocked":  true / false for is blocked and "blockWinT": name of the blocking window, 
				"errorStr": is allways empty in this case
			2. autoclose = 1
				Returns the above object and sends an inquiry to the user if the blocking windows may be closed
			3. autoclose = 2
				all blocking windows are closed without further inquiry, no values ​​are returned
			
			It gets it return value (errorStr) from function AutoCloseBlockingWindows() , which it passes on to the calling process.
			This string returns the success or failure, so that the process can detect errors, to terminate itself, if necessary, or
			        to take other actions that could lead to success
			
*/
	
	errorStr:=""
	 ; WS_DISABLED:= 0x8000000
	WinGet, Style, Style, ahk_id %WinID%
	blocked:= (Style & 0x8000000) ? true : false
	;which window is blocking this window hwnd
	phwnd:= DLLCall("GetLastActivePopup", "uint", WinID)
	WinGetTitle, title, ahk_id %phwnd%


	if (autoclose=1) {
			MsgBox, 4, Note, Your main window is blocked`n by one or more popup windows.`n`nShould all windows be closed now?
			IfMsgBox, Yes
				gosub WinCloseLastActivePopup
	} else if (autoclose=2) {
			gosub WinCloseLastActivePopups
	}

	return {"isblocked": blocked, "blockWinT": title, "errorStr": errorStr}

WinCloseLastActivePopups:

	Loop {

				WinGet, Style, Style, ahk_id %WinID%
				blocked:= (Style & 0x8000000) ? true : false
				if !blocked 
				{
						errorStr:=""
						break
				}

				phwnd:= DLLCall("GetLastActivePopup", "uint", WinID)
					;3 different attempts to close the window from "gentle" to "powerful"
				PostMessage, 0x112, 0xF060,,, ahk_id %phwnd%  ; 0x112 = WM_SYSCOMMAND, 0xF060 = SC_CLOSE
				If ErrorLevel
					WinClose, ahk_id %pHwnd%
				If ErrorLevel
						WinKill, ahk_id %pHwnd%
				If ErrorLevel {
					WinGetTitle, title, ahk_id %pHwnd%
					throw Exception("Can not close entire window : '" . title . "' `n. The function AutoCloseBlockingWindows stops here.", -1)
					errorStr:="noClose"
					break
				}

				sleep 200

			}

return

}
;30
WinActivateEx(WinTitle, WinText="", Seconds=30, Keys="", OnlyIfExist = false) {		;-- Activate a Window, with extra Error Checking and More Features

	/*                              	DESCRIPTION
	
			Func: WinActivateEx
			Activate a Window, with extra Error Checking and More Features
			
			<paste FunctionNameEx>DetectHiddenWindows On
			   
			<paste WinProcParams>Keys := CmdSwitch(WinTitle, "-k", Keys)
			   
	*/
	

   ;   SetTitleMatchMode Regex
   ; Kill Vista Thumbnails.  These hang around a lot, and they're never what you want to activate.
  
   if (Seconds == "")
      Seconds := 30

   if (OnlyIfExist && !WinExist(WinTitle))
      return false

   WinWait %WinTitle%, %WinText%, %Seconds%
   AssertNoError(ProcList("WinActivateEx - Waiting", WinTitle, WinText, Seconds))

   WinShow %WinTitle%
   WinActivate %WinTitle%, %WinText%
   WinWaitActive %WinTitle%, %WinText%
   AssertNoError(ProcList("WinActivateEx - WaitActive", WinTitle, WinText, Seconds))

   if (Keys)
      SendInput %Keys%

   return true
}
;31
ClickOK(Window="") {																									;-- function that search for any button in a window that might be an 'Ok' button to close a window dialog
 
	/*                              	DESCRIPTION
	
			-------------------------------------------------------------------------------------------------------------
			 Func: ClickOK
			 Click on the OK, Yes, Save, whatever button that passes for OK on this form.  It's a handy function that I
			 bind to something like \c nter or \c Enter that basically clicks the \c OK button in a dialog box. I have
			 a list of buttons that are generally considered OK like buttons, and I click on the first one that can be
			 found. You can extend the list as necessary.
			
			 You can also specify a window that you want this to apply to. If you do so, then that window will be given
			 focus before the button is clicked.  If it's  not found the whole action is called off.  If you do not specify a
			 window, then the window that has focus is used. This is by far the more common case, the case where you pass
			 a window is a quick and dirty way to add support for clicking on the OK button in a script without having to
			 figure out what the OK button is.
			
			 Parameters:
			 Window -     Window to click on. If this is passed, this window will be the one that gets clicked. The
			              timeout is set to 10 seconds.
			
			 Returns:
			 \c True if the OK button was clicked on. It is not actually mean that the OK button's action was
			 successful... just that we found an OK like button, and clicked on it.
			
			 Note:
			 The initial list of OK-Like buttons includes
			 <c>OK,Save,Accept,Open,Yes,Save and Close,Connect,Send,Next,Finish,Find Next,&Save,&Yes</c>, and you can
			 edit it to add more.
			-------------------------------------------------------------------------------------------------------------
			
	*/
	

   ; Common delimited list of keys that could pass as an OK button
   Keys := "OK,Save,Accept,Open,Yes,Save and Close,Connect,Send,Next,Finish,Find Next,&Save,&Yes, Ja, &Ja"

   ; If this is for a specific window, wait up to 10 seconds for it
   if (Window) {
	
      WinWait %Window%, , 10
      if (ErrorLevel)
         Return
      WinActivate %Window%
   }

   ; Parse the list of keys in the order in which they appear, and for each key see if we can find button. If
   ; we find button, then click on it. Note that the processing for finding the button seems little
   ; convoluted. This is necessary to get to work in a lot of MDI windows.
   Loop, Parse, Keys, `,
   {
      ControlGet Handle, hWnd, , %A_LoopField%, A
      if (Handle)
      {
         ControlGet En, Enabled, , %A_LoopField%, A
         if (En)
         {
            ControlClick %A_LoopField%, A
            Return true
         }
      }
   }

   Return false
}
;32
ControlSelectTab(Index, Ctl, Win) {																				;-- SendMessage wrapper to select the current tab on a MS Tab Control.
	/*                              	DESCRIPTION
				 
			 Func: ControlSelectTab
			 Select the current tab on a MS Tab Control.
			
			 Parameters:
			 Index  - Tab index to select.  0 is the first tab.
			 Ctl    - Name of the control as detected via Window Spy
			 Win    - Window to send it to
			
			 Returns:
			 Appropriate tab selected.
						
	*/
	
   SendMessage, 0x1330, %Index%,, %Ctl%, %Win%
}
;33
SetParentByClass(Window_Class, Gui_Number) { 														;-- set parent window by using its window class
	;Code by sidola
	;https://autohotkey.com/boards/viewtopic.php?t=26809
	Parent_Handle := DllCall( "FindWindowEx", "uint",0, "uint",0, "str", Window_Class, "uint",0) 
	Gui, %Gui_Number%: +LastFound 
	Return DllCall( "SetParent", "uint", WinExist(), "uint", Parent_Handle )
}
;34
MoveTogether(wParam, lParam, _, hWnd) { 																;-- move 2 windows together - using DllCall to DeferWindowPos

	/*                              	DESCRIPTION
				
				Link: https://autohotkey.com/boards/viewtopic.php?t=43192
				AutoExec in Script or inside function
				;---------------------------------------------
			    CoordMode, Mouse, Screen    ; for MouseGetPos
			    SetBatchLines, -1           ; for onMessage
			    SetWinDelay, -1             ; for WinActivate
			    ;---------------------------------------------
			
				 call MoveTogether(Handles) with an array of handles
				 to set up a bundle of AHK Gui's that move together
				
				 https://autohotkey.com/boards/viewtopic.php?p=199402#p199402
				 version 2018.02.08
	*/
	
	/*                              	EXAMPLE(s)
	
			NoEnv
			SingleInstance Force
			Include, MoveTogether.ahk
			
			    Handles := []
			
			    Loop, 3 
			        Gui, %A_Index%: New, hwndhWin%A_Index%, Window %A_Index%
			        Gui, Show, % "x" A_Index * 280 " y100 w250 h200"
			        Handles.Push(hWin%A_Index%)
			    
			
			Return
			
			GuiClose:
			ExitApp
			
	*/
	
    static init := OnMessage(0xA1, "MoveTogether") ; WM_NCLBUTTONDOWN
    static Handles

	If IsObject(wParam)             ; detect a set up call
		Return, Handles := wParam   ; store the array of handles

    If (wParam != 2) ; HTCAPTION
        Return

    ; changing AHK settings here will have no side effects
    CoordMode, Mouse, Screen    ; for MouseGetPos
    SetBatchLines, -1           ; for onMessage
    SetWinDelay, -1             ; for WinActivate, WinMove

    M_old_X := lParam & 0xFFFF, M_old_Y := lParam >> 16 & 0xFFFF
    WinActivate, ahk_id %hWnd%

    Win := {}
    For each, Handle in Handles {
        WinGetPos, X, Y, W, H, ahk_id %Handle%
        Win[Handle] := {X: X, Y: Y, W: W, H: H}
    }

    While GetKeyState("LButton", "P") {
        MouseGetPos, M_new_X, M_new_Y
        dX := M_new_X - M_old_X, M_old_X := M_new_X
      , dY := M_new_Y - M_old_Y, M_old_Y := M_new_Y

        If GetKeyState("Shift", "P")
            WinMove, ahk_id %hWnd%,, Win[hWnd].X += dX, Win[hWnd].Y += dY

        Else { ; DeferWindowPos cycle
            hDWP := DllCall("BeginDeferWindowPos", "Int", Handles.Length(), "Ptr")
            For each, Handle in Handles
                hDWP := DllCall("DeferWindowPos", "Ptr", hDWP
                    , "Ptr", Handle, "Ptr", 0
                    , "Int", Win[Handle].X += dX
                    , "Int", Win[Handle].Y += dY
                    , "Int", Win[Handle].W
                    , "Int", Win[Handle].H
                    , "UInt", 0x214, "Ptr")
            DllCall("EndDeferWindowPos", "Ptr", hDWP)
        }
    }
}
;35
WinWaitCreated( WinTitle:="", WinText:="", Seconds:=0, 											;-- Wait for a window to be created, returns 0 on timeout and ahk_id otherwise
ExcludeTitle:="", ExcludeText:="" ) {
	
	/*                              	DESCRIPTION
			
			Wait for a window to be created, returns 0 on timeout and ahk_id otherwise
			Parameter are the same as WinWait, see http://ahkscript.org/docs/commands/WinWait.htm
			Link: 					http://ahkscript.org/boards/viewtopic.php?f=6&t=1274&p=8517#p8517
			Dependencies: 	none
	
	*/
	
	
    ; HotKeyIt - http://ahkscript.org/boards/viewtopic.php?t=1274
    static Found := 0, _WinTitle, _WinText, _ExcludeTitle, _ExcludeText 
         , init := DllCall( "RegisterShellHookWindow", "UInt",A_ScriptHwnd )
         , MsgNum := DllCall( "RegisterWindowMessage", "Str","SHELLHOOK" )
         , cleanup:={base:{__Delete:"WinWaitCreated"}}
  If IsObject(WinTitle)   ; cleanup
    return DllCall("DeregisterShellHookWindow","PTR",A_ScriptHwnd)
  else if (Seconds <> MsgNum){ ; User called the function
    Start := A_TickCount, _WinTitle := WinTitle, _WinText := WinText
    ,_ExcludeTitle := ExcludeTitle, _ExcludeText := ExcludeText
    ,OnMessage( MsgNum, A_ThisFunc ),  Found := 0
    While ( !Found && ( !Seconds || Seconds * 1000 < A_TickCount - Start ) ) 
      Sleep 16                                                         
    Return Found,OnMessage( MsgNum, "" )
  }
  If ( WinTitle = 1   ; window created, check if it is our window
    && ExcludeTitle = A_ScriptHwnd
    && WinExist( _WinTitle " ahk_id " WinText,_WinText,_ExcludeTitle,_ExcludeText))
    WinWait % "ahk_id " Found := WinText ; wait for window to be shown
}
;36
closeContextMenu() {																									;-- a smart way to close a context menu
	
	;https://autohotkey.com/board/topic/23859-how-to-detect-and-close-a-context-menu/
	GuiThreadInfoSize = 48
	VarSetCapacity(GuiThreadInfo, 48)
	NumPut(GuiThreadInfoSize, GuiThreadInfo, 0)
	if not DllCall("GetGUIThreadInfo", uint, 0, str, GuiThreadInfo)
	{
		MsgBox GetGUIThreadInfo() indicated a failure.
		return
	}
	; GuiThreadInfo contains a DWORD flags at byte 4
	; Bit 4 of this flag is set if the thread is in menu mode. GUI_INMENUMODE = 0x4
	if (NumGet(GuiThreadInfo, 4) & 0x4)
		send {escape}
}
;37
SetWindowTheme(handle) {																						;-- set Windows UI Theme by window handle
	
	; https://github.com/jNizM/ahk_pi-hole/blob/master/src/pi-hole.ahk
	 ; https://msdn.microsoft.com/en-us/library/bb759827(v=vs.85).aspx
	global WINVER

	if (WINVER >= 0x0600) {
		VarSetCapacity(ClassName, 1024, 0)
		if (DllCall("user32\GetClassName", "ptr", handle, "str", ClassName, "int", 512, "int"))
			if (ClassName = "SysListView32") || (ClassName = "SysTreeView32")
				if !(DllCall("uxtheme\SetWindowTheme", "ptr", handle, "wstr", "Explorer", "ptr", 0))
					return true
	}
	return false
}
;38
HideFocusBorder(wParam, lParam := "", Msg := "", handle := "") {								;-- hides the focus border for the given GUI control or GUI and all of its children
	
	/*                              	DESCRIPTION
	
			 by 'just me'
			 Hides the focus border for the given GUI control or GUI and all of its children.
			 Call the function passing only the HWND of the control / GUI in wParam as only parameter.
			 WM_UPDATEUISTATE  -> msdn.microsoft.com/en-us/library/ms646361(v=vs.85).aspx
			 The Old New Thing -> blogs.msdn.com/b/oldnewthing/archive/2013/05/16/10419105.aspx
			
	*/
	/*                              	EXAMPLE(s)
	
			NoEnv
			SetBatchLines, -1
			Menu, File, Add, &Quit, GuiCLose
			Menu, MenuBar, Add, &File, :File
			Gui, HwndHGUI
			Gui, Menu, MenuBar
			Gui, Add, Text, , Slider:
			Gui, Add, Slider, xp%0 w200 NoTicks ToolTip hwndHSL
			Gui, Show, , Test
			HideFocusBorder(HGUI)
			Return
			GuiClose:
			ExitApp
			
	*/
	
	static Affected         := []
	static WM_UPDATEUISTATE := 0x0128
	static SET_HIDEFOCUS    := 0x00010001 ; UIS_SET << 16 | UISF_HIDEFOCUS
	static init             := OnMessage(WM_UPDATEUISTATE, Func("HideFocusBorder"))

	if (Msg = WM_UPDATEUISTATE) {
		if (wParam = SET_HIDEFOCUS)
			Affected[handle] := true
		else if Affected[handle]
			DllCall("user32\PostMessage", "ptr", handle, "uint", WM_UPDATEUISTATE, "ptr", SET_HIDEFOCUS, "ptr", 0)
	}
	else if (DllCall("IsWindow", "ptr", wParam, "uint"))
		DllCall("user32\PostMessage", "ptr", wParam, "uint", WM_UPDATEUISTATE, "ptr", SET_HIDEFOCUS, "ptr", 0)
}
;39
unmovable() {																												;-- makes Gui unmovable
	; make Gui unmovable -code by SKAN-
Gui 2:+LastFound
Gui1 := WinExist()
hSysMenu:=DllCall("GetSystemMenu","Int",Gui1,"Int",FALSE)
nCnt:=DllCall("GetMenuItemCount","Int",hSysMenu)
DllCall("RemoveMenu","Int",hSysMenu,"UInt",nCnt-6,"Uint","0x400")
DllCall("DrawMenuBar","Int",Gui1)
; end block
}
;40
movable() {																													;-- makes Gui movable
Gui 2:+LastFound
Gui1 := WinExist()
 DllCall( "GetSystemMenu", UInt,Gui1, Int,True )
Return DllCall( "DrawMenuBar", UInt,Gui1 ) ? 1 : 0
}
;41
GuiDisableMove(handle) {                       																	;-- to fix a gui/window to its coordinates
    hMenu := DllCall("user32\GetSystemMenu", "ptr", handle, "int", false, "ptr")
    DllCall("user32\RemoveMenu", "ptr", hMenu, "uint", 0xf010, "uint", 0x0)
    return DllCall("user32\DrawMenuBar", "ptr", handle)
}
;42
WinInsertAfter(hwnd, afterHwnd) {																				;-- insert a window after a specific window handle
	return DllCall("SetWindowPos", "UINT", hwnd, "UINT", afterHwnd, "INT", 0, "INT", 0, "INT", 0, "INT", 0, "UINT", 0x0013)
}
;{ sub WinInsertAfter
;first=top
WinStack(ByRef arr){
	for k,v in arr {
		if(k=1)
			winactivate,% v
		else if (v)
			WinInsertAfter(v, last)
		last:=v?v:last
	
	}
}
;}
;43
CenterWindow(hWnd, Pos := "") {																				;-- center a window or set position optional by using Top, Left, Right, Bottom or a combination of it
	
	/*                              	DESCRIPTION
	
			Syntax: CenterWindow ([ID], [Position])
			Position: can be combined
			Center = center window.
				Top | Bottom = position up. position down.
				Left | Right = position to the left. position to the right.
			Notes:
			• if the window is maximized, the width or height is modified depending on the position.
					--> if it is positioned up or down, the height is modified	(A_ScreenHeight/2-10%).
					--> if it is positioned to the left or to the right, the width is modified (A_ScreenWidth/2-10%).
			• the window fits the visible screen, regardless of the position of the taskbar (the window is not blocked by the taskbar)
			
	*/
	
	/*                              	EXAMPLE(s)
	
			   WindowActive(WinExist("ahk_class Notepad"), true)
				MsgBox % "Center window: " CenterWindow(WinExist("ahk_class Notepad"))
				MsgBox % "Position up on the left: " CenterWindow(WinExist("ahk_class Notepad"), "Top Left")
				MsgBox % "Position up on the right: " CenterWindow(WinExist("ahk_class Notepad"), "Top Right")
				MsgBox % "Position down to the left: " CenterWindow(WinExist("ahk_class Notepad"), "Bottom Left")
				MsgBox % "Position down to the right: " CenterWindow(WinExist("ahk_class Notepad"), "Bottom Right")
				MsgBox % "Position up and center: " CenterWindow(WinExist("ahk_class Notepad"), "Top Center")
				MsgBox % "Position down and center: " CenterWindow(WinExist("ahk_class Notepad"), "Bottom Center")
				MsgBox % "Position to the left and center it: " CenterWindow(WinExist("ahk_class Notepad"), "Left Center")
				MsgBox % "Position to the right and center it: " CenterWindow(WinExist("ahk_class Notepad"), "Right Center")
				
	*/
	
	
	_gethwnd(hWnd), GetWindowPos(hWnd, x, y, w, h)
	, m := GetMonitorInfo(MonitorFromWindow(hWnd)), mx := m.wLeft, my := m.wTop, mw := m.wRight-mx, mh := m.wBottom-my
	, T := InStr(Pos, "Top"), B := InStr(Pos, "Bottom"), L := InStr(Pos, "Left"), R := InStr(Pos, "Right"), C := InStr(Pos, "Center")
	if WinMax(hWnd)
		w := (L||R)?Percent(mw/2, 10):mw, h := (T||B)?Percent(mh/2, 10):mh
	if (T) || (B) || (L) || (R)
		return MoveWindow(hWnd, (L?0:R?(mw-w):C?((mw/2)-(w/2)):x) +mx, (T?0:B?(mh-h):C?((mh/2)-(h/2)):y) +my, w, h)
	return MoveWindow(hWnd, ((mw/2) - (w/2)) +mx, ((mh/2) - (h/2)) +my, w, h)
}

} 

{ ;Gui - menu all types of functions (12)
		
GetMenu(hWnd) {																										;-- returns hMenu handle
	;; only wraps DllCall(GetMenu)
    Return DllCall("GetMenu", "Ptr", hWnd)
}

GetSubMenu(hMenu, nPos) {																						;--
    Return DllCall("GetSubMenu", "Ptr", hMenu, "Int", nPos)
}

GetMenuItemCount(hMenu) {									     												;--
    Return DllCall("GetMenuItemCount", "Ptr", hMenu)
}

GetMenuItemID(hMenu, nPos) {																					;--
    Return DllCall("GetMenuItemID", "Ptr", hMenu, "Int", nPos)
}

GetMenuString(hMenu, uIDItem) {																				;--
    ; uIDItem: the zero-based relative position of the menu item
    Local lpString, MenuItemID
    VarSetCapacity(lpString, 4096)
    If !(DllCall("GetMenuString", "Ptr", hMenu, "UInt", uIDItem, "Str", lpString, "Int", 4096, "UInt", 0x400)) {
        MenuItemID := GetMenuItemID(hMenu, uIDItem)
        If (MenuItemID > -1) {
            Return "SEPARATOR"
        } Else {
            Return (GetSubMenu(hMenu, uIDItem)) ? "SUBMENU" : "ERROR"
        }
    }
    Return lpString
}

MenuGetAll(hwnd) {																									;-- this function and MenuGetAll_sub return all Menu commands from the choosed menu

    if !menu := DllCall("GetMenu", "ptr", hwnd, "ptr")
        return ""
    MenuGetAll_sub(menu, "", cmds)
    return cmds

}

MenuGetAll_sub(menu, prefix, ByRef cmds) {																;-- described above

    Loop % DllCall("GetMenuItemCount", "ptr", menu) {

        VarSetCapacity(itemString, 2000)

        if !DllCall("GetMenuString", "ptr", menu, "int", A_Index-1, "str", itemString, "int", 1000, "uint", 0x400)
            continue

        StringReplace itemString, itemString, &
        itemID := DllCall("GetMenuItemID", "ptr", menu, "int", A_Index-1)
        if (itemID = -1)
        if subMenu := DllCall("GetSubMenu", "ptr", menu, "int", A_Index-1, "ptr") {

            MenuGetAll_sub(subMenu, prefix itemString " > ", cmds)
            continue

        }
        cmds .= itemID "`t" prefix RegExReplace(itemString, "`t.*") "`n"
    }
}

; these 3 belongs together -->
GetContextMenuState(hWnd, Position) {																	;-- returns the state of a menu entry
  WinGetClass, WindowClass, ahk_id %hWnd%
  if WindowClass <> #32768
  {
   return -1
  }
  SendMessage, 0x01E1, , , , ahk_id %hWnd%
  ;Errorlevel is set by SendMessage. It contains the handle to the menu
  hMenu := errorlevel

  ;We need to allocate a struct
  VarSetCapacity(MenuItemInfo, 60, 0)
  ;Set Size of Struct to the first member
  InsertInteger(48, MenuItemInfo, 0, 4)
  ;Get only Flags from dllcall GetMenuItemInfo MIIM_TYPE = 1
  InsertInteger(1, MenuItemInfo, 4, 4)

  ;GetMenuItemInfo: Handle to Menu, Index of Position, 0=Menu identifier / 1=Index
  InfoRes := DllCall("user32.dll\GetMenuItemInfo",UInt,hMenu, Uint, Position, uint, 1, "int", &MenuItemInfo)

  InfoResError := errorlevel
  LastErrorRes := DllCall("GetLastError")
  if InfoResError <> 0
     return -1
  if LastErrorRes != 0
     return -1

  ;Get Flag from struct
  GetMenuItemInfoRes := ExtractInteger(MenuItemInfo, 12, false, 4)
  /*
  IsEnabled = 1
  if GetMenuItemInfoRes > 0
     IsEnabled = 0
  return IsEnabled
  */
  return GetMenuItemInfoRes
}

GetContextMenuID(hWnd, Position) {																			;-- returns the ID of a menu entry
  WinGetClass, WindowClass, ahk_id %hWnd%
  if WindowClass <> #32768
  {
   return -1
  }
  SendMessage, 0x01E1, , , , ahk_id %hWnd%
  ;Errorlevel is set by SendMessage. It contains the handle to the menu
  hMenu := errorlevel

  ;UINT GetMenuItemID(          HMENU hMenu,    int nPos);
  InfoRes := DllCall("user32.dll\GetMenuItemID",UInt,hMenu, Uint, Position)

  InfoResError := errorlevel
  LastErrorRes := DllCall("GetLastError")
  if InfoResError <> 0
     return -1
  if LastErrorRes != 0
     return -1

  return InfoRes
}

GetContextMenuText(hWnd, Position) {																		;-- returns the text of a menu entry (standard windows context menus only!!!)
  WinGetClass, WindowClass, ahk_id %hWnd%
  if WindowClass <> #32768
  {
   return -1
  }
  SendMessage, 0x01E1, , , , ahk_id %hWnd%
  ;Errorlevel is set by SendMessage. It contains the handle to the menu
  hMenu := errorlevel

  ;We need to allocate a struct
  VarSetCapacity(MenuItemInfo, 200, 0)
  ;Set Size of Struct (48) to the first member
  InsertInteger(48, MenuItemInfo, 0, 4)
  ;Retrieve string MIIM_STRING = 0x40 = 64 (/ MIIM_TYPE = 0x10 = 16)
  InsertInteger(64, MenuItemInfo, 4, 4)
  ;Set type - Get only size of string we need to allocate
  ;InsertInteger(0, MenuItemInfo, 8, 4)
  ;GetMenuItemInfo: Handle to Menu, Index of Position, 0=Menu identifier / 1=Index
  InfoRes := DllCall("user32.dll\GetMenuItemInfo",UInt,hMenu, Uint, Position, uint, 1, "int", &MenuItemInfo)
  if InfoRes = 0
     return -1

  InfoResError := errorlevel
  LastErrorRes := DllCall("GetLastError")
  if InfoResError <> 0
     return -1
  if LastErrorRes <> 0
     return -1

  ;Get size of string from struct
  GetMenuItemInfoRes := ExtractInteger(MenuItemInfo, 40, false, 4)
  ;If menu is empty return
  If GetMenuItemInfoRes = 0
     return "{Empty String}"

  ;+1 should be enough, we'll use 2
  GetMenuItemInfoRes += 2
  ;Set capacity of string that will be filled by windows
  VarSetCapacity(PopupText, GetMenuItemInfoRes, 0)
  ;Set Size plus 0 terminator + security ;-)
  InsertInteger(GetMenuItemInfoRes, MenuItemInfo, 40, 4)
  InsertInteger(&PopupText, MenuItemInfo, 36, 4)

  InfoRes := DllCall("user32.dll\GetMenuItemInfo",UInt,hMenu, Uint, Position, uint, 1, "int", &MenuItemInfo)
  if InfoRes = 0
     return -1

  InfoResError := errorlevel
  LastErrorRes := DllCall("GetLastError")
  if InfoResError <> 0
     return -1
  if LastErrorRes <> 0
     return -1

  return PopupText
}
; <---
Menu_AssignBitmap(p_menu, p_item, p_bm_unchecked,                                          	;-- assign bitmap to any item in any AHk menu
p_unchecked_face=false, p_bm_checked=false,p_checked_face=false)   {
	/*                              	DESCRIPTION
	
				Thanks to shimanov for this function
			    Details under http://www.autohotkey.com/forum/viewtopic.php?p=44577
			
			    p_menu            = "MenuName" (e.g., Tray, etc.)
			    p_item            = "MenuItemNumber" (e.g. 1, ...)
			    p_bm_unchecked,
			    p_bm_checked      = path to bitmap for unchecked 'n' checked menu entry/false
			    p_unchecked_face,
			    p_checked_face    = true/false (i.e., true = pixels with same color as 
			                                    first pixel are transparent)
			
	*/

	/*                              	EXAMPLE(s)
	
		**---Work with context menu---*
		
			Menu, menuEmpty, Add
			
			Menu, menuContext$Level2, Add, :menuEmpty
				Menu_AssignBitmap( "menuContext$Level2", 1, "coffee.bmp", true )
			Menu, menuContext$Level2, Add, empty, :menuEmpty
			Menu, menuContext$Level2, Add, world, :menuEmpty
				Menu_AssignBitmap( "menuContext$Level2", 3, "coffee.bmp", true )
			
			Menu, menuContext, Add, empty 1, :menuEmpty
			Menu, menuContext, Add, empty 2, :menuEmpty
				Menu, menuContext, Check, empty 2
				Menu_AssignBitmap( "menuContext", 2, "coffee.bmp", true, "coffee.bmp", false )
			Menu, menuContext, Add, :menuContext$Level2
			
			Gui, Show, x50 y50 w400 h200
			return
			
			GuiContextMenu:
				Menu, menuContext, Show
			return
		
		**---Work with Tray menu:---**
		
			Menu, menuEmpty, Add
			Menu, Tray, NoStandard
			Menu, Tray, Add, Hello, :menuEmpty
				Menu_AssignBitmap( "Tray", 1, "coffee.bmp", true )
			Menu, Tray, Add
			Menu, Tray, Standard
		
		**---Work with Window menu bar--**
		
			Menu, menuEmpty, Add
			Menu, menuFile, Add, Hello, :menuEmpty
				Menu_AssignBitmap( "menuFile", 1, "coffee.bmp", false )
			Menu, menuMain, Add, File, :menuFile
			Gui, Menu, menuMain
			Gui, Show, x50 y50 w400 h200
		
	*/
	
    static   menu_list, h_menuDummy
    
    If h_menuDummy=
    {
      menu_list = |
    
      ; Save current 'DetectHiddenWindows' mode to reset it later
      Old_DetectHiddenWindows := A_DetectHiddenWindows
      DetectHiddenWindows, on
      
      ; Retrieve scripts PID
      Process, Exist
      pid_this := ErrorLevel
      
      ; Create menuDummy and assign to Gui99
      Menu, menuDummy, Add
      Menu, menuDummy, DeleteAll
      
      Gui, 99:Menu, menuDummy
      
      ; Retrieve menu handle (menuDummy)
      h_menuDummy := DllCall( "GetMenu", "uint", WinExist( "ahk_class AutoHotkeyGUI ahk_pid " pid_this ) )
    
      ; Remove menu bar 'menuDummy'
      Gui, 99:Menu
      
      ; Reset 'DetectHiddenWindows' mode to old setting
      DetectHiddenWindows, %Old_DetectHiddenWindows%
    }
    
    ; Assign p_menu to menuDummy and retrieve menu handle
    If (! InStr(menu_list, "|" p_menu ",", false))
      {
        Menu, menuDummy, Add, :%p_menu%    
        menu_ix := DllCall( "GetMenuItemCount", "uint", h_menuDummy ) - 1
        menu_list = %menu_list%%p_menu%,%menu_ix%|
      }
    Else
      {
        menu_ix := InStr(menu_list, ",", false, InStr( menu_list, "|" p_menu ",", false)) + 1
        StringMid, menu_ix, menu_list, menu_ix, InStr(menu_list, "|", false, menu_ix) - menu_ix
      }
    
    h_menu := DllCall("GetSubMenu", "uint", h_menuDummy, "int", menu_ix)
    
    ; Load bitmap for unchecked menu entries
    If (p_bm_unchecked)
      {
        hbm_unchecked := DllCall( "LoadImage"
                                , "uint", 0
                                , "str", p_bm_unchecked
                                , "uint", 0                             ; IMAGE_BITMAP
                                , "int", 0
                                , "int", 0
                                , "uint", 0x10|(0x20*p_unchecked_face)) ; LR_LOADFROMFILE|LR_LOADTRANSPARENT
        
        If (ErrorLevel or ! hbm_unchecked)
          {
             MsgBox, [Menu_AssignBitmap: LoadImage: unchecked] failed: EL = %ErrorLevel%
             Return, false
          }
      }
    
    ; Load bitmap for checked menu entries
    If (p_bm_checked)
      {
        hbm_checked := DllCall( "LoadImage"
                              , "uint", 0
                              , "str", p_bm_checked
                              , "uint", 0                               ; IMAGE_BITMAP
                              , "int", 0
                              , "int", 0
                              , "uint", 0x10|(0x20*p_checked_face))     ; LR_LOADFROMFILE|LR_LOADTRANSPARENT
      
        If (ErrorLevel or ! hbm_checked)
          {
             MsgBox, [Menu_AssignBitmap: LoadImage: checked] failed: EL = %ErrorLevel%
             Return, false
          }
      }
    
    ; On success assign image to menu entry
    success := DllCall( "SetMenuItemBitmaps"
                      , "uint", h_menu
                      , "uint", p_item-1
                      , "uint", 0x400                                   ; MF_BYPOSITION
                      , "uint", hbm_unchecked
                      , "uint", hbm_checked )
                      
    If (ErrorLevel or ! success)
      {
        MsgBox, [Menu_AssignBitmap: SetMenuItemBitmaps] failed: EL = %ErrorLevel%
        Return, false
      }
    
    Return, true
  }

InvokeVerb(path, menu, validate=True) {																				;-- executes the context menu item of the given path
	/*                              	DESCRIPTION
	
				by A_Samurai
				Link: 					https://autohotkey.com/board/topic/73010-invokeverb/
				Doc:						v 1.0.1 http://sites.google.com/site/ahkref/custom-functions/invokeverb
				Dependencies: 	WindowProc and CoHelper.ahk
	*/
	
	
	/*                              	EXAMPLE(s)
	
			Persistent
			;this is the same as right clicking on the folder and selecting Copy.
			if InvokeVerb(A_MyDocuments "\AutoHotkey", "Copy")
			    msgbox copied
			else
			    msgbox not copied
			
			;Opens the property window of Recycle Bin
			InvokeVerb("::", "Properties")
			
			
			path := A_ScriptDir "\Test"
			FileCreateDir, % path
			;this is the same as right clicking on the folder and selecting Delete.
			InvokeVerb(path, "Delete")
			
	*/

	
    objShell := ComObjCreate("Shell.Application")
    if InStr(FileExist(path), "D") || InStr(path, "::{") {
        objFolder := objShell.NameSpace(path)   
        objFolderItem := objFolder.Self
    } else {
        SplitPath, path, name, dir
        objFolder := objShell.NameSpace(dir)
        objFolderItem := objFolder.ParseName(name)
    }
    if validate {
        colVerbs := objFolderItem.Verbs   
        loop % colVerbs.Count {
            verb := colVerbs.Item(A_Index - 1)
            retMenu := verb.name
            StringReplace, retMenu, retMenu, &       
            if (retMenu = menu) {
                verb.DoIt
                Return True
            }
        }
        Return False
    } else
        objFolderItem.InvokeVerbEx(Menu)
}
;{ sub
WindowProc(hWnd, nMsg, wParam, lParam) { 
Critical
  Global   pcm, pcm2, pcm3, WPOld
  If (nMsg = 287) ; WM_MENUSELECT
  {  MenuItem := wParam & 65535
     VarSetCapacity(sHelp,257,79)
     DllCall(NumGet(NumGet(1*pcm)+20), "Uint", pcm, "Uint", MenuItem-3, "Uint", GCS_HELPTEXTA:=1, "Uint", 0, "str", sHelp, "Uint", 256) ; GetCommandString
     if sHelp = %SbText%
        MsgBox, Hey
  }
  If pcm3
  { If !DllCall(NumGet(NumGet(1*pcm3)+28), "Uint", pcm3, "Uint", nMsg, "Uint", wParam, "Uint", lParam, "UintP", lResult)
    Return lResult
  }
  Else If pcm2
  { If !DllCall(NumGet(NumGet(1*pcm2)+24), "Uint", pcm2, "Uint", nMsg, "Uint", wParam, "Uint", lParam)
      Return 0
  }
  Return   DllCall("user32.dll\CallWindowProcA", "Uint", WPOld, "Uint", hWnd, "Uint", nMsg, "Uint", wParam, "Uint", lParam,"Uint")
}
;}


} 

	
} 
;|														|														|														|														|
; -----------------------------------------------------------	#Custom Gui Elements#	---------------------------------------------------------------
;|	HtmlBox()                                	|	EditBox()										|	Popup()										|	PIC_GDI_GUI()                         	|
;|	SplitButton()									|	BetterBox()									|	BtnBox()										|	LoginBox()									|
;|	MultiBox()									|	PassBox()										|	CreateHotkeyWindow()				|	GetUserInput()								|
;|   guiMsgBox()                             	|   URLPrefGui()                            	|	TaskDialog()						    		|	ITaskDialogDirect()						|
;|	TaskDialogMsgBox()					|	TaskDialogToUnicode()				|	TaskDialogCallback()					|  TT_Console()                             	|
;|   ToolTipEx()                                	|   SafeInput()                                 	|   DisableCloseButton()                	|
;
; ----------------------------------------------------------	#Gui - changing functions#	---------------------------------------------------------------
;|	FadeGui()										|	WinFadeToggle()							|	ShadowBorder()							|	FrameShadow() - 2 versions			|
;|	RemoveWindowFromTaskbar()	|	ToggleTitleMenuBar()					|	ToggleFakeFullscreen()	        	   	|	ListView_HeaderFontSet()			|
;|	CreateFont()									|	FullScreenToggleUnderMouse()	|	SetTaskbarProgress() x 2				|   WinSetPlacement()                   	|
;|  AttachToolWindow()                 	|   DeAttachToolWindow()            	|   ControlSetTextAndResize()       	|   winfade()                                    	|
;
; -----------------------------------------------------------	#control type functions#	---------------------------------------------------------------
;|	*Combobox control functions***	|	*********************************	|	********************************* 	|	********************************	|
;|	GetComboBoxChoice()					|	LB_GetItemHeight()						|	LB_SetItemHeight()						|
;|	****** Edit control functions ****	|    *******************************	|	*********************************	|	********************************	|
;|	Edit_Standard_Params()				|	Edit_TextIsSelected()						|	Edit_GetSelection()						|	Edit_Select()									|
;|	Edit_SelectLine()							|	Edit_DeleteLine()							|
;|	****** GDI control functions ****	| 	*********************************	|	*********************************	|	********************************	|
;|	ControlCreateGradient()				|	AddGraphicButtonPlus()				|
;|	****** IMAGELIST functions ****	| 	*********************************	|	*********************************	|	********************************	|
;|	IL_LoadIcon()								|	IL_GuiButtonIcon()						|
;|	******** Listbox functions ******	| 	*********************************	|	*********************************	|	********************************	|
;|	LB_AdjustItemHeight()					|
;|	******** Listview functions *****	| 	*********************************	|	*********************************	|	********************************	|
;|	LV_GetCount()								|	LV_SetSelColors()							|	LV_Select()									|	LV_GetItemText()							|
;|	LV_GetText()									|	LV_SetBackgroundUrl()				|	LV_MoveRow()								|	LV_MoveRow()								|
;|  LV_Find()                                  	|   LV_GetSelectedText()                 	|   LV_Notification()                      	|   LV_IsChecked()                         	|
;|  LV_HeaderFontSet()                   	|   LV_SetCheckState()                   	|   LV_SetItemState()                     	|   LV_SubitemHitTest()                 	|
;|  LV_EX_FindString()                   	|   LV_RemoveSelBorder()               	|   LV_SetExplorerTheme()              	|   LV_Update()                               	|
;|  LV_RedrawItem()                      	|   LV_SetExStyle()                           	|   LV_GetExStyle()                           	|   LV_IsItemVisible()                       	|
;|  LV_SetIconSpacing()                 	|   LV_GetIconSpacing()                   	|   LV_GetItemPos()                        	|   LV_SetItemPos()                          	|
;|   LV_MouseGetCellPos()              	|   LV_GetColOrderLocal()              	|   LV_GetColOrder()                        	|   LV_SetColOrderLocal()               	|
;|   LV_GetCheckedItems()              	|   LV_ClickRow()                            	|
;|	****** TabControl functions ****	| 	*********************************	|	*********************************	|	********************************	|
;|	TabCtrl_GetCurSel()						|	TabCtrl_GetItemText()					|
;|	***** TREEVIEW functions	*****	| 	*********************************	|	*********************************	|	********************************	|
;|	TV_Find()										|	TV_Load()										|
; ---------------------------------------------------  #gui/window/screen - retreaving informations#  ------------------------------------------------
;|	 screenDims()								|	DPIFactor()									|	ControlExists()								|	GetFocusedControl()					|
;|	 GetControls()								|	GetOtherControl()						|	ListControls()								|	Control_GetClassNN()					|
;|	 ControlGetClassNN()	x	2			|   GetClassName()                       	|   Control_GetFont()						|	IsControlFocused()						|
;|	 IsOverTitleBar()							|	WinGetPosEx()					    		|	GetParent()									|	GetWindow()								|
;|	 GetForegroundWindow()	 	  		|	IsWindowVisible()						|	IsFullScreen()								|	IsClosed()										|
;|	 GetClassLong()							|	GetWindowLong()						|	GetClassStyles()							|	GetTabOrderIndex()						|
;|	 GetCursor()									|	GetExtraStyle()								|	GetToolbarItems()						|	ControlGetTabs()							|
;|	 GetHeaderInfo()							|	GetClientCoords()						|	GetClientSize()								|	GetWindowCoords()						|
;|	 GetWindowPos()							|	GetWindowPlacement()				|	GetWindowInfo()							|	GetOwner()									|
;|	 FindWindow()								|	ShowWindow()								|	IsWindow()									|	IsWindowVisible()						|
;|	 GetClassName()							|	WinForms_GetClassNN()				|	FindChildWindow()						|	WinGetMinMaxState()					|
;|	 GetBgBitMapHandle()					|	GetLastActivePopup()					|	getControlNameByHwnd()			|	getByControlName()					|
;|	 getNextControl()							|	TabCtrl_GetCurSel()						|	TabCtrl_GetItemText()					|	IsControlUnderCursor()            	|
;|   GetFreeGuiNum()                    	|   IsWindowUnderCursor()           	|   GetCenterCoords()                   	|   RMApp_NCHITTEST()               	|
;|   GetCPA_file_name()                	|   GetFocusedControl()                 	|   ControlGetTextExt()                   	|   getControlInfo()                        	|
;|   WinGetClientPos()                   	|   FocusedControl()                        	|   CheckWindowStatus()               	|   Control_GetFont()                      	|
;|   GetWindowOrder()                   	|   EnumWindows()                        	|
; ---------------------------------------------------------	#interacting or other functions#	----------------------------------------------------------
;|   ChooseColor()								|	GetWindowIcon()							|	GetImageType()							|	GetStatusBarText()						|
;|   GetAncestor()								|	MinMaxInfo()								|	OnMessage( "MinMaxInfo")			|	SureControlClick()						|
;| 	 SureControlCheck()						|	ControlClick2()								|	ControlFromPoint()						|	EnumChildFindPoint()					|
;|   ControlDoubleClick()                  	|   WinWaitForMinimized()				|	CenterWindow()							|	GuiCenterButtons()						|
;|   CenterControl()							|   SetWindowIcon()							|	SetWindowPos()							|	TryKillWin()									|	
;|   Win32_SendMessage()					|	Win32_TaskKill()							|	Win32_Terminate()						|	TabActivate()								|	
;|   FocuslessScroll()							|	FocuslessScrollHorizontal()			|	Menu_Show()								|	CatMull_ControlMove()				|
;|   Gui_AutoHide()			   				|	SetButtonF()									|	AddToolTip()								|	HelpToolTips()								|   
;|   DisableFadeEffect()						|   SetWindowTransistionDisable()	|   DisableMinimizeAnim()            	|   AutoCloseBlockingWindows()   	|
;|	 WinActivateEx()                      	|   ClickOK()                                   	|   ControlSelectTab()                     	|   SetParentByClass()                    	|     
;|	 MoveTogether()                       	|   WinWaitCreated()                     	|   closeContextMenu()                  	|   SetWindowTheme()                   	|     
;|	 HideFocusBorder()                  	|   unmovable()                              	|   movable()                                 	|   GuiDisableMove()                        |
;|   WinInsertAfter()                       	|   CenterWindow()                         	|
;------------------------------------------------------------------	#Menu functions#	----------------------------------------------------------------
;|	 GetMenu()                               	|	GetSubMenu()								|	GetMenuItemCount()					|	GetMenuItemID()							|     
;|	 GetMenuString()                     	|	MenuGetAll()								|	MenuGetAll_sub()							|	GetContextMenuState()				|     
;|	 GetContextMenuID()               	|	GetContextMenuText()					|	ExtractInteger()							|	InsertInteger()								|     
;|	 Menu_AssignBitmap()             	|   InvokeVerb()                              	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;Filesystem (33)
;-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
InvokeVerb(path, menu, validate=True) {												;-- Executes the context menu item of the given path

    ;by A_Samurai
    ;v 1.0.1 http://sites.google.com/site/ahkref/custom-functions/invokeverb

	/*											Description

		Executes the context menu item of the given path.

		Remarks
		This should be used with #Persistent since closing the script causes an unexpected termination of the invoked action, such as when invoking
		the Copy menu item, if the script exits, the copied item will be canceled. Invoking Properties behaves similarly.

		Requirements
		AutoHotkey_L Revision 53 or later.

		License
		Public Domain.

		Format
		InvokeVerb(path, menu, validate=True)
		Parameters
		path: the path of the file / directory to invoke the context menu.
		menu: the menu item to invoke.
		validate: if this is set to True, the function checks if the given menu item exists. It's True by default.

		Return Value
		True if the menu item is invoked; otherwise, False. If the validate option is set to False, nothing will be returned.

	*/

	/*											Example

		#persistent
		;this is the same as right clicking on the folder and selecting Copy.
		if InvokeVerb(A_MyDocuments "\AutoHotkey", "Copy")
			msgbox copied
		else
			msgbox not copied

		;Opens the property window of Recycle Bin
		InvokeVerb("::{645ff040-5081-101b-9f08-00aa002f954e}", "Properties")


		path := A_ScriptDir "\Test"
		FileCreateDir, % path
		;this is the same as right clicking on the folder and selecting Delete.
		InvokeVerb(path, "Delete")

	*/

    objShell := ComObjCreate("Shell.Application")
    if InStr(FileExist(path), "D") || InStr(path, "::{") {
        objFolder := objShell.NameSpace(path)
        objFolderItem := objFolder.Self
    } else {
        SplitPath, path, name, dir
        objFolder := objShell.NameSpace(dir)
        objFolderItem := objFolder.ParseName(name)
    }
    if validate {
        colVerbs := objFolderItem.Verbs
        loop % colVerbs.Count {
            verb := colVerbs.Item(A_Index - 1)
            retMenu := verb.name
            StringReplace, retMenu, retMenu, &
            if (retMenu = menu) {
                verb.DoIt
                Return True
            }
        }
        Return False
    } else
        objFolderItem.InvokeVerbEx(Menu)

}

Function_Eject(Drive){																				;-- ejects a drive medium
	Try
	{

		hVolume := DllCall("CreateFile"
		    , Str, "\\.\" . Drive
		    , UInt, 0x80000000 | 0x40000000  ; GENERIC_READ | GENERIC_WRITE
		    , UInt, 0x1 | 0x2  ; FILE_SHARE_READ | FILE_SHARE_WRITE
		    , UInt, 0
		    , UInt, 0x3  ; OPEN_EXISTING
		    , UInt, 0, UInt, 0)
		if hVolume <> -1
		{
		    DllCall("DeviceIoControl"
		        , UInt, hVolume
		        , UInt, 0x2D4808   ; IOCTL_STORAGE_EJECT_MEDIA
		        , UInt, 0, UInt, 0, UInt, 0, UInt, 0
		        , UIntP, dwBytesReturned  ; Unused.
		        , UInt, 0)
		    DllCall("CloseHandle", UInt, hVolume)

		}

		Return 1
	}
	Catch
	{

		Return 0
	}
}

FileGetDetail(FilePath, Index) { 																;-- Get specific file property by index
   Static MaxDetails := 350
   SplitPath, FilePath, FileName , FileDir
   If (FileDir = "")
      FileDir := A_WorkingDir
   Shell := ComObjCreate("Shell.Application")
   Folder := Shell.NameSpace(FileDir)
   Item := Folder.ParseName(FileName)
   Return Folder.GetDetailsOf(Item, Index)
}

FileGetDetails(FilePath) { 																		;-- Create an array of concrete file properties
   Static MaxDetails := 350
   Shell := ComObjCreate("Shell.Application")
   Details := []
   SplitPath, FilePath, FileName , FileDir
   If (FileDir = "")
      FileDir := A_WorkingDir
   Folder := Shell.NameSpace(FileDir)
   Item := Folder.ParseName(FileName)
   Loop, %MaxDetails% {
      If (Value := Folder.GetDetailsOf(Item, A_Index - 1))
         Details[A_Index - 1] := [Folder.GetDetailsOf(0, A_Index - 1), Value]
   }
   Return Details
}

DirExist(dirPath) {																						;-- Checks if a directory exists
   return InStr(FileExist(dirPath), "D") ? 1 : 0
}

GetDetails() { 																							;-- Create an array of possible file properties
   Static MaxDetails := 350
   Shell := ComObjCreate("Shell.Application")
   Details := []
   Folder := Shell.NameSpace(A_ScriptDir)
   Loop, %MaxDetails% {
      If (Value := Folder.GetDetailsOf(0, A_Index - 1)) {
         Details[A_Index - 1] := Value
         Details[Value] := A_Index - 1
      }
   }
   Return Details
}

Start(Target, Minimal = false, Title = "") { 												;-- Start programs or scripts easier
   cPID = -1
   if Minimal
      Run %ComSpec% /c "%Target%", A_WorkingDir, Min UseErrorLevel, cPID
   else
      Run %ComSpec% /c "%Target%", A_WorkingDir, UseErrorLevel, cPID
   if ErrorLevel = 0
   {
      if (Title <> "")
      {
         WinWait ahk_pid %cPID%,,,2
         WinSetTitle, %Title%
      }
      return, 0
   }
   else
      return, -1
}

IsFileEqual(filename1, filename2) { 															;-- Returns whether or not two files are equal
    ;TODO make this work for big files, too (this version reads it all into memory first)
   FileRead, file1, %filename1%
   FileRead, file2, %filename2%

   return file1==file2
}

WatchDirectory(p*) {  																				;-- Watches a directory/file for file changes

    ;By HotKeyIt
    ;Docs: http://www.autohotkey.com/forum/viewtopic.php?p=398565#398565

    global _Struct
   ;Structures
   static FILE_NOTIFY_INFORMATION:="DWORD NextEntryOffset,DWORD Action,DWORD FileNameLength,WCHAR FileName[1]"
   static OVERLAPPED:="ULONG_PTR Internal,ULONG_PTR InternalHigh,{struct{DWORD offset,DWORD offsetHigh},PVOID Pointer},HANDLE hEvent"
   ;Variables
   static running,sizeof_FNI=65536,WatchDirectory:=RegisterCallback("WatchDirectory","F",0,0) ;,nReadLen:=VarSetCapacity(nReadLen,8)
   static timer,ReportToFunction,LP,nReadLen:=VarSetCapacity(LP,(260)*(A_PtrSize/2),0)
   static @:=Object(),reconnect:=Object(),#:=Object(),DirEvents,StringToRegEx="\\\|.\.|+\+|[\[|{\{|(\(|)\)|^\^|$\$|?\.?|*.*"
   ;ReadDirectoryChanges related
   static FILE_NOTIFY_CHANGE_FILE_NAME=0x1,FILE_NOTIFY_CHANGE_DIR_NAME=0x2,FILE_NOTIFY_CHANGE_ATTRIBUTES=0x4
         ,FILE_NOTIFY_CHANGE_SIZE=0x8,FILE_NOTIFY_CHANGE_LAST_WRITE=0x10,FILE_NOTIFY_CHANGE_CREATION=0x40
         ,FILE_NOTIFY_CHANGE_SECURITY=0x100
   static FILE_ACTION_ADDED=1,FILE_ACTION_REMOVED=2,FILE_ACTION_MODIFIED=3
         ,FILE_ACTION_RENAMED_OLD_NAME=4,FILE_ACTION_RENAMED_NEW_NAME=5
   static OPEN_EXISTING=3,FILE_FLAG_BACKUP_SEMANTICS=0x2000000,FILE_FLAG_OVERLAPPED=0x40000000
         ,FILE_SHARE_DELETE=4,FILE_SHARE_WRITE=2,FILE_SHARE_READ=1,FILE_LIST_DIRECTORY=1
   If p.MaxIndex(){
      If (p.MaxIndex()=1 && p.1=""){
         for i,folder in #
            DllCall("CloseHandle","Uint",@[folder].hD),DllCall("CloseHandle","Uint",@[folder].O.hEvent)
            ,@.Remove(folder)
         #:=Object()
         DirEvents:=new _Struct("HANDLE[1000]")
         DllCall("KillTimer","Uint",0,"Uint",timer)
         timer=
         Return 0
      } else {
         if p.2
            ReportToFunction:=p.2
         If !IsFunc(ReportToFunction)
            Return -1 ;DllCall("MessageBox","Uint",0,"Str","Function " ReportToFunction " does not exist","Str","Error Missing Function","UInt",0)
         RegExMatch(p.1,"^([^/\*\?<>\|""]+)(\*)?(\|.+)?$",dir)
         if (SubStr(dir1,0)="\")
            StringTrimRight,dir1,dir1,1
         StringTrimLeft,dir3,dir3,1
         If (p.MaxIndex()=2 && p.2=""){
            for i,folder in #
               If (dir1=SubStr(folder,1,StrLen(folder)-1))
                  Return 0 ,DirEvents[i]:=DirEvents[#.MaxIndex()],DirEvents[#.MaxIndex()]:=0
                           @.Remove(folder),#[i]:=#[#.MaxIndex()],#.Remove(i)
            Return 0
         }
      }
      if !InStr(FileExist(dir1),"D")
         Return -1 ;DllCall("MessageBox","Uint",0,"Str","Folder " dir1 " does not exist","Str","Error Missing File","UInt",0)
      for i,folder in #
      {
         If (dir1=SubStr(folder,1,StrLen(folder)-1) || (InStr(dir1,folder) && @[folder].sD))
               Return 0
         else if (InStr(SubStr(folder,1,StrLen(folder)-1),dir1 "\") && dir2){ ;replace watch
            DllCall("CloseHandle","Uint",@[folder].hD),DllCall("CloseHandle","Uint",@[folder].O.hEvent),reset:=i
         }
      }
      LP:=SubStr(LP,1,DllCall("GetLongPathName","Str",dir1,"Uint",&LP,"Uint",VarSetCapacity(LP))) "\"
      If !(reset && @[reset]:=LP)
         #.Insert(LP)
      @[LP,"dir"]:=LP
      @[LP].hD:=DllCall("CreateFile","Str",StrLen(LP)=3?SubStr(LP,1,2):LP,"UInt",0x1,"UInt",0x1|0x2|0x4
                  ,"UInt",0,"UInt",0x3,"UInt",0x2000000|0x40000000,"UInt",0)
      @[LP].sD:=(dir2=""?0:1)

      Loop,Parse,StringToRegEx,|
         StringReplace,dir3,dir3,% SubStr(A_LoopField,1,1),% SubStr(A_LoopField,2),A
      StringReplace,dir3,dir3,%A_Space%,\s,A
      Loop,Parse,dir3,|
      {
         If A_Index=1
            dir3=
         pre:=(SubStr(A_LoopField,1,2)="\\"?2:0)
         succ:=(SubStr(A_LoopField,-1)="\\"?2:0)
         dir3.=(dir3?"|":"") (pre?"\\\K":"")
               . SubStr(A_LoopField,1+pre,StrLen(A_LoopField)-pre-succ)
               . ((!succ && !InStr(SubStr(A_LoopField,1+pre,StrLen(A_LoopField)-pre-succ),"\"))?"[^\\]*$":"") (succ?"$":"")
      }
      @[LP].FLT:="i)" dir3
      @[LP].FUNC:=ReportToFunction
      @[LP].CNG:=(p.3?p.3:(0x1|0x2|0x4|0x8|0x10|0x40|0x100))
      If !reset {
         @[LP].SetCapacity("pFNI",sizeof_FNI)
         @[LP].FNI:=new _Struct(FILE_NOTIFY_INFORMATION,@[LP].GetAddress("pFNI"))
         @[LP].O:=new _Struct(OVERLAPPED)
      }
      @[LP].O.hEvent:=DllCall("CreateEvent","Uint",0,"Int",1,"Int",0,"UInt",0)
      If (!DirEvents)
         DirEvents:=new _Struct("HANDLE[1000]")
      DirEvents[reset?reset:#.MaxIndex()]:=@[LP].O.hEvent
      DllCall("ReadDirectoryChangesW","UInt",@[LP].hD,"UInt",@[LP].FNI[],"UInt",sizeof_FNI
               ,"Int",@[LP].sD,"UInt",@[LP].CNG,"UInt",0,"UInt",@[LP].O[],"UInt",0)
      Return timer:=DllCall("SetTimer","Uint",0,"UInt",timer,"Uint",50,"UInt",WatchDirectory)
   } else {
      Sleep, 0
      for LP in reconnect
      {
         If (FileExist(@[LP].dir) && reconnect.Remove(LP)){
            DllCall("CloseHandle","Uint",@[LP].hD)
            @[LP].hD:=DllCall("CreateFile","Str",StrLen(@[LP].dir)=3?SubStr(@[LP].dir,1,2):@[LP].dir,"UInt",0x1,"UInt",0x1|0x2|0x4
                  ,"UInt",0,"UInt",0x3,"UInt",0x2000000|0x40000000,"UInt",0)
            DllCall("ResetEvent","UInt",@[LP].O.hEvent)
            DllCall("ReadDirectoryChangesW","UInt",@[LP].hD,"UInt",@[LP].FNI[],"UInt",sizeof_FNI
               ,"Int",@[LP].sD,"UInt",@[LP].CNG,"UInt",0,"UInt",@[LP].O[],"UInt",0)
         }
      }
      if !( (r:=DllCall("MsgWaitForMultipleObjectsEx","UInt",#.MaxIndex()
               ,"UInt",DirEvents[],"UInt",0,"UInt",0x4FF,"UInt",6))>=0
               && r<#.MaxIndex() ){
         return
      }
      DllCall("KillTimer", UInt,0, UInt,timer)
      LP:=#[r+1],DllCall("GetOverlappedResult","UInt",@[LP].hD,"UInt",@[LP].O[],"UIntP",nReadLen,"Int",1)
      If (A_LastError=64){ ; ERROR_NETNAME_DELETED - The specified network name is no longer available.
         If !FileExist(@[LP].dir) ; If folder does not exist add to reconnect routine
            reconnect.Insert(LP,LP)
      } else
         Loop {
            FNI:=A_Index>1?(new _Struct(FILE_NOTIFY_INFORMATION,FNI[]+FNI.NextEntryOffset)):(new _Struct(FILE_NOTIFY_INFORMATION,@[LP].FNI[]))
            If (FNI.Action < 0x6){
               FileName:=@[LP].dir . StrGet(FNI.FileName[""],FNI.FileNameLength/2,"UTF-16")
               If (FNI.Action=FILE_ACTION_RENAMED_OLD_NAME)
                     FileFromOptional:=FileName
               If (@[LP].FLT="" || RegExMatch(FileName,@[LP].FLT) || FileFrom)
                  If (FNI.Action=FILE_ACTION_ADDED){
                     FileTo:=FileName
                  } else If (FNI.Action=FILE_ACTION_REMOVED){
                     FileFrom:=FileName
                  } else If (FNI.Action=FILE_ACTION_MODIFIED){
                     FileFrom:=FileTo:=FileName
                  } else If (FNI.Action=FILE_ACTION_RENAMED_OLD_NAME){
                     FileFrom:=FileName
                  } else If (FNI.Action=FILE_ACTION_RENAMED_NEW_NAME){
                     FileTo:=FileName
                  }
          If (FNI.Action != 4 && (FileTo . FileFrom) !="")
                  @[LP].Func(FileFrom=""?FileFromOptional:FileFrom,FileTo)
            }
         } Until (!FNI.NextEntryOffset || ((FNI[]+FNI.NextEntryOffset) > (@[LP].FNI[]+sizeof_FNI-12)))
      DllCall("ResetEvent","UInt",@[LP].O.hEvent)
      DllCall("ReadDirectoryChangesW","UInt",@[LP].hD,"UInt",@[LP].FNI[],"UInt",sizeof_FNI
               ,"Int",@[LP].sD,"UInt",@[LP].CNG,"UInt",0,"UInt",@[LP].O[],"UInt",0)
      timer:=DllCall("SetTimer","Uint",0,"UInt",timer,"Uint",50,"UInt",WatchDirectory)
      Return
   }
   Return
}

WatchDirectory(WatchFolder="", WatchSubDirs=true) {						;-- it's different from above not tested

	;--https://autohotkey.com/board/topic/41653-watchdirectory/page-2

	/*				DESCRIPTION
	;Parameters
	; WatchFolder - Specify a valid path to watch for changes in.
	; - can be directory or drive (e.g. c:\ or c:\Temp)
	; - can be network path e.g. \\192.168.2.101\Shared)
	; - can include last backslash. e.g. C:\Temp\ (will be reported same form)
	;
	; WatchSubDirs - Specify whether to search in subfolders
	;
	;StopWatching - THIS SHOULD BE DONE BEFORE EXITING SCRIPT AT LEAST (OnExit)
	; Call WatchDirectory() without parameters to stop watching all directories
	;
	;ReportChanges
	; Call WatchDirectory("ReportingFunctionName") to process registered changes.
	; Syntax of ReportingFunctionName(Action,Folder,File)
	*/

	/*					EXAMPLE

	#Persistent
	OnExit,Exit
	WatchDirectory("C:\Windows",1)
	SetTimer,WatchFolder,100
	Return
	WatchFolder:
	WatchDirectory("RegisterChanges")
	Return
	RegisterChanges(action,folder,file){
	static
	#1:="New File", #2:="Deleted", #3:="Modified", #4:="Renamed From", #5:="Renamed To"
	ToolTip % #%Action% "`n" folder . (SubStr(folder,0)="" ? "" : "") . file
	}
	Exit:
	WatchDirectory()
	ExitApp

	*/

	static
	local hDir, hEvent, r, Action, FileNameLen, pFileName, Restart, CurrentFolder, PointerFNI, option
	static nReadLen := 0, _SizeOf_FNI_:=65536
	If (Directory=""){
		Gosub, StopWatchingDirectories
		SetTimer,TimerDirectoryChanges,Off
	} else if (Directory=Chr(2) or IsFunc(Directory) or IsLabel(Directory)){
		Gosub, ReportDirectoryChanges
	} else {
		Loop % (DirIdx) {
			If InStr(Directory, Dir%A_Index%Path){
				If (Dir%A_Index%Subdirs)
					Return
			} else if InStr(Dir%A_Index%Path, Directory) {
				If (SubDirs){
					DllCall( "CloseHandle", UInt,Dir%A_Index% )
					DllCall( "CloseHandle", UInt,NumGet(Dir%A_Index%Overlapped, 16) )
					Restart := DirIdx, DirIdx := A_Index
				}
			}
		}
		If !Restart
			DirIdx += 1
		r:=DirIdx
		hDir := DllCall( "CreateFile"
					 , Str  , Directory
					 , UInt , ( FILE_LIST_DIRECTORY := 0x1 )
					 , UInt , ( FILE_SHARE_READ     := 0x1 )
							| ( FILE_SHARE_WRITE    := 0x2 )
							| ( FILE_SHARE_DELETE   := 0x4 )
					 , UInt , 0
					 , UInt , ( OPEN_EXISTING := 0x3 )
					 , UInt , ( FILE_FLAG_BACKUP_SEMANTICS := 0x2000000  )
							| ( FILE_FLAG_OVERLAPPED       := 0x40000000 )
					 , UInt , 0 )
		Dir%r%         := hDir
		Dir%r%Path     := Directory
		Dir%r%Subdirs  := SubDirs
		If (options!="")
			Loop,Parse,options,%A_Space%
				If (option:= SubStr(A_LoopField,1,1))
					Dir%r%%option%:= SubStr(A_LoopField,2)
		VarSetCapacity( Dir%r%FNI, _SizeOf_FNI_ )
		VarSetCapacity( Dir%r%Overlapped, 20, 0 )
		DllCall( "CloseHandle", UInt,hEvent )
		hEvent := DllCall( "CreateEvent", UInt,0, Int,true, Int,false, UInt,0 )
		NumPut( hEvent, Dir%r%Overlapped, 16 )
		if ( VarSetCapacity(DirEvents) < DirIdx*4 and VarSetCapacity(DirEvents, DirIdx*4 + 60))
			Loop %DirIdx%
			{
				If (SubStr(Dir%A_Index%Path,1,1)!="-"){
					action++
					NumPut( NumGet( Dir%action%Overlapped, 16 ), DirEvents, action*4-4 )
				}
			}
		NumPut( hEvent, DirEvents, DirIdx*4-4)
		Gosub, ReadDirectoryChanges
		If Restart
			DirIdx = %Restart%
		If (Dir%r%T!="")
			SetTimer,TimerDirectoryChanges,% Dir%r%T
	}
	Return
	TimerDirectoryChanges:
		WatchDirectory(Chr(2))
	Return
	ReportDirectoryChanges:
		r := DllCall("MsgWaitForMultipleObjectsEx", UInt, DirIdx, UInt, &DirEvents, UInt, -1, UInt, 0x4FF, UInt, 0x6) ;Timeout=-1
		if !(r >= 0 && r < DirIdx)
			Return
		r += 1
		CurrentFolder := Dir%r%Path
		PointerFNI := &Dir%r%FNI
		DllCall( "GetOverlappedResult", UInt, hDir, UInt, &Dir%r%Overlapped, UIntP, nReadLen, Int, true )
		Loop {
			pNext   	:= NumGet( PointerFNI + 0  )
			Action      := NumGet( PointerFNI + 4  )
			FileNameLen := NumGet( PointerFNI + 8  )
			pFileName :=       ( PointerFNI + 12 )
			If (Action < 0x6){
				VarSetCapacity( FileNameANSI, FileNameLen )
				DllCall( "WideCharToMultiByte",UInt,0,UInt,0,UInt,pFileName,UInt,FileNameLen,Str,FileNameANSI,UInt,FileNameLen,UInt,0,UInt,0)
				path:=CurrentFolder . (SubStr(CurrentFolder,0)="\" ? "" : "\") . SubStr( FileNameANSI, 1, FileNameLen/2 )
				SplitPath,path,,,EXT
				SplitPath,frompath,,,EXTFrom
				If ((FileExist(path) and InStr(FileExist(path),"D") and Dir%r%E!="" and Dir%r%E!="?") or (Dir%r%A!="" and !InStr(Dir%r%A, action)) or (FileExist(path) and !InStr(FileExist(path),"D") and Dir%r%E="?")){
					If (!pNext or pNext = 4129024)
						Break
					Else
						frompath:=path, PointerFNI := (PointerFNI + pNext)
					Continue
				}
				option:=Dir%r%E="" ? "|" : Dir%r%E
				Loop,Parse,option,.
					If (Dir%r%E="" or Dir%r%E="?" or Dir%r%E="*" or A_LoopField=EXT or A_LoopField=ExtFrom){
						If action in 2,3
							before:=path,after:=(action=3 ? path : "")
						else if action in 1,5
							before:=(action=5 ? frompath : ""),after:=path
						If (Directory and IsFunc(Directory))
							%Directory%(action,path)
						else if (action!=4){
							If IsFunc(Dir%r%F){
								F:=Dir%r%F
								%F%(before,after)
							}
						}
						If IsLabel(Dir%r%G){
								ErrorLevel:=action . "|" . path
								Gosub % Dir%r%G
							}
						break
					}
			}
			If (!pNext or pNext = 4129024)
				Break
			Else
				frompath:=path, PointerFNI := (PointerFNI + pNext)
		}
		DllCall( "ResetEvent", UInt,NumGet( Dir%r%Overlapped, 16 ) )
		Gosub, ReadDirectoryChanges
	Return
	StopWatchingDirectories:
		Loop % (DirIdx) {
			DllCall( "CloseHandle", UInt,Dir%A_Index% )
			DllCall( "CloseHandle", UInt,NumGet(Dir%A_Index%Overlapped, 16) )
			DllCall( "CloseHandle", UInt, NumGet(Dir%A_Index%Overlapped,16) )
			VarSetCapacity(Dir%A_Index%Overlapped,0)
			Dir%A_Index%=
			Dir%A_Index%Path=
			Dir%A_Index%Subdirs=
			Dir%A_Index%FNI=
		}
		DirIdx=
		VarSetCapacity(DirEvents,0)
	Return
	ReadDirectoryChanges:
		DllCall( "ReadDirectoryChangesW"
			, UInt , Dir%r%
			, UInt , &Dir%r%FNI
			, UInt , _SizeOf_FNI_
			, UInt , Dir%r%SubDirs
			, UInt , ( FILE_NOTIFY_CHANGE_FILE_NAME   := 0x1   )
					| ( FILE_NOTIFY_CHANGE_DIR_NAME    := 0x2   )
					| ( FILE_NOTIFY_CHANGE_ATTRIBUTES  := 0x4   )
					| ( FILE_NOTIFY_CHANGE_SIZE        := 0x8   )
					| ( FILE_NOTIFY_CHANGE_LAST_WRITE  := 0x10  )
					| ( FILE_NOTIFY_CHANGE_CREATION    := 0x40  )
					| ( FILE_NOTIFY_CHANGE_SECURITY    := 0x100 )
			, UInt , 0
			, UInt , &Dir%r%Overlapped
			, UInt , 0  )
	Return
}

GetFileIcon(File, SmallIcon := 1) {                                                        	;-- 

    VarSetCapacity(SHFILEINFO, cbFileInfo := A_PtrSize + 688)
    If (DllCall("Shell32.dll\SHGetFileInfoW"
        , "WStr", File
        , "UInt", 0
        , "Ptr" , &SHFILEINFO
        , "UInt", cbFileInfo
        , "UInt", 0x100 | SmallIcon)) { ; SHGFI_ICON
        Return NumGet(SHFILEINFO, 0, "Ptr")
    }
}

ExtractAssociatedIcon(ByRef ipath, ByRef idx) {										;-- Extracts the associated icon's index for the file specified in path

	; http://msdn.microsoft.com/en-us/library/bb776414(VS.85).aspx
	; shell32.dll
	; Extracts the associated icon's index for the file specified in path
	; Requires path and icon index
	; Icon must be destroyed when no longer needed (see below)

		hInst=0	; reserved, must be zero
		hIcon := DllCall("ExtractAssociatedIcon", "UInt", hInst, "UInt", &ipath, "UShortP", idx)
		return ErrorLevel

}

ExtractAssociatedIconEx(ByRef ipath, ByRef idx, ByRef iID) {					;-- Extracts the associated icon's index and ID for the file specified in path

		; http://msdn.microsoft.com/en-us/library/bb776415(VS.85).aspx
		; shell32.dll
		; Extracts the associated icon's index and ID for the file specified in path
		; Requires path, icon index and ID
		; Icon must be destroyed when no longer needed (see below)

			hInst=0	; reserved, must be zero
			hIcon := DllCall("ExtractAssociatedIconEx", "UInt", hInst, "UInt", &ipath, "UShortP", idx, "UShortP", iID)
			return ErrorLevel
}

DestroyIcon(hIcon) {																				;--
	DllCall("DestroyIcon", UInt, hIcon)
}

listfunc(file){																								;-- list all functions inside ahk scripts

	fileread, z, % file
	StringReplace, z, z, `r, , All			; important
	z := RegExReplace(z, "mU)""[^`n]*""", "") ; strings
	z := RegExReplace(z, "iU)/\*.*\*/", "") ; block comments
	z := RegExReplace(z, "m);[^`n]*", "")  ; single line comments
	p:=1 , z := "`n" z
	while q:=RegExMatch(z, "iU)`n[^ `t`n,;``\(\):=\?]+\([^`n]*\)[ `t`n]*{", o, p)
		lst .= Substr( RegExReplace(o, "\(.*", ""), 2) "`n"
		, p := q+Strlen(o)-1

	Sort, lst
	return lst
}

CreateOpenWithMenu(FilePath, Recommended := True, 						;-- creates an 'open with' menu for the passed file.
ShowMenu := False, MenuName := "OpenWithMenu", Others := "Others") {

	; ==================================================================================================================================
	; Creates an 'open with' menu for the passed file.
	; Parameters:
	;     FilePath    -  Fully qualified path of a single file.
	;     Recommended -  Show only recommended apps (True/False).
	;                    Default: True
	;     ShowMenu    -  Immediately show the menu (True/False).
	;                    Default: False
	;     MenuName    -  The name of the menu.
	;                    Default: OpenWithMenu
	;     Others      -  Name of the submenu holding not recommended apps (if Recommended has been set to False).
	;                    Default: Others
	; Return values:
	;     On success the function returns the menu's name unless ShowMenu has been set to True.
	;     If the menu couldn't be created, the function returns False.
	; Remarks:
	;     Requires AHK 1.1.23.07+ and Win Vista+!!!
	;     The function registers itself as the menu handler.
	; Credits:
	;     Based on code by querty12 -> autohotkey.com/boards/viewtopic.php?p=86709#p86709.
	;     I hadn't even heard anything about the related API functions before.
	; MSDN:
	;     SHAssocEnumHandlers -> msdn.microsoft.com/en-us/library/bb762109%28v=vs.85%29.aspx
	;     SHCreateItemFromParsingName -> msdn.microsoft.com/en-us/library/bb762134%28v=vs.85%29.aspx
	; ==================================================================================================================================


   Static RecommendedHandlers := []
        , OtherHandlers := []
        , HandlerID := A_TickCount
        , HandlerFunc := 0
        , ThisMenuName := ""
        , ThisOthers := ""
   ; -------------------------------------------------------------------------------------------------------------------------------
   Static IID_IShellItem := 0, BHID_DataObject := 0, IID_IDataObject := 0
        , Init := VarSetCapacity(IID_IShellItem, 16, 0) . VarSetCapacity(BHID_DataObject, 16, 0)
          . VarSetCapacity(IID_IDataObject, 16, 0)
          . DllCall("Ole32.dll\IIDFromString", "WStr", "{43826d1e-e718-42ee-bc55-a1e261c37bfe}", "Ptr", &IID_IShellItem)
          . DllCall("Ole32.dll\IIDFromString", "WStr", "{B8C0BD9F-ED24-455c-83E6-D5390C4FE8C4}", "Ptr", &BHID_DataObject)
          . DllCall("Ole32.dll\IIDFromString", "WStr", "{0000010e-0000-0000-C000-000000000046}", "Ptr", &IID_IDataObject)
   ; -------------------------------------------------------------------------------------------------------------------------------
   ; Handler call
   If (Recommended = HandlerID) {
      AssocHandlers := A_ThisMenu = ThisMenuName ? RecommendedHandlers : OtherHandlers
      If (AssocHandler := AssocHandlers[A_ThisMenuItemPos]) && FileExist(FilePath) {
         AssocHandlerInvoke := NumGet(NumGet(AssocHandler + 0, "UPtr"), A_PtrSize * 8, "UPtr")
         If !DllCall("Shell32.dll\SHCreateItemFromParsingName", "WStr", FilePath, "Ptr", 0, "Ptr", &IID_IShellItem, "PtrP", Item) {
            BindToHandler := NumGet(NumGet(Item + 0, "UPtr"), A_PtrSize * 3, "UPtr")
            If !DllCall(BindToHandler, "Ptr", Item, "Ptr", 0, "Ptr", &BHID_DataObject, "Ptr", &IID_IDataObject, "PtrP", DataObj) {
               DllCall(AssocHandlerInvoke, "Ptr", AssocHandler, "Ptr", DataObj)
               ObjRelease(DataObj)
            }
            ObjRelease(Item)
         }
      }
      Try Menu, %ThisMenuName%, DeleteAll
      For Each, AssocHandler In RecommendedHandlers
         ObjRelease(AssocHandler)
      For Each, AssocHandler In OtherHandlers
         ObjRelease(AssocHandler)
      RecommendedHandlers:= []
      OtherHandlers:= []
      Return
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   ; User call
   If !FileExist(FilePath)
      Return False
   ThisMenuName := MenuName
   ThisOthers := Others
   SplitPath, FilePath, , , Ext
   For Each, AssocHandler In RecommendedHandlers
      ObjRelease(AssocHandler)
   For Each, AssocHandler In OtherHandlers
      ObjRelease(AssocHandler)
   RecommendedHandlers:= []
   OtherHandlers:= []
   Try Menu, %ThisMenuName%, DeleteAll
   Try Menu, %ThisOthers%, DeleteAll
   ; Try to get the default association
   Size := VarSetCapacity(FriendlyName, 520, 0) // 2
   DllCall("Shlwapi.dll\AssocQueryString", "UInt", 0, "UInt", 4, "Str", "." . Ext, "Ptr", 0, "Str", FriendlyName, "UIntP", Size)
   HandlerID := A_TickCount
   HandlerFunc := Func(A_ThisFunc).Bind(FilePath, HandlerID)
   Filter := !!Recommended ; ASSOC_FILTER_NONE = 0, ASSOC_FILTER_RECOMMENDED = 1
   ; Enumerate the apps and build the menu
   If DllCall("Shell32.dll\SHAssocEnumHandlers", "WStr", "." . Ext, "UInt", Filter, "PtrP", EnumHandler)
      Return False
   EnumHandlerNext := NumGet(NumGet(EnumHandler + 0, "UPtr"), A_PtrSize * 3, "UPtr")
   While (!DllCall(EnumHandlerNext, "Ptr", EnumHandler, "UInt", 1, "PtrP", AssocHandler, "UIntP", Fetched) && Fetched) {
      VTBL := NumGet(AssocHandler + 0, "UPtr")
      AssocHandlerGetUIName := NumGet(VTBL + 0, A_PtrSize * 4, "UPtr")
      AssocHandlerGetIconLocation := NumGet(VTBL + 0, A_PtrSize * 5, "UPtr")
      AssocHandlerIsRecommended := NumGet(VTBL + 0, A_PtrSize * 6, "UPtr")
      UIName := ""
      If !DllCall(AssocHandlerGetUIName, "Ptr", AssocHandler, "PtrP", StrPtr, "UInt") {
         UIName := StrGet(StrPtr, "UTF-16")
         DllCall("Ole32.dll\CoTaskMemFree", "Ptr", StrPtr)
      }
      If (UIName <> "") {
         If !DllCall(AssocHandlerGetIconLocation, "Ptr", AssocHandler, "PtrP", StrPtr, "IntP", IconIndex := 0, "UInt") {
            IconPath := StrGet(StrPtr, "UTF-16")
            DllCall("Ole32.dll\CoTaskMemFree", "Ptr", StrPtr)
         }
         If (SubStr(IconPath, 1, 1) = "@") {
            VarSetCapacity(Resource, 4096, 0)
            If !DllCall("Shlwapi.dll\SHLoadIndirectString", "WStr", IconPath, "Ptr", &Resource, "UInt", 2048, "PtrP", 0)
               IconPath := StrGet(&Resource, "UTF-16")
         }
         ItemName := StrReplace(UIName, "&", "&&")
         If (Recommended || !DllCall(AssocHandlerIsRecommended, "Ptr", AssocHandler, "UInt")) {
            If (UIName = FriendlyName) {
               If RecommendedHandlers.Length() {
                  Menu, %ThisMenuName%, Insert, 1&, %ItemName%, % HandlerFunc
                  RecommendedHandlers.InsertAt(1, AssocHandler)
               }
               Else {
                  Menu, %ThisMenuName%, Add, %ItemName%, % HandlerFunc
                  RecommendedHandlers.Push(AssocHandler)
               }
               Menu, %ThisMenuName%, Default, %ItemName%
            }
            Else {
               Menu, %ThisMenuName%, Add, %ItemName%, % HandlerFunc
               RecommendedHandlers.Push(AssocHandler)
            }
            Try Menu, %ThisMenuName%, Icon, %ItemName%, %IconPath%, %IconIndex%
         }
         Else {
            Menu, %ThisOthers%, Add, %ItemName%, % HandlerFunc
            OtherHandlers.Push(AssocHandler)
            Try Menu, %ThisOthers%, Icon, %ItemName%, %IconPath%, %IconIndex%
         }
      }
      Else
         ObjRelease(AssocHandler)
   }
   ObjRelease(EnumHandler)
   ; All done
   If !RecommendedHandlers.Length() && !OtherHandlers.Length()
      Return False
   If OtherHandlers.Length()
      Menu, %ThisMenuName%, Add, %ThisOthers%, :%ThisOthers%
   If (ShowMenu)
      Menu, %ThisMenuName%, Show
   Else
      Return ThisMenuName
}

FileCount(filter) {																						;-- count matching files in the working directory

   loop,files,%filter%
     Count := A_Index
   return Count

}

GetImageTypeW(File) {																			;-- Identify the image type (UniCode)

/* Description: Identify the image type

	; AHK version: B:1.0.48.5 L:1.0.92.0
	; Language: Chinese/English, Platform: Win7, Author: Pirate <healthlolicon@gmail.com>,

	;Type 0 Unknow
	;Type 1 BMP *.bmp
	;Type 2 JPEG *.jpg *.jpeg
	;Type 3 PNG *.png
	;Type 4 gif *.gif
	;Type 5 TIFF *.tif

*/


	hFile:=FileOpen(File,"r")
	hFile.seek(0)
	FileHead_hex:=hfile.ReadUint()
	hFile.Close()

	If FileHead_hex = 0x474E5089; small end of the actual data is 89 50 4E 47 under the same PNG file header actually has 8 bytes
	    Type=3 ; png
	Else If FileHead_hex=0x38464947 ; gif file header 6 bytes
	    Type=4 ; gif
	Else
	{
	    Filehead_hex&=0xFFFF
	    If FileHead_hex=0x4D42; BMP file header only 2 bytes
	        Type=1 ; bmp
	    Else if FileHead_hex=0xD8FF ; JPG file header is only 2 bytes
	        Type=2 ; jpg/jpeg
	    Else If FileHead_hex=0x4949 ; TIFF file header 2 bytes II
	        Type=5 ; tif
	    Else If FileHead_hex=0x4D4D ;MM
	        Type=5 ; tif
	    Else
	        Type=0 ; Unknow
	    }

Return,Type
}

FileWriteLine( _File, _Data = "", _Linenum = 1, _Replace = true ) {     		;-- to write data at specified line in a file.

    FileRead, _FileData, % _File
    _DataBefore := Substr( _FileData, 1, Instr( _FileData, "`r`n", false, 1, _Linenum - 1 ) )
    _DataAfter := Substr( _FileData, Instr( _FileData, "`r`n", false, 1, ( _Replace ? _Linenum : _Linenum - 1 ) ) )
    _FileData := _DataBefore . _Data . _DataAfter
    FileDelete, % _File
    FileAppend, % _FileData, % _File
}

FileMD5( sFile = "", cSz = 4 ) {            														;-- file MD5 hashing

    cSz := ( cSz<0 || cSz>8 ) ? 2**22 : 2**( 18+cSz ), VarSetCapacity( Buffer, cSz, 0 )
    hFil := DllCall( "CreateFile", Str, sFile, UInt, 0x80000000, Int, 1, Int, 0, Int, 3, Int, 0, Int, 0 )
    IfLess, hFil, 1, return, hFil
    DllCall( "GetFileSizeEx", UInt, hFil, Str, Buffer ), fSz := NumGet( Buffer, 0, "Int64" )
    VarSetCapacity( MD5_CTX, 104, 0 ), DllCall( "advapi32\MD5Init", Str, MD5_CTX )
    Loop % ( fSz//cSz+!!Mod( fSz, cSz ) )
        DllCall( "ReadFile", UInt, hFil, Str, Buffer, UInt, cSz, UIntP, bytesRead, UInt, 0 )
        , DllCall( "advapi32\MD5Update", Str, MD5_CTX, Str, Buffer, UInt, bytesRead )
    DllCall( "advapi32\MD5Final", Str, MD5_CTX ), DllCall( "CloseHandle", UInt, hFil )
    Loop % StrLen( Hex := "123456789ABCDEF0" )
        N := NumGet( MD5_CTX, 87+A_Index, "Char" ), MD5 .= SubStr( Hex, N>>4, 1 ) . SubStr( Hex, N&15, 1 )
    return MD5
}

FileCRC32(sFile="",cSz=4) {																		;-- computes and returns CRC32 hash for a File passed as parameter

	; by SKAN www.autohotkey.com/community/viewtopic.php?t=64211
	cSz := (cSz<0||cSz>8) ? 2**22 : 2**(18+cSz), VarSetCapacity( Buffer,cSz,0 ) ; 10-Oct-2009
	hFil := DllCall( "CreateFile", Str,sFile,UInt,0x80000000, Int,3,Int,0,Int,3,Int,0,Int,0 )
	IfLess,hFil,1, Return,hFil
	hMod := DllCall( "LoadLibrary", Str,"ntdll.dll" ), CRC32 := 0
	DllCall( "GetFileSizeEx", UInt,hFil, UInt,&Buffer ),    fSz := NumGet( Buffer,0,"Int64" )
	Loop % ( fSz//cSz + !!Mod( fSz,cSz ) )
		DllCall( "ReadFile", UInt,hFil, UInt,&Buffer, UInt,cSz, UIntP,Bytes, UInt,0 )
		, CRC32 := DllCall( "NTDLL\RtlComputeCrc32", UInt,CRC32, UInt,&Buffer, UInt,Bytes, UInt )
	DllCall( "CloseHandle", UInt,hFil )
	SetFormat, Integer, % SubStr( ( A_FI := A_FormatInteger ) "H", 0 )
	CRC32 := SubStr( CRC32 + 0x1000000000, -7 ), DllCall( "CharUpper", Str,CRC32 )
	SetFormat, Integer, %A_FI%
	Return CRC32, DllCall( "FreeLibrary", UInt,hMod )
}

FindFreeFileName(FilePath) {																	;-- Finds a non-existing filename for Filepath by appending a number in brackets to the name
	
	SplitPath, FilePath,, dir, extension, filename
	Testpath := FilePath ;Return path if it doesn't exist
	i := 1
	while FileExist(TestPath)
	{
		i++
		Testpath := dir "\" filename " (" i ")" (extension = "" ? "" : "." extension)
	}
	return TestPath
}

CountFilesR(Folder) {																				;-- count files recursive in specific folder (uses COM method)
	static Counter=0,  fso
	fso := fso?fso:ComObjCreate("Scripting.FileSystemObject")
	Folder := fso.GetFolder(Folder)	, Counter += Counter?0:CountFiles(Folder.path)
	For Subfolder in Folder.SubFolders
		Counter += CountFiles(Subfolder.path) , CountFilesR(Subfolder.path)
	return Counter
}

CountFiles(Folder) {                                                                             	;-- count files in specific folder (uses COM method)
	fso := ComObjCreate("Scripting.FileSystemObject")
	Folder := fso.GetFolder(Folder)
	return fso.GetFolder(Folder).Files.Count
}

PathInfo(ByRef InputVar) {																		;-- splits a given path to return as object
	SplitPath, InputVar, f, d, e, n, dr
	return	Object("FileName",f,"Dir",d,"Extension",e,"NameNoExt",n,"Drive",dr)
}

DriveSpace(Drv="", Free=1) { 																	;-- retrieves the DriveSpace
	; www.autohotkey.com/forum/viewtopic.php?p=92483#92483
	Drv := Drv . ":\",  VarSetCapacity(SPC, 30, 0), VarSetCapacity(BPS, 30, 0)
	VarSetCapacity(FC , 30, 0), VarSetCapacity(TC , 30, 0)  
	DllCall( "GetDiskFreeSpaceA", Str,Drv, UIntP,SPC, UIntP,BPS, UIntP,FC, UIntP,TC )
	Return Free=1 ? (SPC*BPS*FC) : (SPC*BPS*TC) ; Ternary Operator requires 1.0.46+
}

GetBinaryType(FileName) {																		;-- determines the bit architecture of an executable program
  IfNotExist, %FileName%, Return "File not found"
  Binary:=DllCall("GetBinaryType","Str", FileName, "UInt *", RetVal)
  IfEqual, Binary, 0, Return "Not Executable"
  BinaryTypes := "32-Bit|DOS|16-Bit|PIF|POSIX|OS2-16-Bit|64-Bit"
  StringSplit, BinaryType , BinaryTypes, |
  BinaryType:="BinaryType" . RetVal + 1
Return (%BinaryType%)
}

GetFileAttributes(Filename, ByRef Attrib := "", ByRef Path := "", ByRef Type := "") {																			;-- get attributes of a file or folder
	
	/*                              	DESCRIPTION
	
			get attributes of a file or folder
			Syntax: GetFileAttributes ([File / Folder], [out Attrib], [out Path], [out Type])
			Parameters:
			Attrib: returns a value that reproduces the attributes.
			Path: returns the complete path.
			Type: if it is a file, it returns "F", if it is a directory it returns "D".
			Return:
			0 = ERROR
			[attributes] = OK
			R = read only
			A = file | modified
			S = system
			H = hidden
			N = normal
			O = offline
			T = temporary
			C = compressed
			D = directory | binder
			E = encrypted
			V = virtual
			
	*/
	
	
	Path := GetFullPathName(Filename), Path := (StrLen(Path) > 260 ? "\\?\" : "") Path (StrLen(Path) > 2 ? "" : "\")
	if ((Attrib := DllCall("Kernel32.dll\GetFileAttributesW", "Ptr", &Path)) = -1)
		return false
	for k, v in {"R": 0x1, "A": 0x20, "S": 0x4, "H": 0x2, "N": 0x80, "D": 0x10, "O": 0x1000, "C": 0x800, "T": 0x100, "E": 0x4000, "V": 0x10000}
		if (Attrib & v)
			OutputVar .= k
	if IsByRef(Type)
		Type := Attrib&0x10?"D":"F"
	return OutputVar
}

SetFileTime(Time := "", FilePattern := "", WhichTimeMCA := "M", OperateOnFolders := false, Recurse := false) {								;-- to set the time
	if IsObject(Time)
		for k, v in Time
			FileSetTime, %v%, %FilePattern%, % k=1?"M":k=2?"C":k=3?"A":k, %OperateOnFolders%, %Recurse%
	else Loop, Parse, % WhichTimeMCA
		FileSetTime, %Time%, %FilePattern%, %A_LoopField%, %OperateOnFolders%, %Recurse%
	return !ErrorLevel
}

SetFileAttributes(Attributes, Filename, Mode := "FD") {																														;-- set attributes of a file or folder
	
	/*                              	DESCRIPTION
	
				change attribute (s) to folder (s) and / or file (s).
				Syntax: SetFileAttributes ([/ - / Attrib], [Filename], [Mode])
				Parameters:
				Mode: F = include files | D = include directories | R = include subdirectories.
				Attrib: specify one or more of the following letters. to remove use "-", to add use "", to alternate use ", to replace do not specify anything.
							R = read only
							A = file | modified
							S = system
							H = hidden
							N = normal
							O = offline
							T = temporary
							[value] = specify a value that represents the attributes to replace.
							Example: MsgBox% SetFileAttributes ("HS-R?", A_Desktop "\ test.txt")
			
	*/
	
	
	static A := {R: 0x1, A: 0x20, S: 0x4, H: 0x2, N: 0x80, O: 0x1000, T: 0x100}
	if InStr(Mode, "R") || InStr(Filename, "*") || InStr(Filename, "?") {
		Loop, Files, % Filename, % Mode
			Ok += !!SetFileAttributes(Attributes, A_LoopFileFullPath)
		return Ok
	} if !StrLen(Attributes + 0) {
		if (GetFileAttributes(Filename, Attrib, Filename) = 0)
			return false
		Loop, Parse, % Attributes,, % A_Space A_Tab
			if A[A_LoopField]
				Attrib := _cvtvalue(Attrib, P A[A_LoopField])
			else P := A_LoopField
	} else Attrib := Attributes, Filename := (StrLen(Filename) > 260 ? "\\?\" : "") Filename
	return DllCall("Kernel32.dll\SetFileAttributesW", "Ptr",  &Filename, "UInt", Attrib)
}

FileSetSecurity(Path, Trustee := "", AccessMask := 0x1F01FF, Flags := 1, AccesFlag := 0) { 																;--  set security for the file / folder
	
	/*                              	DESCRIPTION
	
			; set security for the file / folder
			; Syntax: FileSetSecurity ([file], [User], [permissions], [options], [access])
			; Parameters:
			; File: specify the file or folder to modify
			; User: specify the SID of the user that inherits the permissions or Domain \ User. if not specified, use the current user
			; Note: to obtain a list of users with information, use UserAccountsEnum ()
			; Permissions: specify the desired access
			; 0x1F01FF = TOTAL CONTROL (F)
			; 0x120089 = READING (R)
			; 0x120116 = WRITING (W)
			; 0x1200a0 = EXECUTION (X)
			; 0x00010000 = DISPOSAL (D)
			; 0x1301BF = MODIFICATION (M)
			; Options:
			; 0 = directories
			; 1 = directories and files
			; 2 = directories and sub-directories
			; 3 = directories, sub-directories and files
			; Access: https://msdn.microsoft.com/en-us/library/windows/desktop/aa772244(v=vs.85).aspx
			; 0 = allow
			; 1 = deny
			;Notes:
			; permissions can be viewed by clicking on file properties, security tab.
			; permissions can be changed with ICACLS in CMD: icacls [file] / grant * [user]: ([permissions, letter], WDAC)
			; the function sets the owner, since it is required to change the permissions
			The invoking process must have administrator permissions to modify the permissions
			;Example:
			; MsgBox% "Take Ownership:" FileSetOwner (A_SysDir () "\ calc.exe") first take ownership
			; MsgBox% "Total Control:" FileSetSecurity (A_SysDir () "\ calc.exe"); second modify permissions
			; Return: 0 | 1
			
	*/
	
	
	Trustee := Trustee=""?A_UserNameEx():Trustee, Path := GetFullPathName(Path)
	, oADsSecurityUtility := ComObjCreate("ADsSecurityUtility")
	, oADsSecurityDescriptor := oADsSecurityUtility.GetSecurityDescriptor(Path, 1, 1)
	, Owner := oADsSecurityDescriptor.Owner
	if !(Trustee=Owner) && !(Owner="") && !(Trustee="")
		FileSetOwner(Path, Trustee)
	oDiscretionaryAcl := oADsSecurityDescriptor.DiscretionaryAcl
	, oAccessControlEntry := ComObjCreate("AccessControlEntry")
	, oAccessControlEntry.Trustee := Trustee
	, oAccessControlEntry.AccessMask := AccessMask
	, oAccessControlEntry.AceFlags := Flags
	, oAccessControlEntry.AceType := AccesFlag
	, oDiscretionaryAcl.AddAce(oAccessControlEntry)
	, oADsSecurityUtility.SetSecurityDescriptor(Path, 1, oADsSecurityDescriptor, 1)
}

FileSetOwner(Path, Owner := "") {																																						;-- set the owner to file / directory
	
	/*                              	DESCRIPTION
	
			; set the owner to file / directory
			; Syntax: FileSetOwner ([file], [user])
			; Parameters:
			; User: specify the domain \ user or user's SID. by default it uses the current user.
			
	*/
	
	
	Owner := Owner=""?A_UserNameEx():Owner
	, oADsSecurityUtility := ComObjCreate("ADsSecurityUtility")
	, oADsSecurityUtility.SecurityMask := 0x1
	, oADsSecurityDescriptor := oADsSecurityUtility.GetSecurityDescriptor(Path:=GetFullPathName(Path), 1, 1)
	, oADsSecurityDescriptor.Owner := Owner
	, oADsSecurityUtility.SetSecurityDescriptor(Path, 1, oADsSecurityDescriptor, 1)
}

FileGetOwner(Path) { 																																											;-- get the owner to file / directory
	
	/*                              	DESCRIPTION
	
			get the domain and username
			; Syntax: FileGetOwner ([file])
			; Return: domain \ user
			
	*/
	
	
	oADsSecurityUtility := ComObjCreate("ADsSecurityUtility")
	, oADsSecurityUtility.SecurityMask := 0x1
	, oADsSecurityDescriptor := oADsSecurityUtility.GetSecurityDescriptor(GetFullPathName(Path), 1, 1)
	return oADsSecurityDescriptor.Owner
}


} 
;|														|														|														|														|
;|	 InvokeVerb()								|	Function_Eject()							|	FileGetDetail()								|	FileGetDetails()							|
;|	 DirExist()										|	GetDetails()									|	Start()	             							|	IsFileEqual()									|
;|	 WatchDirectory()	x 2				|	GetFileIcon()									| 	ExtractAssociatedIcon()				|	ExtractAssociatedIconEx()				|
;|	 DestroyIcon()								|	listfunc()										|	CreateOpenWithMenu()				|	FileCount()									|
;|	 IdentifyImageTypW()					|	FileWriteLine()								|	FileMD5()										|   FileCRC32()                              	|
;|   FindFreeFileName()                 	|   CountFilesR()                            	|   CountFiles()                              	|   PathInfo()                                   	|
;|	 DriveSpace()                           	|   GetBinaryType()                         	|   GetFileAttributes()                    	|   SetFileTime()                          	 	|
;|	 SetFileAttributes()                   	|   FileSetSecurity()                         	|   FileSetOwner()                          	|   FileGetOwner()                         	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;Font things (6)
;1
CreateFont(pFont="") {                                                                                                                     	;-- creates font in memory which can be used with any API function accepting font handles

	;a function by majkinetor
	;https://autohotkey.com/board/topic/21003-function-createfont/
	/*			DESCRIPTION
	
	--------------------------------------------------------------------------
	 Function:  CreateFont
				 Creates font in memory which can be used with any API function accepting font handles.
	
	 Parameters: 
				pFont	- AHK font description, "style, face"
	
	 Returns:
				Font handle
	
	 Example:
	>			hFont := CreateFont("s12 italic, Courier New")
	>			SendMessage, 0x30, %hFont%, 1,, ahk_id %hGuiControl%  WM_SETFONT = 0x30
	
	*/

	;parse font 
	italic      := InStr(pFont, "italic")    ?  1    :  0 
	underline   := InStr(pFont, "underline") ?  1    :  0 
	strikeout   := InStr(pFont, "strikeout") ?  1    :  0 
	weight      := InStr(pFont, "bold")      ? 700   : 400 

	;height 
	RegExMatch(pFont, "(?<=[S|s])(\d{1,2})(?=[ ,])", height)
	if (height = "")
	  height := 10
	RegRead, LogPixels, HKEY_LOCAL_MACHINE, SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontDPI, LogPixels
	height := -DllCall("MulDiv", "int", Height, "int", LogPixels, "int", 72)

	;face 
	RegExMatch(pFont, "(?<=,).+", fontFace)
	if (fontFace != "")
	   fontFace := RegExReplace( fontFace, "(^\s*)|(\s*$)")      ;trim
	else fontFace := "MS Sans Serif"

	;create font
	hFont   := DllCall("CreateFont", "int",  height, "int",  0, "int",  0, "int", 0
					  ,"int",  weight,   "Uint", italic,   "Uint", underline
					  ,"uint", strikeOut, "Uint", nCharSet, "Uint", 0, "Uint", 0, "Uint", 0, "Uint", 0, "str", fontFace)

	return hFont
}
;2
GetHFONT(Options := "", Name := "") {																								;-- gets a handle to a font used in a AHK gui for example
   
   ; source: https://github.com/aviaryan/Clipjump/blob/master/lib/anticj_func_labels.ahk
   ; dependings: no
   
   Gui, New
   Gui, Font, % Options, % Name
   Gui, Add, Text, +hwndHTX, Dummy
   HFONT := DllCall("User32.dll\SendMessage", "Ptr", HTX, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "UPtr") ; WM_GETFONT
   Gui, Destroy
   Return HFONT
}
;3
MsgBoxFont(Fontstring, title, msg) {                                                                                               	;-- style your MsgBox with with your prefered font
; https://autohotkey.com/board/topic/21003-function-createfont/
hFont := CreateFont("s14 italic, Courier New")
	SetTimer, OnTimer, -30
	MsgBox, , %title%, %msg% 

return

OnTimer:
	ControlGet, h, HWND, , Static1, My MsgBox
	SendMessage, 0x30, %hFont%, 1,, ahk_id %h%  ;WM_SETFONT = 0x30 
return
}
;4
GetFontProperties(HFONT) {																												;-- to get the current font's width and height
	
	/*                              	DESCRIPTION
	
			Link: https://autohotkey.com/boards/viewtopic.php?t=1979
			
	*/
	/*                              	EXAMPLE(s)
	
			NoEnv
			   WM_GETFONT := 0x31
			   Gui, Margin, 20, 20
			   Gui, Add, Edit, w400 r5 hwndHED, Edit
			   Gui, Show, , Test
			   SendMessage, %WM_GETFONT%, 0, 0, , ahk_id %HED%
			   Font := GetFontProperties(ErrorLevel)
			   MsgBox, 0, % Font.FaceName, % "Height: " . Font.Height . " - Width: " . Font.Width
			Return
			GuiClose:
			ExitApp
			
	*/
		
   ; LOGFONT -> http://msdn.microsoft.com/en-us/library/dd145037%28v=vs.85%29.aspx
   VarSetCapacity(LF, (4 * 5) + 8 + 64) ; LOGFONT Unicode
   Size := DllCall("Gdi32.dll\GetObject", "Ptr", HFONT, "Int", Size, "Ptr", 0)
   DllCall("Gdi32.dll\GetObject", "Ptr", HFONT, "Int", Size, "Ptr", &LF)
   Font := {}
   Font.Height := Round(Abs(NumGet(LF, 0, "Int")) * 72 / A_ScreenDPI, 1)
   Font.Width := Round(Abs(NumGet(LF, 4, "Int")) * 72 / A_ScreenDPI, 1)
   Font.Escapement := NumGet(LF, 8, "Int")
   Font.Orientation := NumGet(LF, 12, "Int")
   Font.Weight := NumGet(LF, 16, "Int")
   Font.Italic := NumGet(LF, 20, "UChar")
   Font.Underline := NumGet(LF, 21, "UChar")
   Font.StrikeOut := NumGet(LF, 22, "UChar")
   Font.CharSet := NumGet(LF, 23, "UChar")
   Font.OutPrecision := NumGet(LF, 24, "UChar")
   Font.ClipPrecision := NumGet(LF, 25, "UChar")
   Font.Quality := NumGet(LF, 26, "UChar")
   Font.PitchAndFamily := NumGet(LF, 27, "UChar")
   Font.FaceName := StrGet(&LF + 28, 32)
   Return Font
}
;5
FontEnum(lfCharSet := 1, FontName := "") {																						;-- enumerates all uniquely-named fonts in the system that match the font characteristics specified by the LOGFONT structure
	/*                              	DESCRIPTION
	
			SOURCES Parameters:
			hFont: 				specify an identifier to a font, you can use FontCreate (). leave it at zero to use the default font.
			FontName: 		name of the source.
			lf CharSet: 		script, value that identifies the set of characters lists all installed sources.
			Syntax: 			FontEnum ([lfCharSet], [FontName])Example:for k, v in FontEnum ()		
			
			Example
			MsgBox % vNote: to check if a font exists, use the parameters lfCharSet and FontName, if it is not found, return an empty string. 
			
	*/
	
	
	hDC := GetDC(), VarSetCapacity(LOGFONT, 92, 0), NumPut(lfCharSet, LOGFONT, 23, "UChar")
	if StrLen(FontName)
		StrPut(FontName, &LOGFONT + 28)
	Address := RegisterCallback("EnumFontFamExProc", "Fast", 4), Data := {List: []}
	, DllCall("Gdi32.dll\EnumFontFamiliesExW", "Ptr", hDC, "Ptr", &LOGFONT, "Ptr", Address, "Ptr", &Data, "UInt", 0)
	return Data.List, ReleaseDC(0, hDC), GlobalFree(Address)
} EnumFontFamExProc(LOGFONT, lpntme, FontType, Data) {
	Data := Object(Data), FontName := StrGet(LOGFONT + 28)
	if !InArray(Data.List, FontName) ;remover fuentes duplicadas
		Data.List.Push(FontName)
	return true
} ;https://msdn.microsoft.com/en-us/library/dd162620(v=vs.85).aspx
;6
GetFontTextDimension(hFont, Text, ByRef Width := "", ByRef Height := "", c := 1) {							;-- calculate the height and width of the text in the specified font 
	/*                              	DESCRIPTION
	
			Syntax: GetFontTextDimension( [hFont], [Text], [out Width], [out Height] )
			Returns: 0|1
			
	*/
	hFont := hFont?hFont:GetStockObject(17), hDC := GetDC()
	, hSelectObj := SelectObject(hDC, hFont), VarSetCapacity(SIZE, 8, 0)
	if !DllCall("Gdi32.dll\GetTextExtentPoint32W", "Ptr", hDC, "Ptr", &Text, "Int", StrLen(Text), "Ptr", &SIZE, "Int")
		return false, ReleaseDC(0, hDC), Width := Height := 0
	VarSetCapacity(TEXTMETRIC, 60, 0)
	if !DllCall("Gdi32.dll\GetTextMetricsW", "Ptr", hDC, "Ptr", &TEXTMETRIC, "Int") ;https://msdn.microsoft.com/en-us/library/dd144941(v=vs.85).aspx
		return false, ReleaseDC(0, hDC), Width := Height := 0
	SelectObject(hDC, hSelectObj), ReleaseDC(0, hDC), Width := NumGet(SIZE, 0, "Int"), Height := NumGet(SIZE, 4, "Int")
	, Width := Width + NumGet(TEXTMETRIC, 20, "Int") * 3
	, Height := Floor((NumGet(TEXTMETRIC, 0, "Int")*c)+(NumGet(TEXTMETRIC,16, "Int")*(Floor(c+0.5)-1))+0.5)+8
	return true
} ;https://msdn.microsoft.com/en-us/library/dd144938(v=vs.85).aspx

}
;|														|														|														|														|
;| 	CreateFont()                             	|   GetHFONT()                              	|   MsgBoxFont()                            	|   GetFontProperties()                   	|
;|   FontEnum()                              	|   GetFontTextDimension()           	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;Hooks-Messaging (7)

OnMessageEx(MsgNumber, params*) {												;-- Allows multiple functions to be called automatically when the script receives the specified message

    ;version 1.0.2 by A_Samurai http://sites.google.com/site/ahkref/custom-functions/onmessageex

	/*													Description

		Allows multiple functions to be called automatically when the script receives the specified message.

		Remarks
		The parameter, MaxThreads, of the original OnMessage() function is not supported.

		Requirements
		AutoHotkey_L 1.0.97.00 or later.  Tested on: Windows 7 64bit, AutoHotkey 32bit Unicode 1.1.05.01.

		License
		Public Domain.

		Format
		OnMessageEx(MsgNumber, FunctionName=False, Priority=1)

		Parameters
		MsgNumber: 	same as the first parameter of OnMessage()
		FunctionName: 	same as the second parameter of OnMessage(). To remove the function from monitoring the system message, specify 0 in the
								next parameter Priority. To remove the function in lowest priority from monitoring the system message, specify "" (blank).
		Object Method: [v1.0.1+] In order to specify an object method, pass an array consisting of three elements. e.g. [&myobj, "MyMethod", False]
		Object Address: the address of the object. It can be retrieved with the & operator. e.g. &myobj
		MethodName: 	the name of the method.
		AutoRemove: 	decides whether to remove the method if the object no longer exists. True to enable it; otherwise, set it to False. False by default.
		Priority: 			specify a whole number to set the priority of the registering function to be called. 1 is the highest and as the number increases
								the priority gets lowered. 0 is to remove the function from the list.

		Return Value

		If FunctionName and Priority is omitted, it returns the name of the function of the lowest priority in the function list. If FunctionName is explicitly
		blank (e.g. ""), it returns the name of the removed function. If FunctionName has a value and Priority is set to 0, it returns the name of the
		removed function. If FunctionName has a value and it is successfully added in the function list, it returns the name of the function of the highest
		priority in the list before the new function is added.

	*/

	/*													Examples

		#Persistent
		Gui, Font, s20
		Gui, Margin, 30, 30
		Gui, Add, Text,, Click Here
		Gui, Show
		OnMessage(0x200, "MyFuncA")     ;a function registered via OnMessage() will be added in the list when OnMessageEx() is called for the first time.
		OnMessageEx(0x200, "MyFuncB")
		OnMessageEx(0x200, "MyFuncC")
		OnMessageEx(0x201, "MyFuncD")
		OnMessageEx(0x201, "MyFuncE")
		OnMessageEx(0x201, "MyFuncF")
		OnMessageEx(0x201, "MyFuncD")   ;a duplicated item will be removed and the function is inserted again
		Return
		GuiClose:
		ExitApp

		F1::msgbox % "Function Removed: " OnMessageEx(0x200, "")    ;removes the function in the lowest priority for 0x200
		F2::msgbox % "Function Removed: " OnMessageEx(0x201, "")    ;removes the function in the lowest priority for 0x201
		F3::msgbox % "The lowest priority function for 0x200 is: " OnMessageEx(0x200)
		F4::msgbox % "The lowest priority function for 0x201 is: " OnMessageEx(0x201)
		F5::msgbox % "Function Removed: " OnMessageEx(0x201, "MyFuncF", 0)    ;removes MyFuncF from 0x201

		MyFuncA(wParam, lParam, msg, hwnd) {
			display := A_ThisFunc "`nwParam :`t" wParam "`nlParam :`t`t" lParam "`nMessage :`t" msg "`nHwnd :`t`t" hwnd
			mousegetpos, mousex, mousey
			tooltip, % display, mousex - 200, , 1
			SetTimer, RemoveToolTipA, -1000
			Return
			RemoveToolTipA:
				tooltip,,,,1
			Return
		}
		MyFuncB(wParam, lParam, msg, hwnd) {
			display := A_ThisFunc "`nwParam :`t" wParam "`nlParam :`t`t" lParam "`nMessage :`t" msg "`nHwnd :`t`t" hwnd
			mousegetpos, mousex, mousey
			tooltip, % display, mousex,, 2
			SetTimer, RemoveToolTipB, -1000
			Return
			RemoveToolTipB:
				tooltip,,,,2
			Return
		}
		MyFuncC(wParam, lParam, msg, hwnd) {
			display := A_ThisFunc "`nwParam :`t" wParam "`nlParam :`t`t" lParam "`nMessage :`t" msg "`nHwnd :`t`t" hwnd
			mousegetpos, mousex, mousey
			tooltip, % display, mousex + 200 ,, 3
			SetTimer, RemoveToolTipC, -1000
			Return
			RemoveToolTipC:
				tooltip,,,,3
			Return
		}
		MyFuncD(wParam, lParam, msg, hwnd) {
			display := A_ThisFunc "`nwParam :`t" wParam "`nlParam :`t`t" lParam "`nMessage :`t" msg "`nHwnd :`t`t" hwnd
			mousegetpos, mousex, mousey
			tooltip, % display, mousex - 200, mousey - 80, 4
			SetTimer, RemoveToolTipD, -1000
			Return
			RemoveToolTipD:
				tooltip,,,,4
			Return
		}
		MyFuncE(wParam, lParam, msg, hwnd) {
			display := A_ThisFunc "`nwParam :`t" wParam "`nlParam :`t`t" lParam "`nMessage :`t" msg "`nHwnd :`t`t" hwnd
			mousegetpos, mousex, mousey
			tooltip, % display, mousex, mousey - 80, 5
			SetTimer, RemoveToolTipE, -1000
			Return
			RemoveToolTipE:
				tooltip,,,,5
			Return
		}
		MyFuncF(wParam, lParam, msg, hwnd) {
			display := A_ThisFunc "`nwParam :`t" wParam "`nlParam :`t`t" lParam "`nMessage :`t" msg "`nHwnd :`t`t" hwnd
			mousegetpos, mousex, mousey
			tooltip, % display, mousex + 200 , mousey - 80, 6
			SetTimer, RemoveToolTipF, -1000
			Return
			RemoveToolTipF:
				tooltip,,,,6
			Return
		}

		more example can be found at page linked above

	*/

	Static Functions := {}

    ;determine whether this is an on-message call
    FunctionName := params.1, OnMessage := True, DHW := A_DetectHiddenWindows
    DetectHiddenWindows, ON
    if ObjMaxIndex(params) <> 3            ;if the number of optional parameters are not three
        OnMessage := False
    else if FunctionName not between 0 and 4294967295    ;if the second parameter is not between 0 to 4294967295
        OnMessage := False
    else if !WinExist("ahk_id " params.3)    ;if the third parameter is not an existing Hwnd of a window/control
        OnMessage := False
    DetectHiddenWindows, % DHW

    if !OnMessage {
    ;if the function is manually called,
        Priority := params.2 ? params.2 : (params.2 = 0) ? 0 : 1
        If FunctionName    {
            ;if FunctionName is specified, it means to register it or if the priority is set to 0, remove it

            ;prepare for the function stack object
            Functions[MsgNumber] := Functions[MsgNumber] ? Functions[MsgNumber] : []

            ;check if there is already the same function in the stack object
            For index, oFunction in Functions[MsgNumber] {
                if (oFunction.Func = FunctionName) {
                    oRemoved := ObjRemove(Functions[MsgNumber], Index)
                    Break
                }
            }
            ;if the priority is 0, it means to remvoe the function
            if (Priority = 0)
                Return oRemoved.Func

            ;check if there is a function already registered for this message
            if (PrevFunc := OnMessage(MsgNumber)) && (PrevFunc <> A_ThisFunc) {
                ;this means there is one, so add this function to the stack object
                ObjInsert(Functions[MsgNumber], {Func: PrevFunc, Priority: 1})
            }

            ;find out the priority in each registered function and insert it before the element of the same priority
            IndexToInsert := 1
            For Index, oFunction in Functions[MsgNumber] {
                IndexToInsert := Index
            } Until (oFunction.Priority = Priority)

            ;retrieve the function name in the first priority for the return value
            FirstFunc := Functions[MsgNumber][ObjMinIndex(Functions[MsgNumber])].Func

            ;insert the given function in the function stack object
            if IsObject(FunctionName) {
                ;an object is passed for the second parameter
                ThisObj := Object(FunctionName.1), ThisMethod := FunctionName.2, AutoRemove := ObjHasKey(FunctionName, 3) ? FunctionName.3 : False
                If IsFunc(ThisObj[ThisMethod])    ;chceck if the method exists
                    ObjInsert(Functions[MsgNumber], IndexToInsert, {Func: FunctionName.2, Priority: Priority, ObjectAddress: FunctionName.1, AutoRemove: AutoRemove})
                else         ;if the passed function name is not a function, return false
                    return False
            } else {
                if IsFunc(FunctionName)    ;chceck if the function exists
                    ObjInsert(Functions[MsgNumber], IndexToInsert, {Func: FunctionName, Priority: Priority})
                else        ;if the passed function name is not a function, return false
                    return False
            }

            ;register it
            if (PrevFunc <> A_ThisFunc)
                OnMessage(MsgNumber, A_ThisFunc)

            Return FirstFunc
        } Else if ObjHasKey(params, 1) && (FunctionName = "") {
            ;if FunctionName is explicitly empty, remove the function and return its name

            ;remove the lowest priority function (the last element) in the object of the specified message.
            oRemoved := ObjRemove(Functions[MsgNumber], ObjMaxIndex(Functions[MsgNumber]))

            ;if there are no more registered functions, remove the registration of this function for this message
            if !ObjMaxIndex(Functions[MsgNumber])
                OnMessage(MsgNumber, "")

            Return oRemoved.Func
        } Else     ;return the registered function of the lowest priority for this message
            Return Functions[MsgNumber][ObjMaxIndex(Functions[MsgNumber])].Func
    } Else {
    ;if this is an on-message call,
        wParam := MsgNumber, lParam := params.1, msg := params.2, Hwnd := params.3
        For Index, Function in Functions[msg] {
            ThisFunc := Function.Func
            if ObjHasKey(Function, "ObjectAddress") {
                ;if it is an object method
                ThisObj := Object(Function.ObjectAddress)
                ThisObj[ThisFunc](wParam, lParam, msg, Hwnd)
                if Function.AutoRemove {        ;this means if the method no longer exists, remove it
                    If !IsFunc(ThisFunc) {
                        ObjRemove(Functions[MsgNumber], ThisFunc)

                        ;if there are no more registered functions, remove the registration of this function for this message
                        if !ObjMaxIndex(Functions[MsgNumber])
                            OnMessage(MsgNumber, "")
                    }
                }
            } else     ;if it is a function
                %ThisFunc%(wParam, lParam, msg, Hwnd)
        }
    }
}

ReceiveData(wParam, lParam) {															;--  By means of OnMessage(), this function has been set up to be called automatically whenever new data arrives on the connection.

   global ShowRecieved
   global ReceivedData

   Gui, Submit, NoHide
   socket := wParam

    ReceivedDataSize = 4096 ; Large in case a lot of data gets buffered due to delay in processing previous data.
    Loop  ; This loop solves the issue of the notification message being discarded due to thread-already-running.
    {
        VarSetCapacity(ReceivedData, ReceivedDataSize, 0)  ; 0 for last param terminates string for use with recv().
        ReceivedDataLength := DllCall("Ws2_32\recv", "UInt", socket, "Str", ReceivedData, "Int", ReceivedDataSize, "Int", 0)
        if ReceivedDataLength = 0  ; The connection was gracefully closed,
            ExitApp  ; The OnExit routine will call WSACleanup() for us.
        if ReceivedDataLength = -1
        {
            WinsockError := DllCall("Ws2_32\WSAGetLastError")
            if WinsockError = 10035  ; WSAEWOULDBLOCK, which means "no more data to be read".
                return 1
            if WinsockError <> 10054 ; WSAECONNRESET, which happens when Network closes via system shutdown/logoff.
                ; Since it's an unexpected error, report it.  Also exit to avoid infinite loop.
                MsgBox % "recv() indicated Winsock error " . WinsockError
            ExitApp  ; The OnExit routine will call WSACleanup() for us.
        }
        ; Otherwise, process the data received.
        ; Msgbox %ReceivedData%
        Loop, parse, ReceivedData, `n, `r
        {
           	ReceivedData=%A_LoopField%
           	if (ReceivedData!="")
           	{
				GoSub ParseData
				GoSub UseData
			}
        }
	}
    return 1  ; Tell the program that no further processing of this message is needed.
}

HDrop(fnames,x=0,y=0) {																;-- Drop files to another app

	/*						Description

		Return a handle to a structure describing files to be droped.
		Use it with PostMessage to send WM_DROPFILES messages to windows.
		fnames is a list of paths delimited by `n or `r`n
		x and y are the coordinates where files are droped in the window.
		Eg. :
		; Open autoexec.bat in an existing Notepad window.
		PostMessage, 0x233, HDrop("C:\autoexec.bat"), 0,, ahk_class Notepad
		PostMessage, 0x233, HDrop(A_MyDocuments), 0,, ahk_class MSPaintApp

	*/
	fns:=RegExReplace(fnames,"\n$")
   fns:=RegExReplace(fns,"^\n")
   hDrop:=DllCall("GlobalAlloc","UInt",0x42,"UInt",20+StrLen(fns)+2)
   p:=DllCall("GlobalLock","UInt",hDrop)
   NumPut(20, p+0)  ;offset
   NumPut(x,  p+4)  ;pt.x
   NumPut(y,  p+8)  ;pt.y
   NumPut(0,  p+12) ;fNC
   NumPut(0,  p+16) ;fWide
   p2:=p+20
   Loop,Parse,fns,`n,`r
   {
      DllCall("RtlMoveMemory","UInt",p2,"Str",A_LoopField,"UInt",StrLen(A_LoopField))
      p2+=StrLen(A_LoopField)+1
   }
   DllCall("GlobalUnlock","UInt",hDrop)
   Return hDrop
}

WM_MOVE(wParam, lParam, nMsg, hWnd) { 									;-- UpdateLayeredWindow

If   A_Gui
&&   DllCall("UpdateLayeredWindow", "Uint", hWnd, "Uint", 0, "int64P", (lParam<<48>>48)&0xFFFFFFFF|(lParam&0xFFFF0000)<<32>>16, "Uint", 0, "Uint", 0, "Uint", 0, "Uint", 0, "Uint", 0, "Uint", 0)
WinGetPos, GuiX, GuiY,,, WinTitle
if (GuiY)
Gui, 2: Show, x%GuiX% y%GuiY%
else
Gui, 2: Show, Center
Return   0
}

OnMessage(0x46, "WM_WINDOWPOSCHANGING")
WM_WINDOWPOSCHANGING(wParam, lParam) {							;-- two different examples of handling a WM_WINDOWPOSCHANGING

    if (A_Gui = 1 && !(NumGet(lParam+24) & 0x2)) ; SWP_NOMOVE=0x2
    {
        x := NumGet(lParam+8),  y := NumGet(lParam+12)
        x += 10,  y += 30
        Gui, 2:Show, X%x% Y%y% NA
    }
}
; or
WM_WINDOWPOSCHANGING(wParam, lParam) {

	global

	If (A_Gui = 1 && !(NumGet(lParam+24) & 0x2))
	{
		x := NumGet(lParam+8),  y := NumGet(lParam+12)

		Result := DllCall("SetWindowPos", "UInt", Gui2, "UInt", Gui1, "Int", x-50, "Int", y-50, "Int", "", "Int", "", "Int", 0x01)
	}
	SetTimer, OnTop, 10

	Result := DllCall("SetWindowPos", "UInt", Gui1, "UInt", Gui2, "Int", "", "Int", "", "Int", "", "Int", "", "Int", 0x03)
	;Tooltip, %Result%
	Return

}

CallNextHookEx(nCode, wParam, lParam, hHook = 0) {						;-- Passes the hook information to the next hook procedure in the current hook chain. A hook procedure can call this function either before or after processing the hook information
   Return DllCall("CallNextHookEx", "Uint", hHook, "int", nCode, "Uint", wParam, "Uint", lParam)
}

WM_DEVICECHANGE( wParam, lParam) { 										;-- Detects whether a CD has been inserted instead and also outputs the drive - global drv

Global Drv
 global DriveNotification
 Static DBT_DEVICEARRIVAL := 0x8000 ; http://msdn2.microsoft.com/en-us/library/aa363205.aspx
 Static DBT_DEVTYP_VOLUME := 0x2    ; http://msdn2.microsoft.com/en-us/library/aa363246.aspx

 /*
    When wParam is DBT_DEVICEARRIVAL lParam will be a pointer to a structure identifying the
    device inserted. The structure consists of an event-independent header,followed by event
    -dependent members that describe the device. To use this structure,  treat the structure
    as a DEV_BROADCAST_HDR structure, then check its dbch_devicetype member to determine the
    device type.
 */

 dbch_devicetype := NumGet(lParam+4) ; dbch_devicetype is member 2 of DEV_BROADCAST_HDR

 If ( wParam = DBT_DEVICEARRIVAL AND dbch_devicetype = DBT_DEVTYP_VOLUME )
 {

 ; Confirmed lParam is a pointer to DEV_BROADCAST_VOLUME and should retrieve Member 4
 ; which is dbcv_unitmask

   dbcv_unitmask := NumGet(lParam+12 )

 ; The logical unit mask identifying one or more logical units. Each bit in the mask corres
 ; ponds to one logical drive.Bit 0 represents drive A, Bit 1 represents drive B, and so on

   Loop 32                                           ; Scan Bits from LSB to MSB
     If ( ( dbcv_unitmask >> (A_Index-1) & 1) = 1 )  ; If Bit is "ON"
      {
        Drv := Chr(64+A_Index)                       ; Set Drive letter
        Break
      }
   DriveNotification:=DriveData(Drv)
 }
Return TRUE
}


} 
;|														|														|														|														|
;|	OnMessageEx()							|	ReceiveData()								|	HDrop()										|	WM_MOVE()								|
;|	WM_WINDOWPOSCHANGING()	|	CallNextHookEx()							|	WM_DEVICECHANGE()				|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;Internet / Network - Functions (23)

DownloadFile(url, file, info="") {															;--
    static vt
    if !VarSetCapacity(vt)
    {
        VarSetCapacity(vt, A_PtrSize*11), nPar := "31132253353"
        Loop Parse, nPar
            NumPut(RegisterCallback("DL_Progress", "F", A_LoopField, A_Index-1), vt, A_PtrSize*(A_Index-1))
    }
    global _cu, descr
    SplitPath file, dFile
    SysGet m, MonitorWorkArea, 1
    y := mBottom-62-2, x := mRight-330-2, VarSetCapacity(_cu, 100), VarSetCapacity(tn, 520)
    , DllCall("shlwapi\PathCompactPathEx", "str", _cu, "str", url, "uint", 50, "uint", 0)
    descr := (info = "") ? _cu : info . ": " _cu
    Progress Hide CWFAFAF7 CT000020 CB445566 x%x% y%y% w330 h62 B1 FS8 WM700 WS700 FM8 ZH12 ZY3 C11,, %descr%, AutoHotkeyProgress, Tahoma
    if (0 = DllCall("urlmon\URLDownloadToCacheFile", "ptr", 0, "str", url, "str", tn, "uint", 260, "uint", 0x10, "ptr*", &vt))
        FileCopy %tn%, %file%
    else
        ErrorLevel := -1
    Progress Off
    return ErrorLevel
}

NewLinkMsg(VideoSite, VideoName = "") {										;--

   global lng

   TmpMsg := % lng.MSG_NEW_LINK_FOUND . VideoSite . "`r`n"
   if (VideoName <> "")
      TmpMsg := TmpMsg . lng.MSG_NEW_LINK_FILENAME . VideoName . "`r`n`r`n"

	MsgBox 36, %ProgramName%, % TmpMsg lng.MSG_NEW_LINK_ASK, 50
	IfMsgBox Yes
		return, 0
	else
		return, -1

}

TimeGap(ntp="de.pool.ntp.org")	{													;-- Determine by what amount the local system time differs to that of an ntp server

		;Bobo's function
		;https://autohotkey.com/boards/viewtopic.php?f=10&t=34806
		RunWait,% ComSpec " /c w32tm /stripchart /computer:" ntp " /period:1 /dataonly /samples:1 | clip",, Hide ; Query is stored in the clipboard
		array := StrSplit(ClipBoard,"`n")					;disassemble the returned answer after lines
		Return % SubStr(array[4], 10)		                ; difference of time/gap ...

}

GetSourceURL( str ) {																			;--

    FragIdent := RegExReplace( str, "i).*<b.*?>(.*?<!--s\w{11}t-->).*", "$1" )

    For Each, Ident in ( StrSplit( FragIdent, " " ), IdentObj := {} )
        if InStr( Ident, mStr := "SourceURL:" )
            SourceURL := SubStr( Ident, StrLen( mStr )+1 )

    Return SourceURL

}

DNS_QueryName(IP, ByRef NameArray := "") {									;--

   Static OffRR := (A_PtrSize * 2) + 16 ; offset of resource record (RR) within the DNS_RECORD structure
   HDLL := DllCall("LoadLibrary", "Str", "Dnsapi.dll", "UPtr")
   NameArray := []
   IPArray := StrSplit(IP, ".")
   RevIP := IPArray.4 . "." . IPArray.3 . "." . IPArray.2 . "." . IPArray.1 . ".IN-ADDR.ARPA"
   If !DllCall("Dnsapi.dll\DnsQuery_", "Str", RevIP, "Short", 0x0C, "UInt", 0, "Ptr", 0, "PtrP", PDNSREC, "Ptr", 0, "Int") {
      REC_TYPE := NumGet(PDNSREC + 0, A_PtrSize * 2, "UShort")
      If (REC_TYPE = 0x0C) { ; DNS_TYPE_PTR = 0x0C
         PDR := PDNSREC
         While (PDR) {
            Name := StrGet(NumGet(PDR + 0, OffRR, "UPtr"))
            NameArray.Insert(Name)
            PDR := NumGet(PDR + 0, "UPtr")
         }
      }
      DllCall("Dnsapi.dll\DnsRecordListFree", "Ptr", PDNSREC, "Int", 1) ; DnsFreeRecordList = 1
   }
   DllCall("FreeLibrary", "Ptr", HDLL)
   Return NameArray[1] ; returnes the first name from the NameArray on success, otherwise an empty string

}

	;this 4 belongs together
GetHTMLFragment() {																			;--

    FmtArr := EnumClipFormats(), NmeArr := GetClipFormatNames( FmtArr )

    While ( a_index <= NmeArr.Length() && !ClpPtr )
        if ( NmeArr[ a_index ] = "HTML Format" )
            ClpPtr := DllCall( "GetClipboardData", uInt, FmtArr[ a_index ] )

    DllCall( "CloseClipboard" )

    if ( !ClpPtr )
    {
        MsgBox, 0x10, Whoops!, Please Copy Some HTML From a Browser Window!
        Exit
    }

    Return ScrubFragmentIdents( StrGet( ClpPtr, "UTF-8" ) )

}
ScrubFragmentIdents( HTMFrag ) {														;--

    HTMObj := ComObjCreate( "HTMLFile" ), HTMObj.Write( HTMFrag )
    MarkUp := HTMObj.getElementsByTagName( "HTML" )[ 0 ].OuterHtml

    For Needle, Replace in { "(y>).*?(<\w)" : "$1$2", "<!--(s|e).*?-->" : "" }
        MarkUp := RegExReplace( MarkUp, "si)" Needle, Replace )

    Return MarkUp
}
EnumClipFormats() {																			;--
    FmtArr := [], DllCall( "OpenClipboard" )

    While ( DllCall( "CountClipboardFormats" ) >= a_index )
        FmtArr.Push( fmt := DllCall( "EnumClipboardFormats", uint, a_index = 1 ? 0 : fmt ) )

    Return FmtArr
}
GetClipFormatNames( FmtArr ) {														;--
    if ( FmtArr.Length() = False )
    {
        DllCall( "CloseClipboard" )
        Throw "Empty Clipboard Format Array!"
    }

    For Each, Fmt in ( FmtArr, FmtNmArr := [], VarSetCapacity( Buf, 256 ) )
    {
        DllCall( "GetClipboardFormatName", uInt, Fmt, str, Buf, int, 128 )

        if ( Asc( StrGet( &buf ) ) != False  )
            FmtNmArr.Push( StrGet( &buf ) )
    }

    Return FmtNmArr
}
	;------------------------------

GoogleTranslate(phrase,LangIn,LangOut) {											;--

		Critical
		base := "https://translate.google.com.tw/?hl=en&tab=wT#"
		path := base . LangIn . "/" . LangOut . "/" . phrase
		IE := ComObjCreate("InternetExplorer.Application")
		;~ IE.Visible := true
		IE.Navigate(path)

		While IE.readyState!=4 || IE.document.readyState!="complete" || IE.busy
				Sleep 50

		Result := IE.document.all.result_box.innertext
		IE.Quit

return Result

}

getText(byref html) {																			;-- get text from html

	html:=RegExReplace(html,"[\n\r\t]+","")

	html:=regexreplace(html,"\s{2,}<"," <")
	html:=regexreplace(html,">\s{2,}","> ")
	html:=regexreplace(html,">\s+<","><")

	html:=RegExReplace(html,"is)<script[^>]*>.*?<\s*\/\s*script\s*>","")

	html:=regexreplace(html,"<[^<>]+>","")
	html:=regexreplace(html,"i)&nbsp;"," ")
	return html
}

getHtmlById(byref html,id,outer=false) {												;--
	RegExMatch(html,"is)<([^>\s]+)[^>]*\sid=(?:(?:""" id """)|(?:'" id "')|(?:" id "))[^>]*>(.*?)<\s*\/\s*\1\s*>",match)
	return outer ? match : match2
}

getTextById(byref html,id,trim=true) {                                             	;--
	return trim ? trim(s:=getText(getHtmlById(html,id))) : s
}

getHtmlByTagName(byref html,tagName,outer=false) {					;--
	arr:=[]
	i:=0
	while i:=regexmatch(html,"is)<" tagName "(?:\s[^>]*)?>(.*?)<\s*\/\s*" tagName "\s*>",match,i+1)
		outer ? arr.insert(match) : arr.insert(match1)
	return arr
}

getTextByTagName(byref html,tagName,trim=true) {						;--
	arr:=getHtmlByTagName(html,tagName)
	arr2:=[]
	for k,v in arr
		trim ? arr2.insert(trim(s:=getText(v))) : arr2.insert(s)
	return arr2
}

CreateGist(content, description:="", filename:="file1.ahk", 				;--
token:="", public:=true) {

	url := "https://api.github.com/gists"
	obj := { "description": description
	       , "public": (public ? "true" : "false")
	       , "files": { (filename): {"content": content} } }

	whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	whr.Open("POST", url)
	whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
	if token {
		whr.SetRequestHeader("Authorization", "token " token)
	}
	whr.Send( JSON_FromObj(obj) )

	if retUrl := JSON_ToObj(whr.ResponseText).html_url
		return retUrl
	else
		throw, whr.ResponseText
}

GetAllResponseHeaders(Url, RequestHeaders := "",                       	;-- gets the values of all HTTP headers
NO_AUTO_REDIRECT := false, NO_COOKIES := false) {

	static INTERNET_OPEN_TYPE_DIRECT := 1
	     , INTERNET_SERVICE_HTTP := 3
	     , HTTP_QUERY_RAW_HEADERS_CRLF := 22
	     , CP_UTF8 := 65001
	     , Default_UserAgent := "Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; rv:11.0) like Gecko"

	hModule := DllCall("LoadLibrary", "str", "wininet.dll", "ptr")

	if !hInternet := DllCall("wininet\InternetOpen", "ptr", &Default_UserAgent, "uint", INTERNET_OPEN_TYPE_DIRECT
		, "str", "", "str", "", "uint", 0)
		return
	; -----------------------------------------------------------------------------------
	if !InStr(Url, "://")
		Url := "http://" Trim(Url)

	regex := "(?P<protocol>\w+)://((?P<user>\w+):(?P<pwd>\w+)@)?(?P<host>[\w.]+)(:(?P<port>\d+))?(?P<path>.*)"
	RegExMatch(Url, regex, v_)

	if (v_protocol = "ftp") {
		throw, "ftp is not supported."
	}
	if (v_port = "") {
		v_port := (v_protocol = "https") ? 443 : 80
	}
	; -----------------------------------------------------------------------------------
	Internet_Flags := 0
	                | 0x400000   ; INTERNET_FLAG_KEEP_CONNECTION
	                | 0x80000000 ; INTERNET_FLAG_RELOAD
	                | 0x20000000 ; INTERNET_FLAG_NO_CACHE_WRITE
	if (v_protocol = "https") {
		Internet_Flags |= 0x1000  ; INTERNET_FLAG_IGNORE_CERT_CN_INVALID
		               | 0x2000   ; INTERNET_FLAG_IGNORE_CERT_DATE_INVALID
		               | 0x800000 ; INTERNET_FLAG_SECURE ; Technically, this is redundant for https
	}
	if NO_AUTO_REDIRECT
		Internet_Flags |= 0x00200000 ; INTERNET_FLAG_NO_AUTO_REDIRECT
	if NO_COOKIES
		Internet_Flags |= 0x00080000 ; INTERNET_FLAG_NO_COOKIES
	; -----------------------------------------------------------------------------------
	hConnect := DllCall("wininet\InternetConnect", "ptr", hInternet, "ptr", &v_host, "uint", v_port
		, "ptr", &v_user, "ptr", &v_pwd, "uint", INTERNET_SERVICE_HTTP, "uint", Internet_Flags, "uint", 0, "ptr")

	hRequest := DllCall("wininet\HttpOpenRequest", "ptr", hConnect, "str", "HEAD", "ptr", &v_path
		, "str", "HTTP/1.1", "ptr", 0, "ptr", 0, "uint", Internet_Flags, "ptr", 0, "ptr")

	nRet := DllCall("wininet\HttpSendRequest", "ptr", hRequest, "ptr", &RequestHeaders, "int", -1
		, "ptr", 0, "uint", 0)

	Loop, 2 {
		DllCall("wininet\HttpQueryInfoA", "ptr", hRequest, "uint", HTTP_QUERY_RAW_HEADERS_CRLF
			, "ptr", &pBuffer, "uint*", bufferLen, "uint", 0)
		if (A_Index = 1)
			VarSetCapacity(pBuffer, bufferLen, 0)
	}
	; -----------------------------------------------------------------------------------
	output := StrGet(&pBuffer, "UTF-8")
	; -----------------------------------------------------------------------------------
	DllCall("wininet\InternetCloseHandle", "ptr", hRequest)
	DllCall("wininet\InternetCloseHandle", "ptr", hConnect)
	DllCall("wininet\InternetCloseHandle", "ptr", hInternet)
	DllCall("FreeLibrary", "Ptr", hModule)

	return output

}

NetStat() {                                                                                        	;--passes information over network connections similar to the netstat -an CMD command.

	/*	Description: a function by jNizM

		https://autohotkey.com/boards/viewtopic.php?t=4372

		this function returns an array:
		- array[x].proto ;(Das Protokoll der Verbindung -> TCP oder UDP)
		- array[x].ipv ;(Die IP-Version -> 4 oder 6)
		- array[x].localIP ;(Lokale IP Adresse)
		- array[x].localPort ;(Lokaler Port)
		- array[x].localScopeId ;(Lokale Scope ID... nur IPv6)
		- array[x].remoteIP ;(Remote IP Adresse... nur TCP)
		- array[x].remotePort ;(Remote Port :HeHe: ... nur TCP)
		- array[x].remoteScopeId ;(nur TCP/IPv6)
		- array[x].status ;(der Status der Verbindung -> LISTEN, ESTABLISHED, TIME-WAIT, etc...)

	*/

	c := 32
	static status := {1:"CLOSED", 2:"LISTEN", 3:"SYN-SENT", 4:"SYN-RECEIVED"
	, 5:"ESTABLISHED", 6:"FIN-WAIT-1", 7:"FIN-WAIT-2", 8:"CLOSE-WAIT"
	, 9:"CLOSING", 10:"LIST-ACK", 11:"TIME-WAIT", 12:"DELETE-TCB"}

	iphlpapi := DllCall("LoadLibrary", "str", "iphlpapi", "ptr")
	list := []

	VarSetCapacity(tbl, 4+(s := (20*c)), 0)
	while (DllCall("iphlpapi\GetTcpTable", "ptr", &tbl, "uint*", s, "uint", 1)=122)
	VarSetCapacity(tbl, 4+s, 0)

	Loop, % NumGet(tbl, 0, "uint")
	{
		o := 4+((A_Index-1)*20)
		t := {proto:"TCP", ipv:4}
		t.localIP := ((dw := NumGet(tbl, o+4, "uint"))&0xff) "." ((dw&0xff00)>>8) "." ((dw&0xff0000)>>16) "." ((dw&0xff000000)>>24)
		t.localPort := (((dw := NumGet(tbl, o+8, "uint"))&0xff00)>>8)|((dw&0xff)<<8)
		t.remoteIP := ((dw := NumGet(tbl, o+12, "uint"))&0xff) "." ((dw&0xff00)>>8) "." ((dw&0xff0000)>>16) "." ((dw&0xff000000)>>24)
		t.remotePort := (((dw := NumGet(tbl, o+16, "uint"))&0xff00)>>8)|((dw&0xff)<<8)
		t.status := status[NumGet(tbl, o, "uint")]
		list.insert(t)
	}

	if (DllCall("GetProcAddress", "ptr", iphlpapi, "astr", "GetTcp6Table", "ptr"))
	{
		VarSetCapacity(tbl, 4+(s := (52*c)), 0)
		while (DllCall("iphlpapi\GetTcp6Table", "ptr", &tbl, "uint*", s, "uint", 1)=122)
			VarSetCapacity(tbl, 4+s, 0)

		Loop, % NumGet(tbl, 0, "uint")
		{
			VarSetCapacity(str, 94, 0)
			o := 4+((A_Index-1)*52)
			t := {proto:"TCP", ipv:6}
			t.localIP := (DllCall("ws2_32\InetNtop", "uint", 23, "ptr", &tbl+o+4, "ptr", &str, "uint", 94)) ? StrGet(&str) : ""
			t.localScopeId := (((dw := NumGet(tbl, o+20, "uint"))&0xff)<<24) | ((dw&0xff00)<<8) | ((dw&0xff0000)>>8) | ((dw&0xff000000)>>24)
			t.localPort := (((dw := NumGet(tbl, o+24, "uint"))&0xff00)>>8)|((dw&0xff)<<8)
			t.remoteIP := (DllCall("ws2_32\InetNtop", "uint", 23, "ptr", &tbl+o+28, "ptr", &str, "uint", 94)) ? StrGet(&str) : ""
			t.remoteScopeId := (((dw := NumGet(tbl, o+44, "uint"))&0xff)<<24) | ((dw&0xff00)<<8) | ((dw&0xff0000)>>8) | ((dw&0xff000000)>>24)
			t.remotePort := (((dw := NumGet(tbl, o+48, "uint"))&0xff00)>>8)|((dw&0xff)<<8)
			t.status := status[NumGet(tbl, o, "uint")]
			list.insert(t)
		}
	}

	VarSetCapacity(tbl, 4+(s := (8*c)), 0)
	while (DllCall("iphlpapi\GetUdpTable", "ptr", &tbl, "uint*", s, "uint", 1)=122)
	VarSetCapacity(tbl, 4+s, 0)

	Loop, % NumGet(tbl, 0, "uint")
	{
		o := 4+((A_Index-1)*20)
		t := {proto:"UDP", ipv:4}
		t.localIP := ((dw := NumGet(tbl, o, "uint"))&0xff) "." ((dw&0xff00)>>8) "." ((dw&0xff0000)>>16) "." ((dw&0xff000000)>>24)
		t.localPort := (((dw := NumGet(tbl, o+4, "uint"))&0xff00)>>8)|((dw&0xff)<<8)
		list.insert(t)
	}

	if (DllCall("GetProcAddress", "ptr", iphlpapi, "astr", "GetUdp6Table", "ptr"))
	{
		VarSetCapacity(tbl, 4+(s := (52*c)), 0)
		while (DllCall("iphlpapi\GetUdp6Table", "ptr", &tbl, "uint*", s, "uint", 1)=122)
			VarSetCapacity(tbl, 4+s, 0)

		Loop, % NumGet(tbl, 0, "uint")
		{
			VarSetCapacity(str, 94, 0)
			o := 4+((A_Index-1)*52)
			t := {proto:"UDP", ipv:6}
			t.localIP := (DllCall("ws2_32\InetNtop", "uint", 23, "ptr", &tbl+o, "ptr", &str, "uint", 94)) ? StrGet(&str) : ""
			t.localScopeId := (((dw := NumGet(tbl, o+16, "uint"))&0xff)<<24) | ((dw&0xff00)<<8) | ((dw&0xff0000)>>8) | ((dw&0xff000000)>>24)
			t.localPort := (((dw := NumGet(tbl, o+20, "uint"))&0xff00)>>8)|((dw&0xff)<<8)
			list.insert(t)
		}
	}
	return list
}

ExtractTableData( FilePath, HeadingsArray, Delimiter, SaveDir ) {		;-- extracts tables from HTML files

	static htmObj

	if !IsObject( htmObj )
		htmObj := ComObjCreate( "HTMLfile" )
	else
		htmObj.Close()

	tablesArray			:= {}
	tablesDataArray		:= {}

	FileRead, HTML, % FilePath
	htmObj.Write( HTML )
	tablesCollection 	:= htmObj.getElementsByTagName( "table" )
	tablesCount 		:= tablesCollection.length

	For Each, Value in HeadingsArray
	{
		tableNumber 	:= 0
		HeadingName 	:= Each
		HeadingNumbers	:= Value.1
		RowNumbers 		:= Value.2

		loop % tablesCount
		{
			tableObj := tablesCollection[ a_index-1 ]


			if InStr( tableObj.innerText, HeadingName )
			{

				tableNumber++
				tableBodyObj 	 			:= tableObj.getElementsByTagName( "tbody" )
				tableColumnHeadingObj		:= tableBodyObj[ 0 ].firstChild.getElementsByTagName( "th" )
				tableRowObj 	 			:= tableBodyObj[ 0 ].getElementsByTagName( "tr" )

				tableCaption 				:= tableBodyObj[ 0 ].previousSibling.innerText

				tableColumnHeadingCount 	:= tableColumnHeadingObj.length
				tableDataRowCount 	 		:= tableRowObj.length-1 ; table data rows minus the heading row

				loop % tableColumnHeadingCount
				{
					tableColumnHeadingValue := tableColumnHeadingObj[ a_index-1 ].innerText
					columnNumber 			:= a_index-1

					if ( tableColumnHeadingValue ~= "^" HeadingName )
					{
						loop % tableDataRowCount
						{
							tableDataObj 		:= tableRowObj[ a_index ].getElementsByTagName( "td" )
							tableData 			:= tableDataObj[ columnNumber ].innerText

							tablesArray[ RegExReplace( Trim( tableColumnHeadingValue ), "\W", "_" ), tableNumber, a_index ] := { tableData: tableData, tableCaption : tableCaption }
						}
					}
				}
			}
		}

		HeadingName := RegExReplace( HeadingName, "\W", "_" )

		if !( HeadingNumbers.length() || IsObject( HeadingNumbers ) || RowNumbers.length() || IsObject( RowNumbers ) )
		{
			tableCaption 	 := tablesArray[ HeadingName ][ HeadingNumbers ][ RowNumbers ].tableCaption
			tableArrayValue  := tablesArray[ HeadingName ][ HeadingNumbers ][ RowNumbers ].tableData
			tablesDataString .= ( tableArrayValue != "" ? tableCaption " ~ " HeadingName ": " tableArrayValue Delimiter : "" )
		}
		else if ( HeadingNumbers.length() || IsObject( HeadingNumbers ) ) && !(  RowNumbers.length() || IsObject( RowNumbers ) )
 		{
			For i in HeadingNumbers
			{
				tableCaption  	 := tablesArray[ HeadingName ][ i ][ RowNumbers ].tableCaption
				tableArrayValue  := tablesArray[ HeadingName ][ i ][ RowNumbers ].tableData
				tablesDataString .= ( tableArrayValue != "" ? tableCaption " ~ " HeadingName ": " tableArrayValue Delimiter : "" )
			}
		}
		else if !( HeadingNumbers.length() || IsObject( HeadingNumbers ) ) && (  RowNumbers.length() || IsObject( RowNumbers ) )
		{
			For i in RowNumbers
			{
				tableCaption  	 := tablesArray[ HeadingName ][ HeadingNumbers ][ i ].tableCaption
				tableArrayValue  := tablesArray[ HeadingName ][ HeadingNumbers ][ i ].tableData
				tablesDataString .= ( tableArrayValue != "" ? tableCaption " ~ " HeadingName ": " tableArrayValue Delimiter : "" )
			}
		}
		else if ( HeadingNumbers.length() || IsObject( HeadingNumbers ) ) && (  RowNumbers.length() || IsObject( RowNumbers ) )
		{
			For h in HeadingNumbers
			{
				For r in RowNumbers
				{
					tableCaption  	 := tablesArray[ HeadingName ][ h ][ r ].tableCaption
					tableArrayValue  := tablesArray[ HeadingName ][ h ][ r ].tableData
					tablesDataString .= ( tableArrayValue != "" ? tableCaption " ~ " HeadingName ": " tableArrayValue Delimiter : "" )
				}
			}
		}
	}

	SplitPath, % FilePath, FileNameExt,,, FileName

	if !StrLen( tablesDataString )
	{
		Msgbox 0x10, Whoops!, % "No Table Data Found in: " FileNameExt
		return true
	}
	else
	{
		SaveFile := SaveDir "\" FileName ".txt"
		if FileExist( SaveFile )
		{
			FileDelete % SaveFile
		}

		FileAppend, % Trim( tablesDataString, Delimiter ), % SaveFile
		TrayTip,, % "Table Data Written To: " FileName ".txt"
	}

	return tablesDataString
}

IsConnected(URL="https://autohotkey.com/boards/") {                	;-- Returns true if there is an available internet connection
	return DllCall("Wininet.dll\InternetCheckConnection", "Str", URL,"UInt", 1, "UInt",0, "UInt")
}

HostToIp(NodeName) {																		;-- gets the IP address for the given host directly using the WinSock 2.0 dll, without using temp files or third party utilities
	/*                              	DESCRIPTION

			Link: https://autohotkey.com/board/topic/9051-host-to-ip-address-using-winsock-20-dll/
			This function gets the IP address for the given host directly using the WinSock 2.0 dll, without using temp files or third party utilities.
			Multiple addresses are returned, seperated by a newline, if available.

			Note! If a domain has no dedicated IP address because it is run from a server using virtual hosts the IP address of the server is returned.

			The script below is fully functional as given, just copy and paste it (beware of line breaks) into a script file.
			(largely based on functions from the WinLirc script and various other posts in this forum)
		
	*/
	/*                              	EXAMPLE(s)
	
			NodeName = www.google.com
			IPs := HostToIp(NodeName)
			DllCall("Ws2_32\WSACleanup") ; always inlude this line after calling to release the socket connection
			if IPs <> -1 ; no error occurred
				Msgbox, %NodeName%`n%IPs%
			else
				MsgBox, Host "%NodeName%" not found 
				
	*/
	
	 ; returns -1 if unsuccessfull or a newline seperated list of valid IP addresses on success
	VarSetCapacity(wsaData, 32)  ; The struct is only about 14 in size, so 32 is conservative.
	result := DllCall("Ws2_32\WSAStartup", "UShort", 0x0002, "UInt", &wsaData) ; Request Winsock 2.0 (0x0002)
	if ErrorLevel	; check ErrorLevel to see if the OS has Winsock 2.0 available:
	{
		MsgBox WSAStartup() could not be called due to error %ErrorLevel%. Winsock 2.0 or higher is required.
		return -1
	}
	if result  ; Non-zero, which means it failed (most Winsock functions return 0 on success).
	{
		MsgBox % "WSAStartup() indicated Winsock error " . DllCall("Ws2_32\WSAGetLastError") ; %
		return -1
	}
	PtrHostent := DllCall("Ws2_32\gethostbyname", str, Nodename) 
	if (PtrHostent = 0) 
		Return -1 
	VarSetCapacity(hostent,16,0) 
	DllCall("RtlMoveMemory",UInt,&hostent,UInt,PtrHostent,UInt,16)  
	h_name      := ExtractInteger(hostent,0,false,4) 
	h_aliases   := ExtractInteger(hostent,4,false,4) 
	h_addrtype  := ExtractInteger(hostent,8,false,2) 
	h_length    := ExtractInteger(hostent,10,false,2) 
	h_addr_list := ExtractInteger(hostent,12,false,4) 
	; Retrieve official name 
	VarSetCapacity(Name,64,0) 
	DllCall("RtlMoveMemory",UInt,&Name,UInt,h_name,UInt,64) 
	; Retrieve Aliases 
	VarSetCapacity(Aliases,12,0) 
	DllCall("RtlMoveMemory", UInt, &Aliases, UInt, h_aliases, UInt, 12) 
	Loop, 3 
	{ 
	   offset := ((A_Index-1)*4) 
	   PtrAlias%A_Index% := ExtractInteger(Aliases,offset,false,4) 
	   If (PtrAlias%A_Index% = 0) 
	      break 
	   VarSetCapacity(Alias%A_Index%,64,0) 
	   DllCall("RtlMoveMemory",UInt,&Alias%A_Index%,UInt,PtrAlias%A_Index%,Uint,64) 
	} 
	VarSetCapacity(AddressList,12,0) 
	DllCall("RtlMoveMemory",UInt,&AddressList,UInt,h_addr_list,UInt,12) 
	Loop, 3 
	{ 
	   offset := ((A_Index-1)*4) 
	   PtrAddress%A_Index% := ExtractInteger(AddressList,offset,false,4) 
	   If (PtrAddress%A_Index% =0) 
	      break 
	   VarSetCapacity(address%A_Index%,4,0) 
	   DllCall("RtlMoveMemory" ,UInt,&address%A_Index%,UInt,PtrAddress%A_Index%,Uint,4) 
	   i := A_Index 
	   Loop, 4 
	   { 
	      if Straddress%i% 
	         Straddress%i% := Straddress%i% "." ExtractInteger(address%i%,(A_Index-1 ),false,1) 
	      else 
	         Straddress%i% := ExtractInteger(address%i%,(A_Index-1 ),false,1) 
	   }
		Straddress0 = %i%
	}
	loop, %Straddress0% ; put them together and return them
	{
		_this := Straddress%A_Index%
		if _this <>
			IPs = %IPs%%_this%
		if A_Index = %Straddress0%
			break
		IPs = %IPs%`n
	}
	return IPs
} 
;{ sub
ExtractInteger(ByRef pSource, pOffset = 0, pIsSigned = false, pSize = 4)
{ 
	Loop %pSize% 
	  result += *(&pSource+pOffset+A_Index-1) << 8*A_Index-8 
	Return result 
}
;}

LocalIps() {																							;-- with small changes to HostToIP() this can be used to retrieve all LocalIP's
	/*                              	DESCRIPTION
	
			Link: https://autohotkey.com/board/topic/9051-host-to-ip-address-using-winsock-20-dll/
			
	*/
	/*                              	EXAMPLE(s)
	
			IPs := LocalIps() 
			DllCall("Ws2_32\WSACleanup") ; always inlude this line after calling to release the socket connection 
			Msgbox, %IPs%  
			
			
	*/
		
	 ; returns -1 if unsuccessfull or a newline seperated list of valid IP addresses on success 
   VarSetCapacity(wsaData, 32)  ; The struct is only about 14 in size, so 32 is conservative. 
   result := DllCall("Ws2_32\WSAStartup", "UShort", 0x0002, "UInt", &wsaData) ; Request Winsock 2.0 (0x0002) 
   if ErrorLevel   ; check ErrorLevel to see if the OS has Winsock 2.0 available: 
   { 
      MsgBox WSAStartup() could not be called due to error %ErrorLevel%. Winsock 2.0 or higher is required. 
      return -1 
   } 
   if result  ; Non-zero, which means it failed (most Winsock functions return 0 on success). 
   { 
      MsgBox % "WSAStartup() indicated Winsock error " . DllCall("Ws2_32\WSAGetLastError") ; % 
      return -1 
   } 
   ; convert ip to Inet Address 
   Inet_address := DllCall("Ws2_32\inet_addr", Str, "0")  
   PtrHostent := DllCall("Ws2_32\gethostbyaddr", "int *", %Inet_address%, "int", 4, "int", 2)     
   if (PtrHostent = 0) 
      Return -1 
   VarSetCapacity(hostent,16,0) 
   DllCall("RtlMoveMemory",UInt,&hostent,UInt,PtrHostent,UInt,16)  
   h_addr_list := ExtractInteger(hostent,12,false,4) 

   VarSetCapacity(AddressList,12,0) 
   DllCall("RtlMoveMemory",UInt,&AddressList,UInt,h_addr_list,UInt,12) 
   Loop, 3 
   { 
      offset := ((A_Index-1)*4) 
      PtrAddress%A_Index% := ExtractInteger(AddressList,offset,false,4) 
      If (PtrAddress%A_Index% =0) 
         break 
      VarSetCapacity(address%A_Index%,4,0) 
      DllCall("RtlMoveMemory" ,UInt,&address%A_Index%,UInt,PtrAddress%A_Index%,Uint,4) 
      i := A_Index 
      Loop, 4 
      { 
         if Straddress%i% 
            Straddress%i% := Straddress%i% "." ExtractInteger(address%i%,(A_Index-1 ),false,1) 
         else 
            Straddress%i% := ExtractInteger(address%i%,(A_Index-1 ),false,1) 
      } 
      Straddress0 = %i% 
   } 
   loop, %Straddress0% ; put them together and return them 
   { 
      _this := Straddress%A_Index% 
      if _this <> 
         IPs = %IPs%%_this% 
      if A_Index = %Straddress0% 
         break 
      IPs = %IPs%`n 
   } 
   return IPs 
} 

GetAdaptersInfo() {																				;-- GetAdaptersAddresses function & IP_ADAPTER_ADDRESSES structure
	/*                              	DESCRIPTION
	
				Link: https://autohotkey.com/boards/viewtopic.php?t=18768
				Dependencies: none
	*/
	/*                              	EXAMPLE(s)
	
			OutPut := GetAdaptersInfo()
			PrintArr(OutPut)
				
	*/
	

    ; initial call to GetAdaptersInfo to get the necessary size
    if (DllCall("iphlpapi.dll\GetAdaptersInfo", "ptr", 0, "UIntP", size) = 111) ; ERROR_BUFFER_OVERFLOW
        if !(VarSetCapacity(buf, size, 0))  ; size ==>  1x = 704  |  2x = 1408  |  3x = 2112
            return "Memory allocation failed for IP_ADAPTER_INFO struct"

    ; second call to GetAdapters Addresses to get the actual data we want
    if (DllCall("iphlpapi.dll\GetAdaptersInfo", "ptr", &buf, "UIntP", size) != 0) ; NO_ERROR / ERROR_SUCCESS
        return "Call to GetAdaptersInfo failed with error: " A_LastError

    ; get some information from the data we received
    addr := &buf, IP_ADAPTER_INFO := {}
    while (addr)
    {
        IP_ADAPTER_INFO[A_Index, "ComboIndex"]          		:= NumGet(addr+0, o := A_PtrSize, "UInt")   , o += 4
        IP_ADAPTER_INFO[A_Index, "AdapterName"]         	:= StrGet(addr+0 + o, 260, "CP0")           , o += 260
        IP_ADAPTER_INFO[A_Index, "Description"]         		:= StrGet(addr+0 + o, 132, "CP0")           , o += 132
        IP_ADAPTER_INFO[A_Index, "AddressLength"]       		:= NumGet(addr+0, o, "UInt")                , o += 4
        loop % IP_ADAPTER_INFO[A_Index].AddressLength
									mac .= Format("{:02X}",                       NumGet(addr+0, o + A_Index - 1, "UChar")) "-"
        IP_ADAPTER_INFO[A_Index, "Address"]             			:= SubStr(mac, 1, -1), mac := ""            , o += 8
        IP_ADAPTER_INFO[A_Index, "Index"]               			:= NumGet(addr+0, o, "UInt")                , o += 4
        IP_ADAPTER_INFO[A_Index, "Type"]                			:= NumGet(addr+0, o, "UInt")                , o += 4
        IP_ADAPTER_INFO[A_Index, "DhcpEnabled"]         		:= NumGet(addr+0, o, "UInt")                , o += A_PtrSize
																					Ptr 	:= NumGet(addr+0, o, "UPtr")                , o += A_PtrSize
        IP_ADAPTER_INFO[A_Index, "CurrentIpAddress"]   	:= Ptr ? StrGet(Ptr + A_PtrSize, "CP0") : ""
        IP_ADAPTER_INFO[A_Index, "IpAddressList"]       		:= StrGet(addr + o + A_PtrSize, "CP0")
        IP_ADAPTER_INFO[A_Index, "IpMaskList"]          			:= StrGet(addr + o + A_PtrSize + 16, "CP0") , o += A_PtrSize + 32 + A_PtrSize
        IP_ADAPTER_INFO[A_Index, "GatewayList"]         		:= StrGet(addr + o + A_PtrSize, "CP0")      , o += A_PtrSize + 32 + A_PtrSize
        IP_ADAPTER_INFO[A_Index, "DhcpServer"]          		:= StrGet(addr + o + A_PtrSize, "CP0")      , o += A_PtrSize + 32 + A_PtrSize
        IP_ADAPTER_INFO[A_Index, "HaveWins"]            		:= NumGet(addr+0, o, "Int")                 , o += A_PtrSize
        IP_ADAPTER_INFO[A_Index, "PrimaryWinsServer"] 	:= StrGet(addr + o + A_PtrSize, "CP0")      , o += A_PtrSize + 32 + A_PtrSize
        IP_ADAPTER_INFO[A_Index, "SecondaryWinsServer"] := StrGet(addr + o + A_PtrSize, "CP0")      , o += A_PtrSize + 32 + A_PtrSize
        IP_ADAPTER_INFO[A_Index, "LeaseObtained"]       		:= DateAdd(NumGet(addr+0, o, "Int"))        , o += A_PtrSize
        IP_ADAPTER_INFO[A_Index, "LeaseExpires"]        		:= DateAdd(NumGet(addr+0, o, "Int"))
        addr := NumGet(addr+0, "UPtr")
    }

    ; output the data we received and free the buffer
    return IP_ADAPTER_INFO, VarSetCapacity(buf, 0), VarSetCapacity(addr, 0)
}

} 
;|														|														|														|														|
;|	DownloadFile()							|	NewLinkMsg()								|	TimeGap()									|	GetSourceURL()							|
;|	DNS_QueryName()						|	GetHTMLFragment()					|	ScrubFragmentIdents()					|	EnumClipFormats()						|
;|	GetClipFormatNames()				|	GoogleTranslate()						|	getText()										|	getHtmlById()								|
;|	getTextById()								|	getHtmlByTagName()					|	getTextByTagName()					|	DNS_QueryName()						|
;|	CreateGist()									|	GetAllResponseHeaders()				|	NetStat()										|	ExtractTableData()                   	|
;|   IsConnected()                          	|   HostToIp()                                	|   LocalIps()                                  	|   GetAdaptersInfo()                      	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;Mathematical (converting) functions (21)
;1	
Min(x, y) {																						;-- returns the smaller of 2 numbers
  return x < y ? x : y
}
;2
Max(x, y) {																						;-- determines the larger number
  return x > y ? x : y
}
;3
Mean(List) {																						;-- returns Average values in comma delimited list

	;https://autohotkey.com/board/topic/4858-mean-median-mode-functions/

	Loop, Parse, List , `,
	{
		Total += %A_LoopField%
		D = %A_Index%
	}
	R := Total/D

	Return R
}
;4
Median(List) {																					;-- returns Median in a set of numbers from a list

	;https://autohotkey.com/board/topic/4858-mean-median-mode-functions/
	;list must be comma delimited

	Sort, List, N D,  ; Sort numerically, use comma as delimiter.

	;Create Array
	StringSplit, Set, List, `,

	;Figure if odd or even
	R := Set0 / 2
	StringSplit, B, R, .
	StringLeft, C, B2, 1

	;Even
	If (C = 0) {
		pt1 := B1 + 1
		Med := (Set%B1% + Set%pt1%) / 2
	} Else {				;Odd
		Med := Ceil(R)
		Med := Set%Med%
	}

	Return Med
}
;5
Mode(List) {																						;-- returns the mode from a list of numbers

	;https://autohotkey.com/board/topic/4858-mean-median-mode-functions/

	StringSplit, Cont, List, `,

	Loop, %Cont0% {

		i := A_Index
		C := Cont%i%
		If ModeArr%C% =
			ModeArr%C% = 1
		Else {
			Amt := ModeArr%C%
			ModeArr%C% := Amt + 1
		}
	}

	Loop %i%	{
		LMC = %CMC%
		CMC := ModeArr%A_Index%
		If CMC > %LMC%
			Mode = %A_Index%
	}

	Return Mode

}
;6
Dec2Base( _Number, _Base = 16 ) {         										 ;-- Base to Decimal and
    Loop % _BaseLen := _Base<10 ? Ceil( ( 10/_Base ) * Strlen( _Number ) ) : Strlen( _Number )
        _D := Floor( _Number/( T := _Base**( _BaseLen-A_index ) ) ), _B .= !_D ? 0: ( _D>9 ? Chr( _D + 87 ) : _D ), _Number := _Number - _D * T
    return Ltrim( _B, "0" )
}
;7
Base2Dec( _Number, _Base = 16 ) {           										;-- Decimal to Base conversion
    Loop, Parse, _Number
        _N += ( ( A_LoopField * 1 = "" ) ? Asc( A_LoopField ) - 87 : A_LoopField ) * _Base**( Strlen( _Number ) - A_index )
    return _N
}
;8
HexToFloat(value) {																			;-- Hexadecimal to Float conversion
    Return, (1 - 2 * (value >> 31)) * (2 ** ((value >> 23 & 255) - 150)) * (0x800000 | value & 0x7FFFFF)
}
;9
FloatToHex(value) {																			;-- Float to Hexadecimal conversion

   format := A_FormatInteger
   SetFormat, Integer, H
   result := DllCall("MulDiv", Float, value, Int, 1, Int, 1, UInt)
   SetFormat, Integer, %format%
   Return, result

}
;10
CalculateDistance(x1, y1, x2, y2) {													;-- calculates the distance between two points in a 2D-Space
    Return, sqrt(((x2 - x1) ** 2) + ((y2 - y1) ** 2))
}
;11
IsInRange(value1, value2, range) {													;-- shows if a second variable is in range
    If ((value1 >= (value2 - range)) && (value1 <= (value2 + range)))
    {
        Return, True
    }
    Else
    {
        Return, False
    }
}
;12
FormatFileSize(Bytes, Decimals = 1, 												;-- Formats a file size in bytes to a human-readable size string
Prefixes = "B,KB,MB,GB,TB,PB,EB,ZB,YB") {							
	StringSplit, Prefix, Prefixes, `,
	Loop, Parse, Prefixes, `,
		if (Bytes < e := 1024 ** A_Index)
			return % Round(Bytes / (e / 1024), decimals) Prefix%A_Index%
}
;13
Color_RGBtoHSV( r, g, b, Byref h, Byref s, Byref v ) {						;-- converts beetween color two color spaces: RGB -> HSV
	;https://autohotkey.com/board/topic/71858-solved-help-coming-up-with-color-definitions/#p478116
	;from http://www.cs.rit.edu/~ncs/color/t_convert.html
	;// r,g,b values are from 0 to 1
	;// h = [0,360], s = [0,1], v = [0,1]
	;//		if s == 0, then h = -1 (undefined)
	min := MIN( r, g, b )
	max := MAX( r, g, b )
	v := max 				; v
	delta := max - min
	if ( max != 0 )
		s := delta / max  	; s
	else {
		;// r = g = b = 0		// s = 0, v is undefined
		s := 0 
		h := -1 
		return 
	}
	if ( r = max )
		h := ( g - b ) / delta ;		// between yellow & magenta
	else if ( g == max )
		h := 2 + ( b - r ) / delta ;	// between cyan & yellow
	else
		h := 4 + ( r - g ) / delta ;	// between magenta & cyan
	h *= 60 ;				// degrees
	if ( h < 0 )
		h += 360 ;
	return
}
;14
Color_HSVtoRGB( h, s, v, ByRef r, ByRef g, ByRef b ) {						;-- converts beetween color two color spaces: HSV -> RGB
	
	if ( s = 0 ) {
		;// achromatic (grey)
		r := v, g := v, b := v ;
		return
	}
	h /= 60 ;			// sector 0 to 5
	i := floor( h ) ;
	f := h - i ;			// factorial part of h
	p := v * ( 1 - s ) ;
	q := v * ( 1 - s * f ) ;
	t = v * ( 1 - s * ( 1 - f ) ) ;
	if (i = 0) {
		r := v
		g := t
		b := p
		Return
	}
	if (i = 1) {
		r := q
		g := v
		b := p
		Return
	}
	if (i = 2) {
		r := p
		g := v
		b := t
		Return
	}
	if (i = 3) {
		r := p
		g := q
		b := v
		Return
	}
	if (i = 4) {
		r := t
		g := p
		b := v
		Return
	}
	;default
	r := v
	g := p
	b := q
	Return
	
}
;{ sub for Color_RGBtoHSV and Color_HSVtoRGB
MIN(in1="", in2="", in3="", in4="", in5="", in6="", in7="", in8="", in9="", in10="") {
	Loop, 10
		If in%A_Index% is number
		  list .= in%A_Index% . "`n"
		  
	Sort, list, N
	StringSplit, item, list, `n, `r
  Return item1
}
MAX(in1="", in2="", in3="", in4="", in5="", in6="", in7="", in8="", in9="", in10="") {
	Loop, 10
		If in%A_Index% is number
		  list .= in%A_Index% . "`n"
		  
	Sort, list, N R
	StringSplit, item, list, `n, `r
  Return item1
}
;}
;15
JEE_HexToBinData(vHex, ByRef vSize:="") {										;-- hexadecimal to binary
	vChars := StrLen(vHex)
	;CRYPT_STRING_HEX := 0x4
	;CRYPT_STRING_HEXRAW := 0xC ;(not supported by Windows XP)
	DllCall("crypt32\CryptStringToBinary", Ptr,&vHex, UInt,vChars, UInt,0x4, Ptr,0, UIntP,vSize, Ptr,0, Ptr,0)
	VarSetCapacity(vData, vSize, 0)
	DllCall("crypt32\CryptStringToBinary", Ptr,&vHex, UInt,vChars, UInt,0x4, Ptr,&vData, UIntP,vSize, Ptr,0, Ptr,0)
	return &vData
}
;16
JEE_BinDataToHex(vAddr, vSize) {													;-- binary to hexadecimal 
	;CRYPT_STRING_HEX := 0x4 ;to return space/CRLF-separated text
	;CRYPT_STRING_HEXRAW := 0xC ;to return raw hex (not supported by Windows XP)
	DllCall("crypt32\CryptBinaryToString", Ptr,vAddr, UInt,vSize, UInt,0x4, Ptr,0, UIntP,vChars)
	VarSetCapacity(vHex, vChars*2, 0)
	DllCall("crypt32\CryptBinaryToString", Ptr,vAddr, UInt,vSize, UInt,0x4, Str,vHex, UIntP,vChars)
	vHex := StrReplace(vHex, "`r`n")
	vHex := StrReplace(vHex, " ")
	return vHex
}
;17
JEE_BinDataToHex2(vAddr, vSize) {													;-- binary to hexadecimal2
	;CRYPT_STRING_HEXRAW := 0xC ;to return raw hex (not supported by Windows XP)
	DllCall("crypt32\CryptBinaryToString", Ptr,vAddr, UInt,vSize, UInt,0xC, Ptr,0, UIntP,vChars)
	VarSetCapacity(vHex, vChars*2, 0)
	DllCall("crypt32\CryptBinaryToString", Ptr,vAddr, UInt,vSize, UInt,0xC, Str,vHex, UIntP,vChars)
	return vHex
}
;18
RadianToDegree(Radians, Centesimal := false) {								;-- convert radian (rad) to degree 
	/*                              	DESCRIPTION
	
			Syntax: RadianToDegree ([radians], [centesimal?])
			Example: MsgBox % RadianToDegree(120) "`n" RadianToDegree(120, true) ;6875.493542 | 7639.437268
			
	*/
	
	if (Centesimal)
		return Radians*63.6619772368 ;200/pi | 200/3.14159265359 = 63.6619772368
	return Radians*57.2957795131 ;180/pi | 180/3.14159265359 = 57.2957795131
}
;19	
DegreeToRadian(Degrees, Centesimal := false) {							;-- convert degree to radian (rad)
	/*                              	DESCRIPTION
	
			Syntax: RadianToDegree ([degrees], [centesimal?])
			 EXAMPLE
			MsgBox % DegreeToRadian(6875.493542) "`n" DegreeToRadian(7639.437268, true) ;120 | 120
			
	*/
	
	if (Centesimal)
		return Degrees*0.01570796326 ;pi/200 | 3.14159265359/200 = 0.01570796326
	return Degrees*0.01745329251 ;pi/180 | 3.14159265359/180 = 0.01745329251
}
;20
RGBToARGB(RGB, Transparent := -1) { 											;-- convert RGB to ARGB
	/*                              	DESCRIPTION
	
			ARGB (A = alpha channel, transparency). FF = solid color. 00 = Transparent
			convert RGB to ARGB.
			Syntax: RGBToARGB ([RGB], [0 ~ 255])
			Return: ARGB with the prefix 0x
			
			Notes:
			If an RGB color is specified, the default transparency is 0xFF (255).
			If you specify an ARGB color, the transparency by default is the same (does not modify it).
			the prefix 0x does not matter, you can specify an integer, in color and in transparency.
			The value of the transparency ranges from 0 (0x00) to 255 (0xFF), where 0 in total transparency and 255 a solid color.
			
			Example:
			 MsgBox% RGBToARGB ("0x8000FF") "," RGBToARGB ("8000FF")
			 . "`n "RGBToARGB (" 0xFF8000FF ")", "RGBToARGB (" FF8000FF ")
			 . "`n`n "RGBToARGB (" 0x8000FF ", 0)", "RGBToARGB (" 8000FF ", 0)
			 . "`n "RGBToARGB (" 0xFF8000FF ", 0)", "RGBToARGB (" FF8000FF ", 0)
			
	*/
	
	RGB := SubStr(RGB:=Hex(RGB, 6), 1, 2)="0x"?SubStr(RGB, 3):RGB, Transparent := Transparent=0?"00":Transparent
	return "0x" CharUpper(StrLen(RGB)=8?(Transparent=-1?RGB:Hex(Transparent, 2,, "") SubStr(RGB, 3))
	: ((Transparent=-1?"FF":Hex(Transparent, 2,, "")) Hex("0x" RGB, 6,, "")))
}
;21
ARGBToRGB(ARGB) {																		;-- convert ARGB to RGB.
	/*                              	DESCRIPTION
	
			
			; Syntax: ARGBToRGB ([ARGB])
			; Return: RGB with the prefix 0x
			;Notes:
			If a RGB color is specified, it does not change it.
			If you specify an ARGB color, the transparency is removed.
			the prefix 0x does not matter, you can specify a whole number.
			;Example:
			; MsgBox% ARGBToRGB ("0x8000FF") "," ARGBToRGB ("8000FF")
			; . "`n "ARGBToRGB (" 0xFF8000FF ")", "ARGBToRGB (" FF8000FF ")
			
	*/
	
	return Hex(SubStr(SubStr(ARGB:=Hex(ARGB, 8), 1, 2)="0x"?SubStr(ARGB, 3):ARGB, -5), 6, true)
}
;22


} 
;|														|														|														|														|
;|	Min()											|	Max()											|	Mean()											|	Median()										|
;|	Mode()											|	Dec2Base()									|	Base2Dec()									|	HexToFloat()								|
;|	FloatToHex()								|	CalculateDistance()						|	IsInRange()									|   FormatFileSize()                        	|
;|  Color_RGBtoHSV()                    	|   Color_HSVtoRGB()                     	|   JEE_HexToBinData()                  	|   JEE_BinDataToHex()                   	|
;|  JEE_BinDataToHex2()               	|   RadianToDegree()                     	|   DegreeToRadian()                     	|   RGBToARGB()                            	|
;|  ARGBToRGB()                           	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;Object functions (4)

ObjMerge(OrigObj, MergingObj, MergeBase=True) {					;--

    If !IsObject(OrigObj) || !IsObject(MergingObj)
        Return False
    For k, v in MergingObj
        ObjInsert(OrigObj, k, v)
    if MergeBase && IsObject(MergingObj.base) {
        If !IsObject(OrigObj.base)
            OrigObj.base := []
        For k, v in MergingObj.base
            ObjInsert(OrigObj.base, k, v)
    }
    Return True

}

evalRPN(s) { 																					;-- Parsing/RPN calculator algorithm

	/*											Example

			evalRPN("3 4 2 * 1 5 - 2 3 ^ ^ / +")

	*/

	stack := []
	out := "For RPN expression: '" s "'`r`n`r`nTOKEN`t`tACTION`t`t`tSTACK`r`n"
	Loop Parse, s
		If A_LoopField is number
			t .= A_LoopField
		else
		{
			If t
				stack.Insert(t)
				, out .= t "`tPush num onto top of stack`t" stackShow(stack) "`r`n"
				, t := ""
			If InStr("+-/*^", l := A_LoopField)
			{
				a := stack.Remove(), b := stack.Remove()
				stack.Insert(	 l = "+" ? b + a
						:l = "-" ? b - a
						:l = "*" ? b * a
						:l = "/" ? b / a
						:l = "^" ? b **a
						:0	)
				out .= l "`tApply op " l " to top of stack`t" stackShow(stack) "`r`n"
			}
		}
	r := stack.Remove()
	out .= "`r`n The final output value is: '" r "'"
	clipboard := out
	return r
}
StackShow(stack){																			;--

	for each, value in stack
		out .= A_Space value
	return subStr(out, 2)

}

ExploreObj(Obj, NewRow = "`n", Equal = "  =  ", Indent = "`t"   	;-- Returns a string containing the formatted object keys and values (very nice for debugging!)
	, Depth = 12, CurIndent = "") {	
    for k,v in Obj
        ToReturn .= CurIndent k (IsObject(v) && depth > 1 ? NewRow ExploreObj(v, NewRow, Equal, Indent, Depth - 1, CurIndent Indent) : Equal v) NewRow
    return RTrim(ToReturn, NewRow)
}

} 
;|														|														|														|														|
;|	ObjMerge()									|	evalRPN()										|	StackShow()									|   ExploreObj()                              	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;String / Array / Text Operations (37)

Sort2DArray(Byref TDArray, KeyName, Order=1) {							;-- a two dimensional TDArray

   ;TDArray : a two dimensional TDArray
   ;KeyName : the key name to be sorted
   ;Order: 1:Ascending 0:Descending

    For index2, obj2 in TDArray {
        For index, obj in TDArray {
            if (lastIndex = index)
                break
            if !(A_Index = 1) &&  ((Order=1) ? (TDArray[prevIndex][KeyName] > TDArray[index][KeyName]) : (TDArray[prevIndex][KeyName] < TDArray[index][KeyName])) {
               tmp := TDArray[index][KeyName]
               TDArray[index][KeyName] := TDArray[prevIndex][KeyName]
               TDArray[prevIndex][KeyName] := tmp
            }
            prevIndex := index
        }
        lastIndex := prevIndex
    }
}

SortArray(Array, Order="A") {															;-- ordered sort: Ascending, Descending, Reverse

    ;Order A: Ascending, D: Descending, R: Reverse
    MaxIndex := ObjMaxIndex(Array)
    If (Order = "R") {
        count := 0
        Loop, % MaxIndex
            ObjInsert(Array, ObjRemove(Array, MaxIndex - count++))
        Return
    }
    Partitions := "|" ObjMinIndex(Array) "," MaxIndex
    Loop {
        comma := InStr(this_partition := SubStr(Partitions, InStr(Partitions, "|", False, 0)+1), ",")
        spos := pivot := SubStr(this_partition, 1, comma-1) , epos := SubStr(this_partition, comma+1)
        if (Order = "A") {
            Loop, % epos - spos {
                if (Array[pivot] > Array[A_Index+spos])
                    ObjInsert(Array, pivot++, ObjRemove(Array, A_Index+spos))
            }
        } else {
            Loop, % epos - spos {
                if (Array[pivot] < Array[A_Index+spos])
                    ObjInsert(Array, pivot++, ObjRemove(Array, A_Index+spos))
            }
        }
        Partitions := SubStr(Partitions, 1, InStr(Partitions, "|", False, 0)-1)
        if (pivot - spos) > 1    ;if more than one elements
            Partitions .= "|" spos "," pivot-1        ;the left partition
        if (epos - pivot) > 1    ;if more than one elements
            Partitions .= "|" pivot+1 "," epos        ;the right partition
    } Until !Partitions
}

QuickSort(Arr, Ascend = True, M*) {												;-- Sort array using QuickSort algorithm

	;******************************************************************************
	;                          QuickSort
	; 		Sort array using QuickSort algorithm
	;		https://autohotkey.com/boards/viewtopic.php?t=17312
	;
	;    	ARR - Array to be sorted or Matrix to be sorted (By Column)
	;     	ASCEND is TRUE if sort is in ascending order
	;     	*M => VET1,VET2, - Optional arrays of same size to be sorted accordingly
	;        or NCOL - Column number in ARR to be sorted if ARR is a matrix
	;
	; Limitation: Don't check if arrays are sparse arrays.
	;             Assume dense arrays or matrices with integer indices starting from 1.
	;******************************************************************************

	/*		EXAMPLES

	;******************************************************************************************
	;                       PrintMat
	; Sample for print examples
	;*******************************************************************************************
	PrintMat(VetG, bG = 0, cG = 0) 	{
	Local StOut := "", k, v
	If IsObject(VetG[1])
		for k, v in VetG {
			for j, w in v
				StOut := StOut . w  . " - "
			StOut := StOut . "@r@n"
		}
	Else  {
	  for k, v in VetG
		StOut := StOut . v  . ","
	  StOut := StOut . "@r@n"
	  If (bG<> 0) {
		for k, v in bG
		 StOut := StOut . v  . ","
		StOut := StOut . "@r@n"
	  }
	  If (cG<>0) {
		for k, v in cG
		  StOut := StOut . v  . ","
	   }
	}
	MsgBox 0, Example, % StOut
	}

	;**** FIRST EXAMPLE ****

	#EscapeChar @   ;  Changes escape character from ' (default) to  @
	aG := [2, 3, 1, 5, 4]
	bG := ["Butterfly", "Cat","Animal", "Zebra", "Elephant"]
	cG := ["B","C", "A","Z","E"]
	VetG := QuickSort(aG,False,bG,cG)
	PrintMat(VetG,bG,cG)

	;**** SECOND EXAMPLE ****

	#EscapeChar @   ;  Changes escape character from ' (default) to  @
	MatG := [ [2, "Animal", "Z" ],  [3, "Elephant", "E" ],  [1, "Cat", "C" ] ,  [5, "Butterfly", "B" ],  [4, "Zebra", "A" ] ]
	MatG := QuickSort(MatG,True,2)
	PrintMat(MatG)

	*/

	Local I, V, Out, L,  Rasc, N, LI, Multi, ComprM, NCol, Ind

	if (Arr.Length() <= 1) ; Array with size <= 1 is already sorted
		return Arr

	If (Not Isobject(Arr))
		return "First parameter needs to be a array"

	LenM := M.Length()    ; Number of parameters after ASCEND
	NCol := 0               ; Assumes initially no matrix
	HasOtherArrays := ( LenM > 0 )   ; TRUE if has other arrays or column number

	Multi := False
	IF HasOtherArrays {
	   Multi := Not IsObject(M[1])  ; True if ARR is bidimensional
	   If (Multi) {
		 NCol := M[1]                 ; Column number of bidimensional array
		 HasOtherArrays :=  False

		 If NCol is Not Integer
			return "Third parameter needs to be a valid column number"
		 If (Not IsObject(Arr(1)))
			return "First parameter needs to be a multidimensional array"
		 If ( (NCol<=0) or (NCol > Arr[1].Length()) )
			return "Third parameter needs to be a valid column number"
	   }
	}

	If (Not Multi)  {
	   If (IsObject(Arr[1]))
		 return "If first parameter is a bidimensional array, it demands a column number"
	}


	LI := 0
	N := 0
	IF (HasOtherArrays)  {
	   Loop % LenM {    ; Scan aditional array parameters
		 Ind := A_INDEX
		 V := M[Ind]
		 If (IsObject(V[1]))
			return  (Ind+2) . "o. parameter needs to be a single array"
	   }

	   LI := 1   ; Assumes 1 as the array/matrix start
	   N := Arr.Clone()   ; N : Array with same size than Array to be sorted
	   L := Arr.Length()  ; L : Array Size

	   Loop % L
		   N[A_INDEX] := A_INDEX  ; Starts with index number of each element from array
	}


	 ; Sort ARR with ASCEND, N is array with elements positions and
	 ;  LI is 1 if has additional arrays to be sorted
	 ;  NCOL is column number to be sorted if ARR is a bidimensional array
	Out :=  QuickAux(Arr, Ascend, N, LI, NCol)

	; Scan additional arrays storing the original position in sorted array
	If (HasOtherArrays)  {
		Loop % ComprM {
		   V := M[A_Index]  ; Current aditional array
		   Rasc := V.Clone()
		   Loop % L     ; Put its elements in the sorted order based on position of sorted elements in the original array
			   V[A_INDEX] := Rasc[N[A_Index]]
		}
	}

	Return Out
}
{ ; sub start - depending functions for QuickSort
QuickAux(Arr,Ascend, N, LI, NCol) {
;=================================================================
;                       QuickAux
; Auxiliary recursive function to make a Quicksort in a array ou matrix
;    ARR - Array or Matrix to be sorted
;    ASCEND - TRUE if sort is ascending
;    N   - Array with original elements position
;    LI  - Position of array ARR in the array from parent recursion
;    NCOL - Column number in Matrix to be sorted. O in array case.
;===================================================================

Local Bef, Aft, Mid
Local Before, Middle, After
Local Pivot, kInd, vElem, LAr, Met
Local LB := 0, LM := 0, LM := 0

LAr := Arr.Length()

if (LAr <= 1)
	return Arr

IF (LI>0) {    ; Has Another Arrays
   Bef := [],  Aft := [], Mid := []
}

Before := [], Middle := [], After := []


Met := LAr // 2    ; Regarding speed, halfway is the Best pivot element for almost sorted array and matrices

If (NCol > 0)
   Pivot := Arr[Met,NCol]
else
   Pivot := Arr[Met]  ; PIVOT is Random  element in array

; Classify array elems in 3 groups: Greater than PIVOT, Lower Than PIVOT and equal
for kInd, vElem in Arr     {
	if (NCol > 0)
		Ch := vElem[NCol]
	else
		Ch := vElem

	if ( Ascend ? Ch < Pivot : Ch > Pivot )  {
			Before.Push(vElem)    ; Append vElem at BEFORE
			IF (LI>0)             ; if has another arrays
		       Bef.Push(N[kInd+LI-1])     ; Append index to original element at BEF
		} else if ( Ascend ? Ch > Pivot : Ch < Pivot ) {
		    After.Push(vElem)
  		    IF (LI>0)
               Aft.Push(N[kInd+LI-1])
		} else  {
			Middle.Push(vElem)
  			IF (LI>0)
   		       Mid.Push(N[kInd+LI-1])
  	    }
}

;  Put pieces of array with index to elements together in N
IF (LI>0) {
	LB := Bef.Length()
	LM := Mid.Length()
	LA := Aft.Length()

	Loop % LB
	  N[LI + A_INDEX - 1] := Bef[A_INDEX]

	Loop % LM
	  N[LI + LB +  A_INDEX - 1] := Mid[A_INDEX]

	Loop % LA
	  N[LI + LB + LM + A_INDEX - 1] := Aft[A_INDEX]
}

; Concat BEFORE, MIDDLE and AFTER Arrays
; BEFORE and AFTER arrays need to be sorted before
; N stores the array position to be sorted in the original array
return Cat(QuickAux(Before,Ascend,N,LI,NCol), Middle, QuickAux(After,Ascend,N,LI+LB+LM,NCol)) ; So Concat the sorted BEFORE, MIDDLE and sorted AFTER arrays
}

Cat(Vet*) {

	;*************************************************************
	;                       Cat
	; Concat 2 or more arrays or matrices by rows
	;**************************************************************

	Local VRes := [] , L, i, V
	For I , V in Vet {
		L := VRes.Length()+1
		If ( V.Length() > 0 )
			VRes.InsertAt(L,V*)
	}
	Return VRes
}

CatCol(Vet*) {

	;***************************************************************************
	;                       CatCol
	; Concat 2 or more matrices by columns
	; Is a aditional function no used directly in QuickSort, but akin with Cat
	;*************************************************************************

	Local VRes := [] , L, I, V, VAux, NLins, NL, Aux, NC, NV, NCD

	NVets := Vet.Length()          ; Number of parameters
	NLins := Vet[1].Length()       ; Number of rows from matrix

	VRes := []

	Loop % NLins  {
		NL := A_INDEX      ; Current Row
		ColAcum := 0
		Loop % NVets  {
			NV := A_INDEX  ; Current Matrix
			NCols := Vet[NV,1].Length()
			Loop % NCols  {
				NC := A_INDEX  ; Current Column
				NCD := A_INDEX + ColAcum   ; Current Column in Destination
				Aux := Vet[NV,NL,NC]
				VRes[NL,NCD] := Aux
			}
			ColAcum := ColAcum + NCols
		}
	}
	Return VRes
}
} ; sub end

GetNestedTag(data,tag,occurrence="1") {										;--

	; AHK Forum Topic : http://www.autohotkey.com/forum/viewtopic.php?t=77653
   ; Documentation   : http://www.autohotkey.net/~hugov/functions/GetNestedTag.html

	 Start:=InStr(data,tag,false,1,occurrence)
	 RegExMatch(tag,"i)<([a-z]*)",basetag) ; get yer basetag1 here
	 Loop
		{
		 Until:=InStr(data, "</" basetag1 ">", false, Start, A_Index) + StrLen(basetag1) + 3
 		 Strng:=SubStr(data, Start, Until - Start)

		 StringReplace, strng, strng, <%basetag1%, <%basetag1%, UseErrorLevel ; start counting to make match
		 OpenCount:=ErrorLevel
		 StringReplace, strng, strng, </%basetag1%, </%basetag1%, UseErrorLevel
		 CloseCount:=ErrorLevel
		 If (OpenCount = CloseCount)
		 	Break

		 If (A_Index > 250) ; for safety so it won't get stuck in an endless loop,
		 	{                 ; it is unlikely to have over 250 nested tags
		 	 strng=
		 	 Break
		 	}
		}
	 If (StrLen(strng) < StrLen(tag)) ; something went wrong/can't find it
	 	strng=
	 Return strng
	}

GetHTMLbyID(HTMLSource, ID, Format=0) {									;-- uses COM

	;Format 0:Text 1:HTML 2:DOM
	ComError := ComObjError(false), `(oHTML := ComObjCreate("HtmlFile")).write(HTMLSource)
	if (Format = 2) {
		if (innerHTML := oHTML.getElementById(ID)["innerHTML"]) {
			`(oDOM := ComObjCreate("HtmlFile")).write(innerHTML)
			Return oDOM, ComObjError(ComError)
		} else
			Return "", ComObjError(ComError)
	} else
	Return (result := oHTML.getElementById(ID)[(Format ? "innerHTML" : "innerText")]) ? result : "", ComObjError(ComError)

}

GetHTMLbyTag(HTMLSource, Tag, Occurrence=1, Format=0) {		;-- uses COM

	;Format 0:Text 1:HTML 2:DOM
	ComError := ComObjError(false), `(oHTML := ComObjCreate("HtmlFile")).write(HTMLSource)
	if (Format = 2) {
		if (innerHTML := oHTML.getElementsByTagName(Tag)[Occurrence-1]["innerHTML"]) {
			`(oDOM := ComObjCreate("HtmlFile")).write(innerHTML)
			Return oDOM, ComObjError(ComError)
		} else
			Return "", ComObjError(ComError)
	}
	return (result := oHTML.getElementsByTagName(Tag)[Occurrence-1][(Format ? "innerHTML" : "innerText")]) ? result : "", ComObjError(ComError)

}

GetXmlElement(xml, pathToElement) {											;-- RegEx function

   Loop, parse, pathToElement, .,
   {
      elementName:=A_LoopField
      regex=<%elementName%>(.*)</%elementName%>

      RegExMatch(xml, regex, xml)
      ;TODO switch to use xml1, instead of parsing stuff out
      ;errord("nolog", xml1)
      xml := StringTrimLeft(xml, strlen(elementName)+2)
      xml := StringTrimRight(xml, strlen(elementName)+3)
   }

   return xml

}

sXMLget( xml, node, attr = "" ) {														;-- simple solution to get information out of xml and html

	;  by infogulch - simple solution get information out of xml and html
	;  supports getting the values from a nested nodes; does NOT support decendant/ancestor or sibling
	;  for something more than a little complex, try Titan's xpath: http://www.autohotkey.com/forum/topic17549.html

	RegExMatch( xml
      , (attr ? ("<" node "\b[^>]*\b" attr "=""(?<match>[^""]*)""[^>]*>") : ("<" node "\b[^>/]*>(?<match>(?<tag>(?:[^<]*(?:<(\w+)\b[^>]*>(?&tag)</\3>)*)*))</" node ">"))
      , retval )
   return retvalMatch

}

ParseJsonStrToArr(json_data) {														;-- Parse Json string to an array

	;-----------------------------
	;
	; Function: ParseJsonStrToArr(v1.2.1)
	; Description:
	;		Parse Json string to an array
	; Syntax: ParseJsonStrToArr(json_data)
	; Parameters:
	;       json_data - json string
	; Return Value:
	;		return an array
	; Remarks:
	;		Each item in the array still is string type
	; Related:
	;		N/A
	; Example:
	;		j := "[{'id':'a1','subject':'s1'},{'id':'a2','subject':'s2},{'id':'a3','subject':'s3'}]"
	;		arr = ParseJsonStrToArr(j)
	;
	;-------------------------------------------------------------------------------


   arr := []
   pos :=1
   While pos:=RegExMatch(json_data,"((?:{)[\s\S][^{}]+(?:}))", j, pos+StrLen(j))
   {
	arr.Insert(j1)                      ; insert json string to array  arr=[{"id":"a1","subject":"s1"},{"id":"a2","subject":"s2"},{"id":"a3","subject":"s3"}]
   }
   return arr
}

parseJSON(txt) {																				;-- Parse Json string to an object

	out := {}
	Loop																				; Go until we say STOP
	{
		ind := A_index															; INDex number for whole array
		ele := strX(txt,"{",n,1, "}",1,1, n)									; Find next ELEment {"label":"value"}
		if (n > strlen(txt)) {
			break																	; STOP when we reach the end
		}
		sub := StrSplit(ele,",")												; Array of SUBelements for this ELEment
		Loop, % sub.MaxIndex()
		{
			StringSplit, key, % sub[A_Index] , : , `"					; Split each SUB into label (key1) and value (key2)
			out[ind,key1] := key2											; Add to the array
		}
	}
	return out

}

AddTrailingBackslash(ptext) {															;-- adds a backslash to the beginning of a string if there is none

	if (SubStr(ptext, 0, 1) <> "\")
		return, ptext . "\"
	return, ptext

}

CheckQuotes(Path) {																		;--

   if (InStr(Path, A_Space, false) <> 0)
   {
      Path = "%Path%"
   }
   return, Path
}

ReplaceForbiddenChars(S_IN, ReplaceByStr = "") {							;-- hopefully working, not tested function, it uses RegExReplace

   Replace_RegEx := "im)[\/:*?""<>|]*"

   S_OUT := RegExReplace(S_IN, Replace_RegEx, "")
   if (S_OUT = 0)
      return, S_IN
   if (ErrorLevel = 0) and (S_OUT <> "")
      return, S_OUT

}

cleanlines(ByRef txt) {																		;-- removes all empty lines

	Loop, Parse, txt, `n, `r
	{
		i := A_LoopField
		if !(i){
			continue
		}
		newtxt .= i "`n"
	}
	return newtxt
}

cleancolon(txt) {																				;-- what for? removes on ':' at beginning of a string

	if substr(txt,1,1)=":" {
		txt:=substr(txt,2)
		txt = %txt%
	}
	return txt

}

cleanspace(ByRef txt) {																	;-- removes all Space chars

	StringReplace txt,txt,`n`n,%A_Space%, All
	StringReplace txt,txt,%A_Space%.%A_Space%,.%A_Space%, All
	loop
	{
		StringReplace txt,txt,%A_Space%%A_Space%,%A_Space%, UseErrorLevel
		if ErrorLevel = 0
			break
	}
	return txt
}

EnsureEndsWith(string, char) {  														;-- Ensure that the string given ends with a given char

   if ( StringRight(string, strlen(char)) <> char )
      string .= char

   return string
}

EnsureStartsWith(string, char) { 														;-- Ensure that the string given starts with a given char
   if ( StringLeft(string, strlen(char)) <> char )
      string := char . string

   return string
}

StrPutVar(string, ByRef var, encoding) {    										;-- Convert the data to some Enc, like UTF-8, UTF-16, CP1200 and so on
   { ;-------------------------------------------------------------------------------
    ;
    ; Function: StrPutVar
    ; Description:
    ;		Convert the data to some Enc, like UTF-8, UTF-16, CP1200 and so on
    ; Syntax: StrPutVar(Str, ByRef Var [, Enc = ""])
    ; Parameters:
    ;		Str - String
    ;		Var - The name of the variable
    ;		Enc - Encoding
    ; Return Value:
    ;		String in a particular encoding
    ; Example:
    ;		None
    ;
    ;-------------------------------------------------------------------------------
    } 


    VarSetCapacity( var, StrPut(string, encoding)
        * ((encoding="cp1252"||encoding="utf-16") ? 2 : 1) )
    return StrPut(string, &var, encoding)
}

StringMD5( ByRef V, L = 0 ) {               											;-- String MD5 Hashing

    VarSetCapacity( MD5_CTX, 104, 0 ), DllCall( "advapi32\MD5Init", Str, MD5_CTX )
    DllCall( "advapi32\MD5Update", Str, MD5_CTX, Str, V, UInt, L ? L : VarSetCapacity( V ) )
    DllCall( "advapi32\MD5Final", Str, MD5_CTX )
    Loop % StrLen( Hex := "123456789ABCDEF0" )
        N := NumGet( MD5_CTX, 87+A_Index, "Char" ), MD5 .= SubStr( Hex, N>>4, 1 ) . SubStr( Hex, N&15, 1 )
    return MD5

}

uriEncode(str) { 																				;-- a function to escape characters like & for use in URLs.

    f = %A_FormatInteger%
    SetFormat, Integer, Hex
    If RegExMatch(str, "^\w+:/{0,2}", pr)
        StringTrimLeft, str, str, StrLen(pr)
    StringReplace, str, str, `%, `%25, All
    Loop
        If RegExMatch(str, "i)[^\w\.~%/:]", char)
           StringReplace, str, str, %char%, % "%" . SubStr(Asc(char),3), All
        Else Break
    SetFormat, Integer, %f%
    Return, pr . str
}

Ansi2Unicode(ByRef sString, ByRef wString, CP = 0) {					;-- easy convertion from Ansi to Unicode, you can set prefered codepage 
     nSize := DllCall("MultiByteToWideChar"
      , "Uint", CP
      , "Uint", 0
      , "Uint", &sString
      , "int",  -1
      , "Uint", 0
      , "int",  0)

   VarSetCapacity(wString, nSize * 2)

   DllCall("MultiByteToWideChar"
      , "Uint", CP
      , "Uint", 0
      , "Uint", &sString
      , "int",  -1
      , "Uint", &wString
      , "int",  nSize)
}

Unicode2Ansi(ByRef wString, ByRef sString, CP = 0) {					;-- easy convertion from Unicode to Ansi, you can set prefered codepage
     nSize := DllCall("WideCharToMultiByte"
      , "Uint", CP
      , "Uint", 0
      , "Uint", &wString
      , "int",  -1
      , "Uint", 0
      , "int",  0
      , "Uint", 0
      , "Uint", 0)

   VarSetCapacity(sString, nSize)

   DllCall("WideCharToMultiByte"
      , "Uint", CP
      , "Uint", 0
      , "Uint", &wString
      , "int",  -1
      , "str",  sString
      , "int",  nSize
      , "Uint", 0
      , "Uint", 0)
}

RegExSplit(ByRef psText, psRegExPattern, piStartPos:=1) {				;-- split a String by a regular expressin pattern and you will receive an array as a result

	;https://autohotkey.com/board/topic/123708-useful-functions-collection/ - ObiWanKenobi
	;Parameters for RegExSplit:
	;psText                      the text you want to split
	;psRegExPattern      the Regular Expression you want to use for splitting
	;piStartPos               start at this posiiton in psText (optional parameter)
	;function ExtractSE() is a helper-function to extract a string at a specific start and end position.

	aRet := []
	if (psText != "") 	{

		iStartPos := piStartPos
		while (iPos := RegExMatch(psText, "P)" . psRegExPattern, match, iStartPos)) {

			sFound := ExtractSE(psText, iStartPos, iPos-1)
			aRet.Push(sFound)
			iStartPos := iPos + match
		}
        sFound := ExtractSE(psText, iStartPos)
        aRet.Push(sFound)
	}
	return aRet
}
{ ; sub start - depending functions for RegExSplit
ExtractSE(ByRef psText, piPosStart, piPosEnd:="") {
	if (psText != "")
	{
		piPosEnd := piPosEnd != "" ? piPosEnd : StrLen(psText)
		return SubStr(psText, piPosStart, piPosEnd-(piPosStart-1))
	}
}
} ; sub end

StringM( _String, _Option, _Param1 = "", _Param2 = "" ) {          	 ;--  String manipulation with many options is using RegExReplace  (bloat, drop, Flip, Only, Pattern, Repeat, Replace, Scramble, Split)

    if ( _Option = "Bloat" )
        _NewString := RegExReplace( _String, "(.)", _Param1 . "$1" . ( ( _Param2 ) ? _Param2 : _Param1) )
    else if ( _Option = "Drop" )
        _NewString := RegExReplace( _String, "i )[" . _Param1 . "]" )
    else if ( _Option = "Flip" )
        Loop, Parse, _String
            _NewString := A_LoopField . _NewString
    else if ( _Option = "Only" )
        _NewString := RegExReplace( _String, "i )[^" . _Param1 . "]" )
    else if ( _Option = "Pattern" ) {
        _Unique := RegExReplace( _String, "(.)", "$1" . Chr(10) )
        Sort, _Unique, % "U Z D" . Chr(10)
        _Unique := RegExReplace( _Unique, Chr(10) )
        Loop, Parse, _Unique
        {
            StringReplace, _String, _String, % A_LoopField,, UseErrorLevel
            _NewString .= A_LoopField . ErrorLevel
        }
    }
    else if ( _Option = "Repeat" )
        Loop, % _Param1
            _NewString := _NewString . _String
    else if ( _Option = "Replace" )
        _NewString := RegExReplace( _String, "i )" . _Param1, _Param2 )
    else if ( _Option = "Scramble" ) {
        _NewString := RegExReplace( _String, "(.)", "$1" . Chr(10) )
        Sort, _NewString, % "Random Z D" . Chr(10)
        _NewString := RegExReplace( _NewString, Chr(10) )
    }
    else if ( _Option = "Split" ) {
        Loop % Ceil( StrLen( _String ) / _Param1 )
            _NewString := _NewString . SubStr( _String, ( A_Index * _Param1 ) - _Param1 + 1, _Param1 ) . ( ( _Param2 ) ? _Param2 : " " )
        StringTrimRight, _NewString, _NewString, 1
    }
    return _NewString

}

StrCount(Haystack,Needle) {															;-- a very handy function to count a needle in a Haystack
	
	; https://github.com/joedf/AEI.ahk/blob/master/AEI.ahk
	StringReplace, Haystack, Haystack, %Needle%, %Needle%, UseErrorLevel
	return ErrorLevel
}

SuperInstr(Hay, Needles, return_min=true, Case=false,               	;-- Returns min/max position for a | separated values of Needle(s)
Startpoint=1, Occurrence=1)	{					
	
	; Source: https://github.com/aviaryan/autohotkey-scripts/blob/master/Others/Ahk%20Coding%20Assistant.ahk
	
	/*			DESCRIPTION
			SuperInstr()
				Returns min/max position for a | separated values of Needle(s)
				
				return_min = true  ; return minimum position
				return_min = false ; return maximum position
	*/
	
	pos := return_min*Strlen(Hay)
	if return_min
	{
		loop, parse, Needles,|
			if ( pos > (var := Instr(Hay, A_LoopField, Case, startpoint, Occurrence)) )
				pos := ( var = 0 ? pos : var )
	}
	else
	{
		loop, parse, Needles,|
			if ( (var := Instr(Hay, A_LoopField, Case, startpoint, Occurrence)) > pos )
				pos := var
	}
	return pos
}

LineDelete(V, L, R := "", O := "", ByRef M := "") {                            	;-- deletes lines of text from variables / no loop
	
	/*                              	DESCRIPTION
	
			OutputVar := LineDelete(InVar, Pos [, Range, Options := "B", DumpVar]) ;Parameters inside [] are optional.
			https://autohotkey.com/boards/viewtopic.php?f=6&t=46520 by Cuadrix
			
			Parameters
			¯¯¯¯¯¯¯¯¯¯¯¯¯
			InVar:		    	The variable whose lines will be deleted.
			Pos:                	The line which will be deleted.
			Range:          	If this parameter is set, Pos will act as the first line and Range as the last line. All lines in-between and 
			                    	including Pos and Range will be deleted.
			Options:       	If Range has been set, using "B" in Options will make the operation prevent Pos and Range from being 
			                    	deleted, and only delete what's in-between them.
			DumpVar:    	Specify a variable in which to store the deleted lines from the operation.
			Return Value: 	This function returns a version of InVar whose contents have been altered by the operation to 
			                    	OutputVar. If no alterations are needed, InVar is returned unaltered.
									
	*/
	
	/*                              	EXAMPLE(S)
	
			Var =
			(
			One
			Two
			Three
			Four
			Five
			)
			Output := LineDelete(Var, 2) ; Deletes line 2.
			MsgBox, % Output ; Returns variable's contents without line 2.
			
			
	*/
	
	
	
	T := StrSplit(V, "`n").MaxIndex()
	if (L > 0 && L <= T && (O = "" || O = "B")){
		V := StrReplace(V, "`r`n", "`n"), S := "`n" V "`n"
		P := (O = "B") ? InStr(S, "`n",,, L + 1)
		   : InStr(S, "`n",,, L)
		M := (R <> "" && R > 0 && O = "" ) ? SubStr(S, P + 1, InStr(S, "`n",, P, 2 + (R - L)) - P - 1)
		   : (R <> "" && R < 0 && O = "" ) ? SubStr(S, P + 1, InStr(S, "`n",, P, 3 + (R - L + T)) - P - 1)
		   : (R <> "" && R > 0 && O = "B") ? SubStr(S, P + 1, InStr(S, "`n",, P, R - L) - P - 1)
		   : (R <> "" && R < 0 && O = "B") ? SubStr(S, P + 1, InStr(S, "`n",, P, 1 + (R - L + T)) - P - 1)
		   : SubStr(S, P + 1, InStr(S, "`n",, P, 2) - P - 1)
		X := SubStr(S, 1, P - 1) . SubStr(S, P + StrLen(M) + 1), X := SubStr(X, 2, -1)
	}
	Else if (L < 0 && L >= -T && (O = "" || O = "B")){
		V := StrReplace(V, "`r`n", "`n"), S := "`n" V "`n"
		P := (R <> "" && R < 0 && O = "" ) ? InStr(S, "`n",,, R + T + 1)
		   : (R <> "" && R > 0 && O = "" ) ? InStr(S, "`n",,, R)
		   : (R <> "" && R < 0 && O = "B") ? InStr(S, "`n",,, R + T + 2)
		   : (R <> "" && R > 0 && O = "B") ? InStr(S, "`n",,, R + 1)
		   : InStr(S, "`n",,, L + T + 1)
		M := (R <> "" && R < 0 && O = "" ) ? SubStr(S, P + 1, InStr(S, "`n",, P, 2 + (L - R)) - P - 1)
		   : (R <> "" && R > 0 && O = "" ) ? SubStr(S, P + 1, InStr(S, "`n",, P, 3 + (T - R + L)) - P - 1)
		   : (R <> "" && R < 0 && O = "B") ? SubStr(S, P + 1, InStr(S, "`n",, P, (L - R)) - P - 1)
		   : (R <> "" && R > 0 && O = "B") ? SubStr(S, P + 1, InStr(S, "`n",, P, 1 + (T - R + L)) - P - 1)
		   : SubStr(S, P + 1, InStr(S, "`n",, P, 2) - P - 1)
		X := SubStr(S, 1, P - 1) . SubStr(S, P + StrLen(M) + 1), X := SubStr(X, 2, -1)
	}
	Return X
}

ExtractFuncTOuserAHK(data) {                                                     	;-- extract user function and helps to write it to userAhk.api
		
	; https://autohotkey.com/board/topic/78781-extract-function-declarations-from-ahk-lib-to-scite4ahk/	
		
	/*	                                        	DESCRIPTION
	
			 The script extracts AHK function declarations from the clipboard and opens
			 user.ahk.api file where you can paste the function declarations.
			 Example usage:
			 - open an AHK library file you've downloaded, 
			 - copy all code from within the file to the clipboard,
			 - run the script (parse clipboard contents, open user.ahk.api file)
			 - paste function declarations to user.ahk.api file
			 - restart SciTE.
			 Notes:
			 - modify the path variables below if needed
			 - good practice: rescan library catalog every time this script gets updated
				(vide script 1.0.0 skipped function declarations that had comments at 
				the end)
			
			 TODO:
				- enable/disable sorting option?
				- if @ found in string, pick other sign
				- import constants
				- check if any of fn names are AHK built-in function names - if yes, warn
					user (see my GetTypeInfo.ahk)
				- option to skip comments in file
				- GUI window?
			 
			 Version 1.0.4 (20120402)
			 
			 Changes since version 1.0.3 (20120402)
				- regular expressions upgraded thanks to rvcv32's Regex Sandbox
			
			 Changes since version 1.0.2 (20120402)
				- remove duplicate entries
				- inform user if duplicate function names found (dup fn names, but not fn
					params / comments)
				- bug: ? changed to  - comment sign has to be present if text after
					trailing { (or '(')
			 
			 Changes since version 1.0.1 (20120401)
				- look for `n if `r`n not found in clipboard
				- display a warning if both `n and `r`n not found in clipboard
				- small tweaking of the script
			 
			 Changes since version 1.0.0 (20120327)
				- there can be comment sign and comments behind { sign. Updated RegEx
					pattern to handle that. Comment text is added to tooltip.
			 
	*/

		
		editor_path := A_ProgramFiles "\Autohotkey\SciTE\SciTE.exe"
		API_path := A_MyDocuments "\Autohotkey\SciTE\user.ahk.api"

		; extract function declarations from clipboard, update clipboard contents
		data := clipboard
		output := ""
		StringReplace, data, data, `r`n, @, All
		if (ErrorLevel) { ; if `r`n missing in the string
			StringReplace, data, data, `n, @, All
			if (ErrorLevel) { ; if both `r`n and `n missing in the string
				MsgBox, 4132, % "Single line in clipboard, Did you copy a single line"
					. "of text to the clipboard?"
				IfMsgBox, No
				{
					MsgBox, 4112, Error, % "End of line character could not be "
						. "determined. Exiting."
					ExitApp
				}
			}
		}

		Loop, Parse, data, @
		{
			; if fn declaration line found, modify line and save line in output
			if (RegExMatch(A_LoopField, "^[a-zA-Z0-9_]* *\([^\)]*\) *\{? *$") )
										; no comments after {
										; this statement will cover most cases
				output .= RegExReplace(A_LoopField, "^([a-zA-Z0-9_]*) *(\([^\)]*\)) *\{? *$", "$1 $2") . "`r`n"
					; add a space between fn name and left bracket so SciTE parser
					; 	would work properly. I.e. fun (), not fun()
					; skip the trailing space and { if they are present
			else if (RegExMatch(A_LoopField, "^[a-zA-Z0-9_]* *\([^\)]*\) *\{? +;.*$") )
										; comments after {
				output .= RegExReplace(A_LoopField, "^([a-zA-Z0-9_]*) *(\([^\)]*\)) *\{? +; *(.*)$", "$1 $2 \n$3") . "`r`n"
		}

		; Sort the output
		Sort, output, U ; remove duplicates, case insinsitive for [a-zA-Z]

		; Inform user if duplicate function names found
		StringReplace, output, output, `r`n, @, All
		oldLine := ""
		Loop, Parse, output, @
		{
			line := A_LoopField
			line1 := "", oldline1 := ""
			StringSplit, line, line, `(
			StringSplit, oldLine, oldLine, `(
			if (line1 = oldLine1) { ; case insensitive
				MsgBox, 64, % "Duplicate function names found., Duplicate function"
					. " names found. User attention required."
				break
			}
			oldLine := line
		}
		StringReplace, output, output, @, `r`n, All

		clipboard := output

		; open *.api file and exit
		Run, "%editor_path%" "%API_path%"
		ToolTip, Done
		Sleep 1500
		ToolTip

return
}

PdfToText(PdfPath) {																		;-- copies a selected PDF file to memory - it needs xpdf - pdftotext.exe
	
	;  This function copies a selected PDF file to memory.  This function was written by kon at AHK forums
	;  and is origionally published in the AHK forums as post 23 in the following thread:
	;  https://autohotkey.com/boards/viewtopic.php?f=5&t=15880&sid=d554d6a38f58672776ff4e272b317308
	;  please note:  the word " -table" below was origionally " -nopgprk"
	;  kon -- if you ever see this THANK YOU
	
    static XpdfPath := """" A_ScriptDir "\pdftotext.exe"""
    objShell := ComObjCreate("WScript.Shell")
 
    ;--------- Building CmdString (look in the .txt docs incuded with xpdf):
    ; From the xpdf docs in [ScriptDir]\xpdfbin-win-3.04\doc\pdftotext.txt:
    ;   SYNOPSIS
    ;       pdftotext [options] [PDF-file [text-file]]
    ;   ...
    ;       If text-file is '-', the text is sent to stdout.
    ; Options (Example option. Look in the xpdf docs for more):
    ;   -nopgbrk    Don't insert page breaks (form feed characters)  between  pages.
    ;---------
    CmdString := XpdfPath " -table """ PdfPath """ -"
    objExec := objShell.Exec(CmdString)
    while, !objExec.StdOut.AtEndOfStream ; Wait for the program to finish
        strStdOut := objExec.StdOut.ReadAll()
    return strStdOut
}

PdfPageCounter(PathToPdfFile){                                                		;-- counts pages of a pdffile (works with 95% of pdf files)
	
	;https://autohotkey.com/board/topic/90560-pdf-page-counter/
    F:=FileOpen(PathToPdfFile,"r"), FSize:=F.Length, FContents:=F.Read(FSize), F.Close()
    while pos := RegExMatch(FContents, "is)<<[^>]*(/Count[^>]*/Kids|/Kids[^>]*/Count)[^>]*>>", m, (pos?pos:1)+StrLen(m))
	{
		if InStr(m, "Parent")
			continue
		PageCountLine := m
	}
    if !(PageCount := RegExReplace(PageCountLine, "is).*/Count\D*(\d+).*", "$1")) > 0
        while pos  := RegExMatch(FContents, "i)Type\s*/Page[^s/]", m, (pos?pos:1) +StrLen(m))
            PageCount++
    return, PageCount
}

PasteWithIndent(clp, ind="Tab", x=1) {											;-- paste string to an editor with your prefered indent key

	;use Tab or Space for example , x how many times you want to have an indent, clp = can contains many lines (lines must liminated through `n)
	ind:= "`{" . ind . " " . x . "`}"

	Loop, Parse, clp, `n
		{
			Send, {Shift Down}{HOME}{Shift Up}
			Send, {Del}
			StringReplace, t, A_LoopField, `n`r, , All
			Send, %ind%%t%				; {ENTER}
		}
		
return
}

SplitLine(str, Byref key, ByRef val) {                                              	;-- split string to key and value
	
	If (p := InStr(str, "=")) {
		key := Trim(SubStr(str, 1, p - 1))
		val := Trim(SubStr(str, p + 1))
		Return True
	}
	Return False
}

Ask_and_SetbackFocus(AskTitle, AskText) {										;-- by opening a msgbox you lost focus and caret pos in any editor - this func will restore the previous positions of the caret

	/*                              	DESCRIPTION
					
			************************************* a function to assist writing of code *************************************
			
			this function can be used to open a user prompt after entering a hotstring. It saves the the name of the 
			active control and after closing the prompt it will give the focus back.
			
			this function is only tested with SciTE. The Scintilla1 window is losing it's focus when you open a MsgBox.
			This function will restore the focus.
			
			In SciTE it's not necessary to call a Mouse- or ControlClick command at the old position of caret. It's only 
			need to use ControlFocus. Maybe this won't work with other editors, i leave some untested code here.
			
			OPTIONS:                   	AskTitle and AskText are strings for MsgBox title and text only
			DEPENDANCYS:          	you need GetFocusedControl(Option := "") function  
			                                	https://autohotkey.com/boards/viewtopic.php?f=6&t=23987 from V for Vendetta
			
			****************************************************************************************************************
																												        	coded by Ixiko 2018 (in dirty mode)
	*/

	CoordMode, Caret, Window
	CoordMode, Mouse, Window
	;xcaret:= A_CaretX, ycaret:= A_CaretY 
	active_WId:=WinExist("A")
	active_CId:= GetFocusedControl("Hwnd")
	;user input - change this line to what you like
	MsgBox, 4, %AskTitle%, %AskText%
	BlockInput, On
		WinActivate, ahk_id %active_WId%
			WinWaitActive, ahk_id %active_WId%, 4
	ControlFocus, , ahk_id %active_CId%
		;this part can be used, but with SciTE it's only needed to set the focus back to the editor window
		;Pause
		;DllCall("SetCursorPos", int, xcaret, int, ycaret)
		;SetControlDelay -1
		;ControlClick,, ahk_id %active_WId%,, Left, 1, x%xcaret% y%ycaret%
		;Click, %xcaret%, %ycaret%
	BlockInput, Off
	IfMsgBox, Yes
		return 1
	IfMsgBox, No
		return 0
	
}

GetWordsNumbered(string, conditions) {										;-- gives back an array of words from a string, you can specify the position of the words you want to keep

	/*                              	DESCRIPTION

			by Ixiko 2018 - i know there's a better way, but I needed a function quickly
			
			Parameters:
			string:						the string to split in words
			conditions:				it's not the best name for this parameter, conditions must be a comma separated list of numbers like : "1,2,5,6"
	
	*/
	
	;this lines are not mine, they remove some chars i didn't need and they remove repeated space chars to one
	new:= RegExReplace(string, "(\s+| +(?= )|\s+$)", A_Space)
	new:= RegExReplace(new, "(,+)", A_Space)
	word:= StrSplit(new, A_Space)

	Loop, % word.MaxIndex()
	{
		If A_Index not in %conditions%
				word[A_Index]:= " "
	}

	Loop, % word.MaxIndex()
	{
		If (word[A_Index] = " ")
				word.Delete(A_Index)
	}

return word
}

CleanLine(Target) {																			;-- Return a line with leading and trailing spaces removed, and tabs converted to spaces
	/*                              	DESCRIPTION
	
			Func: CleanLine
			 Return a line with leading and trailing spaces removed, and tabs converted to spaces. This is mostly useful
			 for command-line parsing when the command-line is coming from an unknown source.  It makes subsequent
			 parsing of the string using searches and regular expressions simpler, without much danger of removing things
			 you're likely to need.
			 
	*/
	

 Parameters:
  Target   - ByRef Target String to clean

 Returns:
  String minus leading and trailing spaces, and all tabs converted to a single space.

   Work := RegexReplace(Target, "\t"  , " ")
   Work := RegexReplace(Work  , "^\s+", "")
   Work := RegexReplace(Work  , "\s+$", "")
   return Work
}

StrTrim(Target) {																				;-- Remove all leading and trailing whitespace including tabs, spaces, CR and LF
	
	/*                              	DESCRIPTION
	
			 Func: StrTrim
			 Remove all leading and trailing whitespace including tabs, spaces, CR and LF.  This is slightl less
			 agressive than <CleanLine>.
			
			 Parameters:
			  Target   - Target String to clean
			
			 Returns:
			  String minus leading and trailing whitespace.
			
			
	*/
	
	
   return RegexReplace(RegexReplace(Target, "^\s+", ""), "\s+$", "")
}

StrDiff(str1, str2, maxOffset:=5) {													;-- SIFT3 : Super Fast and Accurate string distance algorithm

	/*                              	DESCRIPTION
	
			By Toralf:
			Forum thread: http://www.autohotkey.com/forum/topic59407.html
			Download: https://gist.github.com/grey-code/5286786
			
			Basic idea for SIFT3 code by Siderite Zackwehdex
			http://siderite.blogspot.com/2007/04/super-fast-and-accurate-string-distance.html
			
			Took idea to normalize it to longest string from Brad Wood
			http://www.bradwood.com/string_compare/
			
			Own work: 
			    - when character only differ in case, LSC is a 0.8 match for this character
			    - modified code for speed, might lead to different results compared to original code
			    - optimized for speed (30% faster then original SIFT3 and 13.3 times faster than basic Levenshtein distance) 
		
			Dependencies. None
			
	*/

	/*                              	EXAMPLE(s)
	
			MsgBox % StrDiff( "A H K", "A H Kn" )
			MsgBox % StrDiff( "A H K", "A H K" )
			MsgBox % StrDiff( "A H K", "A h K" )
			MsgBox % StrDiff( "AHK", "" )
			MsgBox % StrDiff( "He", "Ben" )
			MsgBox % StrDiff( "Toralf", "ToRalf" )
			MsgBox % StrDiff( "Toralf", "esromneb" )
			MsgBox % StrDiff( "Toralf", "RalfLaDuce" )
			
	*/
	

	if (str1 = str2)
		return (str1 == str2 ? 0/1 : 0.2/StrLen(str1))
	if (str1 = "" || str2 = "")
		return (str1 = str2 ? 0/1 : 1/1)
	StringSplit, n, str1
	StringSplit, m, str2
	ni := 1, mi := 1, lcs := 0
	while ((ni <= n0) && (mi <= m0)) {
		if (n%ni% == m%mi%)
			lcs += 1
		else if (n%ni% = m%mi%)
			lcs += 0.8
		else {
			Loop, % maxOffset {
				oi := ni + A_Index, pi := mi + A_Index
				if ((n%oi% = m%mi%) && (oi <= n0)) {
					ni := oi, lcs += (n%oi% == m%mi% ? 1 : 0.8)
					break
				}
				if ((n%ni% = m%pi%) && (pi <= m0)) {
					mi := pi, lcs += (n%ni% == m%pi% ? 1 : 0.8)
					break
				}
			}
		}
		ni += 1
		mi += 1
	}
	return ((n0 + m0)/2 - lcs) / (n0 > m0 ? n0 : m0)
}

PrintArr(Arr, Option := "w800 h200", GuiNum := 90) {					;-- show values of an array in a listview gui for debugging
    for index, obj in Arr {
        if (A_Index = 1) {
            for k, v in obj {
                Columns .= k "|"    
                cnt++
            }
            Gui, %GuiNum%: Margin, 5, 5
            Gui, %GuiNum%: Add, ListView, %Option%, % Columns
        }
        RowNum := A_Index        
        Gui, %GuiNum%: default
        LV_Add("")
        for k, v in obj {
            LV_GetText(Header, 0, A_Index)
            if (k <> Header) {    
                FoundHeader := False
                loop % LV_GetCount("Column") {
                    LV_GetText(Header, 0, A_Index)
                    if (k <> Header)
                        continue
                    else {
                        FoundHeader := A_Index
                        break
                    }
                }
                if !(FoundHeader) {
                    LV_InsertCol(cnt + 1, "", k)
                    cnt++
                    ColNum := "Col" cnt
                } else
                    ColNum := "Col" FoundHeader
            } else
                ColNum := "Col" A_Index
            LV_Modify(RowNum, ColNum, (IsObject(v) ? "Object()" : v))
        }
    }
    loop % LV_GetCount("Column")
        LV_ModifyCol(A_Index, "AutoHdr")
    Gui, %GuiNum%: Show,, Array
}


} 
;|														|														|														|														|
; -----------------------------------------------------------------  #Sort functions#  -------------------------------------------------------------------
;|	Sort2DArray()								|	SortArray()									|	QuickSort()									|
;|
; ---------------------------------------------------------------  #encoding/decoding#  ---------------------------------------------------------------
;|	uriEncode()									|	Ansi2Unicode()					    	| 	 Unicode2Ansi()							| 	 StringMD5()								|
;|	AddTrailingBackslash()				|	CheckQuotes()								|	ReplaceForbiddenChars()				|
; ---------------------------------------------------------------------  #parsing#  ----------------------------------------------------------------------
;|	ParseJsonStrToArr()						|	 parseJSON()								|	GetNestedTag()							|	GetHTMLbyID()							|
;|	GetHTMLbyTag()							|	GetXmlElement()							|	sXMLget()										
; ----------------------------------------------------------------  #String handling#  ------------------------------------------------------------------
;| 	 cleanlines()									|	cleancolon()									|	cleanspace()									|   SplitLine()                                  	|
;| 	 EnsureEndsWith()						|	EnsureStartsWith()						|	StrPutVar()									|
;|	 RegExSplit()									|	StringM()										|   StrCount()                                 	|   SuperInstr()                               	|
;|   LineDelete()                               	|   GetWordsNumbered()                	|
; ----------------------------------------------------------------------  #others#  ----------------------------------------------------------------------
;|   ExtractFuncTOuserAHK()          	|   PdfToText()                               	|   PdfPageCounter()                     	|   PasteWithIndent()                       	|
;|   Ask_and_SetbackFocus()            	|   CleanLine()                                	|   StrTrim()                                   	|   StrDiff()                                      	|
;|   PrintArr()                                 	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;Keys - Hotkeys - Hotstring - functions (8)
	
DelaySend(Key, Interval=200, SendMethod="Send") { 					;-- Send keystrokes delayed

	/*
	Sends keystrokes with a specified delay. It will be useful for an application which does not accept key presses sent too quickly.
	Remarks
	It remembers the sent count and completes them all.
	Requirements
	AutoHotkey_L v1.1.01 or later.  Tested on: Windows 7 64bit, AutoHotkey 32bit Unicode 1.1.05.01.
	*/

	static KeyStack := []
    KeyStack[Key] := IsObject(KeyStack[Key]) ? KeyStack[Key] : {base: {LastTickCount: 0}}
    ObjInsert( KeyStack[Key], { Key: Key, Interval: Interval, SendMethod: SendMethod })
    Gosub, Label_DelaySend
    Return

    Label_DelaySend:
        For Key in KeyStack {
            if !(MinIndex := KeyStack[Key].MinIndex())
                Continue
            Span := A_TickCount - KeyStack[Key].LastTickCount
            if (Span < KeyStack[Key][MinIndex].Interval)    ;loaded too early
                SetTimer,, % -1 * (KeyStack[Key][KeyStack[Key].MinIndex()].Interval - Span)     ;[v1.1.01+]
            else {
                SendMethod := KeyStack[Key][MinIndex].SendMethod
                SendingKey := KeyStack[Key][MinIndex].Key
                if (SendMethod = "SendInput")
                    SendInput, % SendingKey
                Else if (SendMethod = "SendPlay")
                    SendPlay, % SendingKey
                Else if (SendMethod = "SendRaw")
                    SendRaw, % SendingKey
                Else if (SendMethod = "SendEvent")
                    SendEvent, % SendingKey
                Else
                    Send, % SendingKey

                ObjRemove(KeyStack[Key], MinIndex)    ;decrement other elements
                if KeyStack[Key].MinIndex() ;if there is a next queue
                    SetTimer,, % -1 * KeyStack[Key][KeyStack[Key].MinIndex()].Interval        ;[v1.1.01+]
                KeyStack[Key].base.LastTickCount := A_TickCount
            }
        }
    Return
}

SetLayout(layout, winid) {																;-- set a keyboard layout
    Result := (DllCall("LoadKeyboardLayout", "Str", layout, "UInt", "257"))
    DllCall("SendMessage", "UInt", winid, "UInt", "80", "UInt", "1", "UInt", Result)
}

GetAllInputChars() {																			;-- Returns a string with input characters

    Loop 256
        ChrStr .= Chr( a_index ) " "

    ChrStr .= "{down} {up} {right} {left} "

    Return ChrStr
}

ReleaseModifiers(Beep = 1, CheckIfUserPerformingAction = 0,    ;-- helps to solve the Hotkey stuck problem
AdditionalKeys = ""	, timeout := "") {
	
	/*						Description
	
				To have maximum reliability you really need to loop through all of the modifier and only proceed with the actions once none of them are down.
				It checks the modifiers keys and if one is down it will continually re-check them every 5ms  - when they are all released it will then wait 35ms and 
				recheck them again (this second re-check is only required for this game) - if none are down it will return otherwise it keeps going (unless a 'timeout' period was specified).

				Also as pointed out some people have had success sending modifer up keystrokes like  {LWin up} - 
				but I think this is hit and miss for many. Some find using Senevent or Send blind is required to 'unstick' the key.
	
	*/
	
	; https://autohotkey.com/board/topic/94091-sometimes-modifyer-keys-always-down/
	 ;timout in ms
	GLOBAL HotkeysZergBurrow
	startTime := A_Tickcount

	startReleaseModifiers:
	count := 0
	firstRun++
	while getkeystate("Ctrl", "P") || getkeystate("Alt", "P") 
	|| getkeystate("Shift", "P") || getkeystate("LWin", "P") || getkeystate("RWin", "P")
	||  AdditionalKeys && (ExtraKeysDown := isaKeyPhysicallyDown(AdditionalKeys))  ; ExtraKeysDown should actually return the actual key
	|| (isPerformingAction := CheckIfUserPerformingAction && isUserPerformingAction()) ; have this function last as it can take the longest if lots of units selected
	{
		count++
		if (timeout && A_Tickcount - startTime >= timeout)
			return 1 ; was taking too long
		if (count = 1 && Beep) && !isPerformingAction && !ExtraKeysDown && firstRun = 1	;wont beep if casting or burrow AKA 'extra key' is down
				nothing=	   ;placeholder i dont want to play songs right now										;~ SoundPlay, %A_Temp%\ModifierDown.wav	
		if ExtraKeysDown
			LastExtraKeyHeldDown := ExtraKeysDown ; as ExtraKeysDown will get blanked in the loop preventing detection in the below if
		else LastExtraKeyHeldDown := ""
		sleep, 5
	}
	if count
	{
		if (LastExtraKeyHeldDown = HotkeysZergBurrow)
			sleep 10 ;as burrow can 'buffer' within sc2
		else sleep, 5	;give time for sc2 to update keystate - it can be a slower than AHK (or it buffers)! 
		Goto, startReleaseModifiers
	}
	return
}

isaKeyPhysicallyDown(Keys) {															;-- belongs to ReleaseModifiers() function
	
  if isobject(Keys)
  {
    for Index, Key in Keys
      if getkeystate(Key, "P")
        return key
  }
  else if getkeystate(Keys, "P")
  	return Keys ;keys!
  return 0
}

GetText(ByRef MyText = "") {                                                       	;-- copies the selected text to a variable while preserving the clipboard.(Ctrl+C method)
	
   SavedClip := ClipboardAll
   Clipboard =
   Send ^c
   ClipWait 0.5
   If ERRORLEVEL
   {
      Clipboard := SavedClip
      MyText =
      Return
   }
   MyText := Clipboard
   Clipboard := SavedClip
   Return MyText
}

PutText(MyText) {                                       	                                	;-- Pastes text from a variable while preserving the clipboard. (Ctrl+v method)
	
   SavedClip := ClipboardAll 
   Clipboard =              ; For better compatability
   Sleep 20                 ; with Clipboard History
   Clipboard := MyText
   Send ^v
   Sleep 100
   Clipboard := SavedClip
   Return
}

Hotkeys(ByRef Hotkeys) {																;-- a handy function to show all used hotkeys in script

	/*                              	DESCRIPTION
	
			Link: https://autohotkey.com/boards/viewtopic.php?t=33437
			
	*/
	
	/*                              	EXAMPLE(s)
	
			F1:: ; Gui Hotkeys
			Gui, Add, ListView, h700 w500, HOTKEY|COMMENT
			LV_ModifyCol(1, 125)
			LV_ModifyCol(2, 375)
			for Index, Element in Hotkeys(Hotkeys)
			    LV_Add("",Element.Hotkey, Element.Comment)
			    If (Toggle := oggle)
			     Gui, Show, x0 y0
			    else
			     Gui, Destroy
			return
			
	*/
	

if (A_ComputerName = "Computer") {
    FileRead, Script, %A_ScriptFullPath%
}
If (A_ComputerName = "Laptop") {
    FileRead, Script, %A_ScriptFullPath%
}
    Script :=  RegExReplace(Script, "ms`a)^\s*/\*.*?^\s*\*/\s*|^\s*\(.*?^\s*\)\s*")
    Hotkeys := {}
    Loop, Parse, Script, `n, `r
        if RegExMatch(A_LoopField,"^\s*(.*):`:.*`;\s*(.*)",Match)
        {
            if !RegExMatch(Match1,"(Shift|Alt|Ctrl|Win)")
            {
                StringReplace, Match1, Match1, +, Shift+
                StringReplace, Match1, Match1, <^>!, AltGr+
                StringReplace, Match1, Match1, <, Left, All
                StringReplace, Match1, Match1, >, Right, All 
                StringReplace, Match1, Match1, !, Alt+
                StringReplace, Match1, Match1, ^, Ctrl+
                StringReplace, Match1, Match1, #, Win+
            }
            Hotkeys.Push({"Hotkey":Match1, "Comment":Match2})
        }
    return Hotkeys
}

} 
;|														|														|														|														|
;|	DelaySend()									|	SetLayout()									|	GetAllInputChars()						|   ReleaseModifiers()						|
;|  isaKeyPhysicallyDown()				|   GetText()                                  	|   PutText()                                   	|   Hotkeys()                                  	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;ToolTips - messages (6)
	
ShowTrayBalloon(TipTitle = "", TipText = "", ShowTime = 5000, TipType = 1) {					;--

   global cfg

   if (not cfg.ShowBalloons)
      return, 0
   gosub, RemoveTrayTip
   if (TipText <> "")
   {
      Title := (TipTitle <> "") ? TipTitle : ProgramName
      TrayTip, %Title%, %TipText%, 10, %TipType%+16
      SetTimer, RemoveTrayTip, %ShowTime%
   }
   else
   {
      gosub, RemoveTrayTip
      return, 0
   }
   return, 0

   RemoveTrayTip:
      SetTimer, RemoveTrayTip, Off
      TrayTip
   return
}

ColoredTooltip(sTooltipTxt,seconds=5,bg=0xFFFFE7,fg=0x0,x=-1,y=-1) {							;-- show a tooltip for a given time with a custom color in rgb format (fore and background is supported). This function shows how to obtain the hWnd of the tooltip.
	/*                              	DESCRIPTION
	
			OriginalName: ColoredToolTip by derRaphael
			Origin: https://autohotkey.com/board/topic/31548-function-stooltip-colored-standard-tooltip-with-timeout/
			this version is not tested by me on Win7 and above
	
	*/
	


	/*                              	EXAMPLE(s)
	
			sTooltip("Tooltip with custom Colors",5,0xffff00,0x00ff00)
			
	*/
	
	
	; (w) derRaphael / zLib Style released / v 0.3
	if (Seconds+0=0)
		Seconds = 5
	StartTime := EndTime := A_Now
	EnvAdd,EndTime,Seconds,Seconds
	
	fg := ((fg&255)<<16)+(((fg>>8)&255)<<8)+(fg>>16) ; rgb -> bgr
	bg := ((bg&255)<<16)+(((bg>>8)&255)<<8)+(bg>>16) ; rgb -> bgr
	
	tooltip,% (ttID:="TooltipColor " A_TickCount)
	tThWnd1:=WinExist(ttID ahk_class tooltips_class32)
	; remove border
	; WinSet,Style,-0x800000,ahk_id %tThWnd1%
	SendMessage, 0x413, bg,0,, ahk_id %tThWnd1%   ; 0x413 is TTM_SETTIPBKCOLOR
	SendMessage, 0x414, fg,0,, ahk_id %tThWnd1%   ; 0x414 is TTM_SETTIPTEXTCOLOR
	; according to http://msdn.microsoft.com/en-us/library/bb760411(VS.85).aspx
	; there is no limitation on vista for this.
	Loop,
	{
		if (EndTime=A_Now)
			Break
		else
			if (x<0) || (y<0)
				ToolTip, %sTooltipTxt%
			else
				ToolTip, %sTooltipTxt%, %x%, %y%
		sleep, 50
	}
	ToolTip
}

AddToolTip(_CtrlHwnd, _TipText, _Modify = 0) {																	;-- very easy to use function to add a tooltip to a control

	/*                              	DESCRIPTION
	
			 Adds Multi-line ToolTips to any Gui Control
			 AHK basic, AHK ANSI, Unicode x86/x64 compatible
			
			 Thanks Superfraggle & Art: http://www.autohotkey.com/forum/viewtopic.php?p=188241
			 Heavily modified by Rseding91 3/4/2014:
			 Version: 1.0
			   * Fixed 64 bit support
			   * Fixed multiple GUI support
			   * Changed the _Modify parameter
					   * blank/0/false:                                	Create/update the tool tip.
					   * -1:                                           		Delete the tool tip.
					   * any other value:                             Update an existing tool tip - same as blank/0/false
																				but skips unnecessary work if the tool tip already
																				exists - silently fails if it doesn't exist.
			   * Added clean-up methods:
					   * AddToolTip(YourGuiHwnd, "Destroy", -1):       		Cleans up and erases the cached tool tip data created
																										for that GUI. Meant to be used in conjunction with
																										GUI, Destroy.
					   * AddToolTip(YourGuiHwnd, "Remove All", -1):	   	Removes all tool tips from every control in the GUI.
																										Has the same effect as "Destroy" but first removes
																										every tool tip from every control. This is only used
																										when you want to remove every tool tip but not destroy
																										the entire GUI afterwords.
					   * NOTE: Neither of the above are required if
								your script is closing.
						
			 - 'Text' and 'Picture' Controls requires a g-label to be defined.
			 - 'ComboBox' = Drop-Down button + Edit (Get hWnd of the 'Edit'   control using "ControlGet" command).
			 - 'ListView' = ListView + Header       (Get hWnd of the 'Header' control using "ControlGet" command).
						 
	*/
	/*                              	EXAMPLE(s)
	
			gui, Add, Button, w180 HwndButton1Hwnd, Button 1
			Gui, Add, Button, w180 HwndButton2Hwnd, Button 2
			Gui, Add, Radio, HwndRadio1Hwnd, Radio 1
			Gui, Add, Radio, HwndRadio2Hwnd, Radio 2

			AddToolTip(Button1Hwnd, "Tool tip for button #1.")
			AddToolTip(Button2Hwnd, "Tool tip #2.")
			AddToolTip(Radio1Hwnd, "Radio 1.")
			AddToolTip(Radio2Hwnd, "Radio 2 with a`nmulti-line tool tip.")
			Gui, Show, w200
			Return

			; This closes the script when the GUI is closed.
			GuiClose:
			GuiEscape:
				Exitapp
			Return
			
*/	

	Static TTHwnds, GuiHwnds, Ptr
	, LastGuiHwnd
	, LastTTHwnd
	, TTM_DELTOOLA := 1029
	, TTM_DELTOOLW := 1075
	, TTM_ADDTOOLA := 1028
	, TTM_ADDTOOLW := 1074
	, TTM_UPDATETIPTEXTA := 1036
	, TTM_UPDATETIPTEXTW := 1081
	, TTM_SETMAXTIPWIDTH := 1048
	, WS_POPUP := 0x80000000
	, BS_AUTOCHECKBOX = 0x3
	, CW_USEDEFAULT := 0x80000000
	
	Ptr := A_PtrSize ? "Ptr" : "UInt"
	
	/*                              	NOTE
	
			     This is used to remove all tool tips from a given GUI and to clean up references used
				 This can be used if you want to remove every tool tip but not destroy the GUI
				 When a GUI is destroyed all Windows tool tip related data is cleaned up.
				 The cached Hwnd's in this function will be removed automatically if the caching code
				 ever matches them to a new GUI that doesn't actually own the Hwnd's.
				 It's still possible that a new GUI could have the same Hwnd as a previously destroyed GUI
				 If such an event occurred I have no idea what would happen. Either the tool tip
				 To avoid that issue, do either of the following:
				       * Don't destroy a GUI once created
				 NOTE: You do not need to do the above if you're exiting the script Windows will clean up
				  all tool tip related data and the cached Hwnd's in this function are lost when the script
				  exits anyway.AtEOF
	*/
	
	If (_TipText = "Destroy" Or _TipText = "Remove All" And _Modify = -1)
	{
		; Check if the GuiHwnd exists in the cache list of GuiHwnds
		; If it doesn't exist, no tool tips can exist for the GUI.
		;
		; If it does exist, find the cached TTHwnd for removal.
		Loop, Parse, GuiHwnds, |
			If (A_LoopField = _CtrlHwnd)
			{
				TTHwnd := A_Index
				, TTExists := True
				Loop, Parse, TTHwnds, |
					If (A_Index = TTHwnd)
						TTHwnd := A_LoopField
			}
		
		If (TTExists)
		{
			If (_TipText = "Remove All")
			{
				WinGet, ChildHwnds, ControlListHwnd, ahk_id %_CtrlHwnd%
			
				Loop, Parse, ChildHwnds, `n
					AddToolTip(A_LoopField, "", _Modify) ;Deletes the individual tooltip for a given control if it has one
				
				DllCall("DestroyWindow", Ptr, TTHwnd)
			}
			
			GuiHwnd := _CtrlHwnd
			; This sub removes 'GuiHwnd' and 'TTHwnd' from the cached list of Hwnds
			GoSub, RemoveCachedHwnd
		}
		
		Return
	}
	
	If (!GuiHwnd := DllCall("GetParent", Ptr, _CtrlHwnd, Ptr))
		Return "Invalid control Hwnd: """ _CtrlHwnd """. No parent GUI Hwnd found for control."
	
	; If this GUI is the same one as the potential previous one
	; else look through the list of previous GUIs this function
	; has operated on and find the existing TTHwnd if one exists.
	If (GuiHwnd = LastGuiHwnd)
		TTHwnd := LastTTHwnd
	Else
	{
		Loop, Parse, GuiHwnds, |
			If (A_LoopField = GuiHwnd)
			{
				TTHwnd := A_Index
				Loop, Parse, TTHwnds, |
					If (A_Index = TTHwnd)
						TTHwnd := A_LoopField
			}
	}
	
	; If the TTHwnd isn't owned by the controls parent it's not the correct window handle
	If (TTHwnd And GuiHwnd != DllCall("GetParent", Ptr, TTHwnd, Ptr))
	{
		GoSub, RemoveCachedHwnd
		TTHwnd := ""
	}
	
	; Create a new tooltip window for the control's GUI - only one needs to exist per GUI.
	; The TTHwnd's are cached for re-use in any subsequent calls to this function.
	If (!TTHwnd)
	{
		TTHwnd := DllCall("CreateWindowEx"
						, "UInt", 0                             ;dwExStyle
						, "Str", "TOOLTIPS_CLASS32"             ;lpClassName
						, "UInt", 0                             ;lpWindowName
						, "UInt", WS_POPUP | BS_AUTOCHECKBOX    ;dwStyle
						, "UInt", CW_USEDEFAULT                 ;x
						, "UInt", 0                             ;y
						, "UInt", 0                             ;nWidth
						, "UInt", 0                             ;nHeight
						, "UInt", GuiHwnd                       ;hWndParent
						, "UInt", 0                             ;hMenu
						, "UInt", 0                             ;hInstance
						, "UInt", 0)                            ;lpParam
		
		; TTM_SETWINDOWTHEME
		DllCall("uxtheme\SetWindowTheme"
					, Ptr, TTHwnd
					, Ptr, 0
					, Ptr, 0)
		
		; Record the TTHwnd and GuiHwnd for re-use in any subsequent calls.
		TTHwnds .= (TTHwnds ? "|" : "") TTHwnd
		, GuiHwnds .= (GuiHwnds ? "|" : "") GuiHwnd
	}
	
	; Record the last-used GUIHwnd and TTHwnd for re-use in any immediate future calls.
	LastGuiHwnd := GuiHwnd
	, LastTTHwnd := TTHwnd
	
	
	/*
		*TOOLINFO STRUCT*
		
		UINT        cbSize
		UINT        uFlags
		HWND        hwnd
		UINT_PTR    uId
		RECT        rect
		HINSTANCE   hinst
		LPTSTR      lpszText
		#if (_WIN32_IE >= 0x0300)
			LPARAM    lParam;
		#endif 
		#if (_WIN32_WINNT >= Ox0501)
			void      *lpReserved;
		#endif
	*/
	
	, TInfoSize := 4 + 4 + ((A_PtrSize ? A_PtrSize : 4) * 2) + (4 * 4) + ((A_PtrSize ? A_PtrSize : 4) * 4)
	, Offset := 0
	, Varsetcapacity(TInfo, TInfoSize, 0)
	, Numput(TInfoSize, TInfo, Offset, "UInt"), Offset += 4                         ; cbSize
	, Numput(1 | 16, TInfo, Offset, "UInt"), Offset += 4                            ; uFlags
	, Numput(GuiHwnd, TInfo, Offset, Ptr), Offset += A_PtrSize ? A_PtrSize : 4      ; hwnd
	, Numput(_CtrlHwnd, TInfo, Offset, Ptr), Offset += A_PtrSize ? A_PtrSize : 4    ; UINT_PTR
	, Offset += 16                                                                  ; RECT (not a pointer but the entire RECT)
	, Offset += A_PtrSize ? A_PtrSize : 4                                           ; hinst
	, Numput(&_TipText, TInfo, Offset, Ptr)                                         ; lpszText
	
	
	; The _Modify flag can be used to skip unnecessary removal and creation if
	; the caller follows usage properly but it won't hurt if used incorrectly.
	If (!_Modify Or _Modify = -1)
	{
		If (_Modify = -1)
		{
			; Removes a tool tip if it exists - silently fails if anything goes wrong.
			DllCall("SendMessage"
					, Ptr, TTHwnd
					, "UInt", A_IsUnicode ? TTM_DELTOOLW : TTM_DELTOOLA
					, Ptr, 0
					, Ptr, &TInfo)
			
			Return
		}
		
		; Adds a tool tip and assigns it to a control.
		DllCall("SendMessage"
				, Ptr, TTHwnd
				, "UInt", A_IsUnicode ? TTM_ADDTOOLW : TTM_ADDTOOLA
				, Ptr, 0
				, Ptr, &TInfo)
		
		; Sets the preferred wrap-around width for the tool tip.
		 DllCall("SendMessage"
				, Ptr, TTHwnd
				, "UInt", TTM_SETMAXTIPWIDTH
				, Ptr, 0
				, Ptr, A_ScreenWidth)
	}
	
	; Sets the text of a tool tip - silently fails if anything goes wrong.
	DllCall("SendMessage"
		, Ptr, TTHwnd
		, "UInt", A_IsUnicode ? TTM_UPDATETIPTEXTW : TTM_UPDATETIPTEXTA
		, Ptr, 0
		, Ptr, &TInfo)
	
	Return
	
	
	RemoveCachedHwnd:
		Loop, Parse, GuiHwnds, |
			NewGuiHwnds .= (A_LoopField = GuiHwnd ? "" : ((NewGuiHwnds = "" ? "" : "|") A_LoopField))
		
		Loop, Parse, TTHwnds, |
			NewTTHwnds .= (A_LoopField = TTHwnd ? "" : ((NewTTHwnds = "" ? "" : "|") A_LoopField))
		
		GuiHwnds := NewGuiHwnds
		, TTHwnds := NewTTHwnds
		, LastGuiHwnd := ""
		, LastTTHwnd := ""
	Return
}

AddToolTip(ID="",TEXT="",TITLE="",OPTIONS="") {															;-- add ToolTips to controls - Advanced ToolTip features + Unicode
	/*					DESCRIPTION
ToolTip() by HotKeyIt http://www.autohotkey.com/forum/viewtopic.php?t=40165
 
Syntax: ToolTip(Number,Text,Title,Options)
 
Return Value: ToolTip returns hWnd of the ToolTip
 
|         Options can include any of following parameters separated by space
| Option   |      Meaning
| A      		|   Aim ConrolId or ClassNN (Button1, Edit2, ListBox1, SysListView321...)
|         		|   - using this, ToolTip will be shown when you point mouse on a control
|         		|   - D (delay) can be used to change how long ToolTip is shown
|         		|   - W (wait) can wait for specified seconds before ToolTip will be shown
|         		|   - Some controls like Static require a subroutine to have a ToolTip!!!
| B + F   	|   Specify here the color for ToolTip in 6-digit hexadecimal RGB code
|        		|   - B = Background color, F = Foreground color (text color)
|        		|   - this can be 0x00FF00 or 00FF00 or Blue, Lime, Black, White...
| C     		|   Close button for ToolTip/BalloonTip. See ToolTip actions how to use it
| D     		|   Delay. This option will determine how long ToolTip should be shown.30 sec. is maximum
|        		|   - this option is also available when assigning the ToolTip to a control.
| E      		|   Edges for ToolTip, Use this to set margin of ToolTip window (space between text and border)
|        		|   - Supply Etop.left.bottom.right in pixels, for example: E10.0.10.5
| G     		|   Execute one or more internal Labels of ToolTip function only.
|        		|   For example:
|        		|   - Track the position only, use ToolTip(1,"","","Xcaret Ycaret gTTM_TRACKPOSITION")
|        		|      - When X+Y are empty (= display near mouse position) you can use TTM_UPDATE
|        		|   - Update text only, use ToolTip(1,"text","","G1"). Note specify L1 if links are used.
|        		|   - Update title only, use ToolTip(1,"","Title","G1")
|        		|   - Hide ToolTip, use ToolTip(1,"","","gTTM_POP")
|        		|      - To show ToolTip again use ToolTip(1,"","","gTTM_TRACKPOSITION.TTM_TRACKACTIVATE")
|        		|   - Update background color + text color, specify . between gLabels to execute several:
|        		|      - ToolTip(1,"","","BBlue FWhite gTTM_SETTIPBKCOLOR.TTM_SETTIPTEXTCOLOR")
|        		|   - Following labels can be used: TTM_SETTITLEA + TTM_SETTITLEW (title+I), TTM_POPUP, TTM_POP
|        		|     TTM_SETTIPBKCOLOR (B), TTM_SETTIPTEXTCOLOR (F), TTM_TRACKPOSITION (N+X+Y),
|        		|     TTM_SETMAXTIPWIDTH (R), TTM_SETMARGIN (E), TT_SETTOOLINFO (text+A+P+N+X+Y+S+L)
|        		|     TTM_SETWINDOWTHEME (Q)
| H     		|   Hide ToolTip after a link is clicked.See L option
| I     		|   Icon 1-3, e.g. I1. If this option is missing no Icon will be used (same as I0)
|       		|   - 1 = Info, 2 = Warning, 3 = Error, > 3 is meant to be a hIcon (handle to an Icon)
|       		|   Use Included MI_ExtractIcon and GetAssociatedIcon functions to get hIcon
| J     		|   Justify ToolTip to center of control
| L     		|   Links for ToolTips. See ToolTip actions how Links for ToolTip work.
| M   		|   Mouse click-trough. So a click will be forwarded to the window underneath ToolTip
| N    		|   Do NOT activate ToolTip (N1), To activate (show) call ToolTip(1,"","","gTTM_TRACKACTIVATE")
| O    		|   Oval ToolTip (BalloonTip). Specify O1 to use a BalloonTip instead of ToolTip.
| P    		|   Parent window hWnd or GUI number. This will assign a ToolTip to a window.
|       		|   - Reqiered to assign ToolTip to controls and actions.
| Q    		|   Quench Style/Theme. Use this to disable Theme of ToolTip.
|       		|   Using this option you can have for example colored ToolTips in Vista.
| R    		|   Restrict width. This will restrict the width of the ToolTip.
|       		|   So if Text is to long it will be shown in several lines
| S    		|   Show at coordinates regardless of position. Specify S1 to use that feature
|       		|   - normally it is fed automaticaly to show on screen
| T    		|   Transparency. This option will apply Transparency to a ToolTip.
|       		|   - this option is not available to ToolTips assigned to a control.
| V    		|   Visible: even when the parent window is not active, a control-ToolTip will be shown
| W   		|   Wait time in seconds (max 30) before ToolTip pops up when pointing on one of controls.
| X + Y   	|   Coordinates where ToolTip should be displayed, e.g. X100 Y200
|         		|   - leave empty to display ToolTip near mouse
|         		|   - you can specify Xcaret Ycaret to display at caret coordinates
|
|          		To destroy a ToolTip use ToolTip(Number), to destroy all ToolTip()
|
|               ToolTip Actions (NOTE, OPTION P MUST BE PRESENT TO USE THAT FEATURE)
|      			Assigning an action to a ToolTip to works using OnMessage(0x4e,"Function") - WM_NOTIFY
|      			Parameter/option P must be present so ToolTip will forward messages to script
|      			All you need to do inside this OnMessage function is to include:
|         		- If wParam=0
|            	ToolTip("",lParam[,Label])
|
|  			    Additionally you need to have one or more of following labels in your script
|  			    - ToolTip: when clicking a link
|  			    - ToolTipClose: when closing ToolTip
|  			       - You can also have a diferent label for one or all ToolTips
|  			       - Therefore enter the number of ToolTip in front of the label
|  			          - e.g. 99ToolTip: or 1ToolTipClose:
|			
|  			    - Those labels names can be customized as well
|  			       - e.g. ToolTip("",lParam,"MyTip") will use MyTip: and MyTipClose:
|  			       - you can enter the number of ToolTip in front of that label as well.
|			
|  			    - Links have following syntax:
|  			       - <a>Link</a> or <a link>LinkName</a>
|  			       - When a Link is clicked, ToolTip() will jump to the label
|  			          - Variable ErrorLevel will contain clicked link
|			
|  			       - So when only LinkName is given, e.g. <a>AutoHotkey</a> Errorlevel will be AutoHotkey
|  			       - When using Link is given as well, e.g. <a http://www.autohotkey.com>AutoHotkey</a>
|  			          - Errorlevel will be set to http://www.autohotkey.com
|			
|  			    Please note some options like Close Button and Links will require Win2000++ (+version 6.0 of comctl32.dll)
|  			      AutoHotKey Version 1.0.48++ is required due to "assume static mode"
|  			      If you use 1 ToolTip for several controls, the only difference between those can be the text.
|  			         - Other options, like Title, color and so on, will be valid globally
*/
	/*                              	EXAMPLE(s)
	
			OnMessage(0x4e,"WM_NOTIFY") ;Will make LinkClick and ToolTipClose possible
			OnMessage(0x404,"AHK_NotifyTrayIcon") ;Will pop up the ToolTip when you click on Tray Icon
			OnExit, ExitApp
			NoEnv
			SingleInstance Force
			
			Restart:
			ToolTip(99,"Please click a link:`n`n"
			. "<a>My Favorite Websites</a>`n`n"
			. "<a>ToolTip Examples</a>`n`n"
			. "<a notepad.exe >Notepad</a>`n"
			. "<a explorer.exe >Explorer</a>`n"
			. "<a calc.exe >Calcu`lator</a>`n"
			. "`n<A>Hide ToolTip</a>n - To show this ToolTip again click onto Tray Icon"
			. "`n<a>ExitApp</a>`n"
			, "Welcome to ToolTip Control"
			, "L1 H1 O1 C1 T220 BLime FBlue I" . GetAssociatedIcon(A_ProgramFiles . "\Internet Explorer\iexplore.exe")
			. " P99 X" A_ScreenWidth . " Y" . A_ScreenHeight)
						
			My_Favorite_Websites:
			ToolTip(98,"<a http://www.autohotkey.com >AutoHotKEY>/a> - <a http://de.autohotkey.com>DE</a>"
			. " - <a http://autohotkey.free.fr/docs/>FR</a> - <a http://www.autohotkey.it/>IT</a>"
			. " - <a http://www.script-coding.info/AutoHotkeyTranslation.html>RU</a>"
			. " - <a http://lukewarm.s101.xrea.com/>JP</a>"
			. " - <a http://lukewarm.s101.xrea.com/>GR</a>"
			. " - <a http://www.autohotkey.com/docs/Tutorial-Portuguese.html>PT</a>"
			. " - <a http://cafe.naver.com/AutoHotKèy>KR</a>"
			. " - <a http://forum.ahkbbs.cn/bbs.php>CN</a>"
			. "`n<a http://www.google.com>Google</a> - <a http://www.maps.google.com>Maps</a>`n"
			. "<a http://social.msdn.microsoft.com/Search/en-US/?Refinement=86&Query=>MSDN</a>`n"
			, "My Websites"
			, "L1 O1 C1 BSilver FBlue I" . GetAssociatedIcon(A_ProgramFiles . "\Internet Explorer\iexplore.exe")
			. " P99")
						
			ToolTip_Examples:
			ToolTip(97, "<a>Message Box ToolTip</a>n"
			. "<a>Change ToolTip</a>`n"
			. "<a>ToolTip Loop 
*/

static
local option,a,b,c,d,e,f,g,h,i,k,l,m,n,o,p,q,r,s,t,v,w,x,y,xc,yc,xw,yw,RECT,_DetectHiddenWindows,OnMessage
If !Init
Gosub, TTM_INIT
OnMessage:=OnMessage(0x4e,"") ,_DetectHiddenWindows:=A_DetectHiddenWindows
DetectHiddenWindows, On
If !ID
{
If text
If text is Xdigit
GoTo, TTN_LINKCLICK
Loop, Parse, hWndArray, % Chr(2) ;Destroy all ToolTip Windows
{
If WinExist("ahk_id " . A_LoopField)
DllCall("DestroyWindow","Uint",A_LoopField)
hWndArray%A_LoopField%=
}
hWndArray=
Loop, Parse, idArray, % Chr(2) ;Destroy all ToolTip Structures
{
TT_ID:=A_LoopField
If TT_ALL_%TT_ID%
Gosub, TT_DESTROY
}
idArray=
Goto, TT_EXITFUNC
}
 
TT_ID:=ID
TT_HWND:=TT_HWND_%TT_ID%
 
;___________________  Load Options Variables and Structures ___________________
 
If (options) {
Loop,Parse,options,%A_Space%
If (option:= SubStr(A_LoopField,1,1))
%option%:= SubStr(A_LoopField,2)
}
If (G) {
If (Title!="") {
                        Gosub, TTM_SETTITLE
Gosub, TTM_UPDATE
}
If (Text!="") {
If (A!="")
ID:=A
If (InStr(text,"<a") and L){
TOOLTEXT_%TT_ID%:=text
text:=RegExReplace(text,"<a\K[^<]*?>",">")
} else
TOOLTEXT_%TT_ID%:=
NumPut(&text,TOOLINFO_%ID%,36)
Gosub, TTM_UPDATETIPTEXT
}
Loop, Parse,G,.
If IsLabel(A_LoopField)
Gosub, %A_LoopField%
Sleep,10
    Goto, TT_EXITFUNC
}
;__________________________  Save TOOLINFO Structures _________________________
 
If P {
If (p<100 and !WinExist("ahk_id " p)){
Gui,%p%:+LastFound
P:=WinExist()
}
If !InStr(TT_ALL_%TT_ID%,Chr(2) . Abs(P) . Chr(2))
TT_ALL_%TT_ID%  .= Chr(2) . Abs(P) . Chr(2)
} 
If !InStr(TT_ALL_%TT_ID%,Chr(2) . ID . Chr(2))
TT_ALL_%TT_ID%  .= Chr(2) . ID . Chr(2)
If H
TT_HIDE_%TT_ID%:=1
;__________________________  Create ToolTip Window  __________________________
 
If (!TT_HWND and text) {
TT_HWND := DllCall("CreateWindowEx", "Uint", 0x8, "str", "tooltips_class32", "str", "", "Uint", 0x02 + (v ? 0x1 : 0) + (l ? 0x100 : 0) + (C ? 0x80 : 0)+(O ? 0x40 : 0), "int", 0x80000000, "int", 0x80000000, "int", 0x80000000, "int", 0x80000000, "Uint", P ? P : 0, "Uint", 0, "Uint", 0, "Uint", 0)
TT_HWND_%TT_ID%:=TT_HWND
hWndArray .=(hWndArray ? Chr(2) : "") . TT_HWND
idArray .=(idArray ? Chr(2) : "") . TT_ID
Gosub, TTM_SETMAXTIPWIDTH
DllCall("SendMessage", "Uint", TT_HWND, "Uint", 0x403, "Uint", 2, "Uint", (D ? D*1000 : -1)) ;TTDT_AUTOPOP
DllCall("SendMessage", "Uint", TT_HWND, "Uint", 0x403, "Uint", 3, "Uint", (W ? W*1000 : -1)) ;TTDT_INITIAL
DllCall("SendMessage", "Uint", TT_HWND, "Uint", 0x403, "Uint", 1, "Uint", (W ? W*1000 : -1)) ;TTDT_RESHOW
} else if (!text and !options){
DllCall("DestroyWindow","Uint",TT_HWND)
Gosub, TT_DESTROY
GoTo, TT_EXITFUNC
}
 
;______________________  Create TOOLINFO Structure  ______________________
 
Gosub, TT_SETTOOLINFO
 
If (Q!="")
Gosub, TTM_SETWINDOWTHEME
If (E!="")
Gosub, TTM_SETMARGIN
If (F!="")
Gosub, TTM_SETTIPTEXTCOLOR
If (B!="")
Gosub, TTM_SETTIPBKCOLOR
If (title!="")
Gosub, TTM_SETTITLE
 
If (!A) {
Gosub, TTM_UPDATETIPTEXT
Gosub, TTM_UPDATE
If D {
A_Timer := A_TickCount, D *= 1000
Gosub, TTM_TRACKPOSITION
Gosub, TTM_TRACKACTIVATE
Loop
{
Gosub, TTM_TRACKPOSITION
If (A_TickCount - A_Timer > D)
Break
}
Gosub, TT_DESTROY
DllCall("DestroyWindow","Uint",TT_HWND)
TT_HWND_%TT_ID%=
} else {
Gosub, TTM_TRACKPOSITION
Gosub, TTM_TRACKACTIVATE
If T
WinSet,Transparent,%T%,ahk_id %TT_HWND%
If M
WinSet,ExStyle,^0x20,ahk_id %TT_HWND%
}
}
 
;________  Return HWND of ToolTip  ________
 
Gosub, TT_EXITFUNC
Return TT_HWND
 
;________________________  Internal Labels  ________________________
 
TT_EXITFUNC:
If OnMessage
OnMessage(0x4e,OnMessage)
DetectHiddenWindows, %_DetectHiddenWindows%
Return
TTM_POP:  ;Hide ToolTip
TTM_POPUP:  ;Causes the ToolTip to display at the coordinates of the last mouse message.
TTM_UPDATE: ;Forces the current tool to be redrawn.
DllCall("SendMessage", "Uint", TT_HWND, "Uint", %A_ThisLabel%, "Uint", 0, "Uint", 0)
Return
TTM_TRACKACTIVATE: ;Activates or deactivates a tracking ToolTip.
DllCall("SendMessage", "Uint", TT_HWND, "Uint", %A_ThisLabel%, "Uint", (N ? 0 : 1), "Uint", &TOOLINFO_%ID%)
Return
TTM_UPDATETIPTEXT:
TTM_GETBUBBLESIZE:
TTM_ADDTOOL:
TTM_DELTOOL:
TTM_SETTOOLINFO:
DllCall("SendMessage", "Uint", TT_HWND, "Uint", %A_ThisLabel%, "Uint", 0, "Uint", &TOOLINFO_%ID%)
Return
TTM_SETTITLE:
title := (StrLen(title) < 96) ? title : (Chr(133) SubStr(title, -97))
DllCall("SendMessage", "Uint", TT_HWND, "Uint", %A_ThisLabel%, "Uint", I, "Uint", &Title)
Return
TTM_SETWINDOWTHEME:
If Q
DllCall("uxtheme\SetWindowTheme", "Uint", TT_HWND, "Uint", 0, "UintP", 0)
else
DllCall("SendMessage", "Uint", TT_HWND, "Uint", %A_ThisLabel%, "Uint", 0, "Uint", &K)
Return
TTM_SETMAXTIPWIDTH:
DllCall("SendMessage", "Uint", TT_HWND, "Uint", %A_ThisLabel%, "Uint", 0, "Uint", R ? R : A_ScreenWidth)
Return
TTM_TRACKPOSITION:
VarSetCapacity(xc, 20, 0), xc := Chr(20)
DllCall("GetCursorInfo", "Uint", &xc)
yc := NumGet(xc,16), xc := NumGet(xc,12)
SysGet,xl,76
SysGet,xr,78
SysGet,yl,77
SysGet,yr,79
xc+=15,yc+=15
If (x="caret" or y="caret") {
WinGetPos,xw,yw,,,A
If x=caret
{
xc:=xw+A_CaretX +1
xc:=(xl>xc ? xl : (xr<xc ? xr : xc))
}
If (y="caret"){
yc:=yw+A_CaretY+15
yc:=(yl>yc ? yl : (yr<yc ? yr : yc))
}
} else if (x="TrayIcon" or y="TrayIcon"){
Process, Exist
PID:=ErrorLevel
hWndTray:=WinExist("ahk_class Shell_TrayWnd")
ControlGet,hWndToolBar,Hwnd,,ToolbarWindow321,ahk_id %hWndTray%
RemoteBuf_Open(TrayH,hWndToolBar,20)
DataH:=NumGet(TrayH,0)
SendMessage, 0x418,0,0,,ahk_id %hWndToolBar%
Loop % ErrorLevel
{
SendMessage,0x417,A_Index-1,RemoteBuf_Get(TrayH),,ahk_id %hWndToolBar%
RemoteBuf_Read(TrayH,lpData,20)
VarSetCapacity(dwExtraData,8)
pwData:=NumGet(lpData,12)
DllCall( "ReadProcessMemory", "uint", DataH, "uint", pwData, "uint", &dwExtraData, "uint", 8, "uint", 0 )
BWID:=NumGet(dwExtraData,0)
WinGet,BWPID,PID, ahk_id %BWID%
If (BWPID!=PID and BWPID!=#__MAIN_PID_)
continue
SendMessage, 0x41d,A_Index-1,RemoteBuf_Get(TrayH),,ahk_id %hWndToolBar%
RemoteBuf_Read(TrayH,rcPosition,20)
If (NumGet(lpData,8)>7){
ControlGetPos,xc,yc,xw,yw,Button2,ahk_id %hWndTray%
xc+=xw/2, yc+=yw/4
} else {
ControlGetPos,xc,yc,,,ToolbarWindow321,ahk_id %hWndTray%
halfsize:=NumGet(rcPosition,12)/2
xc+=NumGet(rcPosition,0)+ halfsize
yc+=NumGet(rcPosition,4)+ (halfsize/2)
}
WinGetPos,xw,yw,,,ahk_id %hWndTray%
xc+=xw,yc+=yw
break
}
RemoteBuf_close(TrayH)
}
If xc not between %xl% and %xr%
xc=xc<xl ? xl : xr
If yc not between %yl% and %yr%
yc=yc<yl ? yl : yr
If (!x and !y)
Gosub, TTM_UPDATE
else if !WinActive("ahk_id " . TT_HWND)
DllCall("SendMessage", "Uint", TT_HWND, "Uint", %A_ThisLabel%, "Uint", 0, "Uint", (x<9999999 ? x : xc & 0xFFFF)|(y<9999999 ? y : yc & 0xFFFF)<<16)
Return
TTM_SETTIPBKCOLOR:
If B is alpha
If (%b%)
B:=%b%
B := (StrLen(B) < 8 ? "0x" : "") . B
B := ((B&255)<<16)+(((B>>8)&255)<<8)+(B>>16) ; rgb -> bgr
DllCall("SendMessage", "Uint", TT_HWND, "Uint", %A_ThisLabel%, "Uint", B, "Uint", 0)
Return
TTM_SETTIPTEXTCOLOR:
If F is alpha
If (%F%)
F:=%f%
F := (StrLen(F) < 8 ? "0x" : "") . F
F := ((F&255)<<16)+(((F>>8)&255)<<8)+(F>>16) ; rgb -> bgr
DllCall("SendMessage", "Uint", TT_HWND, "Uint", %A_ThisLabel%, "Uint",F & 0xFFFFFF, "Uint", 0)
Return
TTM_SETMARGIN:
VarSetCapacity(RECT,16)
Loop,Parse,E,.
NumPut(A_LoopField,RECT,(A_Index-1)*4)
DllCall("SendMessage", "Uint", TT_HWND, "Uint", %A_ThisLabel%, "Uint", 0, "Uint", &RECT)
Return
TT_SETTOOLINFO:
If A {
If A is not Xdigit
ControlGet,A,Hwnd,,%A%,ahk_id %P%
ID :=Abs(A)
If !InStr(TT_ALL_%TT_ID%,Chr(2) . ID . Chr(2))
TT_ALL_%TT_ID%  .= Chr(2) . ID . Chr(2) . ID+Abs(P) . Chr(2)
If !TOOLINFO_%ID%
VarSetCapacity(TOOLINFO_%ID%, 40, 0),TOOLINFO_%ID%:=Chr(40)
else
Gosub, TTM_DELTOOL
Numput((N ? 0 : 1)|(J ? 2 : 0)|(L ? 0x1000 : 0)|16,TOOLINFO_%ID%,4),Numput(P,TOOLINFO_%ID%,8),Numput(ID,TOOLINFO_%ID%,12)
If (text!="")
NumPut(&text,TOOLINFO_%ID%,36)
Gosub, TTM_ADDTOOL
      ID :=ID+Abs(P)
If !TOOLINFO_%ID%
{
VarSetCapacity(TOOLINFO_%ID%, 40, 0),TOOLINFO_%ID%:=Chr(40)
Numput(0|16,TOOLINFO_%ID%,4), Numput(P,TOOLINFO_%ID%,8), Numput(P,TOOLINFO_%ID%,12)
}
Gosub, TTM_ADDTOOL
ID :=Abs(A)
} else {
If !TOOLINFO_%ID%
VarSetCapacity(TOOLINFO_%ID%, 40, 0),TOOLINFO_%ID%:=Chr(40)
If (text!=""){
If InStr(text,"<a"){
TOOLTEXT_%ID%:=text
text:=RegExReplace(text,"<a\K[^<]*?>",">")
} else
TOOLTEXT_%ID%:=
NumPut(&text,TOOLINFO_%ID%,36)
}
      NumPut((J ? 2 : 0)|(!(x . y) ? 0 : 0x20)|(S ? 0x80 : 0)|(L ? 0x1000 : 0),TOOLINFO_%ID%,4), Numput(P,TOOLINFO_%ID%,8), Numput(P,TOOLINFO_%ID%,12)
Gosub, TTM_ADDTOOL
}
    TOOLLINK%ID%:=L
  Return
TTN_LINKCLICK:
Loop 4
m += *(text + 8 + A_Index-1) << 8*(A_Index-1)
If !(TTN_FIRST-2=m or TTN_FIRST-3=m or TTN_FIRST-1=m)
Return, OnMessage ? OnMessage(0x4e,OnMessage) : 0
Loop 4
p += *(text + 0 + A_Index-1) << 8*(A_Index-1)
If (TTN_FIRST-3=m)
Loop 4
option += *(text + 16 + A_Index-1) << 8*(A_Index-1)
Loop,Parse,hWndArray,% Chr(2)
If (p=A_LoopField and i:=A_Index)
break
Loop,Parse,idArray,% Chr(2)
{
If (i=A_Index){
If (TTN_FIRST-1=m){
Loop 4
ErrorLevel += *(text + 4 + A_Index-1) << 8*(A_Index-1)
Return A_LoopField, OnMessage ? OnMessage(0x4e,OnMessage) : 0
}
text:=TOOLTEXT_%A_LoopField%
If (TTN_FIRST-2=m){
If Title
{
If IsLabel(A_LoopField . title . "Close")
Gosub % A_LoopField . title . "Close"
else If IsLabel(title . "Close")
Gosub % title . "Close"
} else {
If IsLabel(A_LoopField . A_ThisFunc . "Close")
Gosub % A_LoopField . A_ThisFunc . "Close"
else If IsLabel(A_ThisFunc . "Close")
Gosub % A_ThisFunc . "Close"
}
} else If (InStr(TOOLTEXT_%A_LoopField%,"<a")){
Loop % option+1
StringTrimLeft,text,text,% InStr(text,"<a")+1
If TT_HIDE_%A_LoopField%
%A_ThisFunc%(A_LoopField,"","","gTTM_POP")
If ((a:=A_AutoTrim)="Off")
AutoTrim, On
ErrorLevel:=SubStr(text,1,InStr(text,">")-1)
StringTrimLeft,text,text,% InStr(text,">")
text:=SubStr(text,1,InStr(text,"</a>")-1)
If !ErrorLevel
ErrorLevel:=text
ErrorLevel=%ErrorLevel%
AutoTrim, %a%
If Title
{
If IsFunc(f:=(A_LoopField . title))
%f%(ErrorLevel)
else if IsLabel(A_LoopField . title)
Gosub % A_LoopField . title
else if IsFunc(title)
%title%(ErrorLevel)
else If IsLabel(title)
Gosub, %title%
} else {
if IsFunc(f:=(A_LoopField . A_ThisFunc))
%f%(ErrorLevel)
else If IsLabel(A_LoopField . A_ThisFunc)
Gosub % A_LoopField . A_ThisFunc
else If IsLabel(A_ThisFunc)
Gosub % A_ThisFunc
}
}
break
}
}
DetectHiddenWindows, %_DetectHiddenWindows%
Return OnMessage ? OnMessage(0x4e,OnMessage) : 0
TT_DESTROY:
Loop, Parse, TT_ALL_%TT_ID%,% Chr(2)
If A_LoopField
{
ID:=A_LoopField
Gosub, TTM_DELTOOL
TOOLINFO_%A_LoopField%:="", TT_HWND_%A_LoopField%:="", TOOLTEXT_%A_LoopField%:="", TT_HIDE_%A_LoopField%:="",TOOLLINK%A_LoopField%:=""
}
TT_ALL_%TT_ID%=
Return
 
TTM_INIT:
Init:=1
; Messages
TTM_ACTIVATE := 0x400 + 1, TTM_ADDTOOL := A_IsUnicode ? 0x432 : 0x404, TTM_DELTOOL := A_IsUnicode ? 0x433 : 0x405
,TTM_POP := 0x41c, TTM_POPUP := 0x422, TTM_UPDATETIPTEXT := 0x400 + (A_IsUnicode ? 57 : 12)
,TTM_UPDATE := 0x400 + 29, TTM_SETTOOLINFO := 0x409, TTM_SETTITLE := 0x400 + (A_IsUnicode ? 33 : 32)
,TTN_FIRST := 0xfffffdf8, TTM_TRACKACTIVATE := 0x400 + 17, TTM_TRACKPOSITION := 0x400 + 18
,TTM_SETMARGIN:=0x41a, TTM_SETWINDOWTHEME:=0x200b, TTM_SETMAXTIPWIDTH:=0x418,TTM_GETBUBBLESIZE:=0x41e
,TTM_SETTIPBKCOLOR:=0x413, TTM_SETTIPTEXTCOLOR:=0x414
;Colors
,Black:=0x000000, Green:=0x008000,Silver:=0xC0C0C0
,Lime:=0x00FF00, Gray:=0x808080, Olive:=0x808000
,White:=0xFFFFFF, Yellow:=0xFFFF00, Maroon:=0x800000
,Navy:=0x000080, Red:=0xFF0000, Blue:=0x0000FF
,Purple:=0x800080, Teal:=0x008080, Fuchsia:=0xFF00FF
   ,Aqua:=0x00FFFF
Return
}
 ;{ sub
MI_ExtractIcon(Filename, IconNumber, IconSize) {
If A_OSVersion in WIN_VISTA,WIN_2003,WIN_XP,WIN_2000
{
 DllCall("PrivateExtractIcons", "Str", Filename, "Int", IconNumber-1, "Int", IconSize, "Int", IconSize, "UInt*", hIcon, "UInt*", 0, "UInt", 1, "UInt", 0, "Int")
If !ErrorLevel
Return hIcon
}
If DllCall("shell32.dll\ExtractIconExA", "Str", Filename, "Int", IconNumber-1, "UInt*", hIcon, "UInt*", hIcon_Small, "UInt", 1)
{
SysGet, SmallIconSize, 49
 
If (IconSize <= SmallIconSize) {
DllCall("DeStroyIcon", "UInt", hIcon)
hIcon := hIcon_Small
}
 Else
DllCall("DeStroyIcon", "UInt", hIcon_Small)
 
If (hIcon && IconSize)
hIcon := DllCall("CopyImage", "UInt", hIcon, "UInt", 1, "Int", IconSize, "Int", IconSize, "UInt", 4|8)
}
Return, hIcon ? hIcon : 0
}
GetAssociatedIcon(File) {
   static
   sfi_size:=352
   local Ext,Fileto,FileIcon,FileIcon#
   If !File
      Loop, Parse, #_hIcons, |
         If A_LoopField
            DllCall("DestroyIcon",UInt,A_LoopField)
   If not sfi
      VarSetCapacity(sfi, sfi_size)
   SplitPath, File,,, Ext
If !Ext
Return
   else if Ext in EXE,ICO,ANI,CUR,LNK
   {
      If ext=LNK
      {
         FileGetShortcut,%File%,Fileto,,,,FileIcon,FileIcon#
         File:=!FileIcon ? FileTo : FileIcon
      }
      SplitPath, File,,, Ext
      hIcon%Ext%:=MI_ExtractIcon(file,FileIcon# ? FileIcon# : 1,32)
   } else If (!hIcon%Ext% or !InStr(hIcons,"|" . hIcon%Ext% . "|")){
      If DllCall("Shell32\SHGetFileInfoA", "str", File, "uint", 0, "str", sfi, "uint", sfi_size, "uint", 0x101){
         Loop 4
            hIcon%Ext% += *(&sfi + A_Index-1) << 8*(A_Index-1)
      }
      hIcons .= "|" . hIcon%Ext% . "|"
   }
   return hIcon%Ext%
}
;}

AddToolTip(con,text,Modify = 0) {																						;-- just a simple add on to allow tooltips to be added to controls without having to monitor the wm_mousemove messages
	/*                              	EXAMPLE(s)
	
			Gui,Add,Button,hwndbutton1 Gbut1,Test Button 1
			AddTooltip(button1,"Press me to change my tooltip")
			Gui,show,,Test Gui
			Return

			But1:
			AddTooltip(button1,"Wasn't that easy `;)",1)
			REturn

			GuiClose:
			Guiescape:
			Exitapp
							
	*/
	
 Static TThwnd,GuiHwnd
  If (!TThwnd){
    Gui,+LastFound
    GuiHwnd:=WinExist()
    TThwnd:=CreateTooltipControl(GuiHwnd)
	Varsetcapacity(TInfo,44,0)
	Numput(44,TInfo)
	Numput(1|16,TInfo,4)
	Numput(GuiHwnd,TInfo,8)
	Numput(GuiHwnd,TInfo,12)
	;Numput(&text,TInfo,36)
	Detecthiddenwindows,on
	Sendmessage,1028,0,&TInfo,,ahk_id %TThwnd%
    SendMessage,1048,0,300,,ahk_id %TThwnd%
  }
  Varsetcapacity(TInfo,44,0)
  Numput(44,TInfo)
  Numput(1|16,TInfo,4)
  Numput(GuiHwnd,TInfo,8)
  Numput(con,TInfo,12)
  Numput(&text,TInfo,36)
  Detecthiddenwindows,on
  If (Modify){
    SendMessage,1036,0,&TInfo,,ahk_id %TThwnd%
  }
  Else {
    Sendmessage,1028,0,&TInfo,,ahk_id %TThwnd%
    SendMessage,1048,0,300,,ahk_id %TThwnd%
  }
  
  
}
;{ sub
CreateTooltipControl(hwind) {																						
	
  Ret:=DllCall("CreateWindowEx"
          ,"Uint",0
          ,"Str","TOOLTIPS_CLASS32"
          ,"Uint",0
          ,"Uint",2147483648 | 3
          ,"Uint",-2147483648
          ,"Uint",-2147483648
          ,"Uint",-2147483648
          ,"Uint",-2147483648
          ,"Uint",hwind
          ,"Uint",0
          ,"Uint",0
          ,"Uint",0)
          
  Return Ret
}
;}

AddToolTip(hControl,p_Text) {																							;-- this is a function from jballi -

		/*                              	DESCRIPTION
	
			 Function: AddToolTip
			
			 Description:
			
			   Add/Update tooltips to GUI controls.
			
			 Parameters:
			
			   hControl - Handle to a GUI control.
			
			   p_Text - Tooltip text.
			
			 Returns:
			
			   Handle to the tooltip control.
			
			 Remarks:
			
			 * This function accomplishes this task by creating a single Tooltip control
			   and then creates, updates, or delete tools which are/were attached to the
			   individual GUI controls.
			
			 * This function returns the handle to the Tooltip control so that, if desired,
			   additional actions can be performed on the Tooltip control outside of this
			   function.  Once created, this function reuses the same Tooltip control.
			   If the tooltip control is destroyed outside of this function, subsequent
			   calls to this function will fail.  If desired, the tooltip control can be
			   destroyed just before the script ends.
			
			 Credit and History:
			
			 * Original author: Superfraggle
			   Post: <http://www.autohotkey.com/board/topic/27670-add-tooltips-to-controls/>
			
			 * Updated to support Unicode: art
			   Post: <http://www.autohotkey.com/board/topic/27670-add-tooltips-to-controls/page-2ntry431059>
			
			 * Additional: jballi
			   Bug fixes.  Added support for x64.  Removed Modify parameter.  Added
			   additional functionality, documentation, and constants.
			   
	*/

	Static hTT

          ;-- Misc. constants
          ,CW_USEDEFAULT:=0x80000000
          ,HWND_DESKTOP :=0
          ,WS_EX_TOPMOST:=0x8

          ;-- Tooltip styles
          ,TTS_ALWAYSTIP:=0x1
                ;-- Indicates that the ToolTip control appears when the cursor
                ;   is on a tool, even if the ToolTip control's owner window is
                ;   inactive. Without this style, the ToolTip appears only when
                ;   the tool's owner window is active.

          ,TTS_NOPREFIX:=0x2
                ;-- Prevents the system from stripping ampersand characters from
                ;   a string or terminating a string at a tab character. Without
                ;   this style, the system automatically strips ampersand
                ;   characters and terminates a string at the first tab
                ;   character. This allows an application to use the same string
                ;   as both a menu item and as text in a ToolTip control.

          ;-- TOOLINFO uFlags
          ,TTF_IDISHWND:=0x1
                ;-- Indicates that the uId member is the window handle to the
                ;   tool.  If this flag is not set, uId is the identifier of the
                ;   tool.

          ,TTF_SUBCLASS:=0x10
                ;-- Indicates that the ToolTip control should subclass the
                ;   window for the tool in order to intercept messages, such
                ;   as WM_MOUSEMOVE. If you do not set this flag, you must use
                ;   the TTM_RELAYEVENT message to forward messages to the
                ;   ToolTip control.  For a list of messages that a ToolTip
                ;   control processes, see TTM_RELAYEVENT.

          ;-- Messages
          ,TTM_ADDTOOLA      :=0x404                    ;-- WM_USER + 4
          ,TTM_ADDTOOLW      :=0x432                    ;-- WM_USER + 50
          ,TTM_DELTOOLA      :=0x405                    ;-- WM_USER + 5
          ,TTM_DELTOOLW      :=0x433                    ;-- WM_USER + 51
          ,TTM_GETTOOLINFOA  :=0x408                    ;-- WM_USER + 8
          ,TTM_GETTOOLINFOW  :=0x435                    ;-- WM_USER + 53
          ,TTM_SETMAXTIPWIDTH:=0x418                    ;-- WM_USER + 24
          ,TTM_UPDATETIPTEXTA:=0x40C                    ;-- WM_USER + 12
          ,TTM_UPDATETIPTEXTW:=0x439                    ;-- WM_USER + 57

    ;-- Workarounds for AutoHotkey Basic and x64
    PtrType:=(A_PtrSize=8) ? "Ptr":"UInt"
    PtrSize:=A_PtrSize ? A_PtrSize:4

    ;-- Save/Set DetectHiddenWindows
    l_DetectHiddenWindows:=A_DetectHiddenWindows
    DetectHiddenWindows On

    ;-- Tooltip control exists?
    if not hTT
        {
        ;-- Create Tooltip window
        hTT:=DllCall("CreateWindowEx"
            ,"UInt",WS_EX_TOPMOST                       ;-- dwExStyle
            ,"Str","TOOLTIPS_CLASS32"                   ;-- lpClassName
            ,"UInt",0                                   ;-- lpWindowName
            ,"UInt",TTS_ALWAYSTIP|TTS_NOPREFIX          ;-- dwStyle
            ,"UInt",CW_USEDEFAULT                       ;-- x
            ,"UInt",CW_USEDEFAULT                       ;-- y
            ,"UInt",CW_USEDEFAULT                       ;-- nWidth
            ,"UInt",CW_USEDEFAULT                       ;-- nHeight
            ,"UInt",HWND_DESKTOP                        ;-- hWndParent
            ,"UInt",0                                   ;-- hMenu
            ,"UInt",0                                   ;-- hInstance
            ,"UInt",0                                   ;-- lpParam
            ,PtrType)                                   ;-- Return type

        ;-- Disable visual style
        DllCall("uxtheme\SetWindowTheme",PtrType,hTT,PtrType,0,"UIntP",0)

        ;-- Set the maximum width for the tooltip window
        ;   Note: This message makes multi-line tooltips possible
        SendMessage TTM_SETMAXTIPWIDTH,0,A_ScreenWidth,,ahk_id %hTT%
        }

    ;-- Create/Populate TOOLINFO structure
    uFlags:=TTF_IDISHWND|TTF_SUBCLASS
    cbSize:=VarSetCapacity(TOOLINFO,8+(PtrSize*2)+16+(PtrSize*3),0)
    NumPut(cbSize,      TOOLINFO,0,"UInt")              ;-- cbSize
    NumPut(uFlags,      TOOLINFO,4,"UInt")              ;-- uFlags
    NumPut(HWND_DESKTOP,TOOLINFO,8,PtrType)             ;-- hwnd
    NumPut(hControl,    TOOLINFO,8+PtrSize,PtrType)     ;-- uId

    VarSetCapacity(l_Text,4096,0)
    NumPut(&l_Text,     TOOLINFO,8+(PtrSize*2)+16+PtrSize,PtrType)
        ;-- lpszText

    ;-- Check to see if tool has already been registered for the control
    SendMessage
        ,A_IsUnicode ? TTM_GETTOOLINFOW:TTM_GETTOOLINFOA
        ,0
        ,&TOOLINFO
        ,,ahk_id %hTT%

    RegisteredTool:=ErrorLevel

    ;-- Update TOOLTIP structure
    NumPut(&p_Text,TOOLINFO,8+(PtrSize*2)+16+PtrSize,PtrType)
        ;-- lpszText

    ;-- Add, Update, or Delete tool
    if RegisteredTool
        {
        if StrLen(p_Text)
            SendMessage
                ,A_IsUnicode ? TTM_UPDATETIPTEXTW:TTM_UPDATETIPTEXTA
                ,0
                ,&TOOLINFO
                ,,ahk_id %hTT%
         else
            SendMessage
                ,A_IsUnicode ? TTM_DELTOOLW:TTM_DELTOOLA
                ,0
                ,&TOOLINFO
                ,,ahk_id %hTT%
        }
    else
        if StrLen(p_Text)
            SendMessage
                ,A_IsUnicode ? TTM_ADDTOOLW:TTM_ADDTOOLA
                ,0
                ,&TOOLINFO
                ,,ahk_id %hTT%

    ;-- Restore DetectHiddenWindows
    DetectHiddenWindows %l_DetectHiddenWindows%

    ;-- Return the handle to the tooltip control
    Return hTT
    }


} 
;|														|														|														|														|
;| ShowTrayBalloon()						|   ColoredTooltip()                        	|   AddToolTip() x 4                          	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;System / binary handling in memory / deep system manipulation (62)

;1
CreateNamedPipe(Name, OpenMode=3, PipeMode=0, MaxInstances=255) {	    	;-- creates an instance of a named pipe and returns a handle for subsequent pipe operations
    return DllCall("CreateNamedPipe","str","\\.\pipe\" Name,"uint",OpenMode
        ,"uint",PipeMode,"uint",MaxInstances,"uint",0,"uint",0,"uint",0,"uint",0)
}
;2
RestoreCursors() {																						    			;-- for normal cursor at GUI
   SPI_SETCURSORS := 0x57
   DllCall( "SystemParametersInfo", UInt,SPI_SETCURSORS, UInt,0, UInt,0, UInt,0 )
}
;3
SetSystemCursor( Cursor = "", cx = 0, cy = 0 ) {										    				;-- enables an application to customize the system cursors by using a file or by using the system cursor

	BlankCursor := 0, SystemCursor := 0, FileCursor := 0
	SystemCursors = 32512IDC_ARROW,32513IDC_IBEAM,32514IDC_WAIT,32515IDC_CROSS
		,32516IDC_UPARROW,32640IDC_SIZE,32641IDC_ICON,32642IDC_SIZENWSE
		,32643IDC_SIZENESW,32644IDC_SIZEWE,32645IDC_SIZENS,32646IDC_SIZEALL
		,32648IDC_NO,32649IDC_HAND,32650IDC_APPSTARTING,32651IDC_HELP
	If Cursor =
	{
		VarSetCapacity( AndMask, 32*4, 0xFF ), VarSetCapacity( XorMask, 32*4, 0 )
		BlankCursor = 1
	}
	Else If SubStr( Cursor,1,4 ) = "IDC_"
	{
		Loop, Parse, SystemCursors, `,
		{
			CursorName := SubStr( A_Loopfield, 6, 15 )
			CursorID := SubStr( A_Loopfield, 1, 5 )
			SystemCursor = 1
			If ( CursorName = Cursor )
			{
				CursorHandle := DllCall( "LoadCursor", Uint,0, Int,CursorID )
				Break
			}
		}
		If CursorHandle =
		{
			Msgbox,, SetCursor, Error: Invalid cursor name
			CursorHandle = Error
		}
	}
	Else If FileExist( Cursor )
	{
		SplitPath, Cursor,,, Ext
		If Ext = ico
			uType := 0x1
		Else If Ext in cur,ani
			uType := 0x2
		Else
		{
			Msgbox,, SetCursor, Error: Invalid file type
			CursorHandle = Error
		}
		FileCursor = 1
	}
	Else
	{
		Msgbox,, SetCursor, Error: Invalid file path or cursor name
		CursorHandle = Error
	}
	If CursorHandle != Error
	{
		Loop, Parse, SystemCursors, `,
		{
			If BlankCursor = 1
			{
				Type = BlankCursor
				%Type%%A_Index% := DllCall( "CreateCursor", Uint,0, Int,0, Int,0, Int,32, Int,32, Uint,&AndMask, Uint,&XorMask )
				CursorHandle := DllCall( "CopyImage", Uint,%Type%%A_Index%, Uint,0x2, Int,0, Int,0, Int,0 )
				DllCall( "SetSystemCursor", Uint,CursorHandle, Int,SubStr( A_Loopfield, 1, 5 ) )
			}
			Else If SystemCursor = 1
			{
				Type = SystemCursor
				CursorHandle := DllCall( "LoadCursor", Uint,0, Int,CursorID )
				%Type%%A_Index% := DllCall( "CopyImage"
					, Uint,CursorHandle, Uint,0x2, Int,cx, Int,cy, Uint,0 )
				CursorHandle := DllCall( "CopyImage", Uint,%Type%%A_Index%, Uint,0x2, Int,0, Int,0, Int,0 )
				DllCall( "SetSystemCursor", Uint,CursorHandle, Int,SubStr( A_Loopfield, 1, 5 ) )
			}
			Else If FileCursor = 1
			{
				Type = FileCursor
				%Type%%A_Index% := DllCall( "LoadImageA"
					, UInt,0, Str,Cursor, UInt,uType, Int,cx, Int,cy, UInt,0x10 )
				DllCall( "SetSystemCursor", Uint,%Type%%A_Index%, Int,SubStr( A_Loopfield, 1, 5 ) )
			}
		}
	}
}
;4
SystemCursor(OnOff=1) {  																				    		;-- hiding mouse cursor

	; Borrowed from Laszlo's post @ http://www.autohotkey.com/board/topic/5727-hiding-the-mouse-cursor/
	; INIT = "I","Init"; OFF = 0,"Off"; TOGGLE = -1,"T","Toggle"; ON = others

    static AndMask, XorMask, $, h_cursor
        ,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13 	; system cursors
        , b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13  	; blank cursors
        , h1,h2,h3,h4,h5,h6,h7,h8,h9,h10,h11,h12,h13   	; handles of default cursors
    if (OnOff = "Init" or OnOff = "I" or $ = "") {      			; init when requested or at first call

			$ = h                                          						; active default cursors
			VarSetCapacity( h_cursor,4444, 1 )
			VarSetCapacity( AndMask, 32*4, 0xFF )
			VarSetCapacity( XorMask, 32*4, 0 )
			system_cursors = 32512,32513,32514,32515,32516,32642,32643,32644,32645,32646,32648,32649,32650
			StringSplit c, system_cursors, `,
			Loop %c0%
			{
				h_cursor   := DllCall( "LoadCursor", "uint",0, "uint",c%A_Index% )
				h%A_Index% := DllCall( "CopyImage",  "uint",h_cursor, "uint",2, "int",0, "int",0, "uint",0 )
				b%A_Index% := DllCall("CreateCursor","uint",0, "int",0, "int",0
					, "int",32, "int",32, "uint",&AndMask, "uint",&XorMask )
			}
    }

    if (OnOff = 0 or OnOff = "Off" or $ = "h" and (OnOff < 0 or OnOff = "Toggle" or OnOff = "T"))
        $ = b  																	; use blank cursors
    else
        $ = h  																	; use the saved cursors

    Loop %c0%
    {
        h_cursor := DllCall( "CopyImage", "uint",%$%%A_Index%, "uint",2, "int",0, "int",0, "uint",0 )
        DllCall( "SetSystemCursor", "uint",h_cursor, "uint",c%A_Index% )
    }

}
;4
ToggleSystemCursor( p_id, p_hide=false ) {                                                            	;-- choose a cursor from system cursor list
	
	/*					DESCRIPTION
	
	from Library of Lateralus138's window functions, objects, and classes for AutoHotkey
	Email: faithnomoread@yahoo.com for help, suggestions, or possible collaboration.
	OCR_NORMAL		IDC_ARROW		32512	1
	OCR_IBEAM		IDC_IBEAM		32513	2
	OCR_WAIT		IDC_WAIT		32514	3
	OCR_CROSS		IDC_CROSS		32515	4
	OCR_UP			IDC_UPARROW		32516	5
	OCR_SIZENWSE	IDC_SIZENWSE	32642	6
	OCR_SIZENESW	IDC_SIZENESW	32643	7
	OCR_SIZEWE		IDC_SIZEWE		32644	8
	OCR_SIZENS		IDC_SIZENS		32645	9
	OCR_SIZEALL		IDC_SIZEALL		32646	10
	OCR_NO			IDC_NO			32648	11
	OCR_HAND		IDC_HAND		32649	12
	OCR_APPSTARTING	IDC_APPSTARTING	32650	13
	*/
	
	static	system_cursor_list
	
	if system_cursor_list=
		system_cursor_list = |1:32512|2:32513|3:32514|4:32515|5:32516|6:32642|7:32643|8:32644|9:32645|10:32646|11:32648|12:32649|13:32650|
	
	ix := InStr( system_cursor_list, "|" p_id )
	ix := InStr( system_cursor_list, ":", false, ix )+1
	
	StringMid, id, system_cursor_list, ix, 5
	
	ix_b := ix+6
	ix_e := InStr( system_cursor_list, "|", false, ix )-1
	
	SysGet, cursor_w, 13
	SysGet, cursor_h, 14
	
	if ( cursor_w != 32 or cursor_h != 32 )
	{
		MsgBox, System parameters not supported!
		return
	}
	
	if ( p_hide )
	{
		if ( ix_b < ix_e )
			return

		h_cursor := DllCall( "LoadCursor", "uint", 0, "uint", id )
		
		h_cursor := DllCall( "CopyImage", "uint", h_cursor, "uint", 2, "int", 0, "int", 0, "uint", 0 )
		
		StringReplace, system_cursor_list, system_cursor_list, |%p_id%:%id%, |%p_id%:%id%`,%h_cursor%
		
		VarSetCapacity( AndMask, 32*4, 0xFF )
		VarSetCapacity( XorMask, 32*4, 0 )
		
		h_cursor := DllCall( "CreateCursor"
								, "uint", 0
								, "int", 0
								, "int", 0
								, "int", cursor_w
								, "int", cursor_h
								, "uint", &AndMask
								, "uint", &XorMask )
	}
	else
	{
		if ( ix_b > ix_e )
			return

		StringMid, h_cursor, system_cursor_list, ix_b, ix_e-ix_b+1
		
		StringReplace, system_cursor_list, system_cursor_list, |%p_id%:%id%`,%h_cursor%, |%p_id%:%id% 
	}
	
	result := DllCall( "SetSystemCursor", "uint", h_cursor, "uint", id )
}
;5
SetTimerF( Function, Period=0, ParmObject=0, Priority=0 ) {  					    			;-- Starts a timer that can call functions and object methods
	
 Static current,tmrs:=Object() ;current will hold timer that is currently running
 If IsFunc( Function ) || IsObject( Function ){
    if IsObject(tmr:=tmrs[Function]) ;destroy timer before creating a new one
       ret := DllCall( "KillTimer", UInt,0, UInt, tmr.tmr)
       , DllCall("GlobalFree", UInt, tmr.CBA)
       , tmrs.Remove(Function)
    if (Period = 0 || Period ? "off")
       return ret ;Return as we want to turn off timer
    ; create object that will hold information for timer, it will be passed trough A_EventInfo when Timer is launched
    tmr:=tmrs[Function]:=Object("func",Function,"Period",Period="on" ? 250 : Period,"Priority",Priority
                        ,"OneTime",(Period<0),"params",IsObject(ParmObject)?ParmObject:Object()
                        ,"Tick",A_TickCount)
    tmr.CBA := RegisterCallback(A_ThisFunc,"F",4,&tmr)
    return !!(tmr.tmr  := DllCall("SetTimer", UInt,0, UInt,0, UInt
                        , (Period && Period!="On") ? Abs(Period) : (Period := 250)
                        , UInt,tmr.CBA)) ;Create Timer and return true if a timer was created
            , tmr.Tick:=A_TickCount
 }
 tmr := Object(A_EventInfo) ;A_Event holds object which contains timer information
 if IsObject(tmr) {
    DllCall("KillTimer", UInt,0, UInt,tmr.tmr) ;deactivate timer so it does not run again while we are processing the function
    If (!tmr.active && tmr.Priority<(current.priority ? current.priority : 0)) ;Timer with higher priority is already current so return
       Return (tmr.tmr:=DllCall("SetTimer", UInt,0, UInt,0, UInt, 100, UInt,tmr.CBA)) ;call timer again asap
    current:=tmr
    tmr.tick:=ErrorLevel :=Priority ;update tick to launch function on time
    func := tmr.func.(tmr.params*) ;call function
    current= ;reset timer
    if (tmr.OneTime) ;One time timer, deactivate and delete it
       return DllCall("GlobalFree", UInt,tmr.CBA)
             ,tmrs.Remove(tmr.func)
    tmr.tmr:= DllCall("SetTimer", UInt,0, UInt,0, UInt ;reset timer
            ,((A_TickCount-tmr.Tick) > tmr.Period) ? 0 : (tmr.Period-(A_TickCount-tmr.Tick)), UInt,tmr.CBA)
 }
}
;6
GlobalVarsScript(var="",size=102400,ByRef object=0) {                                          	;-- 

	
  global
  static globalVarsScript
  If (var="")
    Return globalVarsScript
  else if !size {
    If !InStr(globalVarsScript,var ":= CriticalObject(" CriticalObject(object,1) "," CriticalObject(object,2) ")`n"){
      If !CriticalObject(object,1)
        object:=CriticalObject(object)
      globalVarsScript .= var ":= CriticalObject(" CriticalObject(object,1) "," CriticalObject(object,2) ")`n"
    }
  } else {
    Loop,Parse,Var,|
    If !InStr(globalVarsScript,"Alias(" A_LoopField "," GetVar(%A_LoopField%) ")`n"){
      %A_LoopField%:=""
      If size
        VarSetCapacity(%A_LoopField%,size)
      globalVarsScript:=globalVarsScript . "Alias(" A_LoopField "," GetVar(%A_LoopField%) ")`n"
    }
  }
  Return globalVarsScript
}
;7
patternScan(pattern, haystackAddress, haystackSize) {		 							    		;-- 

	/*                              	DESCRIPTION
	
			 Parameters
			 
						 pattern
									A string of two digit numbers representing the hex value of each byte of the pattern. The '0x' hex-prefix is not required
									?? Represents a wildcard byte (can be any value)
									All of the digit groups must be 2 characters long i.e 05, 0F, and ??, NOT 5, F or ?
									Spaces, tabs, and 0x hex-prefixes are optional
									
						 haystackAddress
									The memory address of the binary haystack eg &haystack
									
						 haystackAddress
									The byte length of the binary haystack
			
						 Return values
						  0  	Not Found
						 -1 	An odd number of characters were passed via pattern
								Ensure you use two digits to represent each byte i.e. 05, 0F and ??, and not 5, F or ?
						 -2   	No valid bytes in the needle/pattern
						 int 	The offset from haystackAddress of the start of the found pattern
						
	*/
	

		StringReplace, pattern, pattern, 0x,, All
		StringReplace, pattern, pattern, %A_Space%,, All
		StringReplace, pattern, pattern, %A_Tab%,, All
		pattern := RTrim(pattern, "?")				; can pass patterns beginning with ?? ?? - but why not just start the pattern with the first known byte
		loopCount := bufferSize := StrLen(pattern) / 2
		if Mod(StrLen(pattern), 2)
			return -1
		VarSetCapacity(binaryNeedle, bufferSize)
		aOffsets := [], startGap := 0
		loop, % loopCount
		{
			hexChar := SubStr(pattern, 1 + 2 * (A_Index - 1), 2)
			if (hexChar != "??") && (prevChar = "??" || A_Index = 1)
				binNeedleStartOffset := A_index - 1
			else if (hexChar = "??" && prevChar != "??" && A_Index != 1)
			{

				aOffsets.Insert({ "binNeedleStartOffset": binNeedleStartOffset
								, "binNeedleSize": A_Index - 1 - binNeedleStartOffset
								, "binNeedleGap": !aOffsets.MaxIndex() ? 0 : binNeedleStartOffset - startGap + 1}) ; equals number of wildcard bytes between two sub needles
				startGap := A_index
			}

			if (A_Index = loopCount) ; last char cant be ??
				aOffsets.Insert({ "binNeedleStartOffset": binNeedleStartOffset
								, "binNeedleSize": A_Index - binNeedleStartOffset
								, "binNeedleGap": !aOffsets.MaxIndex() ? 0 : binNeedleStartOffset - startGap + 1})
			prevChar := hexChar
			if (hexChar != "??")
			{
				numput("0x" . hexChar, binaryNeedle, A_index - 1, "UChar")
				realNeedleSize++
			}
		}
		if !realNeedleSize
			return -2 ; no valid bytes in the needle

		haystackOffset := 0
		aOffset := aOffsets[arrayIndex := 1]
		loop
		{
			if (-1 != foundOffset := scanInBuf(haystackAddress, &binaryNeedle + aOffset.binNeedleStartOffset, haystackSize, aOffset.binNeedleSize, haystackOffset))
			{
				; either the first subneedle was found, or the current subneedle is the correct distance from the previous subneedle
				; The scanInBuf returned 'foundOffset' is relative to haystackAddr regardless of haystackOffset
				if (arrayIndex = 1 || foundOffset = haystackOffset)
				{
					if (arrayIndex = 1)
					{
						currentStartOffstet := aOffset.binNeedleSize + foundOffset ; save the offset of the match for the first part of the needle - if remainder of needle doesn't match,  resume search from here
						tmpfoundAddress := foundOffset
					}
					if (arrayIndex = aOffsets.MaxIndex())
						return foundAddress := tmpfoundAddress - aOffsets[1].binNeedleStartOffset  ;+ haystackAddress ; deduct the first needles starting offset - in case user passed a pattern beginning with ?? eg "?? ?? 00 55"
					prevNeedleSize := aOffset.binNeedleSize
					aOffset := aOffsets[++arrayIndex]
					haystackOffset := foundOffset + prevNeedleSize + aOffset.binNeedleGap   ; move the start of the haystack ready for the next needle - accounting for previous needle size and any gap/wildcard-bytes between the two needles
					continue
				}
				; else the offset of the found subneedle was not the correct distance from the end of the previous subneedle
			}
			if (arrayIndex = 1) ; couldn't find the first part of the needle
				return 0
			; the subsequent subneedle couldn't be found.
			; So resume search from the address immediately next to where the first subneedle was found
			aOffset := aOffsets[arrayIndex := 1]
			haystackOffset := currentStartOffstet
		}

	}
;8
scanInBuf(haystackAddr, needleAddr, haystackSize, needleSize, StartOffset = 0) {	;-- 
		;Doesn't WORK with AHK 64 BIT, only works with AHK 32 bit
	/*                              	DESCRIPTION
	
			;taken from:
				;http://www.autohotkey.com/board/topic/23627-machine-code-binary-buffer-searching-regardless-of-null/
				; -1 not found else returns offset address (starting at 0)
				; The returned offset is relative to the haystackAddr regardless of StartOffset
					static fun
					
	*/
	

		; AHK32Bit a_PtrSize = 4 | AHK64Bit - 8 bytes
		if (a_PtrSize = 8)
		  return -1

		ifequal, fun,
		{
		  h =
		  (  LTrim join
		     5589E583EC0C53515256579C8B5D1483FB000F8EC20000008B4D108B451829C129D9410F8E
		     B10000008B7D0801C78B750C31C0FCAC4B742A4B742D4B74364B74144B753F93AD93F2AE0F
		     858B000000391F75F4EB754EADF2AE757F3947FF75F7EB68F2AE7574EB628A26F2AE756C38
		     2775F8EB569366AD93F2AE755E66391F75F7EB474E43AD8975FC89DAC1EB02895DF483E203
		     8955F887DF87D187FB87CAF2AE75373947FF75F789FB89CA83C7038B75FC8B4DF485C97404
		     F3A775DE8B4DF885C97404F3A675D389DF4F89F82B45089D5F5E5A595BC9C2140031C0F7D0
		     EBF0
		  )
		  varSetCapacity(fun, strLen(h)//2)
		  loop % strLen(h)//2
		     numPut("0x" . subStr(h, 2*a_index-1, 2), fun, a_index-1, "char")
		}

		return DllCall(&fun, "uInt", haystackAddr, "uInt", needleAddr
		              , "uInt", haystackSize, "uInt", needleSize, "uInt", StartOffset)
	}
;9
hexToBinaryBuffer(hexString, byRef buffer) {													    		;-- 
	
	StringReplace, hexString, hexString, 0x,, All
	StringReplace, hexString, hexString, %A_Space%,, All
	StringReplace, hexString, hexString, %A_Tab%,, All
	if !length := strLen(hexString)
	{
		msgbox nothing was passed to hexToBinaryBuffer
		return 0
	}
	if mod(length, 2)
	{
		msgbox Odd Number of characters passed to hexToBinaryBuffer`nEnsure two digits are used for each byte e.g. 0E
		return 0
	}
	byteCount := length/ 2
	VarSetCapacity(buffer, byteCount)
	loop, % byteCount
		numput("0x" . substr(hexString, 1 + (A_index - 1) * 2, 2), buffer, A_index - 1, "UChar")
	return byteCount

}
;10
RegRead64(sRootKey, sKeyName, sValueName = "", DataMaxSize=1024) {		    	;-- Provides RegRead64() function that do not redirect to Wow6432Node on 64-bit machines

	; _reg64.ahk ver 0.1 by tomte
	; Script for AutoHotkey   ( http://www.autohotkey.com/ )
	;
	; Provides RegRead64() and RegWrite64() functions that do not redirect to Wow6432Node on 64-bit machines
	; RegRead64() and RegWrite64() takes the same parameters as regular AHK RegRead and RegWrite commands, plus one optional DataMaxSize param for RegRead64()
	;
	; RegRead64() can handle the same types of values as AHK RegRead:
	; REG_SZ, REG_EXPAND_SZ, REG_MULTI_SZ, REG_DWORD, and REG_BINARY
	; (values are returned in same fashion as with RegRead - REG_BINARY as hex string, REG_MULTI_SZ split with linefeed etc.)
	;
	; RegWrite64() can handle REG_SZ, REG_EXPAND_SZ and REG_DWORD only
	;
	; Usage:
	; myvalue := RegRead64("HKEY_LOCAL_MACHINE", "SOFTWARE\SomeCompany\Product\Subkey", "valuename")
	; RegWrite64("REG_SZ", "HKEY_LOCAL_MACHINE", "SOFTWARE\SomeCompany\Product\Subkey", "valuename", "mystring")
	; If the value name is blank/omitted the subkey's default value is used, if the value is omitted with RegWrite64() a blank/zero value is written
	;

	HKEY_CLASSES_ROOT	:= 0x80000000	; http://msdn.microsoft.com/en-us/library/aa393286.aspx
	HKEY_CURRENT_USER	:= 0x80000001
	HKEY_LOCAL_MACHINE	:= 0x80000002
	HKEY_USERS			:= 0x80000003
	HKEY_CURRENT_CONFIG	:= 0x80000005
	HKEY_DYN_DATA		:= 0x80000006
	HKCR := HKEY_CLASSES_ROOT
	HKCU := HKEY_CURRENT_USER
	HKLM := HKEY_LOCAL_MACHINE
	HKU	 := HKEY_USERS
	HKCC := HKEY_CURRENT_CONFIG

	REG_NONE 				:= 0	; http://msdn.microsoft.com/en-us/library/ms724884.aspx
	REG_SZ 					:= 1
	REG_EXPAND_SZ			:= 2
	REG_BINARY				:= 3
	REG_DWORD				:= 4
	REG_DWORD_BIG_ENDIAN	:= 5
	REG_LINK				:= 6
	REG_MULTI_SZ			:= 7
	REG_RESOURCE_LIST		:= 8

	KEY_QUERY_VALUE := 0x0001	; http://msdn.microsoft.com/en-us/library/ms724878.aspx
	KEY_WOW64_64KEY := 0x0100	; http://msdn.microsoft.com/en-gb/library/aa384129.aspx (do not redirect to Wow6432Node on 64-bit machines)
	KEY_SET_VALUE	:= 0x0002
	KEY_WRITE		:= 0x20006

	myhKey := %sRootKey%		; pick out value (0x8000000x) from list of HKEY_xx vars
	IfEqual,myhKey,, {		; Error - Invalid root key
		ErrorLevel := 3
		return ""
	}

	RegAccessRight := KEY_QUERY_VALUE + KEY_WOW64_64KEY

	DllCall("Advapi32.dll\RegOpenKeyExA", "uint", myhKey, "str", sKeyName, "uint", 0, "uint", RegAccessRight, "uint*", hKey)	; open key
	DllCall("Advapi32.dll\RegQueryValueExA", "uint", hKey, "str", sValueName, "uint", 0, "uint*", sValueType, "uint", 0, "uint", 0)		; get value type
	If (sValueType == REG_SZ or sValueType == REG_EXPAND_SZ) {
		VarSetCapacity(sValue, vValueSize:=DataMaxSize)
		DllCall("Advapi32.dll\RegQueryValueExA", "uint", hKey, "str", sValueName, "uint", 0, "uint", 0, "str", sValue, "uint*", vValueSize)	; get string or string-exp
	} Else If (sValueType == REG_DWORD) {
		VarSetCapacity(sValue, vValueSize:=4)
		DllCall("Advapi32.dll\RegQueryValueExA", "uint", hKey, "str", sValueName, "uint", 0, "uint", 0, "uint*", sValue, "uint*", vValueSize)	; get dword
	} Else If (sValueType == REG_MULTI_SZ) {
		VarSetCapacity(sTmp, vValueSize:=DataMaxSize)
		DllCall("Advapi32.dll\RegQueryValueExA", "uint", hKey, "str", sValueName, "uint", 0, "uint", 0, "str", sTmp, "uint*", vValueSize)	; get string-mult
		sValue := ExtractData(&sTmp) "`n"
		Loop {
			If (errorLevel+2 >= &sTmp + vValueSize)
				Break
			sValue := sValue ExtractData( errorLevel+1 ) "`n"
		}
	} Else If (sValueType == REG_BINARY) {
		VarSetCapacity(sTmp, vValueSize:=DataMaxSize)
		DllCall("Advapi32.dll\RegQueryValueExA", "uint", hKey, "str", sValueName, "uint", 0, "uint", 0, "str", sTmp, "uint*", vValueSize)	; get binary
		sValue := ""
		SetFormat, integer, h
		Loop %vValueSize% {
			hex := SubStr(Asc(SubStr(sTmp,A_Index,1)),3)
			StringUpper, hex, hex
			sValue := sValue hex
		}
		SetFormat, integer, d
	} Else {				; value does not exist or unsupported value type
		DllCall("Advapi32.dll\RegCloseKey", "uint", hKey)
		ErrorLevel := 1
		return ""
	}
	DllCall("Advapi32.dll\RegCloseKey", "uint", hKey)
	return sValue
}
;11
RegWrite64(sValueType, sRootKey, sKeyName, sValueName = "", sValue = "") {		;-- RegWrite64() function that do not redirect to Wow6432Node on 64-bit machines

	HKEY_CLASSES_ROOT	:= 0x80000000	; http://msdn.microsoft.com/en-us/library/aa393286.aspx
	HKEY_CURRENT_USER	:= 0x80000001
	HKEY_LOCAL_MACHINE	:= 0x80000002
	HKEY_USERS			:= 0x80000003
	HKEY_CURRENT_CONFIG	:= 0x80000005
	HKEY_DYN_DATA		:= 0x80000006
	HKCR := HKEY_CLASSES_ROOT
	HKCU := HKEY_CURRENT_USER
	HKLM := HKEY_LOCAL_MACHINE
	HKU	 := HKEY_USERS
	HKCC := HKEY_CURRENT_CONFIG

	REG_NONE 				:= 0	; http://msdn.microsoft.com/en-us/library/ms724884.aspx
	REG_SZ 					:= 1
	REG_EXPAND_SZ			:= 2
	REG_BINARY				:= 3
	REG_DWORD				:= 4
	REG_DWORD_BIG_ENDIAN	:= 5
	REG_LINK				:= 6
	REG_MULTI_SZ			:= 7
	REG_RESOURCE_LIST		:= 8

	KEY_QUERY_VALUE := 0x0001	; http://msdn.microsoft.com/en-us/library/ms724878.aspx
	KEY_WOW64_64KEY := 0x0100	; http://msdn.microsoft.com/en-gb/library/aa384129.aspx (do not redirect to Wow6432Node on 64-bit machines)
	KEY_SET_VALUE	:= 0x0002
	KEY_WRITE		:= 0x20006

	myhKey := %sRootKey%			; pick out value (0x8000000x) from list of HKEY_xx vars
	myValueType := %sValueType%		; pick out value (0-8) from list of REG_SZ,REG_DWORD etc. types
	IfEqual,myhKey,, {		; Error - Invalid root key
		ErrorLevel := 3
		return ErrorLevel
	}
	IfEqual,myValueType,, {	; Error - Invalid value type
		ErrorLevel := 2
		return ErrorLevel
	}

	RegAccessRight := KEY_QUERY_VALUE + KEY_WOW64_64KEY + KEY_WRITE

	DllCall("Advapi32.dll\RegCreateKeyExA", "uint", myhKey, "str", sKeyName, "uint", 0, "uint", 0, "uint", 0, "uint", RegAccessRight, "uint", 0, "uint*", hKey)	; open/create key
	If (myValueType == REG_SZ or myValueType == REG_EXPAND_SZ) {
		vValueSize := StrLen(sValue) + 1
		DllCall("Advapi32.dll\RegSetValueExA", "uint", hKey, "str", sValueName, "uint", 0, "uint", myValueType, "str", sValue, "uint", vValueSize)	; write string
	} Else If (myValueType == REG_DWORD) {
		vValueSize := 4
		DllCall("Advapi32.dll\RegSetValueExA", "uint", hKey, "str", sValueName, "uint", 0, "uint", myValueType, "uint*", sValue, "uint", vValueSize)	; write dword
	} Else {		; REG_MULTI_SZ, REG_BINARY, or other unsupported value type
		ErrorLevel := 2
	}
	DllCall("Advapi32.dll\RegCloseKey", "uint", hKey)
	return ErrorLevel
}
{ ;sub
ExtractData(pointer) {

	; Thanks Chris, Lexikos and SKAN
	; http://www.autohotkey.com/forum/topic37710-15.html
	; http://www.autohotkey.com/forum/viewtopic.php?p=235522
	 ; http://www.autohotkey.com/forum/viewtopic.php?p=91578#91578 SKAN

	Loop {
			errorLevel := ( pointer+(A_Index-1) )
			Asc := *( errorLevel )
			IfEqual, Asc, 0, Break ; Break if NULL Character
			String := String . Chr(Asc)
		}
	Return String
}
} 
;12
KillProcess(proc) {																					     				;-- uses DllCalls to end a process

	; https://autohotkey.com/board/topic/119052-check-if-a-process-exists-if-it-does-kill-it/page-2

    static SYNCHRONIZE                 := 0x00100000
    static STANDARD_RIGHTS_REQUIRED    := 0x000F0000
    static OSVERSION                   := (A_OSVersion = "WIN_XP" ? 0xFFF : 0xFFFF)
    static PROCESS_ALL_ACCESS          := STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | OSVERSION

    local tPtr := pPtr := nTTL := 0, PList := ""
    if !(DllCall("wtsapi32.dll\WTSEnumerateProcesses", "Ptr", 0, "Int", 0, "Int", 1, "PtrP", pPtr, "PtrP", nTTL))
        return "", DllCall("kernel32.dll\SetLastError", "UInt", -1)

    tPtr := pPtr
    loop % (nTTL)
    {
        if (InStr(PList := StrGet(NumGet(tPtr + 8)), proc))
        {
            PID := NumGet(tPtr + 4, "UInt")
            if !(hProcess := DllCall("kernel32.dll\OpenProcess", "UInt", PROCESS_ALL_ACCESS, "UInt", FALSE, "UInt", PID, "Ptr"))
                return DllCall("kernel32.dll\GetLastError")
            if !(DllCall("kernel32.dll\TerminateProcess", "Ptr", hProcess, "UInt", 0))
                return DllCall("kernel32.dll\GetLastError")
            if !(DllCall("kernel32.dll\CloseHandle", "Ptr", hProcess))
                return DllCall("kernel32.dll\GetLastError")
        }
        tPtr += (A_PtrSize = 4 ? 16 : 24)
    }
    DllCall("wtsapi32.dll\WTSFreeMemory", "Ptr", pPtr)

    return "", DllCall("kernel32.dll\SetLastError", "UInt", nTTL)
}
;13
LoadScriptResource(ByRef Data, Name, Type = 10) {									     			;-- loads a resource into memory (e.g. picture, scripts..)

	;https://autohotkey.com/board/topic/77519-load-and-display-imagespng-jpg-with-loadscriptresource/

	/*	 example script demonstrates showing an icon image from the resource. It requires sample.ico with the size 64x64 in the script folder.

		#NoEnv
		SetWorkingDir %A_ScriptDir%

		if A_IsCompiled {
			If size := LoadScriptResource(buf,".\sample.ico")
				hIcon := HIconFromBuffer(buf, 64, 64)
			else MsgBox Resource could not be loaded!
		} else {
			FileRead, buf, *c %A_ScriptDir%\sample.ico
			hIcon := HIconFromBuffer(buf, 64, 64)
		}

		Gui, Margin, 20, 20
		Gui, Add, Picture, w64 h64 0x3 hWndPic1      	;0x3 = SS_ICon
		SendMessage, STM_SETICON := 0x0170, hIcon, 0,, ahk_id %Pic1%
		Gui, Show

		Return
		GuiClose:
		   Gui, Destroy
		   hIcon := hIcon := ""
		   ExitApp
		Return


	*/

	; originally posted by Lexikos, modified by HotKeyIt
	; http://www.autohotkey.com/forum/post-516086.html#516086

    lib := DllCall("GetModuleHandle", "ptr", 0, "ptr")
    res := DllCall("FindResource", "ptr", lib, "str", Name, "ptr", Type, "ptr")
    DataSize := DllCall("SizeofResource", "ptr", lib, "ptr", res, "uint")
    hresdata := DllCall("LoadResource", "ptr", lib, "ptr", res, "ptr")
    VarSetCapacity(Data, DataSize)
    DllCall("RtlMoveMemory", "PTR", &Data, "PTR", DllCall("LockResource", "ptr", hresdata, "ptr"), "UInt", DataSize)
    return DataSize
}
;14
HIconFromBuffer(ByRef Buffer, width, height) {											    			;-- Function provides a HICON handle e.g. from a resource previously loaded into memory (LoadScriptResource)

	;Ptr := Ptr ? "Ptr" : "Uint"	; For AutoHotkey Basic Users
	hIcon := DllCall( "CreateIconFromResourceEx"
		, UInt, &Buffer+22
		, UInt, NumGet(Buffer,14)
		, Int,1
		, UInt, 0x30000
		, Int, width
		, Int, height
		, UInt, 0
		, Ptr)
	return hIcon
}
;15
hBMPFromPNGBuffer(ByRef Buffer, width, height) {										     		;-- Function provides a hBitmap handle e.g. from a resource previously loaded into memory (LoadScriptResource)

	;modified SKAN's code ; http://www.autohotkey.com/forum/post-147052.html#147052

	; for AutoHotkey Basic users
	; Ptr := A_PtrSize ? "Ptr" : "Uint" , PtrP := A_PtrSize ? "PtrP" : "UIntP"

	nSize := StrLen(Buffer) * 2 ;// 2 ; <-- I don't understand why it has to be multiplied by 2
	hData := DllCall("GlobalAlloc", UInt, 2, UInt, nSize, Ptr)
	pData := DllCall("GlobalLock", Ptr, hData , Ptr)
	DllCall( "RtlMoveMemory", Ptr, pData, Ptr,&Buffer, UInt,nSize )
	DllCall( "GlobalUnlock", Ptr, hData )
	DllCall( "ole32\CreateStreamOnHGlobal", Ptr, hData, Int, True, PtrP, pStream )
	DllCall( "LoadLibrary", Str,"gdiplus" )
	VarSetCapacity(si, 16, 0), si := Chr(1)
	DllCall( "gdiplus\GdiplusStartup", PtrP, pToken, Ptr, &si, UInt,0 )
	DllCall( "gdiplus\GdipCreateBitmapFromStream", Ptr, pStream, PtrP, pBitmap )
	DllCall( "gdiplus\GdipCreateHBITMAPFromBitmap", Ptr,pBitmap, PtrP, hBitmap, UInt,0)

	hNewBitMap := DllCall("CopyImage"
		  , Ptr, hBitmap
		  , UInt, 0
		  , Int, width
		  , Int, height
		  , UInt, 0x00000008      ;LR_COPYDELETEORG
		  , Ptr)

	DllCall( "gdiplus\GdipDisposeImage", Ptr, pBitmap )
	DllCall( "gdiplus\GdiplusShutdown", Ptr, pToken )
	DllCall( NumGet(NumGet(1*pStream)+8), Ptr, pStream )

	Return hNewBitMap
}
;16
SaveSetColours(set := False, liteSet := True) {													    		;-- Sys colours saving adapted from an approach found in Bertrand Deo's code

	; https://gist.github.com/qwerty12/110b6e68faa60a0145198722c8b8c291
	; The rest is from Michael Maltsev: https://github.com/RaMMicHaeL/Windows-10-Color-Control
	static DWMCOLORIZATIONPARAMS, IMMERSIVE_COLOR_PREFERENCE
		   ,DwmGetColorizationParameters := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandleW", "WStr", "dwmapi.dll", "Ptr"), "Ptr", 127, "Ptr")
		   ,DwmSetColorizationParameters := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandleW", "WStr", "dwmapi.dll", "Ptr"), "Ptr", 131, "Ptr")
		   ,GetUserColorPreference := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandleW", "WStr", "uxtheme.dll", "Ptr"), "AStr", "GetUserColorPreference", "Ptr")
		   ,SetUserColorPreference := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandleW", "WStr", "uxtheme.dll", "Ptr"), "Ptr", 122, "Ptr")
		   ,WM_SYSCOLORCHANGE := 0x0015, sys_colours, sav_colours, colourCount := 31, GetSysColor := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandleW", "WStr", "user32.dll", "Ptr"), "AStr", "GetSysColor", "Ptr")
	if (!set) {
		if (!VarSetCapacity(DWMCOLORIZATIONPARAMS)) {
			VarSetCapacity(sys_colours, 4 * colourCount)
			,VarSetCapacity(sav_colours, 4 * colourCount)
			VarSetCapacity(DWMCOLORIZATIONPARAMS, 28)
			,VarSetCapacity(IMMERSIVE_COLOR_PREFERENCE, 8)
			Loop % colourCount
				NumPut(A_Index - 1, sys_colours, 4 * (A_Index - 1))
		}
		Loop % colourCount
			NumPut(DllCall(GetSysColor, "Int", A_Index - 1, "UInt"), sav_colours, 4 * (A_Index - 1), "UInt")
		DllCall(DwmGetColorizationParameters, "Ptr", &DWMCOLORIZATIONPARAMS)
		DllCall(GetUserColorPreference, "Ptr", &IMMERSIVE_COLOR_PREFERENCE, "Int", False)
	} else {
		if (!liteSet)
			DllCall("SetSysColors", "int", colourCount, "Ptr", &sys_colours, "Ptr", &sav_colours)
		if (VarSetCapacity(DWMCOLORIZATIONPARAMS)) {
			if (!liteSet)
				DllCall(DwmSetColorizationParameters, "Ptr", &DWMCOLORIZATIONPARAMS, "UInt", 0)
			DllCall(SetUserColorPreference, "Ptr", &IMMERSIVE_COLOR_PREFERENCE, "Int", True)
		}
	}
}
;17
ChangeMacAdress() {																						    		;-- change MacAdress, it makes changes to the registry!

		; http://ahkscript.org/germans/forums/viewtopic.php?t=8423 from ILAN12346
		; Caution: Really only change if you know what a MAC address is or what you are doing.
		; I do not assume any liability for any damages!

		Rootkey := "HKEY_LOCAL_MACHINE"
		ValueName := "DriverDesc"
		loop
		{
		  Subkey := "SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}\" . num := "00" . (A_Index < 10  ? "0" . A_Index : A_Index)
		  RegRead, name, % Rootkey, % Subkey, % ValueName
		  if name
			nwa .= name . "***" . num . (A_Index = 1 ? "||" : "|")
		  Else
			break
		}
		gui, Font, s10
		Gui, Add, Edit, x10 y40 w260 h20 +Center vmac,
		Gui, Add, DropDownList, x10 y10 w260 h20 r10 vselect gselect, % RegExReplace(nwa, "\*\*\*", _
											  . "                                                   *")
		Gui, Add, Button, x280 y10 w60 h50 gset , Set Mac
		Gui, Show, x270 y230 h70 w350, MAC
		ValueName := "NetworkAddress"
		Return

		select:
		  gui, submit, NoHide
		  Subkey := "SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}\" . substr(select,instr(select, "*")+1)
		  RegRead, macaddr, % Rootkey, % Subkey, % ValueName
		  GuiControl,, mac, % macaddr
		Return

		set:
		  gui, submit, NoHide
		  link := "SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}\" . substr(select,instr(select, "*")+1)
		  RegRead, macaddr, % Rootkey, % Subkey, % ValueName
		  newmac := RegExReplace(RegExReplace(mac, "-", ""), " ","")
		  StringLower, newmac, newmac
		  maccheck := "0x" . newmac
		  if (strlen(newmac)=12 && (maccheck+1)) || !strlen(newmac)
			RegWrite, REG_SZ, % RootKey, % SubKey , % ValueName, % newmac
		  Else
			MsgBox,16, Error, Incorrect MAC address
			MsgBox, 48,Successful, New MAC Address Acquired
			MsgBox, 36,Reconnect?,The network adapter needs to be reconnected. `n`n reconnect now?
			 IfMsgBox, Yes
			  Run, "ipconfig.exe" -renew,,Hide
		Return

		GuiClose:
		  ExitApp

}
;18
ListAHKStats(Section="ListVars") {																	        	;-- Select desired section: ListLines, ListVars, ListHotkeys, KeyHistory

	; Based on the "ListVars" feature of Lexikos
	; http://www.autohotkey.com/forum/post-165430.html#165430
	; extensions MEC: http://ahkscript.org/germans/forums/viewtopic.php?t=8080
	; Select desired section: ListLines, ListVars, ListHotkeys, KeyHistory
	; Passed data KeyHistory cleaned up with explanatory text

    static hwndEdit, pSFW, pSW, bkpSFW, bkpSW
    if !hwndEdit
    {
        dhw := A_DetectHiddenWindows
        DetectHiddenWindows, On
        Process, Exist
        ControlGet, hwndEdit, Hwnd,, Edit1, ahk_class AutoHotkey ahk_pid %ErrorLevel%
        DetectHiddenWindows, %dhw%

        astr := A_IsUnicode ? "astr":"str"
        ptr := A_PtrSize=8 ? "ptr":"uint"
        hmod := DllCall("GetModuleHandle", "str", "user32.dll")
        pSFW := DllCall("GetProcAddress", ptr, hmod, astr, "SetForegroundWindow")
        pSW := DllCall("GetProcAddress", ptr, hmod, astr, "ShowWindow")
        DllCall("VirtualProtect", ptr, pSFW, ptr, 8, "uint", 0x40, "uint*", 0)
        DllCall("VirtualProtect", ptr, pSW, ptr, 8, "uint", 0x40, "uint*", 0)
        bkpSFW := NumGet(pSFW+0, 0, "int64")
        bkpSW := NumGet(pSW+0, 0, "int64")
    }

    if (A_PtrSize=8) {
        NumPut(0x0000C300000001B8, pSFW+0, 0, "int64")  ; return TRUE
        NumPut(0x0000C300000001B8, pSW+0, 0, "int64")   ; return TRUE
    } else {
        NumPut(0x0004C200000001B8, pSFW+0, 0, "int64")  ; return TRUE
        NumPut(0x0008C200000001B8, pSW+0, 0, "int64")   ; return TRUE
    }

      ;added by MEC:
      ;Section: "ListLines","ListVars","ListHotkeys","KeyHistory"
      If (Section="ListLines")
         ListLines
      Else
         If (Section="ListVars")
            ListVars
         Else
            If (Section="ListHotkeys")
               ListHotkeys
            Else
               KeyHistory

    NumPut(bkpSFW, pSFW+0, 0, "int64")
    NumPut(bkpSW, pSW+0, 0, "int64")

    ControlGetText, text,, ahk_id %hwndEdit%

      ;---MEC: Text explanations cut out and out with them
      If (Section="KeyHistory") {
         pos:=InStr(text, "NOTE:" ,"", 200)
         text1:=SubStr(text, 1, pos-1)
         pos:=InStr(text, "#IfWinActive/Exist" ,"", pos)
         text:=SubStr(text, pos +23)
         text:=text1 . text
         }
    return text
}
;19
MouseExtras(HoldSub, HoldTime="200", DoubleSub=""								    		;-- Allows to use subroutines for Holding and Double Clicking a Mouse Button.
, DClickTime="0.2", Button="") {

	; Author: Pulover [Rodolfo U. Batista]
	; rodolfoub@gmail.com

	/*		Description
		- Allows to use subroutines for Holding and Double Clicking a Mouse Button.
		- Keeps One-Click and Drag functions.
		- Works with combinations, i.e. LButton & RButton.

		Usage:
		Assign the function to the Mouse Hotkey and input the Labels to
		trigger with GoSub and wait times in the parameters:

		MouseExtras("HoldSub", "DoubleSub", "HoldTime", "DClickTime", "Button")
		  HoldSub: Button Hold Label.
		  HoldTime: Wait Time to Hold Button (miliseconds - optional).
		  DoubleSub: Double Click Label.
		  DClickTime: Wait Time for Double Click (seconds - optional).
		  Button: Choose a different Button (optional - may be useful for combinations).

		- If you don't want to use a certain function put "" in the label.
		- I recommend using the "*" prefix to allow them to work with modifiers.
		- Note: Althought it's designed for MouseButtons it will work with Keyboard as well.
	*/

    If Button =
		Button := A_ThisHotkey
	Button := LTrim(Button, "~*$")
	If InStr(Button, "&")
		Button := RegExReplace(Button, "^.*&( +)?")
	MouseGetPos, xpos
	Loop
	{
		MouseGetPos, xposn
		If (A_TimeSinceThisHotkey > HoldTime)
		{
			If IsLabel(HoldSub)
				GoSub, %HoldSub%
			Else
			{
				Send {%Button% Down}
				KeyWait, %Button%
				Send {%Button% Up}
			}
			return
		}
		Else
		If (xpos <> xposn)
		{
			Send {%Button% Down}
			KeyWait, %Button%
			Send {%Button% Up}
			return
		}
		Else
		If !GetKeyState(Button, "P")
		{
			If !IsLabel(DoubleSub)
			{
				Send {%Button%}
				return
			}
			KeyWait, %Button%, D T%DClickTime%
			If ErrorLevel
				Send {%Button%}
			Else
			{
				If IsLabel(DoubleSub)
					GoSub, %DoubleSub%
				Else
					Send {%Button%}
			}
			return
		}
	}
}
;20
TimedFunction( _Label, _Params = 0, _Period = 250 ) {                                             	;-- SetTimer functionality for functions

    /*
    MIT License
    Copyright (c) 2017 Gene Alyson Fortunado Torcende
    */

    static _List := []
    if IsFunc( _Label ) {
        if _List.HasKey( _Label ) {
            _Func := _List[_Label]
            _Timer := _Func.TID
            if ( _Period = "Off" ) {
                SetTimer, % _Timer, OFF
                _List.Remove( _Label )
                return
            }
            else
                return _List[ _Label ]
        }
        _Timer := Func( _Label ).Bind( _Params* )
        SetTimer, % _Timer, % _Period
        return _List[_Label] := { Function: _Label, Parameters: _Params, Period: _Period, TID: _Timer }
    }

}
;21
ListGlobalVars() {																								    		;-- ListGlobalVars() neither shows nor activates the AutoHotkey main window, it returns a string

	; Written by Lexikos - see: http://www.autohotkey.com/board/topic/20925-listvars/#entry156570
	/*		examples
		Loop {
			tick := A_TickCount
			ToolTip % ListGlobalVars()
		}
	*/

    static hwndEdit, pSFW, pSW, bkpSFW, bkpSW

    if !hwndEdit
    {
        dhw := A_DetectHiddenWindows
        DetectHiddenWindows, On
        Process, Exist
        ControlGet, hwndEdit, Hwnd,, Edit1, ahk_class AutoHotkey ahk_pid %ErrorLevel%
        DetectHiddenWindows, %dhw%

        astr := A_IsUnicode ? "astr":"str"
        ptr := A_PtrSize=8 ? "ptr":"uint"
        hmod := DllCall("GetModuleHandle", "str", "user32.dll")
        pSFW := DllCall("GetProcAddress", ptr, hmod, astr, "SetForegroundWindow")
        pSW := DllCall("GetProcAddress", ptr, hmod, astr, "ShowWindow")
        DllCall("VirtualProtect", ptr, pSFW, ptr, 8, "uint", 0x40, "uint*", 0)
        DllCall("VirtualProtect", ptr, pSW, ptr, 8, "uint", 0x40, "uint*", 0)
        bkpSFW := NumGet(pSFW+0, 0, "int64")
        bkpSW := NumGet(pSW+0, 0, "int64")
    }

    if (A_PtrSize=8) {
        NumPut(0x0000C300000001B8, pSFW+0, 0, "int64")  ; return TRUE
        NumPut(0x0000C300000001B8, pSW+0, 0, "int64")   ; return TRUE
    } else {
        NumPut(0x0004C200000001B8, pSFW+0, 0, "int64")  ; return TRUE
        NumPut(0x0008C200000001B8, pSW+0, 0, "int64")   ; return TRUE
    }

    ListVars

    NumPut(bkpSFW, pSFW+0, 0, "int64")
    NumPut(bkpSW, pSW+0, 0, "int64")

    ControlGetText, text,, ahk_id %hwndEdit%

    RegExMatch(text, "sm)(?<=^Global Variables \(alphabetical\)`r`n-{50}`r`n).*", text)
    return text
}
;22
TaskList(delim:="|",getArray:=0,sort:=0) {		     														;-- list all running tasks (no use of COM)		
	
		;https://github.com/Lateralus138/Task-Lister
		
		d := delim
		s := 4096  
		Process, Exist  
		h := DllCall("OpenProcess", "UInt", 0x0400, "Int", false, "UInt", ErrorLevel, "Ptr")
		DllCall("Advapi32.dll\OpenProcessToken", "Ptr", h, "UInt", 32, "PtrP", t)
		VarSetCapacity(ti, 16, 0)  
		NumPut(1, ti, 0, "UInt")  
		DllCall("Advapi32.dll\LookupPrivilegeValue", "Ptr", 0, "Str", "SeDebugPrivilege", "Int64P", luid)
		NumPut(luid, ti, 4, "Int64")
		NumPut(2, ti, 12, "UInt")  
		r := DllCall("Advapi32.dll\AdjustTokenPrivileges", "Ptr", t, "Int", false, "Ptr", &ti, "UInt", 0, "Ptr", 0, "Ptr", 0)
		DllCall("CloseHandle", "Ptr", t)  
		DllCall("CloseHandle", "Ptr", h)  
		hModule := DllCall("LoadLibrary", "Str", "Psapi.dll")  
		s := VarSetCapacity(a, s)  
		c := 0  
		DllCall("Psapi.dll\EnumProcesses", "Ptr", &a, "UInt", s, "UIntP", r)
		Loop, % r // 4  
		{
		   id := NumGet(a, A_Index * 4, "UInt")
		   h := DllCall("OpenProcess", "UInt", 0x0010 | 0x0400, "Int", false, "UInt", id, "Ptr")
		   if !h
			  continue
		   VarSetCapacity(n, s, 0)  
		   e := DllCall("Psapi.dll\GetModuleBaseName", "Ptr", h, "Ptr", 0, "Str", n, "UInt", A_IsUnicode ? s//2 : s)
		   if !e    
			  if e := DllCall("Psapi.dll\GetProcessImageFileName", "Ptr", h, "Str", n, "UInt", A_IsUnicode ? s//2 : s)
				{
					 SplitPath, n, n
				}
		   DllCall("CloseHandle", "Ptr", h)  
		   if (n && e)  
			  l .= n . d, c++
		}
		DllCall("FreeLibrary", "Ptr", hModule)  
		l:=SubStr(l,1,StrLen(l)-1) " " ndir
		If getArray
			{
				proc:=!proc?Object():""
				Loop, Parse, l, |
					proc.Push(A_LoopField)
			}
		If sort
			Sort, l, D%delim%
		Return getArray?proc:l
}
;23
MouseDpi(mode_speed:=0) {																				    	;-- Change the current dpi setting of the mouse
	
	; https://github.com/Lateralus138/OnTheFlyDpi/blob/master/ontheflydpi_funcs.ahk
	DllCall("SystemParametersInfo","UInt",0x70,"UInt",0,"UIntP",_current_,"UInt",0)
	If mode_speed Is Not Number
		{
			If (InStr(mode_speed,"reset") And (_current_!=10)){
				DllCall("SystemParametersInfo","UInt",0x71,"UInt",0,"UInt",10,"UInt",0)
				DllCall("SystemParametersInfo","UInt",0x70,"UInt",0,"UIntP",_current_,"UInt",0)
			}
			Return _current_
		}
	mode_speed	:=(mode_speed!=0 And mode_speed>20)?20
				:(mode_speed!=0 And mode_speed<0)?1
				:mode_speed
	If (mode_speed!=0 And (_current_!=mode_speed))
		DllCall("SystemParametersInfo","UInt",0x71,"UInt",0,"UInt",mode_speed,"UInt",0)
	Return !mode_speed?_current_:mode_speed
}
;24
SendToAHK(String, WinString) {                                                                                	;-- Sends strings by using a hidden gui between AHK scripts
			
	/*                              	EXAMPLE(s) will be found in ReceiveFromAHK() function
	*/
	
	/*                              	DESCRIPTION
	
		a function by DJAnonimo: posted on https://autohotkey.com/boards/viewtopic.php?f=6&t=45965
		with a bit modification by Ixiko 
		
		added 'WinString' option to handle different windows
		you have to paste a string like WinString:="MyGuiWinTitle" or WinString:="ahk_exe MyAHKScript"
		you can paste also WinString:="ahk_id " . MyGuiHwnd
			
	*/

	Prev_DetectHiddenWindows := A_DetectHiddenWindows
	DetectHiddenWindows On
	StringLen := StrLen(String)
	Loop, %StringLen%
	{
	AscNum := Asc(SubStr(String, A_Index, 1))
	if (A_Index = StringLen)
		LastChar := 1
	PostMessage, 0x5555, AscNum, LastChar,,%WinString%
	}
	DetectHiddenWindows %Prev_DetectHiddenWindows%
}
;25
ReceiveFromAHK(wParam, lParam, Msg) {																	;-- Receiving strings from SendToAHK

	/*                              	EXAMPLE(s)
	
			gui, new,, AHK
			OnMessage(0x5555, "ReceiveFromAHK")
			SetTimer, MyTimer, 100
			
			
			MyTimer:
				if receivedVar 
				Received_String := receivedVar, receivedVar := ""
				Msgbox "%Received_String%"
				
			return
			
	*/
	
	global tempVar
	global receivedVar
		if (Msg = 0x5555)
			{
			tempVar .= Chr(wParam)
			if lParam
				receivedVar := tempVar, tempVar := ""
			}
		
}
;26
GetUIntByAddress(_addr, _offset = 0) {																		;-- get UInt direct from memory. I found this functions only within one script 
	/*                              	DESCRIPTION
	
			Origin: https://autohotkey.com/board/topic/15950-treeview-with-tooltip-tvn-getinfotip-notification/
			
	*/
	local result
	Loop 4
	{
		result += *(_addr + _offset + A_Index-1) << 8*(A_Index-1)
	}
	Return result
}
;27
SetUIntByAddress(_addr, _integer, _offset = 0) {															;-- write UInt direct to memory
	/*                              	DESCRIPTION
	
			Origin: https://autohotkey.com/board/topic/15950-treeview-with-tooltip-tvn-getinfotip-notification/
			
	*/
	Loop 4
	{
		DllCall("RtlFillMemory"
				, "UInt", _addr + _offset + A_Index-1
				, "UInt", 1
				, "UChar", (_integer >> 8*(A_Index-1)) & 0xFF)
	}
}
;28
SetRestrictedDacl() {																									;-- run this in your script to hide it from Task Manager
	
	/*                              	DESCRIPTION
	
			Link: https://autohotkey.com/boards/viewtopic.php?t=43235
			By:	qwerty12
			
			Description: Paste the following functions in somewhere and call SetRestrictedDacl() on startup of your script. 
			It's not foolproof: an admin can always kill the process (even without the explicit PROCESS_ALL_ACCESS granted to it) and given that the owner of the process is you, 
			if a person knows how to re-add the process's missing rights back to its object, then there's nothing stopping them from doing so.
			
			(Note: under default UAC settings, when Task Manager is launched it will automatically be elevated if your account is part of the Administrators group.)
			
	*/
		
	ret := False

	hCurProc := DllCall("GetCurrentProcess", "Ptr")
	if (!DllCall("advapi32\OpenProcessToken", "Ptr", hCurProc, "UInt", TOKEN_QUERY := 0x0008, "Ptr*", hToken))
		return ret

	if (!_GetTokenInformation(hToken, TokenUser := 1, 0, 0, dwLengthNeeded))
		if (A_LastError == 122 && VarSetCapacity(TOKEN_USER, dwLengthNeeded)) ; ERROR_INSUFFICIENT_BUFFER
			if (_GetTokenInformation(hToken, TokenUser, &TOKEN_USER, dwLengthNeeded, dwLengthNeeded)) {
				SECURITY_MAX_SID_SIZE := 68
				SIDs := {"WinWorldSid": "1", "WinLocalSystemSid": "22", "WinBuiltinAdministratorsSid": "26"}
				for k, v in SIDs {
					SIDs.SetCapacity(k, (cbSid := SECURITY_MAX_SID_SIZE))
					if (!DllCall("advapi32\CreateWellKnownSid", "UInt", v+0, "Ptr", 0, "Ptr", SIDs.GetAddress(k), "UInt*", cbSid)) {
						DllCall("CloseHandle", "Ptr", hToken)
						return ret
					}
				}

				EA := [{ "grfAccessPermissions": PROCESS_ALL_ACCESS := (STANDARD_RIGHTS_REQUIRED := 0x000F0000) | (SYNCHRONIZE := 0x00100000) | 0xFFFF ; 0xFFF for XP and 2000
						,"grfAccessMode":        GRANT_ACCESS := 1
						,"grfInheritance":       NO_INHERITANCE := 0
						,"TrusteeForm":          TRUSTEE_IS_SID := 0
						,"TrusteeType":          TRUSTEE_IS_WELL_KNOWN_GROUP := 5
						,"ptstrName":            SIDs.GetAddress("WinLocalSystemSid")}
					  ,{ "grfAccessPermissions": PROCESS_ALL_ACCESS
						,"grfAccessMode":        GRANT_ACCESS
						,"grfInheritance":       NO_INHERITANCE
						,"TrusteeForm":          TRUSTEE_IS_SID
						,"TrusteeType":          TRUSTEE_IS_WELL_KNOWN_GROUP
						,"ptstrName":            SIDs.GetAddress("WinBuiltinAdministratorsSid")}
					  ,{ "grfAccessPermissions": PROCESS_QUERY_LIMITED_INFORMATION := 0x1000 | PROCESS_CREATE_PROCESS := 0x0080
						,"grfAccessMode":        GRANT_ACCESS
						,"grfInheritance":       NO_INHERITANCE
						,"TrusteeForm":          TRUSTEE_IS_SID
						,"TrusteeType":          TRUSTEE_IS_USER := 1
						,"ptstrName":            NumGet(TOKEN_USER,, "Ptr")} ; user script is running under
					  ,{ "grfAccessPermissions": PROCESS_ALL_ACCESS
						,"grfAccessMode":        DENY_ACCESS := 3
						,"grfInheritance":       NO_INHERITANCE
						,"TrusteeForm":          TRUSTEE_IS_SID
						,"TrusteeType":          TRUSTEE_IS_WELL_KNOWN_GROUP
						,"ptstrName":            SIDs.GetAddress("WinWorldSid")}]

				padding := A_PtrSize == 8 ? 4 : 0
				cbEXPLICIT_ACCESS_W := (4 * 3) + padding + (A_PtrSize + (4 * 3) + padding + A_PtrSize)
				VarSetCapacity(EXPLICIT_ACCESS_W, cbEXPLICIT_ACCESS_W * EA.MaxIndex(), 0)
				for i, v in EA {
					thisEA := cbEXPLICIT_ACCESS_W * (i - 1)
					NumPut(v.grfAccessPermissions, EXPLICIT_ACCESS_W, thisEA, "UInt")
					NumPut(v.grfAccessMode, EXPLICIT_ACCESS_W, thisEA + 4, "UInt")
					NumPut(v.grfInheritance, EXPLICIT_ACCESS_W, thisEA + (4 * 2), "UInt")
					NumPut(v.TrusteeForm, EXPLICIT_ACCESS_W, thisEA + ((4 * 3) + padding + A_PtrSize + 4), "UInt")
					NumPut(v.TrusteeType, EXPLICIT_ACCESS_W, thisEA + ((4 * 3) + padding + A_PtrSize + (4 * 2)), "UInt")
					NumPut(v.ptstrName, EXPLICIT_ACCESS_W, thisEA + ((4 * 3) + padding + A_PtrSize + (4 * 3) + padding), "Ptr")				
				}
						
				if (!DllCall("advapi32\SetEntriesInAcl", "UInt", EA.MaxIndex(), "Ptr", &EXPLICIT_ACCESS_W, "Ptr", 0, "Ptr*", pNewDacl)) {
					ret := !DllCall("Advapi32\SetSecurityInfo", "Ptr", hCurProc, "UInt", SE_KERNEL_OBJECT := 6, "UInt", DACL_SECURITY_INFORMATION := 0x00000004, "Ptr", 0, "Ptr", 0, "Ptr", pNewDacl, "Ptr", 0)
					DllCall("LocalFree", "Ptr", pNewDacl, "Ptr")
				}
			}
	
	DllCall("CloseHandle", "Ptr", hToken)
	return ret
}
;{ sub
_GetTokenInformation(TokenHandle, TokenInformationClass, ByRef TokenInformation, TokenInformationLength, ByRef ReturnLength, _tokenInfoType := "Ptr") {
	return DllCall("advapi32\GetTokenInformation", "Ptr", TokenHandle, "UInt", TokenInformationClass, _tokenInfoType, TokenInformation, "UInt", TokenInformationLength, "UInt*", ReturnLength)
}
;}
;29
getActiveProcessName() {																							;-- this function finds the process to the 'ForegroundWindow'
	;by Lexikos  https://autohotkey.com/boards/viewtopic.php?p=73137#p73137
	handle := DllCall("GetForegroundWindow", "Ptr")
	DllCall("GetWindowThreadProcessId", "Int", handle, "int*", pid)
	global true_pid := pid
	callback := RegisterCallback("enumChildCallback", "Fast")
	DllCall("EnumChildWindows", "Int", handle, "ptr", callback, "int", pid)
	handle := DllCall("OpenProcess", "Int", 0x0400, "Int", 0, "Int", true_pid)
	length := 259 ;max path length in windows
	VarSetCapacity(name, length)
	DllCall("QueryFullProcessImageName", "Int", handle, "Int", 0, "Ptr", &name, "int*", length)
	SplitPath, name, pname
	return pname
}
;30
enumChildCallback(hwnd, pid) {																					;-- i think this retreave's the child process ID for a known gui hwnd and the main process ID
	DllCall("GetWindowThreadProcessId", "Int", hwnd, "int*", child_pid)
	if (child_pid != pid)
		global true_pid := child_pid
	return 1
}
;31
GetDllBase(DllName, PID = 0) {		;--
    TH32CS_SNAPMODULE := 0x00000008
    INVALID_HANDLE_VALUE = -1
    VarSetCapacity(me32, 548, 0)
    NumPut(548, me32)
    snapMod := DllCall("CreateToolhelp32Snapshot", "Uint", TH32CS_SNAPMODULE
                                                 , "Uint", PID)
    If (snapMod = INVALID_HANDLE_VALUE) {
        Return 0
    }
    If (DllCall("Module32First", "Uint", snapMod, "Uint", &me32)){
        while(DllCall("Module32Next", "Uint", snapMod, "UInt", &me32)) {
            If !DllCall("lstrcmpi", "Str", DllName, "UInt", &me32 + 32) {
                DllCall("CloseHandle", "UInt", snapMod)
                Return NumGet(&me32 + 20)
            }
        }
    }
    DllCall("CloseHandle", "Uint", snapMod)
    Return 0
}
;32
getProcBaseFromModules(process) {		;--

/*
	http://stackoverflow.com/questions/14467229/get-base-address-of-process
	Open the process using OpenProcess -- if successful, the value returned is a handle to the process, which is just an opaque token used by the kernel to identify a kernel object. Its exact integer value (0x5c in your case) has no meaning to userspace programs, other than to distinguish it from other handles and invalid handles.
	Call GetProcessImageFileName to get the name of the main executable module of the process.
	Use EnumProcessModules to enumerate the list of all modules in the target process.
	For each module, call GetModuleFileNameEx to get the filename, and compare it with the executable's filename.
	When you've found the executable's module, call GetModuleInformation to get the raw entry point of the executable.
*/


	_MODULEINFO := "
					(
					  LPVOID lpBaseOfDll;
					  DWORD  SizeOfImage;
					  LPVOID EntryPoint;
				  	)"
	Process, Exist, %process%
	if ErrorLevel 							; PROCESS_QUERY_INFORMATION + PROCESS_VM_READ
		hProc := DllCall("OpenProcess", "uint", 0x0400 | 0x0010 , "int", 0, "uint", ErrorLevel)
	if !hProc
		return -2
	VarSetCapacity(mainExeNameBuffer, 2048 * (A_IsUnicode ? 2 : 1))
	DllCall("psapi\GetModuleFileNameEx", "uint", hProc, "Uint", 0
				, "Ptr", &mainExeNameBuffer, "Uint", 2048 / (A_IsUnicode ? 2 : 1))
	mainExeName := StrGet(&mainExeNameBuffer)
	; mainExeName = main executable module of the process
	size := VarSetCapacity(lphModule, 4)
	loop
	{
		DllCall("psapi\EnumProcessModules", "uint", hProc, "Ptr", &lphModule
				, "Uint", size, "Uint*", reqSize)
		if ErrorLevel
			return -3, DllCall("CloseHandle","uint",hProc)
		else if (size >= reqSize)
			break
		else
			size := VarSetCapacity(lphModule, reqSize)
	}
	VarSetCapacity(lpFilename, 2048 * (A_IsUnicode ? 2 : 1))
	loop % reqSize / A_PtrSize ; sizeof(HMODULE) - enumerate the array of HMODULEs
	{
		DllCall("psapi\GetModuleFileNameEx", "uint", hProc, "Uint", numget(lphModule, (A_index - 1) * 4)
				, "Ptr", &lpFilename, "Uint", 2048 / (A_IsUnicode ? 2 : 1))
		if (mainExeName = StrGet(&lpFilename))
		{
			moduleInfo := struct(_MODULEINFO)
			DllCall("psapi\GetModuleInformation", "uint", hProc, "Uint", numget(lphModule, (A_index - 1) * 4)
				, "Ptr", moduleInfo[], "Uint", SizeOf(moduleInfo))
			;return moduleInfo.SizeOfImage, DllCall("CloseHandle","uint",hProc)
			return moduleInfo.lpBaseOfDll, DllCall("CloseHandle","uint",hProc)
		}
	}
	return -1, DllCall("CloseHandle","uint",hProc) ; not found
}
;33
InjectDll(pid,dllpath)  {																									;-- injects a dll to a running process (ahkdll??)

    FileGetSize, size, %dllpath%
    file := FileOpen(dllpath, "r")
    file.RawRead(dllFile, size)

    pHandle := DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", false, "UInt", pid)

    pLibRemote := DllCall("VirtualAllocEx", "Uint", pHandle, "Uint", 0, "Uint", size, "Uint", 0x1000, "Uint", 4)

    VarSetCapacity(result,4)
    DllCall("WriteProcessMemory","Uint",pHandle,"Uint",pLibRemote,"Uint",&dllFile,"Uint",size,"Uint",&result)

    LoadLibraryAdd := DllCall("GetProcAddress", "Uint", DllCall("GetModuleHandle", "str", "kernel32.dll"),"AStr", "LoadLibraryA")

    hThrd := DllCall("CreateRemoteThread", "Uint", pHandle, "Uint", 0, "Uint", 0, "Uint", LoadLibraryAdd, "Uint", pLibRemote, "Uint", 0, "Uint", 0)

    DllCall("VirtualFreeEx","Uint",hProcess,"Uint",pLibRemote,"Uint",0,"Uint",32768)

    DllCall("CloseHandle", "Uint", hThrd)
    DllCall("CloseHandle", "Uint", pHandle)
    Return True

}
;34
getProcessBaseAddress(WindowTitle, MatchMode=3)	{											;-- gives a pointer to the base address of a process for further memory reading

	;-- https://autohotkey.com/boards/viewtopic.php?t=9016
	;--WindowTitle can be anything ahk_exe ahk_class etc
	mode :=  A_TitleMatchMode
	SetTitleMatchMode, %MatchMode%	;mode 3 is an exact match
	WinGet, hWnd, ID, %WindowTitle%
	; AHK32Bit A_PtrSize = 4 | AHK64Bit - 8 bytes
	BaseAddress := DllCall(A_PtrSize = 4
		? "GetWindowLong"
		: "GetWindowLongPtr", "Uint", hWnd, "Uint", -6)
	SetTitleMatchMode, %mode%	; In case executed in autoexec

	return BaseAddress
}
;35
LoadFile(path, exe:="", exception_level:=-1) {																;-- Loads a script file as a child process and returns an object

	/*		DESCRIPTION

    LoadFile(Path [, EXE])

        Loads a script file as a child process and returns an object
        which can be used to call functions or get/set global vars.

    Path:
          The path of the script.
    EXE:
          The path of the AutoHotkey executable (defaults to A_AhkPath).

    Requirements:
      - AutoHotkey v1.1.17+    http://ahkscript.org/download/
      - ObjRegisterActive      http://goo.gl/wZsFLP
      - CreateGUID             http://goo.gl/obfmDc

    Version: 1.0
*/

    ObjRegisterActive(client := {}, guid := CreateGUID())
    code =
    (LTrim
    LoadFile.Serve("%guid%")
    #include %A_LineFile%
    #include %path%
    )
    try {
        exe := """" (exe="" ? A_AhkPath : exe) """"
        exec := ComObjCreate("WScript.Shell").Exec(exe " /ErrorStdOut *")
        exec.StdIn.Write(code)
        exec.StdIn.Close()
        while exec.Status = 0 && !client._proxy
            Sleep 10
        if exec.Status != 0 {
            err := exec.StdErr.ReadAll()
            ex := Exception("Failed to load file", exception_level)
            if RegExMatch(err, "Os)(.*?) \((\d+)\) : ==> (.*?)(?:\s*Specifically: (.*?))?\R?$", m)
                ex.Message .= "`n`nReason:`t" m[3] "`nLine text:`t" m[4] "`nFile:`t" m[1] "`nLine:`t" m[2]
            throw ex
        }
    }
    finally
        ObjRegisterActive(client, "")
    return client._proxy
}
{ ;sub LoadFile_class
class LoadFile {
    Serve(guid) {
        try {
            client := ComObjActive(guid)
            client._proxy := new this.Proxy
            client := ""
        }
        catch ex {
            stderr := FileOpen("**", "w")
            stderr.Write(format("{} ({}) : ==> {}`n     Specifically: {}"
                , ex.File, ex.Line, ex.Message, ex.Extra))
            stderr.Close()  ; Flush write buffer.
            ExitApp
        }
        ; Rather than sleeping in a loop, make the script persistent
        ; and then return so that the #included file is auto-executed.
        Hotkey IfWinActive, %guid%
        Hotkey vk07, #Persistent, Off
        #Persistent:
    }
    class Proxy {
        __call(name, args*) {
            if (name != "G")
                return %name%(args*)
        }
        G[name] { ; x.G[name] because x[name] via COM invokes __call.
            get {
                global
                return ( %name% )
            }
            set {
                global
                return ( %name% := value )
            }
        }
        __delete() {
            ExitApp
        }
    }
}
} 
;36
ReadProcessMemory(hProcess, BaseAddress, Buffer, Bytes := 0								;-- reads data from a memory area in a given process.
, ByRef NumberOfBytesRead := "", ReturnType := "UInt") {

		/*                              	DESCRIPTION
		
			The entire area to be read must be accessible or the operation will fail
			Syntax: 				ReadProcessMemory ([hProcess], [BaseAddress], [data (out)], [size, in bytes], [NumberOfBytesRead (in_out)], [ReturnType])
			Parameters:			BaseAddress: a pointer to the base address in the specific process to read
			Data: 					A pointer to a buffer that receives the contents of the address space of the specified process.
			Size: 					the number of bytes that is read from the specified processNumberOfBytesRead: receives the number of bytes transferred in the specified bufferReturnType: type of value to return. defect = UInt 
			
	*/
	

	BaseAddress := IsObject(BaseAddress)?BaseAddress:["UInt", BaseAddress], Error := ErrorLevel
	if IsByRef(NumberOfBytesRead)
		VarSetCapacity(NumberOfBytesRead, NumberOfBytesRead?NumberOfBytesRead:16, 0)
	Result := DllCall("Kernel32.dll\ReadProcessMemory", "Ptr", hProcess, BaseAddress[1], BaseAddress[2], "Ptr", Buffer, "UPtr"
	, Bytes>0?Bytes:VarSetCapacity(Buffer), "UPtrP", IsByRef(NumberOfBytesRead)?&NumberOfBytesRead:0, ReturnType)
	if IsByRef(NumberOfBytesRead)
		NumberOfBytesRead := NumGet(NumberOfBytesRead, 0, "UPtrP")
	return Result, ErrorLevel := Error
}
;37
WriteProcessMemory(hProcess, BaseAddress															;-- writes data to a memory area in a specified process. the entire area to be written must be accessible or the operation will fail
, Buffer, Bytes := 0, ByRef NumberOfBytesWritten := "") { 
	
	/*                              	DESCRIPTION
	
			Syntax: WriteProcessMemory( [hProcess], [BaseAddress], [Buffer], [Size], [NumberOfBytesWritten] )
			
	*/
		
	BaseAddress := IsObject(BaseAddress)?BaseAddress:["UInt", BaseAddress], Error := ErrorLevel
	if IsByRef(NumberOfBytesWritten)
		VarSetCapacity(NumberOfBytesWritten, 16, 0)
	Result :=  DllCall("Kernel32.dll\WriteProcessMemory", "Ptr", hProcess, BaseAddress[1], BaseAddress[2], "Ptr", Buffer, "UPtr"
	, Bytes>0?Bytes:VarSetCapacity(Buffer), "UPtrP", IsByRef(NumberOfBytesWritten)?&NumberOfBytesWritten:0, "UInt")
	if IsByRef(NumberOfBytesWritten)
		NumberOfBytesWritten := NumGet(NumberOfBytesWritten, 0, "UPtrP")
	return Result, ErrorLevel := Error
}
;38
CopyMemory(ByRef Destination, Source, Bytes) {														;-- Copy a block of memory from one place to another
	/*                              	DESCRIPTION
	
			Syntax: CopyMemory[ [destination], [source], [bytes] )
			
	*/
	
	DllCall("msvcrt.dll\memcpy_s", "Ptr", Destination, "UInt", Bytes, "Ptr", Source, "UInt", Bytes)
}
;39
MoveMemory(ByRef Destination, Source, Bytes) {                                                   	;-- moves a block memory from one place to another												
   	 /*                              	DESCRIPTION
 			Syntax: MoveMemory [[target], [source], [bytes])
	*/

	DllCall("msvcrt.dll\memmove_s", "Ptr", Destination, "UInt", Bytes, "Ptr", Source, "UInt", Bytes)
} 
 ;40
FillMemory(ByRef Destination, Bytes, Fill) {																	;-- fills a block of memory with the specified value
	;Syntax: FillMemory ([destination], [bytes], [value])
	DllCall("ntdll.dll\RtlFillMemory", "Ptr", Destination, "UInt", Bytes, "UChar", Fill) 
} ;https://msdn.microsoft.com/en-us/library/windows/hardware/ff561870(v=vs.85).aspx
;41
ZeroMemory(ByRef Destination, Bytes) {																	;-- fills a memory block with zeros
	DllCall("ntdll.dll\RtlZeroMemory", "Ptr", Destination, "UInt", Bytes)
} ;https://msdn.microsoft.com/en-us/library/windows/hardware/ff563610(v=vs.85).aspx
;42
CompareMemory(Source1, Source2, Size := 0) {															;-- compare two memory blocks
	
	/*                              	DESCRIPTION
	
			Syntax: 	CompareMemory ([mem1], [mem2], [total size, in bytes])
			Return:		1 	= mem1> mem2
							0 	= mem1 = mem2
							-1	= mem1 <mem2
	*/
	
	if !(Size)
		Size1 := VarSetCapacity(Source1), Size2 := VarSetCapacity(Source2), Size := Size1<Size2?Size1:Size2
		, Result := DllCall("msvcrt.dll\memcmp", "UPtr", &Source1, "UPtr", &Source2, "UInt", Size, "CDecl Int")
	else Result := DllCall("msvcrt.dll\memcmp", "UPtr", Source1, "UPtr", Source2, "UInt", Size, "CDecl Int")
	return Result>0?1:Result<0?-1:0, ErrorLevel := ((Result+0)="")
}
 ;43
VirtualAlloc(ByRef hProcess := 0, ByRef Address := 0													;-- changes the state of a region of memory within the virtual address space of a specified process. the memory is assigned to zero.AtEOF
, ByRef Bytes := 0, AllocationType := 0x00001000, Protect := 0x04, Preferred := 0) {
	
	/*                              	DESCRIPTION
	
			Syntax: VirtualAlloc ([hProcess], [address], [size], [type], [protection], [NUMA])
			hProcess (optional): HANDLE a process, if it is not used, use the current process.
			Address (optional): start address of the assign Region
			Size: size of the region, in bytes
			Type: type of memory allocation
			MEM_COMMIT (default) = 0x00001000
			MEM_RESERVE = 0x00002000
			MEM_RESET = 0x00080000
			MEM_RESET_UNDO = 0x1000000
			-------------------------------------------------- -------
			MEM_LARGE_PAGES = 0x20000000
			MEM_PHYSICAL = 0x00400000
			MEM_TOP_DOWN = 0x00100000
			Protection: Memory protection for the region of pages that will be assigned
			PAGE_EXECUTE = 0x10
			PAGE_EXECUTE_READ = 0x20
			PAGE_EXECUTE_READWRITE = 0x40
			PAGE_EXECUTE_WRITECOPY = 0x80
			PAGE_NOACCESS = 0x01
			PAGE_READONLY = 0x02
			PAGE_READWRITE (default) = 0x04
			PAGE_WRITECOPY = 0x08
			PAGE_TARGETS_INVALID = 0x40000000
			PAGE_TARGETS_NO_UPDATE = 0x40000000
			-------------------------------------------------- -------
			PAGE_GUARD = 0x100
			PAGE_NOCACHE = 0x200
			PAGE_WRITECOMBINE = 0x400
			NUMA (optional): NUMA node, where the physical memory must reside.
			
	*/
		
	if !(hProcess) ;VirtualAlloc
		return DllCall("Kernel32.dll\VirtualAlloc", "UInt", Address, "UPtr", Bytes, "UInt", AllocationType, "UInt", Protect, "UInt")
	if !(Preferred) ;VirtualAllocEx + hProcess | else VirtualAllocExNuma + NUMA
		return DllCall("Kernel32.dll\VirtualAllocEx", "Ptr", hProcess, "UInt", Address, "UPtr", Bytes, "UInt", AllocationType, "UInt", Protect, "UInt")
	return DllCall("Kernel32.dll\VirtualAllocExNuma", "Ptr", hProcess, "UInt", Address, "UPtr", Bytes, "UInt", AllocationType, "UInt", Protect, "UInt", Preferred, "UInt")
} ;https://msdn.microsoft.com/en-us/library/windows/desktop/aa366891(v=vs.85).aspx
 ;44
VirtualFree(hProcess := 0, Address := 0, Bytes := 0, AllocationType := 0x8000) {		;-- release a region of pages within the virtual address space of the specified process 
	/*                              	DESCRIPTION
			Syntax: VirtualFree( [hProcess], [direccion], [tamaño, en bytes], [tipo] )
			Types:
			MEM_DECOMMIT = 0x4000
			MEM_RELEASE (default) = 0x8000
	*/
	
	Error := ErrorLevel
	if !(hProcess) ;VirtualFree | else VirtualFreeEx + hProcess
		return DllCall("Kernel32.dll\VirtualFree", "UInt", Address, "UPtr", Bytes, "UInt", AllocationType, "UInt"), ErrorLevel := Error
	return DllCall("Kernel32.dll\VirtualFreeEx", "Ptr", hProcess, "UInt", Address, "UPtr", Bytes, "UInt", AllocationType, "UInt"), ErrorLevel := Error
}
 ;45
ReduceMem() {																											;-- reduces usage of memory from calling script 
	
	/*                              	DESCRIPTION
	
			Link: 					https://autohotkey.com/board/topic/56984-new-process-notifier/
			 Function from: 	New Process Notifier 
			 Language:       	English
			 Platform:       		Windows XP or later
			 			 
										Copyright (C) 2010 sbc <http://sites.google.com/site/littlescripting/>
										Licence: GNU GENERAL PUBLIC LICENSE. Please reffer to this page for more information. http://www.gnu.org/licenses/gpl.html
			
	*/
	
	
    pid := DllCall("GetCurrentProcessId")
    h := DllCall("OpenProcess", "UInt", 0x001F0FFF, "Int", 0, "Int", pid)
    DllCall("SetProcessWorkingSetSize", "UInt", h, "Int", -1, "Int", -1)
    DllCall("CloseHandle", "Int", h)
}
;46
GlobalLock(hMem) {																									;-- memory management function
	return DllCall("Kernel32.dll\GlobalLock", "Ptr", hMem, "Ptr")
} GlobalAlloc(Bytes, Flags := 0x0002) {
	return DllCall("Kernel32.dll\GlobalAlloc", "UInt", Flags, "UInt", Bytes, "Ptr")
} GlobalReAlloc(hMem, Bytes, Flags := 0x0002) {
	return DllCall("Kernel32.dll\GlobalReAlloc", "Ptr", hMem, "UInt", Bytes, "UInt", Flags, "Ptr")
} GlobalUnlock(hMem) {
	return DllCall("Kernel32.dll\GlobalUnlock", "Ptr", hMem, "UInt")
} GlobalFree(hMem) {
	return DllCall("Kernel32.dll\GlobalFree", "Ptr", hMem, "Ptr")
} GlobalSize(hMem) {
	return DllCall("Kernel32.dll\GlobalSize", "Ptr", hMem, "UInt")
} GlobalDiscard(hMem) {
	return DllCall("Kernel32.dll\GlobalDiscard", "Ptr", hMem, "Ptr")
} GlobalFlags(hMem) {
	return DllCall("Kernel32.dll\GlobalFlags", "Ptr", hMem, "UInt")
}
;47
LocalFree(hMem*) {																										;-- free a locked memory object
	Error := ErrorLevel, Ok := 0
	for k, v in hMem
		Ok += !DllCall("Kernel32.dll\LocalFree", "Ptr", v, "Ptr")
	return Ok=hMem.MaxIndex(), ErrorLevel := Error
}
;48
CreateStreamOnHGlobal(hGlobal, DeleteOnRelease := true) {									;-- creates a stream object that uses an HGLOBAL memory handle to store the stream contents. This object is the OLE-provided implementation of the IStream interface.
	DllCall("ole32.dll\CreateStreamOnHGlobal", "Ptr", hGlobal, "Int", !!DeleteOnRelease, "PtrP", IStream)
	return IStream
}
;49
CoTaskMemFree(ByRef hMem) {																					;-- releases a memory block from a previously assigned task through a call to the CoTaskMemAlloc () or CoTaskMemAlloc () function.
	Error := ErrorLevel
	, Ok := DllCall("Ole32.dll\CoTaskMemFree", "UPtr", hMem)
	return !!Ok, VarSetCapacity(hMem, 0), ErrorLevel := Error
} ;https://msdn.microsoft.com/en-us/library/windows/desktop/ms680722(v=vs.85).aspx
;50
CoTaskMemAlloc(Bytes) {																							;-- assign a working memory block
	/*                              	DESCRIPTION
				Syntax: CoTaskMemAlloc ([memory block size, in bytes])
			Return: hMem 
	*/
	
	return DllCall("Ole32.dll\CoTaskMemAlloc", "UPtr", Bytes, "UPtr")
} ;https://msdn.microsoft.com/en-us/library/windows/desktop/ms692727(v=vs.85).aspx
;51
CoTaskMemRealloc(hMem, Bytes) {																			;-- change the size of a previously assigned block of working memory
	/*                              	DESCRIPTION
	
			.Syntax: CoTaskMemRealloc ([hMem], [new size for the memory block, in bytes]) 
			
	*/
	
	return DllCall("Ole32.dll\CoTaskMemRealloc", "Ptr", hMem, "UPtr", Bytes, "Ptr")
} ;https://msdn.microsoft.com/en-us/library/windows/desktop/ms687280(v=vs.85).aspx
;52
VarAdjustCapacity(ByRef Var) {																					;-- adjusts the capacity of a variable to its content
	/*                              	DESCRIPTION
	
			Example:
			VarSetCapacity (OutputVar, 104857600, 0) attaches 100 MB to OutputVar
			OutputVar: = "123456789" assigns a string of characters to OutputVar	
			MsgBox % "Contenido: " OutputVar "`nCapacidad: " 
			VarSetCapacity(OutputVar) shows the content and current capacity of OutputVar, in bytes.
			VarAdjustCapacity (OutputVar) by applying the adjustment.	
			MsgBox % "Contenido: " OutputVar "`nCapacidad: " VarSetCapacity(OutputVar) returns to show the current content and capacity of OutputVar, in bytes. 
			
	*/
	
	return Capacity := VarSetCapacity(Var, -1)
	, OutputVar := Var, VarSetCapacity(Var, 0)
	, VarSetCapacity(Var, Capacity), Var := OutputVar
}
;53
DllListExports( DLL, Hdr := 0 ) {         																			;-- List of Function exports of a DLL

	/*                              	DESCRIPTION
	
			By SKAN,  http://goo.gl/DsMqa6 ,  CD:26/Aug/2010 | MD:14/Sep/2014  
			llListExports() - List of Function exports of a DLL  |  http://ahkscript.org/boards/viewtopic.php?t=4563
			Author: Suresh Kumar A N ( arian.suresh@gmail.com )        
			_________________________________________________________________________________________________________
	*/
	


Local LOADED_IMAGE, nSize := VarSetCapacity( LOADED_IMAGE, 84, 0 ), pMappedAddress, pFileHeader
    , pIMGDIR_EN_EXP, IMAGE_DIRECTORY_ENTRY_EXPORT := 0, RVA, VA, LIST := ""  
    , hModule := DllCall( "LoadLibrary", "Str","ImageHlp.dll", "Ptr" ) 

  If ! DllCall( "ImageHlp\MapAndLoad", "AStr",DLL, "Int",0, "Ptr",&LOADED_IMAGE, "Int",True, "Int",True )
    Return                

  pMappedAddress := NumGet( LOADED_IMAGE, ( A_PtrSize = 4 ) ?  8 : 16 )
  pFileHeader    := NumGet( LOADED_IMAGE, ( A_PtrSize = 4 ) ? 12 : 24 )
 
  pIMGDIR_EN_EXP := DllCall( "ImageHlp\ImageDirectoryEntryToData", "Ptr",pMappedAddress 
                           , "Int",False, "UShort",IMAGE_DIRECTORY_ENTRY_EXPORT, "PtrP",nSize, "Ptr" )

  VA  := DllCall( "ImageHlp\ImageRvaToVa", "Ptr",pFileHeader, "Ptr",pMappedAddress, "UInt"
, RVA := NumGet( pIMGDIR_EN_EXP + 12 ), "Ptr",0, "Ptr" )

  If ( VA ) {
     VarSetCapacity( LIST, nSize, 0 )
     Loop % NumGet( pIMGDIR_EN_EXP + 24, "UInt" ) + 1
        LIST .= StrGet( Va + StrLen( LIST ), "" ) "`n"
             ,  ( Hdr = 0 and A_Index = 1 and ( Va := Va + StrLen( LIST ) ) ? LIST := "" : "" )  
  }
    
  DllCall( "ImageHlp\UnMapAndLoad", "Ptr",&LOADED_IMAGE ),   DllCall( "FreeLibrary", "Ptr",hModule )

Return RTrim( List, "`n" )
}
;54
RtlUlongByteSwap64(num){																						;-- routine reverses the ordering of the four bytes in a 32-bit unsigned integer value (AHK v2)
	/*                              	DESCRIPTION
	
			; Url:
				;	- https://msdn.microsoft.com/en-us/library/windows/hardware/ff562886(v=vs.85).aspx (RtlUlongByteSwap routine)
				;	- https://msdn.microsoft.com/en-us/library/e8cxb8tk.aspx (_swab function)
				; For example, if the Source parameter value is 0x12345678, the routine returns 0x78563412.
				; works on both 32 and 64 bit.
				
	*/
	/*                              	EXAMPLE(s)
	
			; Tested only on these examples,
			msgbox(format("0x", RtlUlongByteSwap64(0x12345678)))
			msgbox(format("0x", RtlUlongByteSwap64(0x78563412)))
			
	*/
	
	static dest, i := varsetcapacity(dest,4)
	DllCall("MSVCRT.dll\_swab", "ptr", &num, "ptr", &dest+2, "int", 2, "cdecl")
	,DllCall("MSVCRT.dll\_swab", "ptr", &num+2, "ptr", &dest, "int", 2, "cdecl")
	return numget(dest,"uint")
}
;55
RtlUlongByteSwap64(num) {																						;-- routine reverses the ordering of the four bytes in a 32-bit unsigned integer value (AHK v1)
	/*                              	DESCRIPTION
	
				Link: https://autohotkey.com/boards/viewtopic.php?f=5&t=39002
					- https://msdn.microsoft.com/en-us/library/windows/hardware/ff562886(v=vs.85).aspx (RtlUlongByteSwap routine)
					- https://msdn.microsoft.com/en-us/library/e8cxb8tk.aspx (_swab function)
				A ULONG value to convert to a byte-swapped version
				For example, if the Source parameter value is 0x12345678, the routine returns 0x78563412.
				works on both 32 and 64 bit.
				v1 version
				
	*/
	/*                              	EXAMPLE(s)
	
			; Tested only on these examples,
			msgbox % format("0x", RtlUlongByteSwap64(0x12345678))
			msgbox % format("0x", RtlUlongByteSwap64(0x78563412))
			
	*/
	
	static dest, src
	static i := varsetcapacity(dest,4) + varsetcapacity(src,4)
	numput(num,src,"uint")
	,DllCall("MSVCRT.dll\_swab", "ptr", &src, "ptr", &dest+2, "int", 2, "cdecl")
	,DllCall("MSVCRT.dll\_swab", "ptr", &src+2, "ptr", &dest, "int", 2, "cdecl")
	return numget(dest,"uint")
}


{ ;retreaving informations about system, user, hardware (7)
;1
UserAccountsEnum(Options := "") {																			;-- list all users with information
	
	/*                              	DESCRIPTION
	
			; list all users with information
			; Syntax: UserAccountsEnum ([options])
			; Parameters:
			; Options: specify the search conditions
			; Syntax: [space] WHERE [that] = '[equal to]' [AND | OR ...]
			;Example:
			; for k, v in UserAccountsEnum ()
			; MsgBox% k "#` n "v.Domain" \ "v.Name
			 ;https://msdn.microsoft.com/en-us/library/windows/desktop/aa394507(v=vs.85).aspx
			 
	*/
		
	List := []
	for this in ComObjGet("winmgmts:\\.\root\CIMV2").ExecQuery("SELECT * FROM Win32_UserAccount" Options) {
		Info := {}
		Loop, Parse, % "AccountType|Caption|Description|Disabled|Domain|FullName|InstallDate|LocalAccount"
		. "|Lockout|Name|PasswordChangeable|PasswordExpires|PasswordRequired|SID|SIDType|Status", |
			Info[A_LoopField] := this[A_LoopField]
		List.Push(Info)
	} return List
}
;2
GetCurrentUserInfo() {																									;-- obtains information from the current user
	
	/*                              	DESCRIPTION
	
			; obtains information from the current user
			; Example: MsgBox% "Domain \ User:" GetCurrentUserInfo (). Domain "\" GetCurrentUserInfo (). Name "`nSID: "GetCurrentUserInfo (). SID
			;Notes:
			Another way to get the SID, is using cmd.
			Link: http://www.windows-commandline.com/get-sid-of-user/
			; Example: wmic useraccount where (name = '% username%' and domain = '% userdomain%') get sid
			
	*/
	
	
	static CurrentUserInfo
	if !(CurrentUserInfo)
		if !(CurrentUserInfo:=UserAccountsEnum(" WHERE Name = '" A_UserName "' AND Domain = '" A_UserDomain() "'")[1])
			CurrentUserInfo := UserAccountsEnum(" WHERE Name = '" A_UserName "'")[1]
	return CurrentUserInfo
} 
;3
GetHandleInformation(Handle, ByRef Flags := "") {													;-- obtain certain properties of a HANDLE
	
	/*                              	DESCRIPTION
	
			; https: //msdn.microsoft.com/en-us/library/windows/desktop/ms724329 (v = vs.85) .aspx
			; obtain certain properties of a HANDLE
			; Syntax: GetHandleInformation ([HANDLE], [flags])
			; Parameters:
			; Flags: can be one of the following values.
			; 0x00000000
			; 0x00000001 = HANDLE_FLAG_INHERIT
			; 0x00000002 = HANDLE_FLAG_PROTECT_FROM_CLOSE
			; Return: 0 | 1
			; ErrorLevel:
			; 1 = OK
			; 6 = the HANDLE is invalid
			; [another] = see https://msdn.microsoft.com/en-us/library/ms681382(v=vs.85).aspx
			
	*/
	
	
	Ok := DllCall("Kernel32.dll\GetHandleInformation", "Ptr", Handle, "UIntP", Flags)
	return !!Ok, ErrorLevel := Ok?false:A_LastError
} 
;4
SetHandleInformation(Handle, Flags := 0x00000000) {												;-- establishes the properties of a HANDLE
	
	/*                              	DESCRIPTION
	
			; establishes the properties of a HANDLE
			; Syntax: SetHandleInformation ([HANDLE], [flags])
			; Return / ErrorLevel / Parameters: see GetHandleInformation ()
			
	*/
	
	
	Ok := DllCall("Kernel32.dll\SetHandleInformation", "Ptr", Handle, "UInt", Flags, "UInt", Flags)
	return !!Ok, ErrorLevel := Ok?false:A_LastError
}
;5
 GetPhysicallyInstalledSystemMemory() { 																	;-- recovers the amount of RAM in physically installed KB from the SMBIOS (System Management BIOS) firmware tables, WIN_V SP1+
	/*                              	DESCRIPTION
	
			Example: MsgBox % Round(GetPhysicallyInstalledSystemMemory()/1024, 1) " MB"
			Note: to recover only RAM, use GlobalMemoryStatus (). TotalPhys
			
	*/
	DllCall("Kernel32.dll\GetPhysicallyInstalledSystemMemory", "Int64P", TotalMemoryInKilobytes)
	return TotalMemoryInKilobytes
}
;6
GlobalMemoryStatus() {																								;-- retrieves information about the current use of physical and virtual memory of the system
	/*                              	EXAMPLE(s)
			MsgBox % (l:=GlobalMemoryStatus()) "Load: " l.Load " %`nRAM: " Round(l.TotalPhys/(1024**2), 1) " MB" 
	*/
	
	VarSetCapacity(MEMORYSTATUSEX, 64, 0), NumPut(64, MEMORYSTATUSEX, "UInt")
	r := DllCall("Kernel32.dll\GlobalMemoryStatusEx", "Ptr", &MEMORYSTATUSEX)
	return !r?false:{Load: NumGet(MEMORYSTATUSEX, 4, "UInt") ;número entre 0 y 100 que especifica el porcentaje aproximado de la memoria física que está en uso
	, TotalPhys: NumGet(MEMORYSTATUSEX, 8, "UInt64") ;cantidad de memoria física real, en bytes
	, AvailPhys: NumGet(MEMORYSTATUSEX, 16, "UInt64") ;cantidad de memoria física disponible actualmente, en bytes
	, TotalPageFile: NumGet(MEMORYSTATUSEX, 24, "UInt64") ;límite de memoria comprometida actual para el sistema o el proceso actual, en bytes
	, AvailPageFile: NumGet(MEMORYSTATUSEX, 32, "UInt64") ;cantidad máxima de memoria que el proceso actual puede usar, en bytes.
	, TotalVirtual: NumGet(MEMORYSTATUSEX, 40, "UInt64") ;espacio de direcciones virtuales del proceso de llamada, en bytes
	, AvailVirtual: NumGet(MEMORYSTATUSEX, 48, "UInt64")} ;espacio disponible de direcciones virtuales del proceso de llamada, en bytes
} ;https://msdn.microsoft.com/en-us/library/windows/desktop/aa366589(v=vs.85).aspx
;7
GetSystemFileCacheSize(ByRef MinimumFileCacheSize := ""										;-- retrieves the current size limits for the working set of the system cache
, ByRef MaximumFileCacheSize := "", ByRef Flags := "") {
	/*                              	DESCRIPTION
	
			Syntax: GetSystemFileCacheSize ([min, in bytes], [max, in bytes], [FILE_CACHE_MAX_HARD_ENABLE = 1 
			Example: MsgBox % GetSystemFileCacheSize(Min, Max, Flags) "`nMin: " Round(Min/(1024**2), 1) " MB" "`nMax: " Round(Max/(1024**2), 1) " MB" "`nFlags: " Flags
			
	*/
	
	return DllCall("Kernel32.dll\GetSystemFileCacheSize", "Int64P", MinimumFileCacheSize, "Int64P", MaximumFileCacheSize, "UIntP", Flags)
} ;https://msdn.microsoft.com/en-us/library/windows/desktop/aa965224(v=vs.85).aspx
;

}
} 
;|														|														|														|														|
;|	CreateNamedPipe()						|	RestoreCursors()							|	SetSystemCursor()						|	SystemCursor()								|
;|  ToggleSystemCursor()              	|	SetTimerF()									|	IGlobalVarsScript()						|	patternScan()								|
;|	scanInBuf()									|	hexToBinaryBuffer()						|	GetDllBase()									|	getProcBaseFromModules()			|
;|	RegRead64()								|	RegWrite64()								|	LoadScriptResource()					|
;|	HIconFromBuffer()						|	hBMPFromPNGBuffer()				|	SaveSetColours()							|	ChangeMacAdress()						|
;|	ListAHKStats()								|	MouseExtras()								|	TimedFunction()							|	ListGlobalVars()							|
;|	TaskList()										|   MouseDpi()                              	|   SendToAHK()                            	|   ReceiveFromAHK()                   	|
;|   GetUIntByAddress()                  	|   SetUIntByAddress()                   	|   SetRestrictedDacl()                    	|   getActiveProcessName()           	|
;|   enumChildCallback()                	|	GetDllBase()									|	getProcBaseFromModules()			|	InjectDll()										|
;|	getProcessBaseAddress()				|	LoadFile()										|   ReadProcessMemory()              	|   WriteProcessMemory()             	|
;|   CopyMemory()                         	|   MoveMemory()                         	|   FillMemory()                             	|   ZeroMemory()                          	|
;|   CompareMemory()                    	|   VirtualAlloc()                            	|   VirtualFree()                             	|   ReduceMem()                           	|
;|   GlobalLock()                             	|   LocalFree()                                	|   CreateStreamOnHGlobal()       	|   CoTaskMemFree()                     	|
;|   CoTaskMemRealloc()                	|   VarAdjustCapacity()                  	|   DllListExports()                         	|   RtlUlongByteSwap64() x2            	|
;|
; - informations about system, user, hardware -
;|														|														|														|														|
;|   UserAccountsEnum()               	|   GetCurrentUserInfo()                 	|   GetHandleInformation()           	|   SetHandleInformation()             	|
;|   GetPhysicallyInstalledSystemMemory()                                            	|   GlobalMemoryStatus()              	|   GetSystemFileCacheSize()         	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;UIAutomation (5)
;1	
CreatePropertyCondition(propertyId, ByRef var, type :="Variant") {     									;-- I hope this one works
		If (A_PtrSize=8) {
			if (type!="Variant")
			UIA_Variant(var,type,var)
			return UIA_Hr(DllCall(this.__Vt(23), "ptr",this.__Value, "int",propertyId, "ptr",&var, "ptr*",out))? new UIA_PropertyCondition(out):
		} else {
			if (type<>8)
				return UIA_Hr(DllCall(this.__Vt(23), "ptr",this.__Value, "int",propertyId, "int64",type, "int64", var, "ptr*",out))? new UIA_PropertyCondition(out):
			else
			{
				vart:=DllCall("oleaut32\SysAllocString", "wstr",var,"ptr")
				return UIA_Hr(DllCall(this.__Vt(23), "ptr",this.__Value, "int",propertyId, "int64",type, "ptr", vart, "ptr", 0, "ptr*",out))? new UIA_PropertyCondition(out):
			}
		}
	}
;2
CreatePropertyCondition(propertyId, ByRef var, type := "Variant") {        								;-- I hope this one is better
        ; CREDITS: Elgin, http://ahkscript.org/boards/viewtopic.php?f=5&t=6979&p=43985#p43985
        ; Parameters:
        ;   propertyId  - An ID number of the property to check.
        ;   var         - The value to check for.  Can be a variant, number, or string.
        ;   type        - The data type.  Can be the string "Variant", or one of standard
        ;                 variant type such as VT_I4, VT_BSTR, etc.
        local out:="", hr, bstr
        If (A_PtrSize = 8)
        {
            if (type!="Variant")
                UIA_Variant(var,type,var)
            hr := DllCall(this.__Vt(23), "ptr",this.__Value, "int",propertyId, "ptr",&var, "ptr*",out)
            if (type!="Variant")
                UIA_VariantClear(&var)
            return UIA_Hr(hr)? new UIA_PropertyCondition(out):
        }
        else ; 32-bit.
        {
            if (type <> 8)
                return UIA_Hr(DllCall(this.__Vt(23), "ptr",this.__Value, "int",propertyId
                            , "int64",type, "int64",var, "ptr*",out))? new UIA_PropertyCondition(out):
            else ; It's type is VT_BSTR.
            {
                bstr := DllCall("oleaut32\SysAllocString", "wstr",var, "ptr")
                hr := DllCall(this.__Vt(23), "ptr",this.__Value, "int",propertyId
                            , "int64",type, "ptr",bstr, "ptr",0, "ptr*",out)
                DllCall("oleaut32\SysFreeString", "ptr", bstr)
                return UIA_Hr(hr)? new UIA_PropertyCondition(out):
            }
        }
    }
;3
CreatePropertyConditionEx(propertyId, ByRef var, type := "Variant", flags := 0x1) {				;--
        ; PropertyConditionFlags_IgnoreCase = 0x1
        local out:="", hr, bstr

        If (A_PtrSize = 8) {
            if (type!="Variant")
                UIA_Variant(var,type,var)
            hr := DllCall(this.__vt(24), "ptr",this.__Value, "int",propertyId
                        , "ptr",&var, "uint",flags, "ptr*",out)
            if (type!="Variant")
                UIA_VariantClear(&var)
            return UIA_Hr(hr)? new UIA_PropertyCondition(out):
        }
        else ; 32-bit.
        {
            if (type <> 8)
                return UIA_Hr(DllCall(this.__vt(24), "ptr",this.__Value, "int",propertyId
                            , "int64",type, "int64",var
                            , "uint",flags, "ptr*",out))? new UIA_PropertyCondition(out):
            else ; It's type is VT_BSTR.
            {
                bstr := DllCall("oleaut32\SysAllocString", "wstr",var, "ptr")
                hr := DllCall(this.__vt(24), "ptr",this.__Value, "int",propertyId
                            , "int64",type, "ptr",bstr, "ptr",0, "uint",flags, "ptr*",out)
                DllCall("oleaut32\SysFreeString", "ptr", bstr)
                return UIA_Hr(hr)? new UIA_PropertyCondition(out):
            }
        }
    }
;4
UIAgetControlNameByHwnd(_, controlHwnd) {																		;--
	
	UIAutomation := ComObjCreate("{ff48dba4-60ef-4201-aa87-54103eef594e}", "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")
	DllCall(NumGet(NumGet(UIAutomation+0)+6*A_PtrSize), "Ptr", UIAutomation, "Ptr", controlHwnd, "Ptr*", IUIAutomationElement)
	DllCall(NumGet(NumGet(IUIAutomationElement+0)+29*A_PtrSize), "Ptr", IUIAutomationElement, "Ptr*", automationId)
	ret := StrGet(automationId,, "UTF-16")
	DllCall("oleaut32\SysFreeString", "Ptr", automationId)
	ObjRelease(IUIAutomationElement)
	ObjRelease(UIAutomation)
	return ret
}
;5
MouseGetText(x := "", y := "", Encoding := "UTF-16") {															;-- get the text in the specified coordinates, function uses Microsoft UIA
	
	/*                              	DESCRIPTION
	
			; get the text in the specified coordinates
			; Syntax: MouseGetText ([x], [y])
			
	*/
	
	/*                              	EXAMPLE(s)
	
			;for k, v in MouseGetText()
				;	MsgBox % k ": " v
				;ExitApp
				
	*/
	
	
	static uia
	if (x="") || (y="")
		CursorGetPos(_x, _y), x := x=""?_x:x, y := y=""?_y:y
	if !(uia) ;https://msdn.microsoft.com/en-us/library/windows/desktop/ff384838%28v=vs.85%29.aspx
		uia := ComObjCreate("{ff48dba4-60ef-4201-aa87-54103eef594e}", "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")
	Item := {}, DllCall(_vt(uia,7),"Ptr",uia,"int64",x|y<<32,"Ptr*",element)
	if !(element)
		return "", ErrorLevel := true
	DllCall(_vt(element,23),"Ptr",element,"Ptr*",name),DllCall(_vt(element,10),"Ptr",element,"UInt",30045,"Ptr",_variant(var))
	,DllCall(_vt(element,10),"Ptr",element,"uint",30092,"Ptr",_variant(lname)), DllCall(_vt(element,10),"Ptr",element,"uint",30093,"Ptr",_variant(lval))
	,a:=StrGet(name,"utf-16"),b:=StrGet(NumGet(val,8,"Ptr"),Encoding),c:=StrGet(NumGet(lname,8,"Ptr"),Encoding)
	,d:=StrGet(NumGet(lval,8,"Ptr"),Encoding),a?Item.Push(a):0,b&&_vas(Item,b)?Item.Push(b):0,c&&_vas(Item,c)?Item.Push(c):0
	,d&&_vas(Item,d)?Item.Push(d):0,DllCall(_vt(element,21),"Ptr",element,"Uint*",type)
	if (type=50004)
		e:=MouseGetText_ElementWhole(uia,element),e&&_vas(item,e)?item.Push(e):false
	return Item, ObjRelease(element), ErrorLevel := false
} MouseGetText_ElementWhole(uia, element) {
	static init := 1, trueCondition, walker
	if (init)
		init:=DllCall(_vt(uia,21),"ptr",uia,"ptr*",trueCondition),init+=DllCall(_vt(uia,14),"ptr",uia,"ptr*",walker)
	DllCall(_vt(uia,5),"ptr",uia,"ptr*",root), DllCall(_vt(uia,3),"ptr",uia,"ptr",element,"ptr",root,"int*",same), ObjRelease(root)
	if (same)
		return
	hr:=DllCall(_vt(walker,3),"ptr",walker,"ptr",element,"ptr*",parent)
	if !(e:="") && !(parent)
		return
	DllCall(_vt(parent,6),"ptr",parent,"uint",2,"ptr",trueCondition,"ptr*",array), DllCall(_vt(array,3),"ptr",array,"int*",length)
	Loop % (length)
		DllCall(_vt(array,4),"ptr",array,"int",A_Index-1,"ptr*",newElement), DllCall(_vt(newElement,23),"ptr",newElement,"ptr*",name)
		, e.=StrGet(name,"utf-16"), ObjRelease(newElement)
	return e, ObjRelease(array), ObjRelease(parent)
} _vas(obj,ByRef txt) {
	for k,v in obj
		if (v=txt)
			return false
	return true
}_variant(ByRef var,type:=0,val:=0) {
	return (VarSetCapacity(var,8+2*A_PtrSize)+NumPut(type,var,0,"short")+NumPut(val,var,8,"ptr"))*0+&var
}_vt(p,n) {
	return NumGet(NumGet(p+0,"ptr")+n*A_PtrSize,"ptr")
} ;http://www.autohotkey.com/board/topic/94619-ahk-l-screen-reader-a-tool-to-get-text-anywhere/

} 
;|														|														|														|														|
;|	CreatePropertyCondition()			|	CreatePropertyCondition()			|	CreatePropertyConditionEx()		|	getControlNameByHwnd()			|
;|   MouseGetText()                       	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;ACC (MSAA) - different methods (7)
;1
Acc_Get(Cmd, ChildPath="", ChildID=0, WinTitle="", WinText="", ExcludeTitle="", ExcludeText="") {		;--
	
	static properties := {Action:"DefaultAction", DoAction:"DoDefaultAction", Keyboard:"KeyboardShortcut"}
	AccObj :=   IsObject(WinTitle)? WinTitle
			:   Acc_ObjectFromWindow( WinExist(WinTitle, WinText, ExcludeTitle, ExcludeText), 0 )
	if ComObjType(AccObj, "Name") != "IAccessible"
		ErrorLevel := "Could not access an IAccessible Object"
	else {
		StringReplace, ChildPath, ChildPath, _, %A_Space%, All
		AccError:=Acc_Error(), Acc_Error(true)
		Loop Parse, ChildPath, ., %A_Space%
			try {
				if A_LoopField is digit
					Children:=Acc_Children(AccObj), m2:=A_LoopField ; mimic "m2" output in else-statement
				else
					RegExMatch(A_LoopField, "(\D*)(\d*)", m), Children:=Acc_ChildrenByRole(AccObj, m1), m2:=(m2?m2:1)
				if Not Children.HasKey(m2)
					throw
				AccObj := Children[m2]
			} catch {
				ErrorLevel:="Cannot access ChildPath Item #" A_Index " -> " A_LoopField, Acc_Error(AccError)
				if Acc_Error()
					throw Exception("Cannot access ChildPath Item", -1, "Item #" A_Index " -> " A_LoopField)
				return
			}
		Acc_Error(AccError)
		StringReplace, Cmd, Cmd, %A_Space%, , All
		properties.HasKey(Cmd)? Cmd:=properties[Cmd]:
		try {
			if (Cmd = "Location")
				AccObj.accLocation(ComObj(0x4003,&x:=0), ComObj(0x4003,&y:=0), ComObj(0x4003,&w:=0), ComObj(0x4003,&h:=0), ChildId)
			      , ret_val := "x" NumGet(x,0,"int") " y" NumGet(y,0,"int") " w" NumGet(w,0,"int") " h" NumGet(h,0,"int")
			else if (Cmd = "Object")
				ret_val := AccObj
			else if Cmd in Role,State
				ret_val := Acc_%Cmd%(AccObj, ChildID+0)
			else if Cmd in ChildCount,Selection,Focus
				ret_val := AccObj["acc" Cmd]
			else
				ret_val := AccObj["acc" Cmd](ChildID+0)
		} catch {
			ErrorLevel := """" Cmd """ Cmd Not Implemented"
			if Acc_Error()
				throw Exception("Cmd Not Implemented", -1, Cmd)
			return
		}
		return ret_val, ErrorLevel:=0
	}
	if Acc_Error()
		throw Exception(ErrorLevel,-1)
}
;2
Acc_Error(p="") {		;--
   static setting:=0
   return p=""?setting:setting:=p
}
;3
Acc_ChildrenByRole(Acc, Role) {		;--
   if ComObjType(Acc,"Name")!="IAccessible"
      ErrorLevel := "Invalid IAccessible Object"
   else {
      Acc_Init(), cChildren:=Acc.accChildCount, Children:=[]
      if DllCall("oleacc\AccessibleChildren", "Ptr",ComObjValue(Acc), "Int",0, "Int",cChildren, "Ptr",VarSetCapacity(varChildren,cChildren*(8+2*A_PtrSize),0)*0+&varChildren, "Int*",cChildren)=0 {
         Loop %cChildren% {
            i:=(A_Index-1)*(A_PtrSize*2+8)+8, child:=NumGet(varChildren,i)
            if NumGet(varChildren,i-8)=9
               AccChild:=Acc_Query(child), ObjRelease(child), Acc_Role(AccChild)=Role?Children.Insert(AccChild):
            else
               Acc_Role(Acc, child)=Role?Children.Insert(child):
         }
         return Children.MaxIndex()?Children:, ErrorLevel:=0
      } else
         ErrorLevel := "AccessibleChildren DllCall Failed"
   }
   if Acc_Error()
      throw Exception(ErrorLevel,-1)
}
VARIANTstruct() { ;so wahrscheinlich nicht funktionsfähig
	DllCall("LoadLibrary",str,"oleacc", ptr)

	VarSetCapacity(Point, 8, 0)
	DllCall("GetCursorPos", ptr, &Point)

	DllCall("oleacc\AccessibleObjectFromPoint", "int64", NumGet(Point, 0, "int64"), ptrp, pAccessible, ptr, &varChild)

	; get vtable for IAccessible
	vtAccessible :=  NumGet(pAccessible+0, "ptr")

	; call get_accName() through the vtable
	hr := DllCall(NumGet(vtAccessible+0, 10*A_PtrSize, "ptr"), ptr, pAccessible,"int64", 3, "int64", 0,"int64", 0 ptrp, pvariant)
	; variant's type is VT_I4 = 3
	; variant's value is CHILDID_SELF = 0

	; get_accName returns the following hresult error with 64 bit ahk
	hr_facility := (0x07FF0000 & hr) >>16	; shows facility = 7 "win32"
	hr_code := 0x0000ffff & hr		; code 1780 "RPC_X_NULL_REF_POINTER"

}
;4
listAccChildProperty(hwnd){	;--

	COM_AccInit()
	If	pacc :=	COM_AccessibleObjectFromWindow(hWnd)
	{
		;~ VarSetCapacity(l,4),VarSetCapacity(t,4),VarSetCapacity(w,4),VarSetCapacity(h,4)
		;~ COM_Invoke(pacc,"accLocation",l,t,w,h,0)
		;~ a:=COM_Invoke(pacc,"accParent")

		sResult	:="[Window]`n"
			. "Name:`t`t"		COM_Invoke(pacc,"accName",0) "`n"
			. "Value:`t`t"		COM_Invoke(pacc,"accValue",0) "`n"
			. "Description:`t"	COM_Invoke(pacc,"accDescription",0) "`n"
			. COM_Invoke(pacc,"accDefaultAction",0) "`n"
			. COM_Invoke(pacc,"accHelp",0) "`n"
			. COM_Invoke(pacc,"accKeyboardShortcut",0) "`n"
			. COM_Invoke(pacc,"accRole",0) "`n"
			. COM_Invoke(pacc,"accState",0) "`n"


		Loop, %	COM_AccessibleChildren(pacc, COM_Invoke(pacc,"accChildCount"), varChildren)
			If	NumGet(varChildren,16*(A_Index-1),"Ushort")=3 && idChild:=NumGet(varChildren,16*A_Index-8)
				sResult	.="[" A_Index "]`n"
					. "Name:`t`t"		COM_Invoke(pacc,"accName",idChild) "`n"
					. "Value:`t`t"		COM_Invoke(pacc,"accValue",idChild) "`n"
					. "Description:`t"	COM_Invoke(pacc,"accDescription",idChild) "`n"
					. COM_Invoke(pacc,"accParent",idChild) "`n"

			Else If	paccChild:=NumGet(varChildren,16*A_Index-8) {
				sResult	.="[" A_Index "]`n"
					. "Name:`t`t"		COM_Invoke(paccChild,"accName",0) "`n"
					. "Value:`t`t"		COM_Invoke(paccChild,"accValue",0) "`n"
					. "Description:`t"	COM_Invoke(paccChild,"accDescription",0) "`n"
				if a_index=3
				{
					numput(1,var,"UInt")
					COM_Invoke(pacc,"accSelect",1,paccChild)
				}
				 COM_Release(paccChild)
			}
		COM_Release(pacc)
	}
	COM_AccTerm()

	return sResult
}
;5
GetInfoUnderCursor() {																									;-- retreavies ACC-Child under cursor
	Acc := Acc_ObjectFromPoint(child)
	if !value := Acc.accValue(child)
		value := Acc.accName(child)
	accPath := GetAccPath(acc, hwnd).path
	return {text: value, path: accPath, hwnd: hwnd}
}
;6
GetAccPath(Acc, byref hwnd="") {																					;-- get the Acc path from (child) handle
	hwnd := Acc_WindowFromObject(Acc)
	WinObj := Acc_ObjectFromWindow(hwnd)
	WinObjPos := Acc_Location(WinObj).pos
	while Acc_WindowFromObject(Parent:=Acc_Parent(Acc)) = hwnd {
		t2 := GetEnumIndex(Acc) "." t2
		if Acc_Location(Parent).pos = WinObjPos
			return {AccObj:Parent, Path:SubStr(t2,1,-1)}
		Acc := Parent
	}
	while Acc_WindowFromObject(Parent:=Acc_Parent(WinObj)) = hwnd
		t1.="P.", WinObj:=Parent
	return {AccObj:Acc, Path:t1 SubStr(t2,1,-1)}
}
;7
GetEnumIndex(Acc, ChildId=0) {                                                                                  	;-- for Acc child object
	if Not ChildId {
		ChildPos := Acc_Location(Acc).pos
		For Each, child in Acc_Children(Acc_Parent(Acc))
			if IsObject(child) and Acc_Location(child).pos=ChildPos
				return A_Index
	} 
	else {
		ChildPos := Acc_Location(Acc,ChildId).pos
		For Each, child in Acc_Children(Acc)
			if Not IsObject(child) and Acc_Location(Acc,child).pos=ChildPos
				return A_Index
	}
}


} 
;|														|														|														|														|
;|	Acc_Get()										|	Acc_Error()									|	Acc_ChildrenByRole()					|	listAccChildProperty()					|
;|   GetInfoUnderCursor()              	|   GetAccPath()                            	|   GetEnumIndex()                       	|
;|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;Internet Explorer/Chrome/FireFox/HTML functions (9)
; AutoHotkey_L: von jethrow
IEGet(name="") {																							    			;-- AutoHotkey_L
   IfEqual, Name,, WinGetTitle, Name, ahk_class IEFrame ; Get active window if no parameter
   Name := (Name="New Tab - Windows Internet Explorer")? "about:Tabs":RegExReplace(Name, " - (Windows|Microsoft) Internet Explorer")
   for WB in ComObjCreate("Shell.Application").Windows
      if WB.LocationName=Name and InStr(WB.FullName, "iexplore.exe")
         return WB
}
; AHK Basic:
IEGet(name="") {																							     			;-- AutoHotkey_Basic
   IfEqual, Name,, WinGetTitle, Name, ahk_class IEFrame ; Get active window if no parameter
   Name := (Name="New Tab - Windows Internet Explorer") ? "about:Tabs":RegExReplace(Name, " - (Windows|Microsoft) Internet Explorer")
   oShell := COM_CreateObject("Shell.Application") ; Contains reference to all explorer windows
   Loop, % COM_Invoke(oShell, "Windows.Count") {
      if pwb := COM_Invoke(oShell, "Windows", A_Index-1)
         if COM_Invoke(pwb, "LocationName")=name and InStr(COM_Invoke(pwb, "FullName"), "iexplore.exe")
            Break
      COM_Release(pwb), pwb := ""
   }
   COM_Release(oShell)
   return, pwb
}
; AutoHotkey_L:
WBGet(WinTitle="ahk_class IEFrame", Svr#=1) { 														;-- AHK_L: based on ComObjQuery docs
	static	msg := DllCall("RegisterWindowMessage", "str", "WM_HTML_GETOBJECT")
	,	IID := "{0002DF05-0000-0000-C000-000000000046}" ; IID_IWebBrowserApp
;	,	IID := "{332C4427-26CB-11D0-B483-00C04FD90119}" ; IID_IHTMLWindow2
	SendMessage msg, 0, 0, Internet Explorer_Server%Svr#%, %WinTitle%
	if (ErrorLevel != "FAIL") {
		lResult:=ErrorLevel, VarSetCapacity(GUID,16,0)
		if DllCall("ole32\CLSIDFromString", "wstr","{332C4425-26CB-11D0-B483-00C04FD90119}", "ptr",&GUID) >= 0 {
			DllCall("oleacc\ObjectFromLresult", "ptr",lResult, "ptr",&GUID, "ptr",0, "ptr*",pdoc)
			return ComObj(9,ComObjQuery(pdoc,IID,IID),1), ObjRelease(pdoc)
		}
	}
}
; AHK Basic:
WBGet(WinTitle="ahk_class IEFrame", Svr#=1) { 														;-- AHK_Basic: based on Sean's GetWebBrowser function
	static msg, IID := "{332C4427-26CB-11D0-B483-00C04FD90119}" ; IID_IWebBrowserApp
	if Not msg
		msg := DllCall("RegisterWindowMessage", "str", "WM_HTML_GETOBJECT")
	SendMessage msg, 0, 0, Internet Explorer_Server%Svr#%, %WinTitle%
	if (ErrorLevel != "FAIL") {
		lResult:=ErrorLevel, GUID:=COM_GUID4String(IID_IHTMLDocument2,"{332C4425-26CB-11D0-B483-00C04FD90119}")
		DllCall("oleacc\ObjectFromLresult", "Uint",lResult, "Uint",GUID, "int",0, "UintP",pdoc)
		return COM_QueryService(pdoc,IID,IID), COM_Release(pdoc)
	}
}
;
wb := WBGet()				;inner HTML
MsgBox % wb.document.documentElement.innerHTML
WBGet(WinTitle="ahk_class IEFrame", Svr#=1) { 														;-- based on ComObjQuery docs
   static   msg := DllCall("RegisterWindowMessage", "str", "WM_HTML_GETOBJECT")
         ,  IID := "{332C4427-26CB-11D0-B483-00C04FD90119}" ; IID_IWebBrowserApp
   SendMessage msg, 0, 0, Internet Explorer_Server%Svr#%, %WinTitle%
   if (ErrorLevel != "FAIL") {
      lResult:=ErrorLevel, VarSetCapacity(GUID,16,0)
      if DllCall("ole32\CLSIDFromString", "wstr","{332C4425-26CB-11D0-B483-00C04FD90119}", "ptr",&GUID) >= 0 {
         DllCall("oleacc\ObjectFromLresult", "ptr",lResult, "ptr",&GUID, "ptr",0, "ptr*",pdoc)
         return ComObj(9,ComObjQuery(pdoc,IID,IID),1), ObjRelease(pdoc)
      }
   }
}
; Firefox
SetTitleMatchMode 2
MsgBox % Acc_Get("Value", "4.20.2.4.2", 0, "Firefox")
MsgBox % Acc_Get("Value", "application1.property_page1.tool_bar2.combo_box1.editable_text1", 0, "Firefox")

IE_TabActivateByName(TabName, WinTitle="") {														;-- activate a TAB by name in InternetExplorer

	/*                              	DESCRIPTION
	
			Link: https://autohotkey.com/boards/viewtopic.php?f=9&t=542
			
	*/
	

	ControlGet, hTabUI , hWnd,, DirectUIHWND5, % WinTitle=""? "ahk_class IEFrame":WinTitle
	Tabs := Acc_ObjectFromWindow(hTabUI).accChild(1) ; access "Tabs" control
	Loop, % Tabs.accChildCount
		if (Tabs.accChild(A_Index).accName(0) = TabName)
			return, Tabs.accChild(A_Index).accDoDefaultAction(0)
}

IE_TabActivateByHandle(hwnd, tabName) {																;-- activates a tab by hwnd in InternetExplorer
	
	/*                              	DESCRIPTION
	
			Link: http://www.autohotkey.com/forum/topic37651.html&p=231093
	
	*/
	
   ControlGet, hTabUI , hWnd,, DirectUIHWND1, ahk_id %hwnd%
   Acc := Acc_ObjectFromWindow(hTabUI) ;// access "Tabs" control
   If (Acc.accChildCount > 1) ;// more than 1 tab
      tabs := Acc.accChild(3) ;// access just "IE document tabs"
   While (tabs.accChildCount >= A_Index) {
      tab := tabs.accChild(A_Index)
      If (tab.accName(0) = tabName)  ;// test vs. "tabName"
         return tab.accDoDefaultAction(0) ;// invoke tab
   }
}

IE_TabWinID(tabName) {																								;-- find the HWND of an IE window with a given tab name
	
	/*                              	DESCRIPTION
	
			Link: https://autohotkey.com/board/topic/52685-winactivate-on-a-specific-ie-browser-tab
			
	*/
	
	
   WinGet, winList, List, ahk_class IEFrame
   While, winList%A_Index% {
      n:=A_Index, ErrorLevel:=0
      While, !ErrorLevel {
         ControlGetText, tabText, TabWindowClass%A_Index%, % "ahk_id" winList%n%
         if InStr(tabText, tabName)
            return, winList%n%
      }
   }
}

ReadProxy(ProxySettingsRegRoot="HKEY_CURRENT_USER") {                                 	;-- reads the proxy settings from the windows registry
    static ProxySettingsIEKey:="Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    RegRead ProxyEnable, %ProxySettingsRegRoot%, %ProxySettingsIEKey%, ProxyEnable
    If ProxyEnable
	RegRead ProxyServer, %ProxySettingsRegRoot%, %ProxySettingsIEKey%, ProxyServer
    return ProxyServer
}

IE_getURL(t) {    																											 ;-- using shell.application
	If	psh	:=	COM_CreateObject("Shell.Application") {
		If	psw	:=	COM_Invoke(psh,	"Windows") {
			Loop, %	COM_Invoke(psw,	"Count")
				If	url	:=	(InStr(COM_Invoke(psw,"Item[" A_Index-1 "].LocationName"),t) && InStr(COM_Invoke(psw,"Item[" A_Index-1 "].FullName"), "iexplore.exe")) ? COM_Invoke(psw,"Item[" A_Index-1 "].LocationURL") :
					Break
			COM_Release(psw)
		}
		COM_Release(psh)
	}
	Return	url
}

ACCTabActivate(hwnd, tabName) { 																			;-- activate a Tab in IE - function uses acc.ahk library
	
	; https://autohotkey.com/boards/viewtopic.php?f=9&t=542
   ControlGet, hTabUI , hWnd,, DirectUIHWND5, ahk_id %hwnd%
   Acc := Acc_ObjectFromWindow(hTabUI) ;// access "Tabs" control
   msgbox % Acc.accChildCount
   If (Acc.accChildCount > 1) ;// more than 1 tab
      tabs := Acc.accChild(3) ;// access just "IE document tabs"
   While (tabs.accChildCount >= A_Index) {
      tab := tabs.accChild(A_Index)
      If (tab.accName(0) = tabName)  ;// test vs. "tabName"
         return tab.accDoDefaultAction(0) ;// invoke tab
   }
}

TabActivate(TabName, WinTitle="") {																			;-- a different approach to activate a Tab in IE - function uses acc.ahk library
	ControlGet, hTabUI , hWnd,, DirectUIHWND5, % WinTitle=""? "ahk_class IEFrame":WinTitle
	Tabs := Acc_ObjectFromWindow(hTabUI).accChild(1) ; access "Tabs" control
	Loop, % Tabs.accChildCount
		if (Tabs.accChild(A_Index).accName(0) = TabName)
			return, Tabs.accChild(A_Index).accDoDefaultAction(0)
}


} 
;|														|														|														|														|
;|	IEGet()											|   WBGet()										|	IE_TabActivateByName()				|   IE_TabActivateByHandle()        	|
;|   IE_TabWinID()                          	|   ReadProxy()                              	|	IE_getURL()									|   ACCTabActivate()                      	|
;|   TabActivate()                           	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------       
    
{ ;Variables - Handling (8)
ComVar(Type:=0xC) { 																								;-- Creates an object which can be used to pass a value ByRef.

    ;   ComVar: Creates an object which can be used to pass a value ByRef.
    ;   ComVar[] retrieves the value.
    ;   ComVar[] := Val sets the value.
    ;   ComVar.ref retrieves a ByRef object for passing to a COM function.

    static base := { __Get: "ComVarGet", __Set: "ComVarSet" }
    ; Create an array of 1 VARIANT.  This method allows built-in code to take
    ; care of all conversions between VARIANT and AutoHotkey internal types.
    arr := ComObjArray(Type, 1)
    ; Retrieve a pointer to the VARIANT.
    arr_data := NumGet(ComObjValue(arr)+8+A_PtrSize)
    ; Store the array and an object which can be used to pass the VARIANT ByRef.
    return { ref: ComObject(0x4000|Type, arr_data), _: arr, base: base }
}
ComVarGet(cv, p*) { 																								;-- Called when script accesses an unknown field.
    if p.MaxIndex() = "" ; No name/parameters, i.e. cv[]
        return cv._[0]
}
ComVarSet(cv, v, p*) { 																							;-- Called when script sets an unknown field.
    if p.MaxIndex() = "" ; No name/parameters, i.e. cv[]:=v
        return cv._[0] := v
}

GetScriptVARs() {																										;-- returns a key, value array with all script variables (e.g. for debugging purposes)

		; http://www.autohotkey.com/board/topic/20925-listvars/#entry156570

	global
	static hEdit, pSFW, pSW, bkpSFW, bkpSW
	local dhw, AStr, Ptr, hmod, text, v, i := 0, vars := []

	if !hEdit {
		dhw := A_DetectHiddenWindows
		DetectHiddenWindows, On
		ControlGet, hEdit, Hwnd,, Edit1, % "ahk_id " A_ScriptHwnd
		DetectHiddenWindows, % dhw

		AStr := A_IsUnicode ? "AStr" : "Str"
		Ptr := A_PtrSize=8 ? "Ptr" : "UInt"
		hmod := DllCall("GetModuleHandle", "Str", "user32.dll")
		pSFW := DllCall("GetProcAddress", Ptr, hmod, AStr, "SetForegroundWindow")
		pSW := DllCall("GetProcAddress", Ptr, hmod, AStr, "ShowWindow")
		DllCall("VirtualProtect", Ptr, pSFW, Ptr, 8, "UInt", 0x40, "UInt*", 0)
		DllCall("VirtualProtect", Ptr, pSW, Ptr, 8, "UInt", 0x40, "UInt*", 0)
		bkpSFW := NumGet(pSFW+0, 0, "int64")
		bkpSW := NumGet(pSW+0, 0, "int64")
	}

	if (A_PtrSize=8) {
        NumPut(0x0000C300000001B8, pSFW+0, 0, "int64")  ; return TRUE
        NumPut(0x0000C300000001B8, pSW+0, 0, "int64")   ; return TRUE
    } else {
        NumPut(0x0004C200000001B8, pSFW+0, 0, "int64")  ; return TRUE
        NumPut(0x0008C200000001B8, pSW+0, 0, "int64")   ; return TRUE
    }

    ListVars

    NumPut(bkpSFW, pSFW+0, 0, "int64")
    NumPut(bkpSW, pSW+0, 0, "int64")

    ControlGetText, text,, % "ahk_id " hEdit

    RegExMatch(text, "sm)(?<=^Global Variables \(alphabetical\)`r`n-{50}`r`n).*", text)
    Loop, Parse, text, `n, `r
    {
    	if (A_LoopField~="^\d+\[") || (A_LoopField = "")
    		continue
		v := SubStr(A_LoopField, 1, InStr(A_LoopField, "[")-1)
    	vars[i+=1] := {name: v, value:%v%}
    }
    return vars
}

Valueof(VarinStr) {																									;-- Super Variables processor by Avi Aryan, overcomes the limitation of a single level ( return %var% ) in nesting variables
	
	; https://github.com/aviaryan/autohotkey-scripts/blob/master/Functions/ValueOf.ahk
	; dependings: none
	
	/*			DESCRIPTION
	Super Variables processor by Avi Aryan
	Overcomes the limitation of a single level ( return %var% ) in nesting variables
	The function can nest as many levels as you want
	Run the Example to get going
	Updated 10/4/14
*/

	/*			EXAMPLE -------------------------------------------
		variable := "some_value"
		msgbox % valueof("%variable%")
		some_value := "Some_another_value"
		some_another_value := "a_unique_value"
		a_unique_value := "A magical value. Ha Ha Ha Ha"
		msgbox,% "%%%%variable%%%% (4 times)`t" ValueOf("%%%%variable%%%%")

		works with objects Too

		obj := {}
		obj["key"] := "value"
		msgbox % valueOf("%obj.key%")
		msgbox % valueOf("%some_%obj.key%%")        ==== value of some_value
		return
*/

global
local Midpoint, emVar, $j, $n
	loop,
	{
		StringReplace, VarinStr, VarinStr,`%,`%, UseErrorLevel
		Midpoint := ErrorLevel / 2
		if Midpoint = 0
			return ( emvar := VarinStr )
		emVar := Substr(VarinStr, Instr(VarinStr, "%", 0, 1, Midpoint)+1, Instr(VarinStr, "%", 0, 1, Midpoint+1)-Instr(VarinStr, "%", 0, 1, Midpoint)-1)

		if Instr(emVar, ".")
		{
			loop, parse, emVar,`.
				$j%A_index% := Trim(A_LoopField) , $n := A_index-1
			if $n=1
				emVar := %$j1%[$j2]
			if $n=2
				emVar := %$j1%[$j2][$j3]
		} 
		else emVar := %emVar%

		VarinStr := Substr(VarinStr, 1, Instr(VarinStr, "%", 0, 1, Midpoint)-1) emVar Substr(VarinStr, Instr(VarinStr, "%", 0, 1, Midpoint+1)+1)
	}
}

type(v) {																													;-- Object version: Returns the type of a value: "Integer", "String", "Float" or "Object"

	/*                              	DESCRIPTION
	
			By:					Lexikos
			Link: 				https://autohotkey.com/boards/viewtopic.php?f=6&t=2306
			Description: 	Object version - depends on current float format including a decimal point.
	*/
	/*                              	EXAMPLE(s)
	
			MsgBox % type("")     ; String
			MsgBox % type(1)      ; Integer
			MsgBox % type(1/1)    ; Float
			MsgBox % type("1")    ; String
			MsgBox % type(2**42)  ; Integer
			
	*/
	
	
    if IsObject(v)
        return "Object"
    return v="" || [v].GetCapacity(1) ? "String" : InStr(v,".") ? "Float" : "Integer"
}

type(ByRef v) {																											;-- COM version: Returns the type of a value: "Integer", "String", "Float" or "Object"
	
	/*                              	DESCRIPTION
	
			By:					Lexikos
			Link: 				https://autohotkey.com/boards/viewtopic.php?f=6&t=2306
			Description:		COM version - reports the wrong type for integers outside 32-bit range.
			
	*/
	
	
	if IsObject(v)
		return "Object"
	a := ComObjArray(0xC, 1)
	a[0] := v
	DllCall("oleaut32\SafeArrayAccessData", "ptr", ComObjValue(a), "ptr*", ap)
	type := NumGet(ap+0, "ushort")
	DllCall("oleaut32\SafeArrayUnaccessData", "ptr", ComObjValue(a))
	return type=3?"Integer" : type=8?"String" : type=5?"Float" : type
}

A_DefaultGui() {																										;-- a nice function to have a possibility to get the number of the default gui
	
	/*                              	DESCRIPTION
	
			Link: https://autohotkey.com/board/topic/24532-function-a-defaultgui/
			Description: You don't have the way to get the current default gui in AHK. This functions fills that hole.
							
	*/
	/*                              	EXAMPLE(s)
	
			Gui,13: Default
				msgbox % A_DefaultGui()
				
	*/
		
	
	if A_Gui !=
		return A_GUI

	Gui, +LastFound
	m := DllCall( "RegisterWindowMessage", Str, "GETDEFGUI")
	OnMessage(m, "A_DefaultGui")
	res := DllCall("SendMessageW", "uint",  WinExist(), "uint", m, "uint", 0, "uint", 0)		;use A for Ansi and W for Unicode
	OnMessage(m, "")
	return res
}


} 
;|														|														|														|														|
;|	ComVar()										|	ComVarGet()								|	ComVarSet()								|	GetScriptVARs()							|
;|   Valueof()                                 	|   type() x 2                                     	|   A_DefaultGui()                          	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;other languages or MCode functions(1)
MCode_Bin2Hex(addr, len, ByRef hex) { 							;-- By Lexikos, http://goo.gl/LjP9Zq
	Static fun
	If (fun = "") {
		If Not A_IsUnicode
			h =
			( LTrim Join
				8B54240C85D2568B7424087E3A53578B7C24148A07478AC8C0E90480F9090F97C3F6
				DB80E30702D980C330240F881E463C090F97C1F6D980E10702C880C130880E464A75
				CE5F5BC606005EC3
			)
		Else
			h =
			( LTrim Join
				8B44240C8B4C240485C07E53568B74240C578BF88A168AC2C0E804463C090FB6C076
				066683C037EB046683C03066890180E20F83C10280FA09760C0FB6D26683C2376689
				11EB0A0FB6C26683C03066890183C1024F75BD33D25F6689115EC333C0668901C3
			)
		VarSetCapacity(fun, n := StrLen(h)//2)
		Loop % n
			NumPut("0x" . SubStr(h, 2 * A_Index - 1, 2), fun, A_Index - 1, "Char")
	}
	hex := ""
	VarSetCapacity(hex, A_IsUnicode ? 4 * len + 2 : 2 * len + 1)
	DllCall(&fun, "uint", &hex, "uint", addr, "uint", len, "cdecl")
	VarSetCapacity(hex, -1) ;update StrLen
}

} 
;|														|														|														|														|
;|	MCode_Bin2Hex()						|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ;other functions(5)
;1
GetCommState(ComPort) {																							;-- this function retrieves the configuration settings of a given serial port

	/*                              	DESCRIPTION
	
			this function retrieves the configuration settings of a given serial port.
			Having hardly any C\C experience it took me some time to find out that there is a bitmask in the DCB (Device Configuration Block) structure.
			
			Using BuildCommDCB and SetCommState functions it should also be possible to configure a serial port.
			Data can be written to a serial port using one of the binary writing functions on this forum.
			I appologize for the script not beeing commented at all, also I am not sure if I did everything right. Comments and suggestions are welcome.
			
			Regards, 	olfen
			
			Dependencies:				DecToBin()
												ExtractInteger()
			
	*/
	
	/*                              	EXAMPLE(s)
	
			msgbox, % GetCommState(4)
			listvars
			pause
			
	*/
	


global
local h, cs, ch, port, DCB, Str, Uint

port=com%comport%
h := DllCall("CreateFile","Str", port,"Uint",0x80000000,"Uint",3,"UInt",0,"UInt",3,"Uint",0,"UInt",0)
If (h = -1 or h = 0 or ErrorLevel != 0)
return, -1
VarSetCapacity(DCB, 28, 0)
cs := DllCall("GetCommState", Uint, h, str, DCB)
If (cs = 0 or ErrorLevel != 0)
return, -2

;DCB_DCBlength:=ExtractInteger(DCB, 0, true, 4)
DCB_BaudRate:=ExtractInteger(DCB, 4, true, 4)

DCB_fBitMask:=ExtractInteger(DCB, 8, true, 4)
DCB_fBitMaskDec:=DCB_fBitMask
DCB_fBitMask:=DecToBin(DCB_fBitMask)

StringLeft, DCB_fAbortOnError, DCB_fBitMask, 1
StringMid, DCB_fRtsControl, DCB_fBitMask, 2, 2
StringMid, DCB_fNull, DCB_fBitMask, 4, 1
StringMid, DCB_fErrorChar, DCB_fBitMask, 5, 1
StringMid, DCB_fInX, DCB_fBitMask, 6, 1
StringMid, DCB_fOutX, DCB_fBitMask, 7, 1
StringMid, DCB_fTXContinueOnXoff, DCB_fBitMask, 8, 1
StringMid, DCB_fDsrSensitivity, DCB_fBitMask, 9, 1
StringMid, DCB_fDtrControl, DCB_fBitMask, 10, 2
StringMid, DCB_fOutxDsrFlow, DCB_fBitMask, 12, 1
StringMid, DCB_fOutxCtsFlow, DCB_fBitMask, 13, 1
StringMid, DCB_fParity, DCB_fBitMask, 14, 1
StringRight, DCB_fBinary, DCB_fBitMask, 1

IfEqual, DCB_fDtrControl, 00, SetEnv, DCB_fDtrControl, DTR_CONTROL_DISABLE
IfEqual, DCB_fDtrControl, 01, SetEnv, DCB_fDtrControl, DTR_CONTROL_ENABLE
IfEqual, DCB_fDtrControl, 10, SetEnv, DCB_fDtrControl, DTR_CONTROL_HANDSHAKE

IfEqual, DCB_fRtsControl, 00, SetEnv, DCB_fRtsControl, RTS_CONTROL_DISABLE
IfEqual, DCB_fRtsControl, 01, SetEnv, DCB_fRtsControl, RTS_CONTROL_ENABLE
IfEqual, DCB_fRtsControl, 10, SetEnv, DCB_fRtsControl, RTS_CONTROL_HANDSHAKE
IfEqual, DCB_fRtsControl, 11, SetEnv, DCB_fRtsControl, RTS_CONTROL_TOGGLE

DCB_XonLim:=ExtractInteger(DCB, 14, true, 2)
DCB_XoffLim:=ExtractInteger(DCB, 16, true, 2)
DCB_ByteSize:=ExtractInteger(DCB, 18, true, 1)

DCB_Parity:=ExtractInteger(DCB, 19, true, 1)
IfEqual, DCB_Parity, 2, SetEnv, DCB_Parity, Even
IfEqual, DCB_Parity, 3, SetEnv, DCB_Parity, Mark
IfEqual, DCB_Parity, 0, SetEnv, DCB_Parity, None
IfEqual, DCB_Parity, 1, SetEnv, DCB_Parity, Odd
IfEqual, DCB_Parity, 4, SetEnv, DCB_Parity, Space

DCB_StopBits:=ExtractInteger(DCB, 20, true, 1)
IfEqual, DCB_StopBits, 2, SetEnv, DCB_StopBits, 2
IfEqual, DCB_StopBits, 1, SetEnv, DCB_StopBits, 1,5
IfEqual, DCB_StopBits, 0, SetEnv, DCB_StopBits, 1

DCB_XonChar:=ExtractInteger(DCB, 21, true, 1)
DCB_XoffChar:=ExtractInteger(DCB, 22, true, 1)
DCB_ErrorChar:=ExtractInteger(DCB, 23, true, 1)
DCB_EofChar:=ExtractInteger(DCB, 24, true, 1)
DCB_EvtChar:=ExtractInteger(DCB, 25, true, 1)

ch:=DllCall("CloseHandle", "Uint", h)
If (ch = 0 or ErrorLevel != 0)
return, -3
return, 0
}
;{ sub for GetCommState
DecToBin(In_Val) {
	local bit, bin, dec
	if In_Val is not integer
	return, "ERROR"
	dec:=In_Val
	Loop
	{
		bit:=mod(dec, 2)
		dec:=dec//2
		bin=%bit%%bin%
		IfEqual, dec, 0, break
  }
	return, %bin%
}
;}
;2
pauseSuspendScript(ScriptTitle, suspendHotkeys := False, pauseScript := False) {	;-- function to suspend/pause another script
	
	/*                              	EXAMPLE(s)
	
			f1::
			msgbox % pauseSuspendScript("test2.ahk", True, True)
			return 
			
	*/
	
	
	prevDetectWindows := A_DetectHiddenWindows
	prevMatchMode := A_TitleMatchMode
	DetectHiddenWindows, On
	SetTitleMatchMode, 2
	if (script_id := WinExist(ScriptTitle " ahk_class AutoHotkey"))
	{
		; Force the script to update its Pause/Suspend checkmarks.
		SendMessage, 0x211,,,, ahk_id %script_id%  ; WM_ENTERMENULOOP
		SendMessage, 0x212,,,, ahk_id %script_id%  ; WM_EXITMENULOOP		
		; Get script status from its main menu.
		mainMenu := DllCall("GetMenu", "uint", script_id)
		fileMenu := DllCall("GetSubMenu", "uint", mainMenu, "int", 0)
		isPaused := DllCall("GetMenuState", "uint", fileMenu, "uint", 4, "uint", 0x400) >> 3 & 1
		isSuspended := DllCall("GetMenuState", "uint", fileMenu, "uint", 5, "uint", 0x400) >> 3 & 1
		DllCall("CloseHandle", "uint", fileMenu)
		DllCall("CloseHandle", "uint", mainMenu)
		if (suspendHotkeys && !isSuspended) || (!suspendHotkeys && isSuspended)
			PostMessage, 0x111, 65305, 1,,  ahk_id %script_id% ; this toggles the current suspend state.
		if (pauseScript && !isPaused) || (!pauseScript && isPaused)
			PostMessage, 0x111, 65403,,,  ahk_id %script_id% ; this toggles the current pause state.
	}
	DetectHiddenWindows, %prevDetectWindows%
	SetTitleMatchMode, %prevMatchMode%
	return script_id
}
;3
RtlGetVersion() {																											;-- retrieves version of installed windows system
	
	; https://github.com/jNizM/ahk_pi-hole/blob/master/src/pi-hole.ahk
	 ; https://msdn.microsoft.com/en-us/library/mt723418(v=vs.85).aspx
	; 0x0A00 - Windows 10
	; 0x0603 - Windows 8.1
	; 0x0602 - Windows 8 / Windows Server 2012
	; 0x0601 - Windows 7 / Windows Server 2008 R2
	; 0x0600 - Windows Vista / Windows Server 2008
	; 0x0502 - Windows XP 64-Bit Edition / Windows Server 2003 / Windows Server 2003 R2
	; 0x0501 - Windows XP
	; 0x0500 - Windows 2000
	; 0x0400 - Windows NT 4.0
	static RTL_OSV_EX, init := NumPut(VarSetCapacity(RTL_OSV_EX, A_IsUnicode ? 284 : 156, 0), RTL_OSV_EX, "uint")
	if (DllCall("ntdll\RtlGetVersion", "ptr", &RTL_OSV_EX) != 0)
		throw Exception("RtlGetVersion failed", -1)
	return ((NumGet(RTL_OSV_EX, 4, "uint") << 8) | NumGet(RTL_OSV_EX, 8, "uint"))
}
;4
PostMessageUnderMouse(Message, wParam = 0, lParam=0) {									;-- Post a message to the window underneath the mouse cursor, can be used to do things involving the mouse scroll wheel

	/*                              	DESCRIPTION
	
			 Func: PostMessageUnderMouse
			 Post a message to the window underneath the mouse cursor. I mostly uses to do things involving the mouse
			 scroll wheel. Note you should only call this from a hotkey.
			 All the parameters are the same as for PostMessage.   
			 See \c SendMessage in AHK Help.
			  
			  
	*/
	
	oldCoordMode:= A_CoordModeMouse
	CoordMode, Mouse, Screen
	MouseGetPos X, Y, , , 2
	hWnd := DllCall("WindowFromPoint", "int", X , "int", Y)
	PostMessage %Message%, %wParam%, %lParam%, , ahk_id %hWnd%
	CoordMode, Mouse, %oldCoordMode%
  }
;5
WM_SETCURSOR(wParam, lParam) { 																			;-- Prevent "sizing arrow" cursor when hovering over window border
		/*                              	DESCRIPTION
		
				Link: https://gist.github.com/grey-code/5304819
				WM_SETCURSOR := 0x0020
				standard arrow cursor
				
	*/
	static HARROW := DllCall("LoadCursor", "Ptr", 0, "Ptr", 32512, "UPtr")

	HTCODE := lParam & 0xFFFF
	if (HTCODE > 9) && (HTCODE < 19) { ; cursor is on a border
		DllCall("SetCursor", "Ptr", HARROW) ; show arrow cursor
		return true ; prevent further processing
	}
}


}
;|														|														|														|														|
;|   pauseSuspendScript()               	|   GetCommState()                       	|   RtlGetVersion()                          	|   PostMessageUnderMouse()       	|
;|   WM_SETCURSOR()                   	|
;---------------------------------------------------------------------------------------------------------------------------------------------------------
;---------------------------------------------------------------------------------------------------------------------------------------------------------

{ ; RegEx - Strings / 
	
	;1. ####### AHK Code finders ###########
	
	
		; a) https://autohotkey.com/boards/viewtopic.php?f=60&t=29996
		; If you would like, this is the RegEx I use to find function definitions, it could probably be improved on still for efficiency, but it might save people a step if they have those multi-line function definitions.
			funcdef:=	"^[ \t]*(?!(if\(|while\(|for\())([\w#!^+&<>*~$])+\d*\([^)]*\)([\s]|(/\*.*?\*)/|((?<=[\s]);[^\r\n]*?$))*?[\s]*\{"
						or
			funcfinder01:= "^\s*\w+\(.*?\)\s*(;?.*\n(^\s*(;.*|)\n)*?^\s*|)\{"		;from https://autohotkey.com/board/topic/7807-editor/#entry48536
			funcfinder02:= "^[a-zA-Z0-9_].*(\(.*\))"											;tested works most in SciTE find dialog
			funcfinder03:= "[a-zA-Z0-9_]*\([a-zA-Z0-9_\,]*\)\s*\{*.*\}*"			;tested works in AHK Code - finds all functions

		; If you want it to not find functions with no parameters I believe you just need to change a * to a + like:
			funcdefNoParams:= 			"^[ \t]*(?!(if\(|while\(|for\())([\w#!^+&<>*~$])+\d*\([^)]+\)([\s]|(/\*.*?\*)/|((?<=[\s]);[^\r\n]*?$))*?[\s]*\{"
		; finds all in () including the brackets
			findAllinBrackets:= 				"(\(.*\))"
			SpaceAtLineBeginning:= 	"^[\s]*"
		; find alphanumeric words 
			findAllWordsIncludingDoubleNames:= ([A-Za-z|-])+   ;finds Peter Tiger-Woods => Match1: Peter , Match2: Tiger-Woods

			Code := RegExReplace(Code,"mS)(?:^| );.*$") 																;remove single line comments
			Code := RegExReplace(Code,"msS)^ */\*.*?\r\n *\*/") 												;remove multiline comments
			Code := RegExReplace(Code,"S)""(?:[^""]|"""")*""","|") 												;remove string literals
			Code := RegExReplace(Code,"mS)^ *([\w#_@\$%]+) *=.*?$","$1") 							;remove classic assignment text
		
		; strip ahk_ from start and .ahk from end
			ApplicationName    := RegExReplace(A_ScriptName,"i)(ahk_)(.*)([.]ahk)","$2") 
		
} 
;|														|														|														|														|
;|	1. Regex Strings to find functions	|


;{ ----- NOT SORTED FUNCTION OR FUNCTION I CANT IDENTIFY - but looks interesting






	






;}



;}

{ ; Script by Rajat saves settings in .ahk file itselfs!
/*
[settings]
like=0

*/

IniRead, like, %a_scriptfullpath%, settings, like

Gui, Add, button, x16 y17 w90 h30 glike, I like this
Gui, Add, button, x16 y57 w90 h30 gdontlike, I don't like this
Gui, Add, Text, x26 y97 w70 h20, Previous = %like%
Gui, Show, x158 y110 h120 w128, Generated using SmartGUI 2.6
Return
[]
GuiClose:
        Gui, submit
ExitApp

like:
        IniWrite, 1, %a_scriptfullpath%, settings, like
Return

dontlike:
        IniWrite, 0, %a_scriptfullpath%, settings, like
Return
} 

{ ;Scite4AHK options

	{ ; Toggle All Fold RightContextMenu
# 23 Un/Fold #Region
command.name.23.$(ahk)=Toggle Fold #Region
command.23.*.ahk=dostring local text = editor:GetText() tReg = {} pos, iEnd = text:find('#[Rr][Ee][Gg][Ii][Oo][Nn]') \
if pos ~= nil then table.insert(tReg, pos) while true do \
pos, iEnd = text:find('#[Rr][Ee][Gg][Ii][Oo][Nn]', iEnd) \
if pos == nil then
function RunAsTI {param([Parameter(Position=0)]$cmd,[Parameter(ValueFromRemainingArguments)]$xargs)
 $Ex=$xargs-contains'-Exit';$xargs=$xargs|?{$_-ne'-Exit'}
 $wi=[Security.Principal.WindowsIdentity]::GetCurrent()
 $id='RunAsTI';$key="Registry::HKU\$($wi.User.Value)\Volatile Environment";$arg='';$rs=$false
 $csf=gcs|?{$_.ScriptName-and$_.ScriptName-like'*.ps1'}|select -l 1;$cs=if($csf){$csf.ScriptName}else{$null}
 if(!$cmd){if($wi.User.Value-eq'S-1-5-18'){return};$rs=$true;$arr=[Environment]::GetCommandLineArgs();$i=[array]::IndexOf($arr,'-File');if($i-lt0){$i=[array]::IndexOf($arr,'-f')}
  if($i -ge 0 -and($i+1)-lt$arr.Count){if(!$cs){$cs=$arr[$i+1]};if(($i+2)-lt$arr.Count){$arg=($arr[($i+2)..($arr.Count-1)]|%{"`"$($_-replace'"','""')`""})-join' '}}
  else{$cp=if($csf){$csf.InvocationInfo.BoundParameters}else{gv PSBoundParameters -sc 1 -va -ea 0};$ca=if($csf){$csf.InvocationInfo.UnboundArguments}else{gv args -sc 1 -va -ea 0};if($null-eq$cp){$cp=@{}};if($null-eq$ca){$ca=@()}
  $arg=(@($cp.GetEnumerator()|%{if(($_.Value-is[switch]-and$_.Value.IsPresent)-or($_.Value-eq$true)){"-$($_.Key)"}elseif($_.Value-isnot[switch]-and$_.Value-ne$true-and$_.Value-ne$false){"-$($_.Key) `"$($_.Value-replace'"','""')`""}})+@($ca|%{"`"$($_-replace'"','""')`""})) -join' '}
  if($cs){$cmd='powershell';$arg="-nop -ep bypass -f `"$cs`" $arg"}else{$cmd='powershell';$arg='-nop -ep bypass'}}
 elseif($xargs){$arg=$xargs-join' '};if($rs-or$Ex){$t=[AppDomain]::CurrentDomain.DefineDynamicAssembly((new-object Reflection.AssemblyName('Z')),1).DefineDynamicModule('Z').DefineType('Z');$null=$t.DefinePInvokeMethod('ShowWindow','user32.dll',22,1,[bool],[Type[]]([IntPtr],[int]),1,2);$null=$t.CreateType()::ShowWindow([Diagnostics.Process]::GetCurrentProcess().MainWindowHandle,0)}
 $V='';'cmd','arg','id','key'|%{$V+="`n`$$_='$($(gv $_ -val)-replace"'","''")';"}
 Edit-Registry $key $id $($V,@'
 $I=[int32];$M=$I.module.gettype("System.Runtime.Interop`Services.Mar`shal");$P=$I.module.gettype("System.Int`Ptr");$S=[string]
 $D=@();$T=@();$DM=[AppDomain]::CurrentDomain."DefineDynami`cAssembly"(1,1)."DefineDynami`cModule"(1);$Z=[uintptr]::size
 0..5|%{$D+=$DM."Defin`eType"("AveYo_$_",1179913,[ValueType])};$D+=[uintptr];4..6|%{$D+=$D[$_]."MakeByR`efType"()}
 $F='kernel','advapi','advapi',($S,$S,$I,$I,$I,$I,$I,$S,$D[7],$D[8]),([uintptr],$S,$I,$I,$D[9]),([uintptr],$S,$I,$I,[byte[]],$I)
 0..2|%{$9=$D[0]."DefinePInvok`eMethod"(('CreateProcess','RegOpenKeyEx','RegSetValueEx')[$_],$F[$_]+'32',8214,1,$S,$F[$_+3],1,4)}
 $DF=($P,$I,$P),($I,$I,$I,$I,$P,$D[1]),($I,$S,$S,$S,$I,$I,$I,$I,$I,$I,$I,$I,[int16],[int16],$P,$P,$P,$P),($D[3],$P),($P,$P,$I,$I)
 1..5|%{$k=$_;$n=1;$DF[$_-1]|%{$9=$D[$k]."Defin`eField"('f'+$n++,$_,6)}};0..5|%{$T+=$D[$_]."Creat`eType"()}
 0..5|%{nv "A$_" ([Activator]::CreateInstance($T[$_])) -fo};function F($1,$2){$T[0]."G`etMethod"($1).invoke(0,$2)}
 $wi=[Security.Principal.WindowsIdentity]::GetCurrent();$TI=$wi.User.Value-eq'S-1-5-18';$As=$null
 if(!$TI){foreach($n in 'TrustedInstaller','lsass','winlogon'){$As=@(gps -name $n -ea 0)[0];if($As){break}
 $null=sc.exe start $n 2>$null;$As=@(gps -name $n -ea 0)[0];if($As){break}}
 function M($1,$2,$3){$M."G`etMethod"($1,[type[]]$2).invoke(0,$3)};$H=@();$Z,(4*$Z+16)|%{$H+=M "AllocHG`lobal" $I $_}
 M "WriteInt`Ptr" ($P,$P) ($H[0],$As.Handle);$A1.f1=131072;$A1.f2=$Z;$A1.f3=$H[0];$A2.f1=1;$A2.f2=1;$A2.f3=1;$A2.f4=1
 $A2.f6=$A1;$A3.f1=10*$Z+32;$A4.f1=$A3;$A4.f2=$H[1];M "StructureTo`Ptr" ($D[2],$P,[boolean]) (($A2-as$D[2]),$A4.f2,$false)
 $Run=@($null,"powershell -win 1 -nop -c iex `$env:R; # $id",0,0,0,0x0E080600,0,$null,($A4-as$T[4]),($A5-as$T[5]))
 F 'CreateProcess' $Run;return};$env:R='';rp $key $id -force;$priv=[diagnostics.process]."GetM`ember"('SetPrivilege',42)[0]
 'SeSecurityPrivilege','SeTakeOwnershipPrivilege','SeBackupPrivilege','SeRestorePrivilege'|%{$priv.Invoke($null,@("$_",2))}
 $HKU=[uintptr][uint32]2147483651;$NT='S-1-5-18';$reg=($HKU,$NT,8,2,($HKU-as$D[9]));F 'RegOpenKeyEx' $reg;$LNK=$reg[4]
 function L($1,$2,$3){Edit-Registry 'HKLM\SOFTWARE\Classes\AppID\{CDCBCFCA-3CDC-436f-A4E2-0E02075250C2}' 'RunAs' $3
  $b=[Text.Encoding]::Unicode.GetBytes("\Registry\User\$1");F 'RegSetValueEx' @($2,'SymbolicLinkValue',0,6,[byte[]]$b,$b.Length)}
 L ($key-split'\\')[1] $LNK '';$R=[diagnostics.process]::start($cmd,$arg);if($R){$R.WaitForExit()};L '.Default' $LNK 'Interactive User'
'@) -type 7;$a="-win 0 -nop -c `n$V `$env:R=(gi `$key -ea 0).getvalue(`$id)-join''; iex `$env:R"
 (new-object -com shell.application).shellexecute('powershell',$a,'','runas',0);if($rs-or$Ex){[Environment]::Exit(0)}
} # lean & mean snippet by AveYo; refined by RapidOS [haslate]

Export-ModuleMember -Function *
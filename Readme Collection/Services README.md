# Streamlined Services for RapidOS Stable

In **RapidOS Stable**, several services are adjusted or disabled to optimize system performance. Below is a list of streamlined services:

### Core Services:
- **App Management (AppMgmt)** - Disabled: `Startup 4`
- **ActiveX Installer (AxInstSV)** - Disabled: `Startup 4`
- **Delivery Optimization (DoSvc)** - Manual: `Startup 3`
- **Diagnostic Policy Service (DPS)** - Disabled: `Startup 4`
- **Font Cache (FontCache)** - Manual: `Startup 3`
- **Server (LanmanServer)** - Manual: `Startup 3`
- **Program Compatibility Assistant (PcaSvc)** - Disabled: `Startup 4`
- **Sign-in Manager (SEMgrSvc)** - Disabled: `Startup 4`
- **Shell Hardware Detection (ShellHWDetection)** - Disabled: `Startup 4`
- **SSDP Discovery (SSDPSRV)** - Disabled: `Startup 4`
- **Distributed Link Tracking Client (TrkWks)** - Disabled: `Startup 4`
- **Windows Event Log (WEPHOSTSVC)** - Disabled: `Startup 4`
- **Windows Remote Management (WinRM)** - Disabled: `Startup 4`

### Telemetry-related Services (Disabled):
- **Assigned Access Manager (AssignedAccessManagerSvc)** 
- **Diagnostic Hub Standard Collector (diagnosticshub.standardcollector.service)**
- **Connected User Experiences and Telemetry (DiagTrack)**
- **Diagnostic Service Host (diagsvc)**
- **WAP Push Message Routing Service (dmwappushservice)**
- **NVIDIA Telemetry Container (NvTelemetryContainer)**
- **Performance Logs and Alerts (pla)**
- **Telemetry Service**
- **Troubleshooting Service (TroubleshootingSvc)**
- **User Device Registration Service (UdkUserSvc)**
- **Update Health Services (uhssvc)**
- **Warp JIT Service (WarpJITSvc)**
- **Windows Diagnostic Infrastructure (WdiServiceHost, WdiSystemHost)**
- **Windows Event Collector (Wecsvc)**
- **Windows Error Reporting Service (WerSvc, wercplsupport)**

### Streamlined Drivers:
<!-- - **Network Data Usage (Ndu)** - Disabled: `Startup 4` -->
- **NetBIOS over TCP/IP (NetBT)** - Disabled: `Startup 4`
- **GPU Energy Driver (GpuEnergyDrv)** - Disabled: `Startup 4`

>[!Important]
>
>These changes only apply to **RapidOS Stable**. The **Speed** and **Extreme** versions are still in development and will have different service configurations.
# Streamlined services in RapidOS

Below is a list of streamlined services:

### Core services:

- **Application Management (AppMgmt)** - Disabled: `Startup 4`
- **Delivery Optimization (DoSvc)** - Manual: `Startup 3`
- **Server (LanmanServer)** - Manual: `Startup 3`
- **Distributed Transaction Coordinator (MSDTC)** - Disabled: `Startup 4`
- **Program Compatibility Assistant Service (PcaSvc)** - Disabled: `Startup 4`
- **Payments and NFC/SE Manager (SEMgrSvc)** - Disabled: `Startup 4`
- **Shell Hardware Detection (ShellHWDetection)** - Disabled: `Startup 4`
- **SSDP Discovery (SSDPSRV)** - Disabled: `Startup 4`
- **Distributed Link Tracking Client (TrkWks)** - Disabled: `Startup 4`
- **User Choice Protection Driver (UCPD)** - Disabled: `Startup 4`
- **Offline Maps Broker (MapsBroker)** - Manual: `Startup 3`

### Telemetry-related services (Disabled or Internet-restricted):

- **Connected User Experiences and Telemetry (DiagTrack)** - Disabled
- **Diagnostic Service Host (diagsvc)** - Disabled
- **NVIDIA Telemetry Container (NvTelemetryContainer)** - Disabled
- **Telemetry Service (Telemetry)** - Disabled
- **Troubleshooting Service (TroubleshootingSvc)** - Disabled
- **Update Health Service (uhssvc)** - Disabled
- **User Device Registration (UdkUserSvc)** - Network access restricted
- **Performance Logs & Alerts (pla)** - Network access restricted
- **Windows Event Collector (Wecsvc)** - Network access restricted
- **Windows Error Reporting Service (WerSvc)** - Network access restricted
- **Problem Reports and Solutions Control Panel Support (wercplsupport)** - Network access restricted

### Streamlined drivers:

- **NetBIOS over TCP/IP (NetBT)** - Disabled: `Startup 4`
- **GPU Energy Driver (GpuEnergyDrv)** - Disabled: `Startup 4` (applied only if not a laptop)
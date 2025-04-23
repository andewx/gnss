## GNSS GPS C/A Code SDR Application

#### Requirements

> Running this application on your host machine requires the following:

- MATLAB 2024b
- Communications Toolbox
- DSP Toolbox
- Parallel Computation Toolbox


### Developer Notes

#### SDR GNSS Signal Computation Requirements

Developing a GNSS GPS Receiver requires the system to maintain lock onto a continuous signal with fairly tight tolerances at 1.023MhZ while we are confined to implementing this project with Software Defined Radio Application. 

On the receiver side of things we break the recieve chain into a the `GPSSignalProcessor` which accomplished the signal locking and acquisition tasks. Followed by the `GPSReceiver` which recieves and decodes the GPS LNAV frame data.

In order to successfully process the data we need to ensure that our processor and receive block ends are completing their processing before the next frame issuance. So if we decide we will signal process 3 bits worth of data in GPS C/A Code data we must process 60ms worth of 1.023MhZ frame data in < 60ms. This means we process 61k samples, so around 240kb worth of frame IQ data.

This may be feasible for a single frame or satellite but to allow multiple satellite reception we will likely at least for a software implementation require parallel signal processing and parallel frame processing capabilities.

Additionally it may be helpful to separate the frame decoding application from the signal processing application in order to ensure our `GPSSignalProcessor` runs at a steady rate without frame, calculation, and data issuance interrupts.

### MATLAB Thread Based Parallel Pools

Thread-based parallelism requires MATLAB R2020b or newer and a supported function set.

Check with:

```
parpool("threads");
```

This will initialize a pool using lightweight threads, not separate MATLAB workers (processes). It’s efficient for memory-bound tasks or when functions support thread-based execution.


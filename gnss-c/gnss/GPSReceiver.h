//GPSReciever.h
#ifndef GPSRECEIVER_H
#define GPSRECEIVER_H
#include <memory>
#include <string>
#include <vector>
#include "GPSEphemeris.h"
#include "GPSSatellite.h"

using GPSRecieverChannelPtr = std::shared_ptr<GPSReceiverChannel>;
GPSRecieverChannelPtr makeGPSReceiverChannel(int satelliteID) {
    return std::make_shared<GPSReceiverChannel>(satelliteID);
};
class GPSReceiverChannel
{
public:
    ~GPSReceiverChannel() = default;
    GPSReceiverChannel(int satelliteID);
    std::string toString() const;



private:

    // Private Methods
    friend GPSRecieverChannelPtr makeGPSReceiverChannel(int satelliteID);
    bool hasChipLock();
    void seekChipLock();
    void seekBitLock();
    void processBit(int);
    void seekPreamble();
    void processSubframe();
    void processTLM();
    void processHOW();
    void processFrame1();
    void processFrame2();
    void processFrame3();
    void processFrame4();
    void processFrame5();
    void computeWord();


    // Private Members
    int satelliteID_; // Satellite ID
    int gpsStatus_; // GPS status
    int preambleCode_; // Preamble code
    int trackBit_; // Track bit
    int lastParityBit_; // Last parity bit
    int timeOfWeek;
    int gpsWeek;

    GPSSatellitePtr satellite_; // Pointer to the satellite object

};



#endif
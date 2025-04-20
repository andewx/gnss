//GPSTransmitter.h
#ifndef GPSTRANSMITTER_H
#define GPSTRANSMITTER_H
#include <memory>
#include <string>
#include <vector>
#include "GPSEphemeris.h"
#include "GPSSatellite.h"


class GPSTransmitter;
using GPSTransmitterPtr = std::shared_ptr<GPSTransmitter>;
GPSTransmitterPtr makeGPSTransmitter(int id, double latitude, double longitude, double altitude) {
    return std::make_shared<GPSTransmitter>(id, latitude, longitude, altitude);
};

class GPSTransmitter {
    public:
        ~GPSTransmitter() = default;
        GPSTransmitter(int id);

    private:
        friend GPSTransmitterPtr makeGPSTransmitter(int id, double latitude, double longitude, double altitude);
        void computeTime();
        std::vector<int> GenerateRandomBits(int n);
        std::string toString() const;
        std::vector<int> ComputeWord(int bits);
        std::vector<int> GenerateRandomWord();
        std::vector<int> GenerateSubframe(int subframe);
        std::vector<int> GenerateFrame(int frame);

        
        int id_; // Transmitter ID
        double latitude_; // Latitude in degrees
        double longitude_; // Longitude in degrees
        double altitude_; // Altitude in meters
        double x_; // X coordinate in ECEF
        double y_; // Y coordinate in ECEF
        double z_; // Z coordinate in ECEF
        GPSEphemerisPtr ephemeris_; // Pointer to the ephemeris object
};


#endif
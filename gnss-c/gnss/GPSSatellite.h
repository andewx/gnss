// GPSSatellite.h
#ifndef GPSSATELLITE_H
#define GPSSATELLITE_H
#include <memory>
#include <GPSEphemeris.h>

class GPSSatellite;

using GPSSatellitePtr = std::shared_ptr<GPSSatellite>;

GPSSatellitePtr makeGPSSatellite(int id, double latitude, double longitude, double altitude) {
    return std::make_shared<GPSSatellite>(id, latitude, longitude, altitude);
};

class GPSSatellite {
    public:
        ~GPSSatellite() = default;
        GPSSatellite(int id, double latitude, double longitude, double altitude)
            : id_(id), latitude_(latitude), longitude_(longitude), altitude_(altitude) {};

    private:
        friend GPSSatellitePtr makeGPSSatellite(int id, double latitude, double longitude, double altitude);
        int id_; // Satellite ID
        double latitude_; // Latitude in degrees
        double longitude_; // Longitude in degrees
        double altitude_; // Altitude in meters
        double x_; // X coordinate in ECEF
        double y_; // Y coordinate in ECEF
        double z_; // Z coordinate in ECEF
        GPSEphemerisPtr ephemeris_; // Pointer to the ephemeris object
};

#endif // GPSSATELLITE_H
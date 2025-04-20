//GPSEphemeris.h
#ifndef GPSEPHIMERIS_H
#define GPSEPHIMERIS_H
#include <memory>
#include <string>

using ECEFPositionPtr = std::shared_ptr<ECEFPosition>;
ECEFPositionPtr makeECEFPosition(double x, double y, double z) {
    return std::make_shared<ECEFPosition>(x, y, z);
};

class ECEFPosition {
    public:
        ECEFPosition(double x, double y, double z) : x_(x), y_(y), z_(z) {}
        double getX() const { return x_; }
        double getY() const { return y_; }
        double getZ() const { return z_; }
    private:
        double x_;
        double y_;
        double z_;
};



class GPSEphemeris;
using GPSEphemerisPtr = std::shared_ptr<GPSEphemeris>;
GPSEphemerisPtr makeGPSEphemeris(int id, double a, double e, double i, double omega, double w, double M0, double t0) {
    return std::make_shared<GPSEphemeris>(id, a, e, i, omega, w, M0, t0);
};

class GPSEphemeris {
    public:
        ~GPSEphemeris() = default;
        GPSEphemeris(int id, double a, double e, double i, double omega, double w, double M0, double t0)
            : id_(id), a_(a), e_(e), i_(i), omega_(omega), w_(w), M0_(M0), t0_(t0) {};
        ECEFPositionPtr getPosition(double t);
        ECEFPositionPtr setPosition(double lat, double lon, double alt);
        std::string toString() const {
            return "GPSEphemeris ID: " + std::to_string(id_) + ", Semi-major axis: " + std::to_string(a_) +
                   ", Eccentricity: " + std::to_string(e_) + ", Inclination: " + std::to_string(i_) +
                   ", Longitude of ascending node: " + std::to_string(omega_) +
                   ", Argument of perigee: " + std::to_string(w_) +
                   ", Mean anomaly at epoch: " + std::to_string(M0_) +
                   ", Time of epoch: " + std::to_string(t0_);
        }



    private:
        friend GPSEphemerisPtr makeGPSEphemeris(int id, double a, double e, double i, double omega, double w, double M0, double t0);
        int id_; // Satellite ID
        double a_; // Semi-major axis in meters
        double e_; // Eccentricity
        double i_; // Inclination in radians
        double omega_; // Longitude of ascending node in radians
        double w_; // Argument of perigee in radians
        double M0_; // Mean anomaly at epoch in radians
        double t0_; // Time of epoch in seconds since the reference time
        double delN; // Mean motion difference from computed value
        int IDOT;
        int IDOE;
        double Cuc;
        double Cus;
        double Crc;
        double Crs;
        double Cic;
        double Cis;
        double toe;

};


#endif
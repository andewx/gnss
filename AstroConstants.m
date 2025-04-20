classdef AstroConstants
    properties (Constant)
        % Constants
        c = 299792458; % Speed of light in m/s
        mu = 3.986005e14; % Earth's gravitational constant in m^3/s^2
        omegaE = 7.2921151467e-5; % Earth's rotation rate in rad/s
        J2 = 1.08262968e-3; % Earth's second zonal harmonic
        Re = 6378137.0; % Earth's equatorial radius in meters
        f = 1/298.257223563; % Earth's flattening factor
        
    end
end
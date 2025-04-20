% Implements GPS Satellite on a C/A 10-bit shift register code with
% standard octet format used for defining satellite, simulated satellite
% will need to simulate a GPS time keeping mechanism for delivery
classdef GPSSatellite < handle
    properties
        gnssId
        prnCoder
        caCode
        caModulatedCode
        correlatorPos
        LNAV
        ephemeris;
        position;
        time;
    end

    methods
        %% Constructor
        function obj = GPSSatellite(id)
            % Constructor for the GPSSatellite class
            % id - Satellite ID
            obj.gnssId = id;
            obj.prnCoder = CACodeGenerator(id);
            obj.caCode = obj.prnCoder.generate();
            obj.caModulatedCode = 1 - 2*obj.caCode;
            obj.correlatorPos = 0;
            obj.LNAV = zeros(1500,1);
            obj.time;
            obj.ephemerisObj = Ephemeris();
        end

        function pos = Position(obj)
            obj.position =  obj.ephemeris.Position(obj.time);
            pos = obj.pos;
        end

        function pos = StaticPosition(obj)
            pos = obj.ephemeris.GetStaticPosition();
        end

    end
end
classdef Ephemeris < handle
    % User algorithm for ephemeris determination
    % IS-GPS-200M 20.3.3.4.3
    % User shall compute the ECEF coordinates of position for the phase center of the SV's antennas
    % utilizing a variation of the equations shown in Table 20-IV
    % Subframes 2 and 3 are keplerian elements
    % User equations give SV's antenna phase center position in WGS-84 ECEF coordinates
    % Origin = Earths center of mass
    % Z-Axis = IERS Reference Pole IRP
    % X-Axis = IERS Reference Meridian and the plan passing through the origin and normal to the z axis
    % Y-Axis = Completes the right handed Earther Centered, Earth Fixed Orthogonal coordinate system
    properties
        M0                  % Mean anomaly of reference time
        delN                % Mean motion difference from computed value
        e                   % Eccentricity
        A                   %Square root of the semi-major axis
        O0                  % Longitude of adcende node of orbit plane at weekly epoch
        i0                  % Inclination angle at reference time
        o                   % Argument of perigee
        ODot                % Rate of right ascension
        IDOT                % Rate of inclination angle
        Cuc                 % Amplitude of the cosine harmonic correction term to the argument of latitude
        Cus                 % Amplitude of the sine harmonic correction term to the argument of latitude
        Crc                 % Amplitude of the cosine harmonic correction term to the orbit radius
        Crs                 % Amplitude of the sine harmonic correction term to the orbit radius
        Cic                 % Amplitude of the cosine harmonic correction term to the angle of inclination
        Cis                 % Amplitude of the sine harmonic correction term to the angle of inclination
        toe                 % Reference time ephemeris
        IODE                % Issue of Data Ephemeris
        pos;
    end
    methods
        function obj = Ephemeris()
            obj.M0 = 0;
            obj.delN = 0;
            obj.e = 1;
            obj.A = 1;
            obj.O0 = 1;
            obj.i0 = 1;
            obj.o = 1;
            obj.ODot = 1;
            obj.IDOT = 1;
            obj.Cuc = 1;
            obj.Cus = 1;
            obj.Crc = 1;
            obj.Crs = 1;
            obj.Cic = 1;
            obj.Cis = 1;
            obj.toe = 0;
            obj.IODE = 8;
            obj.pos = [0 0 0];
        end

        % SV Position in ECEF WGS-84 Coordinates derived from I-GPS-200M
        % gps time is the time of transmission of this message which will
        % then reference the reference epoch time for translation
        function [position] = Position(obj, gpstime)
            %Argument of Latitude
            n = sqrt((3.986005*10^14)/obj.A^5)+ obj.delN;
            Mk = obj.M0 + n0;
            vals = [Mk 0 0];
            m = 3;
            %Refined value
            for j = 2:m
                vals(j) = vals(j-1)+(Mk - vals(j-1)+ obj.e*sin(vals(j-1)))/(1-e * cos(vals(j-1)));
            end
            Ek = vals(m);
            vk = 2*tan2(sqrt((1 + obj.e)/(1-obj.e))*tan(Ek/2));
            tk = gpstime - obj.toe;

            phik = vk + obj.o;

            % Second harmonic perturbations
            deluk = obj.Cus*sin(2*phik)+ obj.Cuc*cos(2*phik);
            delrk = obj.Crs*sin(2*sin(phik))+ obj.Crc*cos(2*phik);
            delik = obj.Cis*sin(2*phik)+ obj.Cic*cos(2*phik);

            % uk 
            uk = phik + deluk;
            rk = obj.A^2*(1- obj.e*cos(Ek)) + delrk;
            ik = obj.i0 + delik + obj.IDOT*tk;


            %orbital plan positions
            xkp = rk*cos(uk);
            ykp = rk*sin(uk);

            %Corrected longitude of the ascending node
            omegaK = obj.O0 + (obj.ODot-7.291151467*10^(-5))*tk - 7.291151467*10^(-5)*obj.toe;
            
            %ECEF Cartesian Coordinates
            xk = xkp*cos(omegaK) - ykp*cos(ik)*sin(omegaK);
            yk = xkp*sin(omegaK) + ykp*cos(ik)*cos(omegaK);
            zk = ykp*sin(ik);
            obj.pos = [xk,yk, zk];
            position = obj.pos;
        end
        
        % Writes coordinates to LLA for visualization
        function [lla] = WriteLLA(filename)
            lla = cef2lla(obj.pos);
        end


        % Sets an ephemeris satellite position manually for debugging and
        % test setup purposes.
        function SetStaticPosition(obj, x, y, z)
            obj.pos = [x y z];
        end

        function [position] =  GetStaticPosition()
            position = obj.pos;
        end
    end

end
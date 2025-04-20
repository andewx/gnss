%% Test Setting Up the Satellite and See if the PRN Code is generating the correct sequence

sat1 = GPSSatellite(1);
bits = (DecodeOctet('1440',10));
disp(['GPS PRN Code   ', num2str(sat1.caCode(1:10))]);
disp(['GPS Validation ', num2str(bits)]);
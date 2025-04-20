% GNSS Scenario on Google Earth Address: 
% LLA-ECEF Coordinate for GPS Scenario Testing
% https://earth.google.com/web/@39.80883101,-111.12228659,956.30378714a,10049054.52910781d,35y,4.84927677h,0t,0r/data=CgRCAggBMikKJwolCiExNjFsc21KbjhzSEo4MnRNemJ4M0g2eXlPeVBwS0ZvUDMgAToDCgEwQgIIAEoICJyEgKYCEAE
% GPS 12 - Mexico / GPS 20 Calgary / GPS 5 Wisconis / GPS 2 Boise
% Parameters are ficticious for simulation purposes

alt = 20200000.0; %meters
lla12 = [27.066846 109.468093 alt];
lla02 = [44.541766 112.686838 alt];
lla20 = [53.198541 117.939793 alt];
lla05 = [50.089971 88.102649 alt]

ecef12 = lla2ecef(lla12);
ecef02 = lla2ecef(lla02);
ecef20 = lla2ecef(lla20);
ecef05 = lla2ecef(lla05);
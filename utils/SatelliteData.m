%% PRN Assignments for Live Satellite Recievers
% Satellite C/A Codes PRN is a Gold Code generated from two subsequence
% G1 and G2 as a 1023 chip long pattern with 1ms chipping length.
% Sequence generated from modulo 2 addition of LFSR registers

% First 10 chips are specified by a leading 1 bit for the first chip
% Followed by 3 Octets (111) for 10 bits Which is our initialization
sat1 = GPSSatellite(1,5,440);
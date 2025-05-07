%% GNSS GPS Tracking with Pluto SDR Hardware
%% Test Bench for Signal Acquisition and Tracking
% This generates a test signal and powers it through SDR Hardware Frontend
% and Receives and Demodulates the Test GPS GNSS C/A Signal on the Q
% Branch.
 thisDir = fileparts(mfilename('fullpath'));
 parentDir = fullfile(thisDir, '..');


addpath(parentDir);
% Create an instance of the FLL class before ach
DSP = GPSSignalProcessor(3,SAMPLES_PER_CHIP,1.023e6*SAMPLES_PER_CHIP, 0);

% Test updating the output of the DLL
SAMPLES_PER_CHIP = 2;
fs = 1.023e6*SAMPLES_PER_CHIP; % Sample rate

% Send Through Pluto Hardware at 920MHZ
fc = 920.1e6;

% Setup RTL-SDR RX
rx = sdrrx('RTL-SDR','SamplesPerFrame',floor(SAMPLES*2),'OutputDataType','double', ...
    'BasebandSampleRate', fs, 'CenterFrequency', fc, 'Gain', -5.0);

% Acquire the signal
disp('Acquiring Signal...');
inputSignal = rx();
DSP.Acquire2D(inputSignal, 500,true);
disp('Signal Acquired - Starting Tracking...\n Press Ctrl-C to stop tracking.');
quit = false;
while ~quit
    % Receive and process the signal
    inputSignal = rx();
    DSP.TestTrack(inputSignal);
end

release(rx);
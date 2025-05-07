%% GNSS GPS Tracking with Pluto SDR Hardware
%% Test Bench for Signal Acquisition and Tracking
% This generates a test signal and powers it through SDR Hardware Frontend
% and Receives and Demodulates the Test GPS GNSS C/A Signal on the Q
% Branch.
thisDir = fileparts(mfilename('fullpath'));
parentDir = fullfile(thisDir, '..');
addpath(parentDir);


SAMPLES_PER_CHIP = 2;
fs = 1.023e6*SAMPLES_PER_CHIP; % Sample rate
DATA_RATE = 20; % 20ms 
NUM_DATA_BITS = 5;
SAMPLE_TIME = (DATA_RATE*NUM_DATA_BITS)*1e-3;
SAMPLES = floor(SAMPLE_TIME*fs);

% Create an instance of the FLL class before ach
DSP = GPSSignalProcessor(3,SAMPLES_PER_CHIP,1.023e6*SAMPLES_PER_CHIP, 0);

% Test updating the output of the DLL


% Send Through Pluto Hardware at 920MHZ
fc = 920.1e6;

% Setup RTL-SDR RX
rx = comm.SDRRTLReceiver('CenterFrequency',fc,...
      'EnableTunerAGC', true, ...
      'SampleRate', fs, ...
      'OutputDataType','double',...
      'SamplesPerFrame',floor(SAMPLES),...
      'FrequencyCorrection',0);

% Setup a scope to visualize the values
scope = timescope('SampleRate', fs/1023, 'TimeSpan', SAMPLES*(1/fs), 'TimeSpanSource', "property");

% Acquire the signal
disp('Acquiring Signal...');
inputSignal = rx();
DSP.Acquire2D(inputSignal, 500,true);
disp('Signal Acquired - Starting Tracking...\n Press Ctrl-C to stop tracking.');
DSP.TestTrack(inputSignal);
pause(10);
release(rx);
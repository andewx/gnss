%% GNSS GPS Tracking with Pluto SDR Hardware
%% Test Bench for Signal Acquisition and Tracking
% This generates a test signal and powers it through SDR Hardware Frontend
% and Receives and Demodulates the Test GPS GNSS C/A Signal on the Q
% Branch.
thisDir = fileparts(mfilename('fullpath'));
parentDir = fullfile(testDir, '..');
resourceFile = fullfile(testDir, '..', 'resource_files','gps.bb');
addpath(parentDir);


SAMPLES_PER_CHIP = 2;

% Create an instance of the FLL class before ach
DSP = GPSSignalProcessor(3,SAMPLES_PER_CHIP,1.023e6*SAMPLES_PER_CHIP, 0);

% Test updating the output of the DLL
INITIAL_CODE_DELAY = floor(1023 * randn());
fs = 1.023e6*SAMPLES_PER_CHIP; % Sample rate
carrier = 1e3; %1khz IF Carrier
 s
% Every 1ms/1023 chips modulate the input signal
prnCode = CACodeGenerator(3).generate().';
prnCode = circshift(prnCode, INITIAL_CODE_DELAY);
%data = randi([0 1], TIME/DATA_RATE, 1); % Random data
data = [0 0 1 1 0 0 1 1 0 0 ]; % Test data
data = [data; data]
data = (2 .* data - 1)*1j; % Map the data to -1,1

DATA_RATE = 20; % 20ms 
SAMPLE_TIME = (DATA_RATE*length(data))*1e-3;
SAMPLES = floor(SAMPLE_TIME*fs);
signal = complex(zeros(SAMPLES,1), ones(SAMPLES,1));
modCode = (2*prnCode - 1)*1j; % Map the code to -1,1 on the Q Branch
modCode = DSP.dllController.ExpandCode(modCode,SAMPLES_PER_CHIP);

% Generate our Input Signal for the Receiver
j = 1;
s = 1/20;
for k = 1:SAMPLES_PER_CHIP*1023:length(signal)
    if k+SAMPLES_PER_CHIP*1023-1 >= length(signal)
        break;
    end
    A = k;
    B = k + SAMPLES_PER_CHIP*1023-1;
    C = floor(j);
    signal(A:B) = signal(A:B).*modCode * data(C);
    j = j + s;
end


% Ensure Signal is ~ Full Scale
signal = signal * 2^15;

% Send Through Pluto Hardware at 920MHZ
fc = 920.1e6;

% Setup Pluto TX RX
tx = sdrtx('Pluto','Gain',-5.0, 'BasebandSampleRate', fs, 'CenterFrequency', fc);
rx = sdrrx('Pluto','SamplesPerFrame',floor(SAMPLES*2),'OutputDataType','double', ...
    'BasebandSampleRate', fs, 'CenterFrequency',fc, ...
    'GainSource', 'Manual', 'Gain', 30.0);

% Transmit the signal
transmitRepeat(tx, signal);
% Receive the signal
inputSignal = rx();
% Stop the Pluto TX RX
release(tx);
release(rx);

% Track our output signal and phase adjustments
DSP.Acquire2D(inputSignal, 500,true);
values = DSP.TestTrack(inputSignal);

figure;
plot(imag(values));
xlabel("Sequence");
ylabel("Bit Value");
grid on;
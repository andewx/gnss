classdef TestCFO < matlab.unittest.TestCase
    properties
        % Define properties for the test case
        DLL
        PRN
        CFO

    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            %Reference the parent directory
            SAMPLES_PER_CHIP = 2;
            testDir = fileparts(mfilename('fullpath'));
            parentDir = fullfile(testDir, '..');
            resourceFile = fullfile(testDir, '..', 'resource_files','gps.bb');
            addpath(parentDir);
            % Create an instance of the FLL class before ach
            testCase.PRN = CACodeGenerator(3);
            testCase.DLL = GPSCodeDLL(CACodeGenerator(3).generate().', 1.023e6*SAMPLES_PER_CHIP);
            testCase.CFO = comm.CarrierSynchronizer('SamplesPerSymbol',SAMPLES_PER_CHIP,...
            'Modulation','BPSK',...
            'DampingFactor',1.007,'NormalizedLoopBandwidth',0.001);
        end
    end

methods (Test)
        function testInitialization(testCase)
            % Test the initialization of the FLL object
            testCase.verifyNotEmpty(testCase.FLL);
            testCase.verifyNotEmpty(testCase.DLL);
        end
        
        function testPLL(testCase)
           % Test updating the output of the DLL
            SAMPLES_PER_CHIP = 2;
            INITIAL_CODE_DELAY = floor(1023 * randn());
            fs = 1.023e6*SAMPLES_PER_CHIP; % Sample rate
            carrier = 1.0e3; %1khz s Carrier
            TIME = 100;  % 100ms
            sampleTime = 0.001*TIME; % 100ms samples time
            t = (0:1/fs:sampleTime).'; % Time vector
            DATA_RATE = 10;

            % Create a test input signal (e.g., a sine wave)
            inputSignal = 1.0 * exp(-1j * 2 * pi * carrier * t);

            % Every 1ms/1023 chips modulate the input signal
            prnCode = CACodeGenerator(3).generate().';
            prnCode = circshift(prnCode, INITIAL_CODE_DELAY);
            %data = randi([0 1], TIME/DATA_RATE, 1); % Random data
            data = [0 0 1 1 0 0 1 1 0 0]; % Test data
            data = 2 .* data - 1; % Map the data to -1,1
            modCode = (2*prnCode - 1)*1j; % Map the code to -1,1 on the Q Branch
            modCode = testCase.DLL.ExpandCode(modCode,SAMPLES_PER_CHIP);
            modulatedSignal = zeros(length(inputSignal),1);

            for k = 1:SAMPLES_PER_CHIP*1023:length(inputSignal)
                if k+SAMPLES_PER_CHIP*1023-1 >= length(inputSignal)
                    break;
                end
                modPortion = inputSignal(k:k+1023*SAMPLES_PER_CHIP-1) .* modCode;
                modulatedSignal(k:k+1023*SAMPLES_PER_CHIP-1) = modPortion;
            end

            % Every 10ms apply a data modulation to the code
            j = 1;

            for i = 1:1023*SAMPLES_PER_CHIP*DATA_RATE:length(modulatedSignal)
                if i+1023*SAMPLES_PER_CHIP*DATA_RATE-1 > length(modulatedSignal)
                    break;
                end
                % Apply the data modulation to the code
                modulatedSignal(i:i+1023*SAMPLES_PER_CHIP*DATA_RATE-1) = modulatedSignal(i:i+1023*SAMPLES_PER_CHIP*DATA_RATE-1) * data(j);
                j = j + 1;  
            end

            % Pass Signal through AWGN Channel and Mix to ZeroIF
            modulatedSignal = awgn(modulatedSignal, 20);
            fc = carrier*0.5;
            modulatedSignal = modulatedSignal .* exp(1i*2*pi*fc*t);

            % Track our output signal and phase adjustments
            outputSignal = [];
            phases = [];
            FRAMESIZE = 1;

            testCase.DLL.Acquire(modulatedSignal);
            tic;
            nominal_freq = 1.0;
            carrier_freq = nominal_freq;
            carrier_phase = 0;
            two_pi = 2*pi;
            T = 0.001;

            baseband = zeros(length(modulatedSignal),1);
            corrections = [];

            for k = 1:FRAMESIZE*1023*testCase.DLL.samplesPerChip:length(modulatedSignal)
 
                % Process the samples update needs at least 2ms of samples
                A = k;
                B = k+FRAMESIZE*1023*testCase.DLL.samplesPerChip-1;

                if k+FRAMESIZE*1023*testCase.DLL.samplesPerChip-1 > length(modulatedSignal)
                   B = length(modulatedSignal)-1;
                end
                baseband(A:B) = testCase.CFO(modulatedSignal(A:B));   
                [signal, ~, prompt] = testCase.DLL.Update(baseband, A, B);
                outputSignal = [outputSignal; signal];
            end
            processTime = toc
            outputSignal = [outputSignal;0i];

            % Timescope for the outputSignal
            scope = timescope('SampleRate', testCase.DLL.sampleRate, 'TimeSpan', 0.1, 'TimeSpanSource', "property");
            scope(outputSignal);
            pause(3);


        end

    end
end
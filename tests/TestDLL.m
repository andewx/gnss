classdef TestDLL < matlab.unittest.TestCase
    properties
        % Define properties for the test case
        DLL
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            %Reference the parent directory
            testDir = fileparts(mfilename('fullpath'));
            parentDir = fullfile(testDir, '..');
            resourceFile = fullfile(testDir, '..', 'resource_files','gps.bb');
            addpath(parentDir);
            % Create an instance of the DLL class before each test
            testCase.DLL = GPSCodeDLL(CACodeGenerator(3).generate().', 2.046e6, 2); % PRN code 3, sample rate 4.092 MHz, samples per chip 4
        end
    end
    
    methods (Test)
        function testInitialization(testCase)
            % Test the initialization of the DLL object
            testCase.verifyNotEmpty(testCase.DLL);

        end
        
        
        function testUpdateOutput(testCase)
            % Test updating the output of the DLL
            fs = 2.046e6; % Sample rate
            carrier = 1.0e3; %1khz s Carrier
            TIME = 100;  % 100ms
            sampleTime = 0.001*TIME; % 100ms samples time
            t = (0:1/fs:sampleTime).'; % Time vector
            DATA_RATE = 10;
            SAMPLES_PER_CHIP = 2;
            % Create a test input signal (e.g., a sine wave)
            inputSignal = cos(2*pi*carrier*t); % 10MhZ sine wave

            % Every 1ms/1023 chips modulate the input signal
            prnCode = CACodeGenerator(3).generate().';
            %data = randi([0 1], TIME/DATA_RATE, 1); % Random data
            data = [0 0 1 1 0 0 1 1 0 0]; % Test data
            data = 2 .* data - 1; % Map the data to -1,1
            modCode = 2*prnCode - 1; % Map the code to -1,1
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

            % AWGN
            modulatedSignal = awgn(modulatedSignal, 20);
            % Shift 1khz signal to DC
            modulatedSignal = modulatedSignal .* exp(1i*2*pi*carrier*t);
            outputSignal = [];
            phases = [];
            % Test the DLL Despreading on the Code stepping through the
            % samples using 2ms steps in 100ms frame (20 iterations)
            % framesize is 2ms minimum to handle any delays
            FRAMESIZE = 2;
            tic;
            for k = 1:FRAMESIZE*1023*testCase.DLL.samplesPerChip:length(modulatedSignal)

                k = k + floor(testCase.DLL.GetDelay());
                if k+FRAMESIZE*1023*testCase.DLL.samplesPerChip-1 > length(modulatedSignal)
                    break;
                end
                % Process the samples update needs at least 2ms of samples
                A = k;
                B = k+FRAMESIZE*1023*testCase.DLL.samplesPerChip-1;
                [signal, phase] = testCase.DLL.Update(modulatedSignal, A, B);
                phases = [phases; phase];
                outputSignal = [outputSignal; signal];
            end
            processTime = toc

            finalSignal = lowpass(outputSignal, 500, fs);

            % Timescope for the outputSignal
            scope = timescope('SampleRate', testCase.DLL.sampleRate, 'TimeSpan', 0.1, 'TimeSpanSource', "property");
            scope(finalSignal);
            pause(10);

            % Spectrum Analyzer
            sa = spectrumAnalyzer('SampleRate', testCase.DLL.sampleRate, 'PlotAsTwoSidedSpectrum', true, 'YLimits', [-100 0]);
            sa(finalSignal);
            pause(10);

            figure;
            plot(phases);
            title('Phase Tracking');
            xlabel('Chunk #');
            ylabel('Phase');
            grid on;


        end
    end
end
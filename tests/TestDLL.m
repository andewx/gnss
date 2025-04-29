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
            testCase.DLL = GPSCodeDLL(CACodeGenerator(3).generate().', 4.092e6, 4); % PRN code 3, sample rate 4.092 MHz, samples per chip 4
        end
    end
    
    methods (Test)
        function testInitialization(testCase)
            % Test the initialization of the DLL object
            testCase.verifyNotEmpty(testCase.DLL);

        end
        
        
        function testUpdateOutput(testCase)
            % Test updating the output of the DLL
            fs = 4.092e6; % Sample rate
            sampleTime = 0.001*20; % 20ms samples time
            t = (0:1/fs:sampleTime).'; % Time vector
            % Create a test input signal (e.g., a sine wave)
            inputSignal = sin(2*pi*1000*t); % 1kHz sine wave

            % Every 1ms/1023 chips modulate the input signal
            prnCode = CACodeGenerator(3).generate().';
            data = rand(1,20);
            data = 2 * data - 1; % Map the data to -1,1
            modCode = 2*prnCode - 1; % Map the code to -1,1
            modCode = testCase.DLL.ExpandCode(modCode,4);
            modulatedSignal = zeros(length(inputSignal),1);

            for k = 1:4*1023:length(inputSignal)
                if k+4*1023-1 >= length(inputSignal)
                    break;
                end
                modulatedSignal(k:k+1023*4-1) = inputSignal(k:k+1023*4-1) .* modCode;
            end

            % Every 1ms apply a data modulation to the code
            j = 1;
            for i = 1:1023*4:length(modulatedSignal)
                if i+1023-1 > length(modulatedSignal)
                    break;
                end
                % Apply the data modulation to the code
                modulatedSignal(i:i+1023*4-1) = modulatedSignal(i:i+1023*4-1) * data(j);
                j = j + 1;
            end
            % Shift 1khz signal to DC
            modulatedSignal = modulatedSignal .* exp(1i*2*pi*1000*t);
            outputSignal = [];
            indexes = [];
            phases = [];
            % Test the DLL Despreading on the Code stepping through the samples
            for k = 1:2*4*1023*testCase.DLL.samplesPerChip:length(modulatedSignal)
                if k+2*4*1023*testCase.DLL.samplesPerChip-1 > length(modulatedSignal)
                    break;
                end
                % Process the samples
                [signal, index, phase] = testCase.DLL.Update(modulatedSignal(k:k+2*1023*testCase.DLL.samplesPerChip-1))
                indexes = [indexes; index]; % Still need to try and delay the signal by the prompt correlator output
                phases = [phases; phase];
                outputSignal = [outputSignal; signal];
            end

            % Plot the output signal
            figure;
            plot(real(outputSignal));
            title('Output Signal');
            xlabel('Sample Index');
            ylabel('Amplitude');
            grid on;

            %Plot the DLL indexes for delay
            figure;
            plot(indexes);
            title('Output Delay Indexes');
            xlabel('Chunk #');
            ylabel('Index');
            grid on;

            %Plot the DLL Code Phase compuation
            figure;
            plot(phases);
            title("DLL Sample Phases");
            title('Output Phases');
            ylabel('Phase');
            grid on;
            

        end
    end
end
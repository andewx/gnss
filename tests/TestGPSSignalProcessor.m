classdef TestGPSSignalProcessor < matlab.unittest.TestCase
    properties
        % Define properties for the test case
        DSP
        GPS
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            %Reference the parent directory
            testDir = fileparts(mfilename('fullpath'));
            parentDir = fullfile(testDir, '..');
            resourceFile = fullfile(testDir, '..', 'resource_files','gps.bb');
            addpath(parentDir);
            % Create an instance of the GPSSignalProcessor class before each test
            testCase.DSP = GPSSignalProcessor(3, 4,4.092e6);
            testCase.GPS = comm.BasebandFileReader(resourceFile, "SamplesPerFrame",Inf);
        end
    end
    
    methods (Test)
        function testInitialization(testCase)
            % Test the initialization of the GPSSignalProcessor object
            testCase.verifyNotEmpty(testCase.DSP);
            testCase.verifyEqual(testCase.DSP.sampleRate, 4.092e6);
            testCase.verifyEqual(testCase.DSP.samplesPerChip, 4);
        end
        
    
        function testProcessFrame(testCase)
            % Test processing a GPS signal with the GPSSignalProcessor
            samplesPerFrame = 1023 * testCase.DSP.samplesPerChip* 100;
            samples = testCase.GPS();
            values = [];
            for n = 1:samplesPerFrame:length(samples)
                if n+samplesPerFrame-1 > length(samples)
                    break;
                end
                % Process the samples
                [values] = testCase.DSP.ProcessFrame(samples(n:n+samplesPerFrame-1));
            end

            % Value is integrated over 1ms display values
            domain = linspace(1,length(values),length(values));
            figure;
            plot(domain, values);
            title('GPS Signal Processing');
            xlabel('ms');
            ylabel('Signal Value');
            grid on;
        end

        function testDespreadingFrame(testCase)
            % Test processing a GPS signal with the GPSSignalProcessor
            samplesPerFrame = 1023 * testCase.DSP.samplesPerChip* 100;
            samples = testCase.GPS();
            values = [];
            for n = 1:samplesPerFrame:length(samples)
                if n+samplesPerFrame-1 > length(samples)
                    break;
                end
                % Process the samples
                [values] = testCase.DSP.TestProcessFrame(samples(n:n+samplesPerFrame-1));
            end

            % Value is integrated over 1ms display values
            domain = linspace(1,length(values),length(values));
            figure;
            plot(domain, values);
            title('GPS Signal Processing');
            xlabel('ms');
            ylabel('Signal Value');
            grid on;
        end


        function testBenchmarkThroughput(testCase)
            % Test processing a GPS signal with the GPSSignalProcessor
            samplesPerFrame = 1023 * testCase.DSP.samplesPerChip* 100;
            avgTime = 0;
            timeIndex = 1;
            samples = testCase.GPS();
            values = [];
            for n = 1:samplesPerFrame:length(samples)
                if n+samplesPerFrame-1 > length(samples)
                    break;
                end
                % Process the samples
                tic;
                [values] = testCase.DSP.ProcessFrame(samples(n:n+samplesPerFrame-1));
                avgTime = avgTime + toc;
                timeIndex = timeIndex + 1;
            end
            % Calculate the average time taken for processing
            avgTime = avgTime / timeIndex;
            % Verify that the average time is within acceptable limits
            testCase.verifyLessThan(avgTime, 0.1); % Adjust the threshold as needed 100ms
        end


    end
end
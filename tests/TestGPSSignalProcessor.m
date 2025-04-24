classdef TestGPSSignalProcessor < matlab.unittest.TestCase
    properties
        % Define properties for the test case
        GPSSignalProcessor
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            %Reference the parent directory
            testDir = fileparts(mfilename('fullpath'));
            parentDir = fullfile(testDir, '..');
            resourceFile = fullfile(testDir, '..', 'resource_files','gpsWaveform.bb');
            addpath(parentDir);
            % Create an instance of the GPSSignalProcessor class before each test
            testCase.GPSSignalProcessor = GPSSignalProcessor();
        end
    end
    
    methods (Test)
        function testInitialization(testCase)
            % Test the initialization of the GPSSignalProcessor object
            testCase.verifyNotEmpty(testCase.GPSSignalProcessor);
            testCase.verifyEqual(testCase.GPSSignalProcessor.sampleRate, 0);
            testCase.verifyEqual(testCase.GPSSignalProcessor.samplesPerChip, 0);
        end
        
        function testSetSampleRate(testCase)
            % Test setting the sample rate of the GPSSignalProcessor
            newSampleRate = 1000;
            testCase.GPSSignalProcessor.setSampleRate(newSampleRate);
            testCase.verifyEqual(testCase.GPSSignalProcessor.sampleRate, newSampleRate);
        end
        
        function testSetSamplesPerChip(testCase)
            % Test setting the samples per chip of the GPSSignalProcessor
            newSamplesPerChip = 10;
            testCase.GPSSignalProcessor.setSamplesPerChip(newSamplesPerChip);
            testCase.verifyEqual(testCase.GPSSignalProcessor.samplesPerChip, newSamplesPerChip);
        end
        
        function testProcessSignal(testCase)
            % Test processing a GPS signal with the GPSSignalProcessor
            inputSignal = randn(1, 100); % Example input signal
            outputSignal = testCase.GPSSignalProcessor.processSignal(inputSignal);
            
            % Verify that the output signal is not empty and has the same size as input signal
            testCase.verifyNotEmpty(outputSignal);
            testCase.verifySize(outputSignal, size(inputSignal));
        end


        function testBenchmarkThroughput(testCase)
            % Test the throughput of the GPSSignalProcessor
            inputSignal = randn(1, 1000); % Example input signal
            tic;
            testCase.GPSSignalProcessor.processSignal(inputSignal);
            elapsedTime = toc;
            
            % Verify that the elapsed time is within acceptable limits
            testCase.verifyLessThan(elapsedTime, 1); % Adjust the threshold as needed
        end
        function testBenchmarkMemoryUsage(testCase)
            % Test the memory usage of the GPSSignalProcessor
            inputSignal = randn(1, 1000); % Example input signal
            initialMemory = memory();
            testCase.GPSSignalProcessor.processSignal(inputSignal);
            finalMemory = memory();
            
            % Verify that the memory usage is within acceptable limits
            memoryUsage = finalMemory.MemUsedMATLAB - initialMemory.MemUsedMATLAB;
            testCase.verifyLessThan(memoryUsage, 1000000); % Adjust the threshold as needed
        end
    end
end
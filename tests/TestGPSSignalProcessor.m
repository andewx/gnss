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
            % Create an instance of the GPSSignalProcessor class before-0.1030e3 + each test
            testCase.DSP = GPSSignalProcessor(1, 2,2.046e6, -2.6721e3);
            testCase.GPS = comm.BasebandFileReader(resourceFile, "SamplesPerFrame",Inf);
        end
    end
    
    methods (Test)
        function testInitialization(testCase)
            % Test the initialization of the GPSSignalProcessor object
            testCase.verifyNotEmpty(testCase.DSP);
            testCase.verifyEqual(testCase.DSP.sampleRate, 2.046e6);
            testCase.verifyEqual(testCase.DSP.samplesPerChip, 2);
        end
        
    
        function testProcessFrame(testCase)
            % Test processing a GPS signal with the GPSSignalProcessor in
            % 100ms frames (5 bits) - Samples at 600ms total (30 bits)

            subframe = testCase.GPS();
            B = (1023*testCase.DSP.samplesPerChip*300)+1;
            subframe = (subframe(1:B));

            % Acquisition Search Method First
            [freq, delay] = testCase.DSP.Acquire2D(testCase.DSP.ApplyFrequencyCorrection(subframe));
            testCase.DSP.frequencyCorrection = testCase.DSP.frequencyCorrection + freq;

            % Left Shift/Right Shift Samples by the delay
            subframe = testCase.DSP.ShiftSamples(subframe, delay);
            
            values = [];
            tic
            [values] = testCase.DSP.ProcessSubFrame(subframe);
            timeElapsed = toc;
            testCase.verifyLessThan(timeElapsed, 0.6);

            figure;
            plot(values);
          
        end

        function testVisualization(testCase)
             % Test processing a GPS signal with the GPSSignalProcessor in
            % 100ms frames (5 bits) - Samples at 500ms total (25 bits) - Q
            % Component Data
            subframe = testCase.GPS();
            B = (1023*testCase.DSP.samplesPerChip*300)+1;
            subframe = (subframe(1:B));

            % Acquisition Search Method First
            [freq, delay] = testCase.DSP.Acquire2D(testCase.DSP.ApplyFrequencyCorrection(subframe));
            testCase.DSP.frequencyCorrection = testCase.DSP.frequencyCorrection + freq;

            % Left Shift/Right Shift Samples by the delay
            subframe = testCase.DSP.ShiftSamples(subframe, delay);

            values = [];
            tic
            [values] = testCase.DSP.TestProcessSubFrame(subframe);
            timeElapsed = toc;
            testCase.verifyLessThan(timeElapsed, 0.25);

            figure;
            plot(values);
        end
    end
end
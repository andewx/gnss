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
            resourceFile = fullfile(testDir, '..', 'resource_files','gpsWaveform.bb');
            addpath(parentDir);
            % Create an instance of the DLL class before each test
            testCase.DLL = DLL();
        end
    end
    
    methods (Test)
        function testInitialization(testCase)
            % Test the initialization of the DLL object
            testCase.verifyNotEmpty(testCase.DLL);
            testCase.verifyEqual(testCase.DLL.frequency, 0);
            testCase.verifyEqual(testCase.DLL.phase, 0);
        end
        
        function testSetFrequency(testCase)
            % Test setting the frequency of the DLL
            newFrequency = 1000;
            testCase.DLL.setFrequency(newFrequency);
            testCase.verifyEqual(testCase.DLL.frequency, newFrequency);
        end
        
        function testSetPhase(testCase)
            % Test setting the phase of the DLL
            newPhase = pi/4;
            testCase.DLL.setPhase(newPhase);
            testCase.verifyEqual(testCase.DLL.phase, newPhase);
        end
        
        function testUpdateOutput(testCase)
            % Test updating the output of the DLL
            inputSignal = sin(2 * pi * (0:0.01:1));
            outputSignal = testCase.DLL.updateOutput(inputSignal);
            
            % Verify that the output signal is not empty and has the same size as input signal
            testCase.verifyNotEmpty(outputSignal);
            testCase.verifySize(outputSignal, size(inputSignal));
        end
    end
end
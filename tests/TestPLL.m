classdef TestPLL < matlab.unittest.TestCase
    properties
        % Define properties for the test case
        PLL
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            % Create an instance of the PLL class before each test
            testCase.PLL = PLL();
        end
    end
    
    methods (Test)
        function testInitialization(testCase)
            % Test the initialization of the PLL object
            testCase.verifyNotEmpty(testCase.PLL);
            testCase.verifyEqual(testCase.PLL.frequency, 0);
            testCase.verifyEqual(testCase.PLL.phase, 0);
        end
        
        function testSetFrequency(testCase)
            % Test setting the frequency of the PLL
            newFrequency = 1000;
            testCase.PLL.setFrequency(newFrequency);
            testCase.verifyEqual(testCase.PLL.frequency, newFrequency);
        end
        
        function testSetPhase(testCase)
            % Test setting the phase of the PLL
            newPhase = pi/4;
            testCase.PLL.setPhase(newPhase);
            testCase.verifyEqual(testCase.PLL.phase, newPhase);
        end
        
        function testUpdateOutput(testCase)
            % Test updating the output of the PLL
            inputSignal = sin(2 * pi * (0:0.01:1));
            outputSignal = testCase.PLL.updateOutput(inputSignal);
            
            % Verify that the output signal is not empty and has the same size as input signal
            testCase.verifyNotEmpty(outputSignal);
            testCase.verifySize(outputSignal, size(inputSignal));
        end
    end
end
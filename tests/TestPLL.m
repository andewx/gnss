classdef TestPLL < matlab.unittest.TestCase
    properties
        % Define properties for the test case
        PLL
        GPS
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            %Reference the parent directory
            testDir = fileparts(mfilename('fullpath'));
            parentDir = fullfile(testDir, '..');
            resourceFile = fullfile(testDir, '..', 'resource_files','gps.bb');
            addpath(parentDir);
            % Create an instance of the PLL class before each test
            testCase.PLL = GPSCodePLL(0.1, 0.707, 1, 40920000, 0, 1023*4);
            testCase.GPS = comm.BasebandFileReader(resourceFile, "SamplesPerFrame",1023*4);
        end 
    end
    
    methods (Test)
        function testInitialization(testCase)
            % Test the initialization of the PLL object
            testCase.verifyNotEmpty(testCase.PLL);
            testCase.verifyEqual(testCase.PLL.f0, 0);
            testCase.verifyEqual(testCase.PLL.phi, 0);
            testCase.verifyEqual(testCase.GPS.SampleRate, 4.092e6);
            testCase.verifyEqual(testCase.GPS.CenterFrequency, 0);
        end
        
       function testPLLCompute(testCase)
            samples = testCase.GPS();
            tic
            samplesOutput = testCase.PLL.Compute(0,samples(1:testCase.PLL.N));
            toc
            testCase.verifyNotEmpty(samplesOutput);
            testCase.verifySize(samplesOutput, [testCase.PLL.N,1]);
            testCase.verifyGreaterThan(abs(testCase.PLL.phi), 0);
            testCase.verifyGreaterThan(abs(testCase.PLL.f0),0);
       end


       function testPLLVisualize(testCase)

            samples = testCase.GPS();
            [~,~,out] = testCase.PLL.ComputeAndVisualize(0,samples(1:testCase.PLL.N));
            testCase.verifyNotEmpty(out);
            testCase.verifySize(out, [testCase.PLL.N,1]);
            testCase.verifyGreaterThan(abs(testCase.PLL.phi), 0);
            testCase.verifyGreaterThan(abs(testCase.PLL.f0),0);
       end


    end
end
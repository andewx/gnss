classdef TestFLL < matlab.unittest.TestCase
    properties
        % Define properties for the test case
        FLL
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            %Reference the parent directory
            testDir = fileparts(mfilename('fullpath'));
            parentDir = fullfile(testDir, '..');
            resourceFile = fullfile(testDir, '..', 'resource_files','gpsWaveform.bb');
            addpath(parentDir);
            % Create an instance of the FLL class before each
        end
    end
end
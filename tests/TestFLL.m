classdef TestFLL < matlab.unittest.TestCase
    properties
        % Define properties for the test case
        FLL
        GPS
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            %Reference the parent directory
            testDir = fileparts(mfilename('fullpath'));
            parentDir = fullfile(testDir, '..');
            resourceFile = fullfile(testDir, '..', 'resource_files','gps.bb');
            addpath(parentDir);
            % Create an instance of the FLL class before each
            testCase.FLL = GPSCodeFLL(4, 40920000);
            testCase.GPS = comm.BasebandFileReader(resourceFile, "SamplesPerFrame",Inf);
        end
    end

methods (Test)
        function testInitialization(testCase)
            % Test the initialization of the FLL object
            testCase.verifyNotEmpty(testCase.FLL);
            testCase.verifyEqual(testCase.FLL.sampleRate, 40920000);
            testCase.verifyEqual(testCase.FLL.samplesPerChip, 4);
            testCase.verifyEqual(testCase.FLL.M, 2);
        end
        
        function testFLLCompute(testCase)
            samplesPerFrame = 1024;
            samples = testCase.GPS();
            freqs = [];
            phases = [];
            for n = 1:samplesPerFrame:length(samples)
                if n+samplesPerFrame-1 > length(samples)
                    break;
                end
                [samplesOutput, freq, phase] = testCase.FLL.Compute(samples(n:n+samplesPerFrame-1));
                freqs = [freqs; freq];
                phases = [phases; phase];
            end
            testCase.verifyNotEmpty(samplesOutput);
            testCase.verifySize(samplesOutput, [1024,1]);
            %
            meanFreq = mean(freqs);
            meanPhase = mean(phases);
            mFreqs = zeros(length(freqs),1);
            mPhase = zeros(length(freqs),1);

            for n = 1:length(freqs)
                mFreqs(n) = meanFreq;
                mPhase(n) = meanPhase;
            end

            %Plot the frequency and phase estimates
            x = linspace(1,length(freqs),length(freqs));
            figure;
            subplot(2,1,1);
            plot(x,freqs); hold on;
            plot(x,mFreqs);hold off;
            title('Frequency Offset');
            xlabel('Sample Index');
            ylabel('Frequency Offset (Hz)');
            grid on;
            subplot(2,1,2);
            plot(x,phases); hold on;
            plot(x,mPhase); hold off;
            title('Phase Offset');
            xlabel('Sample Index');
            ylabel('Phase Offset (radians)');
            grid on;
        end

    end
end
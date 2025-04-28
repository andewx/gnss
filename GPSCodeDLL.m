classdef GPSCodeDLL < handle
    properties
        sampleRate
        codeRate
        codeLength
        codePhase
        code
        correlationBuffer
        correlationIndexes
        interpolator
        loopFilter
        interpolationController
        prnCode
        mappedCode
        interpolatedCode
        reversedInterpolatedCode
        samplesPerChip

    end

    methods
        % DLL Code Phase Tracking Estimates the code phase as a fractional delay into the correlation index
        function obj = GPSCodeDLL(code, sampleRate, samplesPerChip)
            % Constructor for the GPSCodeDLL class
            obj.sampleRate = sampleRate; % Sample rate
            obj.codeRate = 1.023e6; % Code rate in Hz
            obj.codeLength = 1023; % Length of the C/A code
            obj.codePhase = 0; % Initial code phase
            obj.prnCode = code; % PRN code
            obj.samplesPerChip = samplesPerChip; % Number of samples per chip
            obj.interpolator = GPSInterpolator('PPF'); % Interpolator object
            obj.loopFilter = GPSLoopFilter(1.0, 0.707, 1, sampleRate); % Loop filter object
            obj.interpolatedCode = resample(obj.prnCode.PRN, samplesPerChip, 1); % Interpolated PRN code
            obj.reversedInterpolatedCode = fliplr(obj.interpolatedCode); % Interpolated PRN code
            obj.mappedCode = 2 .* obj.prnCode.PRN - 1; % Map the code to -1,1
            obj.correlationIndexes = zeros(3, 1); % Correlation indexes
        end


        function [interpolatedSamples] = Interpolate(obj, samples, codePhase)
            % Interpolate the samples using the code phase
            fractionalDelay = mod(codePhase, 1);
            obj.interpolator.UpdateMu(fractionalDelay);
            obj.interpolator.UpdateTaps(fractionalDelay);
            interpolatedSamples = obj.interpolator.GetSamples(samples);
        end


        % Autocorrelation function assumes that the we are sampling a
        % single 1023 bit chip at a time with 1023 samples per chip
        % The early, prompt, and late signals are -0.5, 0.0, and 0.5
        % chips respectively. values is a [3 x 1] vector of the early, prompt, and late signals
        % indexes is a [3 x 1] vector of the indexes of the early, prompt, and late signals
        function [values] = AutoCorr(obj,samples)
            % Initialize the early, prompt, and late signals

            values = zeros(3, 1);
            % Calculate autocorrelation with reverse filter
            obj.correlationBuffer = filter(obj.reversedInterpolatedCode, 1, real(samples));
            absCorrelation = abs(obj.correlationBuffer);
            idx = find(obj.correlationBuffer == max(absCorrelation), 1);
            promptIndex = length(obj.interpolatedCode) + idx - 1;
            prompt = obj.correlationBuffer(promptIndex);
            earlyIndex = floor(promptIndex - obj.samplesPerChip/2);
            early = obj.correlationBuffer(earlyIndex);
            lateIndex = floor(promptIndex + obj.samplesPerChip/2);
            late = obj.correlationBuffer(lateIndex);
            % Store the values and indexes
            values(1) = early;
            values(2) = prompt;
            values(3) = late;
            obj.correlationIndexes(1) = earlyIndex;
            obj.correlationIndexes(2) = promptIndex;
            obj.correlationIndexes(3) = lateIndex;

            
       end

        % Update provides the DLL routine by computing the autocorrelation
        % of the incoming samples and updating the code phase
        % updating the prn code rotation and then interpolating the samples according
        % to the code phase delay and finally despreading the incoming signal, the value
        % output is the integration of the despread signal
        function [samples] = Update(obj, samples)
            % Update the DLL with the early and late signal
            % Calculate the error signal
            [values] = obj.AutoCorr(samples);
            early = values(1);
            late = values(3);

            errorSignal = sqrt(early - late) / sqrt(early + late);
            
            % Calculate the loop filter output
            loopFilterOutput = obj.loopFilter.Filter(errorSignal);
            
            % Update the code phase
            obj.codePhase = obj.codePhase + loopFilterOutput;
            
            % Wrap the code phase to the range [0, 1023]
            if obj.codePhase > obj.codeLength
                obj.codePhase = obj.codePhase - obj.codeLength;
            elseif obj.codePhase < 0
                obj.codePhase = obj.codePhase + obj.codeLength;
            end
            
            % Interpolate the samples according to the code phase delay
            obj.interpolator.UpdateMu(obj.codePhase);
            samples = obj.interpolator.GetSamples(samples);
            % Despread the samples
            samples = obj.Despread(samples);
            
        end

        function [output] = Despread(obj, samples)
            % Despread the samples by applying the PRN Code which is tracked in the DLL
            % The code is a 1023 bit code, so we need to map it to -1,1
            % We need to mix the PRN code and integrate the signal summation over the period to despread the signal
            output = (obj.mappedCode .* samples);
        end

        function [output] = GetCodePhase(obj)
            % Get the code phase
            output = obj.codePhase;
        end

        function [output] = GetCodePhaseIndex(obj)
            % Get the code phase index
            output = obj.correlationIndexes(2);
        end
    end 
end
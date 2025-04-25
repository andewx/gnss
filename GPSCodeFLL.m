% GPSCodeFLL - For frequency adjustment of the GPS signal we want to save compute time
% therefore, we imiplement a direct frequency offset calculation and apply directly to the samples
% ostensibly in hardware the FLL would be an actual locked loop. For our software implementation we
% forgo the loop and just compute the frequency offset for a simplified FLL
classdef GPSCodeFLL < handle
    properties
        sampleRate
        samplesPerChip
        M
        phaseVector
        normalizedOffset
        windowFunc
        frequencyOffset
        phaseOffset
        loopFilterFreq
        loopFilterPhase
        code
    end

    methods
        % FLL Code Phase Tracking Estimates the code phase as a fractional delay into the correlation index
        function obj = GPSCodeFLL(samplesPerChip, sampleRate, prnCode, initialFrequencyOffset)
            % Constructor for the GPSCodeFLL class
            obj.sampleRate = sampleRate; % Sample rate
            obj.samplesPerChip = samplesPerChip; % Number of samples per chip
            obj.M = 2; % Modulation order
            obj.phaseVector = (1:(1024)).';
            obj.normalizedOffset = 1i.*2*pi/sampleRate;
            obj.windowFunc = blackmanharris(1024); %1024
            obj.frequencyOffset = initialFrequencyOffset; % Initialize frequency offset
            obj.phaseOffset = 0; % Initialize phase offset
            obj.code = prnCode; % PRN code
            obj.loopFilterFreq = GPSLoopFilter(0.001, 1.207, 1.0, sampleRate); % Loop filter object
            obj.loopFilterPhase = GPSLoopFilter(0.001, 1.3, 1.0, sampleRate); % Loop filter object

        end

        function [output, frequencyOffset, phaseOffset] = Compute(obj, samples)
             % Compute the updated samples
            if length(samples) < 1024
                return
            end

            samples = GPSCarrierWipe(samples, obj.sampleRate, obj.frequencyOffset, obj.phaseOffset, false, obj.samplesPerChip, 0, obj.code, true);   
            updateSamples = samples(1:1024);%.*obj.windowFunc;
            % Apply current frequency offset to the samples
            fftdata = fft(updateSamples.^2,1024);
            [~, maxIndex] = max(abs(fftdata));
            % Compute the frequency offset
            frequencyOffset = (maxIndex - 1) * (obj.sampleRate / (4*1024));
            % Compute the phase offset
            phaseOffset = angle(fftdata(maxIndex));

            obj.frequencyOffset = obj.loopFilterFreq.Filter(frequencyOffset);
            obj.phaseOffset = obj.loopFilterPhase.Filter(phaseOffset);

            frequencyOffset = obj.frequencyOffset;
            phaseOffset = obj.phaseOffset;

            samplesPerRadian = (2*pi)/obj.sampleRate;

            % Compute the updated samples
            output = samples .* exp(-1i * obj.normalizedOffset* (obj.frequencyOffset + obj.phaseOffset));            

        end

        
    end
end
classdef GPSCodeFLL < handle
    properties
        sampleRate
        samplesPerChip
        M
        phaseVector
        normalizedOffset
    end

    methods
        % FLL Code Phase Tracking Estimates the code phase as a fractional delay into the correlation index
        function obj = GPSCodeFLL(samplesPerChip, sampleRate)
            % Constructor for the GPSCodeFLL class
            obj.sampleRate = sampleRate; % Sample rate
            obj.samplesPerChip = samplesPerChip; % Number of samples per chip
            obj.M = 2; % Modulation order
            obj.phaseVector = (1:(samplesPerChip*1023)).';
            obj.normalizedOffset = 1i.*2*pi/sampleRate;
        end

        function [updatedSamples] = Compute(obj, samples)
            % For FLL we used CFC to compute the frequency FFT Peak from the modulation order
            % segement and use the max index to compute the frequency offset
            fftdata = fft(samples^2,1024);
            [~, maxIndex] = max(abs(fftdata));
            % Compute the frequency offset
            frequencyOffset = (maxIndex - 1) * (obj.sampleRate / (4*1024));
            % Compute the phase offset
            phaseOffset = angle(fftdata(maxIndex));
            % Compute the updated samples
            updatedSamples = samples .* exp(-1i * (obj.normalizedOffset * frequencyOffset + phaseOffset));            

        end
    end
end
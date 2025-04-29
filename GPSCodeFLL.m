% GPSCodeFLL - For frequency adjustment of the GPS signal we want to save compute time
% therefore, we imiplement a direct frequency offset calculation and apply directly to the samples
% ostensibly in hardware the FLL would be an actual locked loop. For our software implementation we
% forgo the loop and just compute the frequency offset for a simplified FLL
classdef GPSCodeFLL < handle
    properties
        sampleRate
        samplesPerChip
        M
        normalizedOffset
        windowFunc
        frequencyOffset
        phaseOffset
        loopFilterFreq
        loopFilterPhase
    end

    methods
        % FLL Code Phase Tracking Estimates the code phase as a fractional delay into the correlation index
        function obj = GPSCodeFLL(samplesPerChip, sampleRate, initialFrequencyOffset)
            % Constructor for the GPSCodeFLL class
            obj.sampleRate = sampleRate; % Sample rate
            obj.samplesPerChip = samplesPerChip; % Number of samples per chip
            obj.M = 2; % Modulation order
            obj.normalizedOffset = 1i.*2*pi/sampleRate;
            obj.windowFunc = blackmanharris(1024); %1024
            obj.frequencyOffset = initialFrequencyOffset; % Initialize frequency offset
            obj.loopFilterFreq = GPSLoopFilter(0.001, 1.207, 1.0, sampleRate); % Loop filter object
            obj.loopFilterPhase = GPSLoopFilter(0.001, 1.3, 1.0, sampleRate); % Loop filter object
        end


        function obj = Reset(obj)
            % Reset the FLL object
            obj.frequencyOffset = 0;
            obj.loopFilterFreq = GPSLoopFilter(0.001, 1.207, 1.0, obj.sampleRate); % Loop filter object
            obj.loopFilterPhase = GPSLoopFilter(0.001, 1.3, 1.0, obj.sampleRate); % Loop filter object
        end

    function [output] = Compute(obj, samples)
             % Compute the updated samples
            if length(samples) < 1024
                return
            end

            % Apply the frequency offset to the samples
            t = ((0:length(samples)-1) / obj.sampleRate).';

            updateSamples = samples(1:1024);%.*obj.windowFunc;
            % Apply current frequency offset to the samples
            fftdata = fft(updateSamples.^2,1024);
            [~, maxIndex] = max(abs(fftdata));
            % Compute the frequency offset
            fo = (maxIndex - 1) * (obj.sampleRate / (4*1024));
            obj.frequencyOffset = obj.loopFilterFreq.Filter(fo);

            % Compute the updated samples
            expTerm = exp(-1i * (obj.normalizedOffset * t * obj.frequencyOffset));
            output = samples .* expTerm;            

        end

        % Apply the current frequency and phase offsets to the samples
        function [samples] = Apply(obj, samples)
            % Apply the frequency offset to the samples to entire data set
            % If we need sample phase continuity we should use phase perfect sampling amounts
            t = ((0:length(samples)-1) / obj.sampleRate).';
            expTerm = exp(-1i * (obj.normalizedOffset * obj.frequencyOffset*t));
            samples = samples .* expTerm;
        end

        
    end
end
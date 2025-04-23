classdef GPSCodeDLL < handle
    properties
        sampleRate
        codeRate
        codeLength
        codePhase
        interpolator
        loopFilter
        interpolationController
    end

    methods
        % DLL Code Phase Tracking Estimates the code phase as a fractional delay into the correlation index
        function obj = GPSCodeDLL(loopBandwidth, dampingFactor, loopGain, interpolationFactor, sampleRate)
            % Constructor for the GPSCodeDLL class
            obj.sampleRate = sampleRate; % Sample rate
            obj.codeRate = 1.023e6; % Code rate in Hz
            obj.codeLength = 1023; % Length of the C/A code
            obj.codePhase = 0; % Initial code phase
            obj.interpolator = GPSInterpolator('PPF'); % Interpolator object
            obj.loopFilter = GPSLoopFilter(loopBandwidth, dampingFactor, loopGain, sampleRate); % Loop filter object
            obj.interpolationController = InterpolationController(); % Interpolation controller object
        end


        function [interpolatedSamples] = Interpolate(obj, mu, samples, codePhase)
            % Interpolate the samples using the code phase
            fractionalDelay = mod(codePhase, 1);
            obj.interpolator.UpdateMu(fractionalDelay);
            interpolatedSamples = obj.interpolator.GetSamples(samples)
        end

        function [codePhase] = Update(obj, earlyLateValues)
            % Update the DLL with the early and late signal
            % Calculate the error signal
            early = earlyLateValues(1);
            late = earlyLateValues(3);

            errorSignal = (early - late) / (early + late);
            
            % Calculate the loop filter output
            loopFilterOutput = obj.loopFilter.Filter(errorSignal);
            
            % Update the code phase and code rate
            obj.codePhase = obj.codePhase + loopFilterOutput;
            
            % Wrap the code phase to the range [0, 1023]
            if obj.codePhase > obj.codeLength
                obj.codePhase = obj.codePhase - obj.codeLength;
            elseif obj.codePhase < 0
                obj.codePhase = obj.codePhase + obj.codeLength;
            end
            
            % Return the updated code phase and code rate
            codePhase = obj.codePhase;
        end
    end 
end
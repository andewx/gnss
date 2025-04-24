classdef GPSLoopFilter < handle
    properties
        loopBandwidth
        dampingFactor
        loopGain
        biquadFilter
        theta
        delta
        sps
        g1
        g2
        prevErr
        prevOut
    end 

    methods
        function obj = GPSLoopFilter(loopBandwidth, dampingFactor, loopGain, sampleRate)
            % Constructor for the GPSLoopFilter class
            M=4;
            obj.loopBandwidth = loopBandwidth; % Loop bandwidth in Hz
            obj.dampingFactor = dampingFactor; % Damping factor
            obj.loopGain = loopGain; % Loop gain
            obj.biquadFilter = dsp.SOSFilter([1 0 0], [-1 0 1]); % Biquad filter
            obj.theta = obj.loopBandwidth /(M*(obj.dampingFactor + 0.25/obj.dampingFactor));
            obj.delta = 1 + 2*obj.dampingFactor*obj.theta + obj.theta^2;
            obj.sps = 1/sampleRate; % Samples per second
            obj.g1 = ((4*obj.dampingFactor*obj.theta)/(obj.delta))/(M);
            obj.g2 = ((4*obj.theta^2)/(obj.delta))/M;
            obj.prevErr = 0;
            obj.prevOut = 0;
        end

        function [g] = Filter(obj, err)
            Kp = 0.1;
            Ki = 0.01;
            deltaErr = err-obj.prevErr;
            obj.prevErr = err;
            obj.prevOut = obj.g1*deltaErr + obj.biquadFilter(obj.g2*err);
            g = obj.prevOut;
            %g = obj.g1*err + obj.biquadFilter(obj.g2*err);
        end
    end
end

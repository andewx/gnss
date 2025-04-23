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
    end 

    methods
        function obj = GPSLoopFilter(loopBandwidth, dampingFactor, loopGain, sampleRate)
            % Constructor for the GPSLoopFilter class
            obj.loopBandwidth = loopBandwidth; % Loop bandwidth in Hz
            obj.dampingFactor = dampingFactor; % Damping factor
            obj.loopGain = loopGain; % Loop gain
            obj.biquadFilter = dsp.SOSFilter([1 0 0], [-1 0 1]); % Biquad filter
            obj.theta = obj.loopBandwidth / (obj.dampingFactor + 0.25/obj.damingFactor);
            obj.delta = 1 + 2*obj.dampingFactor*obj.theta + obj.theta^2;
            obj.sps = 1/sampleRate; % Samples per second
            obj.g1 = obj.loopGain*(-4*obj.dampingFactor*obj.theta)/(obj.delta*obj.sps);
            obj.g2 = obj.loopGain*((-4*obj.theta^2)/obj.delta)/(obj.sps*obj.delta);
        end

        function [g] = Filter(err)
            g = obj.g1*err + obj.bqFilter(obj.g2*err);
        end
    end
end

classdef GPSCodePLL < handle
    properties
        loopBandwidth
        dampingFactor
        loopGain
        theta
        Kp
        Ki
        fs
        f0
        nco_out
        N
        phaseEst
        freqEst
    end

    methods
        % Constructor for the GPSCodePLL class
        function obj = GPSCodePLL(loopBandwidth, dampingFactor, loopGain, fs, f0, N)
            % Constructor for the GPSCodePLL class
            obj.loopBandwidth = loopBandwidth; % Loop bandwidth
            obj.dampingFactor = dampingFactor; % Damping factor
            obj.loopGain = loopGain; % Loop gain
            obj.theta = loop_bw/fs; % Initial phase
            obj.fs = fs; % Sampling frequency
            obj.f0 = f0; % Frequency of the incoming signal
            obj.Kp = 2 * damping * theta;
            obj.Ki = theta^2;
            obj.nco_out = zeros(1, N); % NCO output
            obj.N = N; % Number of samples
            obj.phaseEst = 0; % Initial phase estimate
            obj.freqEst = 2 * pi * f0 / fs; % Initial frequency estimate radians
            for n = 1:N
                obj.nco_out(n) = exp(-1j * obj.theta);
            end
        end

        function [samplesOut] = Compute(obj,f0,samples)
    
            % Initialize loop variables
            phase_est = 0;
            freq_est = 2*pi*f0/obj.fs;  % Normalize freq to radians/sample
        
            % Outputs
            phases = zeros(1,obj.N);
            freqs = zeros(1,obj. N);
        
            % Loop variables
            phase_err = 0;
            integrator = 0;
        
            for n = 1:obj.N
                % Mix signal with NCO (carrier wipe-off)
                mixed = samples(n) * conj(obj.nco_out(n));
        
                % Phase detector: Get phase error (atan2 of mixed signal)
                phase_err = atan2(imag(mixed), real(mixed));  % Phase error in radians
        
                % Loop filter (PI controller)
                integrator = integrator + obj.Ki * phase_err;
                obj.freqEst = obj.freqEst + obj.Kp * phase_err + integrator;
        
                % Update NCO phase
                obj.phaseEst = obj.phaseEst + freq_est;

            end

            samplesOut = samples .* exp(-1j *(obj.freqEst + obj.phaseEst)); % Output samples
        end 
    end
end
        
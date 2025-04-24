% GPSCodePLL - Please note that in functional GPS Receiver the PLL
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
        phi
        integrator
    end

    methods
        % Constructor for the GPSCodePLL class
        % Parameters:
        % loopBandwidth: Loop bandwidth
        % dampingFactor: Damping factor
        % loopGain: Loop gain
        % fs: Sampling frequency
        % f0: Initial frequency of the incoming signal
        % N: Number of samples
        function obj = GPSCodePLL(loopBandwidth, dampingFactor, loopGain, fs, f0, N)
            % Constructor for the GPSCodePLL class
            obj.loopBandwidth = loopBandwidth; % Loop bandwidth
            obj.dampingFactor = dampingFactor; % Damping factor
            obj.loopGain = loopGain; % Loop gain
            obj.theta = loopBandwidth/fs; % Initial phase
            obj.fs = fs; % Sampling frequency
            obj.f0 = f0; % Frequency of the incoming signal
            obj.Kp = 2 * dampingFactor * obj.theta;
            obj.Ki = obj.theta^2;
            obj.nco_out = zeros(1, N); % NCO output
            obj.N = N; % Number of samples
            obj.phi = 0; % Initial phase estimate
            obj.f0 = f0; % Initial frequency estimate in Hz
            obj.integrator = 0;
            for n = 1:N
                obj.nco_out(n) = exp(-1j * obj.theta);
            end
        end

        function [output] = Compute(obj,f0,r)
            % Initialize loop variables
            obj.f0 = f0;
            output = zeros(size(r));
            
            for n = 1:length(r)
                v = exp(-1j * obj.phi);           % NCO output
                err = angle(r(n) * conj(v));  % Phase error (phase detector)
                obj.f0 = obj.f0 + obj.loopGain * err;     % Frequency correction (simple loop filter)
                obj.phi = obj.phi + obj.f0;    % Update phase
                output(n) = r(n) * conj(v);   % Carrier-wiped signal
            end
        end 


        function [freqs, phases,output] = ComputeAndVisualize(obj,f0,r)
          % Initialize loop variables
            obj.f0 = f0;
            output = zeros(size(r));
            freqs = zeros(size(r));
            phases = zeros(size(r));

            for n = 1:length(r)
                v = exp(-1j * obj.phi);           % NCO output
                err = angle(r(n) * conj(v));  % Phase error (phase detector)
                obj.f0 = obj.f0 + obj.loopGain * err;     % Frequency correction (simple loop filter)
                obj.phi = obj.phi + 2*pi*obj.f0/obj.fs;    % Update phase
                output(n) = r(n) * conj(v);   % Carrier-wiped signal
                freqs(n) = obj.f0;
                phases(n) = obj.phi;
            end

            %Verify behavior of PLL with Plot of Phase and Frequency Adjust by plotting
            % the phase and frequency estimates
            figure;
            subplot(2, 1, 1);
            plot(phases);
            title('Phase Estimate');
            xlabel('Sample Index');
            ylabel('Phase (radians)');
            grid on;
            subplot(2, 1, 2);
            plot(freqs);
            title('Frequency Estimate');
            xlabel('Sample Index');
            ylabel('Frequency (radians/sample)');
            grid on;
            % Display the final phase and frequency estimates
            disp(['Final Phase Estimate: ', num2str(phases(end))]);
            disp(['Final Frequency Estimate: ', num2str(freqs(end))]);
     

        end
    end
end
        
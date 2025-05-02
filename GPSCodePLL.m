% GPSCodePLL - Please note that in functional GPS Receiver the PLL
classdef GPSCodePLL < handle
    properties  
        fs
        f0
        nco_out
        N
        phi
        loopFilter
        normalizedOffset
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
        function obj = GPSCodePLL(fs, f0)
            % Constructor for the GPSCodePLL class
            obj.loopFilter = GPSLoopFilter(0.1, 0.707, 1.0,fs);
            obj.fs = fs; % Sampling frequency
            obj.f0 = f0; % Frequency of the incoming signal     
            obj.phi = 0; % Initial phase estimate
            obj.normalizedOffset = 1i * 2 * pi / fs; % Normalized offset
            % Initialize the NCO output
            obj.f0 = f0; % Initial frequency estimate in Hz
        end

        function [err] = PhaseError(obj,r)
            % Initialize loop variables
            for n = 1:length(r)
                v = exp(-1j * obj.phi);       % NCO output
                err = angle(r(n) * conj(v));  % Phase error (phase detector)
                obj.phi = obj.loopFilter.Filter(err);
            end
            err = obj.phi;
        end 

        function obj = Reset(obj)
            % Reset the PLL object
            obj.f0 = 0; % Reset frequency estimate
            obj.phi = 0; % Reset phase estimate
            obj.loopFilter = GPSLoopFilter(0.001, 1.207, 1.0, obj.fs); % Loop filter object
        end

        % Apply the current phase offset value to the samples
        function [output] = Apply(obj, samples)
            % Apply current frequence and phase offset normalized to the sampling rate
            % Apply the frequency offset to the samples
            t = ((0:length(samples)-1) / obj.fs).';
            output = samples .* exp(-1j * obj.normalizedOffset * t * obj.phi); % Apply the current frequency and phase offset
        end


        function [freqs, phases,output] = ComputeAndVisualize(obj,r)
          % Initialize loop variables
            output = zeros(size(r));
            freqs = zeros(size(r));
            phases = zeros(size(r));
           
            for n = 1:length(r)
                v = exp(-1j * obj.normalizedOffset * obj.phi);       % NCO output
                err = angle(r(n) * conj(v));  % Phase error (phase detector)
                obj.f0 = obj.loopFilter.Filter(err);
                obj.phi = obj.phi + obj.f0;    % Update phase
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
        
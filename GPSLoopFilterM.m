classdef GPSLoopFilterM < handle
    % Implements a second-order loop filter for DLL or PLL
    properties
        % Loop filter parameters
        Kp   % Proportional gain
        Ki   % Integral gain

        % State variables
        integrator = 0      % Accumulated error
        last_output = 0     % Last frequency correction
    end

    methods
        function obj = GPSLoopFilterM(BL, zeta, T)
            % Constructor: BL = bandwidth (Hz), zeta = damping, T = interval (s)
            % Use: T = 1e-3 for GPS DLL (1 ms update rate)
            omega_n = BL * 8 * zeta / (4 * zeta^2 + 1);
            obj.Kp = 2 * zeta * omega_n;
            obj.Ki = omega_n^2 * T;
        end

        function freq_correction = Filter(obj, discriminator_output)
            % Update filter with current discriminator value
            obj.integrator = obj.integrator + obj.Ki * discriminator_output;
            freq_correction = obj.Kp * discriminator_output + obj.integrator;
            obj.last_output = freq_correction;
        end

        function reset(obj)
            % Reset filter state
            obj.integrator = 0;
            obj.last_output = 0;
        end
    end
end

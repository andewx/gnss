classdef CACodeGenerator < handle
    properties
        G1
        G2
        PRN
        G2TapMap
    end
    
    methods
        function obj = CACodeGenerator(prn)
            % Validate PRN number
            if prn < 1 || prn > 37
                error('PRN must be in the range 1 to 37.');
            end
            
            % Initialize shift registers
            obj.G1 = ones(1, 10);
            obj.G2 = ones(1, 10);
            obj.PRN = prn;
            
            % G2 tap pairs (from ICD-GPS-200)
            obj.G2TapMap = [
                2 6; 3 7; 4 8; 5 9; 1 9; 2 10; 1 8; 2 9; 3 10; 2 3; % 1–10
                3 4; 5 6; 6 7; 7 8; 8 9; 9 10; 1 4; 2 5; 3 6; 4 7; % 11–20
                5 8; 6 9; 1 3; 4 6; 5 7; 6 8; 7 9; 8 10; 1 6; 2 7; % 21–30
                3 8; 4 9; 5 10; 4 10; 1 7; 2 8; 4 10                 % 31–37
            ];
        end

        function ca_code = generate(obj)
            g1 = obj.G1;
            g2 = obj.G2;
            ca_code = zeros(1, 1023);

            taps = obj.G2TapMap(obj.PRN, :);

            for i = 1:1023
                g1_out = g1(10);
                g2_out = xor(g2(taps(1)), g2(taps(2)));
                ca_code(i) = xor(g1_out, g2_out);

                % Feedback and shift G1
                g1_fb = xor(g1(3), g1(10));
                g1 = [g1_fb, g1(1:9)];

                % Feedback and shift G2
                g2_fb = xor(g2(2), xor(g2(3), xor(g2(6), xor(g2(8), xor(g2(9), g2(10))))));
                g2 = [g2_fb, g2(1:9)];
            end
        end
    end
end

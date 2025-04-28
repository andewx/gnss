classdef GPSSignalProcessor < handle
    properties
        satellite               % GPS satellite object
        coder                   % prn coder
        prn                     % calculated PRN code
        expandedPrn             % interpolated PRN code
        revPrn                  % reversed PRN code
        preamble                % frame preamble
        parityBits              % 2 parity bits from previous frame used to decode current word
        sampleRate              % sample rate in Hz
        buffers                 % triple cylicic buffer for 3 1023 bit chips
        bufferIndex             % index for the buffer
        correlationBuffer       % buffer for the correlation results
        codePhase               % code phase
        dllController           % DLL controller object
        samplesBuffer           % samples for a triple buffered frame
        samplesBufferIndex      % index for the samples buffer
        samplesPerChip          % number of samples per chip
        fllController           % FLL controller object
        pllController           % PLL controller object
        trackingMode            % tracking mode [ 1 = COARSE; 2 = FINE; 3 = COARSE(LO CONFIGURE)]
    end
    
    methods
        % Constructor for the GPSSignalProcessor class
        % Initializes the satellite, coder, preamble, sample rate, and
        % for our implementation we try to receive 20ms x 3 of sample data (3 bits)
        % at the nominal 1.023 MhZ Sampling Rate. We need some form of parallelism that will
        % allow us to process the data while continuing to recieve data frames at this fundamental level
        function obj = GPSSignalProcessor(id, samplesPerChip, sampleRate)
            obj.satellite = GPSSatellite(id);
            obj.coder = CACodeGenerator(id);
            obj.samplesPerChip = samplesPerChip;
            obj.prn = obj.coder.PRN;    
            obj.expandedPrn = zeros(1023*samplesPerChip, 1);
            obj.preamble = [1 0 0 0 1 0 1 1];
            obj.sampleRate = sampleRate; % Sample rate in Hz
            obj.buffers = zeros(3, 1023*samplesPerChip);
            obj.samplesBuffer = zeros(3, 1023*samplesPerChip);
            obj.samplesBufferIndex = 1;
            obj.bufferIndex = 1;
            obj.dllController = GPSCodeDLL(0.1, 0.707, 0.5, 4, obj.sampleRate);
            obj.fllController = GPSCodeFLL(samplesPerChip, obj.sampleRate);
            obj.pllController = GPSCodePLL(0.1, 0.707, 0.5, obj.sampleRate);
            obj.trackingMode = 1; % COARSE (LO CONFIGURE)
        end


        function obj = ReceiveSamples(obj, samples)
            % Store the samples in the buffer
            obj.samplesBuffer(obj.samplesBufferIndex, :) = samples;
            obj.samplesBufferIndex = mod(obj.samplesBufferIndex, 3) + 1;

            % Process the samples
            if obj.samplesBufferIndex == 1
                % Process the samples in the buffer
                obj.ProcessSamples();
            end
        end


        function obj = ProcessSamples(obj,samples)
            % First perform the DLL tracking with the DLL update retrieving the update samples
            % process the samples in the 1ms code chunks with the given sample rates

            %Apply Frequency and phase correction prior to the Code Tracking Loop
            samples = obj.pllController.Apply(obj.fllController.Apply(samples));
            % Apply the carrier wipe to the samples
            for k = 1:1023*obj.samplesPerChip:length(samples)
                % Every 20ms we update the harware tracking frequency and need to recompute the FLL positions
                if samplesProcessed > 1023*obj.samplesPerChip*20
                    hardwareCorrect = true;
                end
                if k + 1023*obj.samplesPerChip - 1 > length(samples)
                    break;
                end
                % Get the samples for the current code chunk
                codeSamples = samples(k:k+1023*obj.samplesPerChip-1);
                % Get the code phase from the DLL controller
                [despreadSamples, ~] = obj.dllController.AutoCorr(codeSamples);
                % Get the code phase from the FLL controller the FLL controller should only once every subframe and adjusts the
                % Hardware Carrier Frequency
                if hardwareCorrect
                    [correction, ~,~] = obj.fllController.Compute(despreadSamples);
                    % Perform frequency correction in hardware
                    despreadSamples = despreadSamples .* exp(-1i * correction);
                    frequencyCorrect = false;
                else
                    [correction, ~,~] = obj.fllController.Compute(despreadSamples);
                    despreadSamples = despreadSamples .* exp(-1i * correction);
                end

                % Ajdust the PLL loop adjustment and apply to the samples
                finalSamples = obj.pllController.Compute(despreadSamples);

                % Apply the PLL delay to the samples and comput the integrated sum
                value = sum(final)

            end
            

        end
        
    



    end
end
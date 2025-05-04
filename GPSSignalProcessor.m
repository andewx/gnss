classdef GPSSignalProcessor < handle
    properties
        satellite               % GPS satellite object
        coder                   % prn coder
        prn                     % calculated PRN code
        expandedPrn             % interpolated PRN code
        preamble                % frame preamble
        sampleRate              % sample rate in Hz
        codePhase               % code phase
        dllController           % DLL controller object
        samplesBuffer           % buffer for received samples
        samplesBufferIndex      % index for the samples buffer
        samplesPerChip          % number of samples per chip
        fllController           % FLL controller object
        pllController           % PLL controller object
        trackingMode            % tracking mode [ 1 = COARSE; 2 = FINE; 3 = COARSE(LO CONFIGURE)]
        frequencyCorrection     % Estimated Frequency Correction - Term used for initial Signal Acquisition
        cmloN                   % number of iterations for the coarse LO mode
        cmN                     % number of iterations for the coarse mode
        frameT                  % Frame Time for samples in ms
        t                       % Frame Time phase vector
    end
    
    methods
        % Constructor for the GPSSignalProcessor class
        % Initializes the satellite, coder, preamble, sample rate, and
        % for our implementation we try to receive 20ms x 3 of sample data (3 bits)
        % at the nominal 1.023 MhZ Sampling Rate. We need some form of parallelism that will
        % allow us to process the data while continuing to recieve data frames at this fundamental level
        function obj = GPSSignalProcessor(id, samplesPerChip, sampleRate, initialFrequencyOffset)
            obj.satellite = GPSSatellite(id);
            obj.coder = CACodeGenerator(id).generate();
            obj.samplesPerChip = samplesPerChip;
            obj.preamble = [1 0 0 0 1 0 1 1];
            obj.sampleRate = sampleRate; % Sample rate in Hz
            obj.samplesBuffer = zeros(3,1); % Buffer for received samples
            obj.samplesBufferIndex = 1; % Index for the samples buffer
            obj.dllController = GPSCodeDLL(obj.coder, obj.sampleRate, 2);
            obj.fllController = GPSCodeFLL(samplesPerChip, obj.sampleRate,initialFrequencyOffset);
            obj.pllController = GPSCodePLL(obj.sampleRate,0);
            obj.frequencyCorrection = initialFrequencyOffset;
            obj.trackingMode = 1; % COARSE (LO CONFIGURE)
            obj.cmloN = 20; % Number of iterations for the coarse LO mode    
            obj.cmN = 10; % Number of iterations for the coarse mode
            obj.frameT = 300; % 600 ms
            obj.t = (0:1/sampleRate:obj.frameT*0.001).'; %600ms matches subframe size (actual subframe 1500)
        end


        % Performs a 2D acquisition search of the PRN satellite signal -
        % Identifies initial strongest correlation and phase delay observed
        % 2ms signal- We assume a known satellite PRN ID but could adjust
        % for this
        function [frequency, delay] = Acquire2D(obj,samples)
                frequencyOffset = -4000;
                maxCorrelation = 0;
                delay = 0;
                A = 1;
                B = 1023*obj.samplesPerChip*2 - 1;
                subsamples = samples(A:B);
                frequencyStep = 1;
                frequencyRange = 8000;
                frequency = 0;
                zscores = [];
                
                for i = 1:frequencyStep:frequencyRange
                    f = frequencyOffset +frequencyStep*i;
                    corrSamples = subsamples .* exp(1i * 2 * pi * f * obj.t(A:B));
                    zscore = obj.dllController.AutoCorr(corrSamples);
                    zscores = [zscores; zscore];
                    if zscore > maxCorrelation
                       % obj.dllController.ShowCorrelation();
                        maxCorrelation = zscore;
                        delay = obj.dllController.codeDelayInitial;
                        frequency = f;
                        disp(['Frequency: ', num2str(f), ' Delay: ', num2str(delay)]);
                    end
    
                end

                % Plot the corrleation sequence for the detected highest z
                % score with the delayed version of the samples
                corrSamples = subsamples .* exp(1i * 2 *pi * f * obj.t(A:B));
                
                z = obj.dllController.AutoCorr(corrSamples);
                obj.dllController.ShowCorrelation();


                figure;
                plot(zscores);
                title('Z-Scores');
                xlabel('Frequency Offset');
                ylabel('Z-Score');
                grid on;
        end


        function [output] = ApplyFrequencyCorrection(obj,samples)
            A = 1;
            B = length(samples);
            output = [];
            if B > length(obj.t)
                disp('Error Samples Length Greater than Max ALlowed Frame Time');
                return
            end
      
            output = samples .* exp(1i * 2 * pi * obj.frequencyCorrection * obj.t(A:B));
        end




        % ProcessSubFrame() - Performs Total GPS Receiver Loop on provided
        % samples which includes estimated Frequency/Phase Correction
        % Followed by despreading, FLL/PLL application, and Value
        % extraction - when the frame is processed we update obj.t for
        % phase continuity - processes subframe size for 30 bits (600ms);
        function [values] = ProcessSubFrame(obj,samples)

            values = ones(30,1);
            vIdx = 1;

            % Apply Estimated Frequency Correction to the Samples
            samples = samples .* exp(1i * 2 * pi * obj.frequencyCorrection * obj.t);

            % Applies Receiever loop and estimate on 1 bit frames (20ms)
            for k = 1:1023*obj.samplesPerChip*20:length(samples)

                A = k;
                B = k+1023*obj.samplesPerChip*20 - 1;
                C = 1023*obj.samplesPerChip*20-1;

                if B > length(samples)
                    return
                end
                
                samples(A:B) = obj.fllController.Apply(samples(A:B),obj.t(A:B));
                [despreadSamples] = obj.dllController.Update(samples,A,B);
                
                % Use the average to detect value for now
                value = mean(despreadSamples);

                % Lazy Evaluation
                if value <= 0
                    value = -1;
                else
                    value = 1;
                end
                values(vIdx) = value;
                vIdx = vIdx + 1;

                % Get the code phase from the FLL controller the FLL controller should only once every subframe and adjusts the
                switch obj.trackingMode
                    case 1 % COARSE
                        % Get the code phase from the FLL controller
                        obj.fllController.Compute(despreadSamples);
                    case 2 % FINE
                        % Get the code phase from the FLL controller
                        err = obj.pllController.PhaseError(despreadSamples);
                        K = B+1;
                        D = K + C;

                        if D > length(samples)
                            return
                        end

                        %Update next samples and update time vector object
                        %for phase accurracy
                        obj.t = obj.t + 0.6;
                        samples(K:D) = samples(K:D).*exp(1i * 2 * pi * err * obj.t);

                    case 3 % COARSE(LO CONFIGURE)
                        % Get the code phase from the FLL controller
                        obj.fllController.Compute(despreadSamples);
                end
         
            end
            

        end

        % ShiftSamples() - Shifts the samples by the delay and resets the dll code initial delay to zero
        function [shiftedSamples] = ShiftSamples(obj,samples, delay)
            % Shift the samples by the delay
            shiftedSamples = circshift(samples, -delay);

            if delay > 0 %left shift
                shiftedSamples(end-delay+1:end) = 0;
            else %right shift
                shiftedSamples(1:delay) = 0;
            end

            obj.dllController.codeDelayInitial = 0; % Reset the DLL code delay to zero
            obj.dllController.codeDelay = 0; % Reset the DLL code delay to zero
        end

        %% Test Case Process Frame Function with Visualization for debugging
         % Max Samples is 1023*300*samplesPerChip as we allow a full subframe of processing max
         % ProcessSubFrame() - Performs Total GPS Receiver Loop on provided
        % samples which includes estimated Frequency/Phase Correction
        % Followed by despreading, FLL/PLL application, and Value
        % extraction - when the frame is processed we update obj.t for
        % phase continuity - processes subframe size for 30 bits (250ms);
        function [values] = TestProcessSubFrame(obj,samples)

            values = ones(30,1);
            vIdx = 1;
            % Apply Estimated Frequency Correction to the Samples
            samples = samples .* exp(1i * 2 * pi * obj.frequencyCorrection * obj.t);

            % Timescope for the outputSignal
            scope = timescope('SampleRate', obj.sampleRate, 'TimeSpan', 0.1, 'TimeSpanSource', "property");

            % Spectrum Analyzer
            sa = spectrumAnalyzer('SampleRate', obj.sampleRate, 'PlotAsTwoSidedSpectrum', true, 'YLimits', [-100 0]);


            % Applies Receiever loop and estimate on 1 bit frames (20ms)
            for k = 1:1023*obj.samplesPerChip*20:length(samples)

                A = k;
                B = k+1023*obj.samplesPerChip*20 - 1;
                C = 1023*obj.samplesPerChip*20-1;

                  if B > length(samples)
                    return
                end
                %Apply Frequency and phase correction prior to the Code Tracking Loop
                samples(A:B) = obj.fllController.Apply(samples(A:B), obj.t(A:B));

                % Get the code phase from the DLL controller
                [despreadSamples] = obj.dllController.Update(samples,A,B);
                if length(despreadSamples) > 0
                    disp('Processing samples');
                    scope(despreadSamples);
                    sa(despreadSamples);
                    pause(1);
                else
                    disp('No samples to process');
                    return
                end
                
                % Use the average to detect value for now
                value = mean(despreadSamples);

                % Lazy Evaluation
                if value < 0
                    value = -1;
                else if value > 0
                    value = 1;
                else
                    value = 0;
                end
                values(vIdx) = value;
                vIdx = vIdx + 1;

                % Get the code phase from the FLL controller the FLL controller should only once every subframe and adjusts the
                switch obj.trackingMode
                    case 1 % COARSE
                        % Get the code phase from the FLL controller
                        obj.fllController.Compute(despreadSamples);
                        if obj.cmN == 0
                            % Apply the LO adjustment to the SDR hardware
                            % Reset the FLL controller
                            obj.fllController.Reset();
                            obj.cmN = 20; % Reset the number of iterations for the coarse mode
                            obj.trackingMode = 2; % Set the tracking mode to FINE
                        else
                            obj.cmN = obj.cmN - 1;
                        end
                    case 2 % FINE
                        % Get the code phase from the FLL controller
                        err = obj.pllController.PhaseError(despreadSamples);
                        K = B+1;
                        D = K + C;

                        if D > length(samples)
                            return
                        end

                        %Update next samples and update time vector object
                        %for phase accurracy
                        obj.t = obj.t + 0.6;
                        samples(K:D) = samples(K:D).*exp(1i * 2 * pi * err * obj.t);


                    case 3 % COARSE(LO CONFIGURE)
                        % Get the code phase from the FLL controller
                        obj.fllController.Compute(despreadSamples);
                        % Here we apply the LO adjustment to the SDR hardware and reset the FLL after a number of iterations
                        if obj.cmloN == 0
                            % Apply the LO adjustment to the SDR hardware
                            % Reset the FLL controller
                            obj.fllController.Reset();
                            obj.cmloN = 20; % Reset the number of iterations for the coarse LO mode
                            obj.trackingMode = 1; % Set the tracking mode to COARSE
                        else
                            obj.cmloN = obj.cmloN - 1;
                        end
                end
            end
            end
        end
    end
end
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
        trackingMode            % tracking mode [ 1 = COARSE; 2 = FINE; 3 = COARSE(LO CONFIGURE)]
        frequencyCorrection     % Estimated Frequency Correction - Term used for initial Signal Acquisition
        cmloN                   % number of iterations for the coarse LO mode
        cmN                     % number of iterations for the coarse mode
        frameT                  % Frame Time for samples in ms
        t                       % Frame Time phase vector
        CFO                     % Comm Carrier Synchronizer
        nco_phase               % NCO Phase Tracking
        nco_freq                % NCO Freq Tracking Provides Coarse Frequency Initial Estimation
        frameSize               % Frame Size
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
            obj.dllController = GPSCodeDLL(obj.coder.', obj.sampleRate);
            obj.frequencyCorrection = initialFrequencyOffset
            obj.CFO = comm.CarrierSynchronizer('SamplesPerSymbol',samplesPerChip,...
            'Modulation','BPSK',...
            'DampingFactor',1.007,...
            'NormalizedLoopBandwidth',0.001);
            obj.nco_freq = 0;
            obj.nco_phase = 0;
            obj.frameSize = 1;
        end


        % Performs a 2D acquisition search of the PRN satellite signal -
        % Finding Frequency Offset and Code Delay for a Given Satellite PRN
        % ID associated with this GPS Signal Processor within 1HZ -
        % Performs analysis on GPS Environment with Cold Start data should
        % be saved for warm starting receiver
        function [frequency, delay] = Acquire2D(obj,samples, range, showPlot)
                frequencyOffset = -(range/2);
                maxCorrelation = 0;
                delay = 0;
                A = 1;
                B = 1023*obj.samplesPerChip*2;
                subsamples = samples(A:B);
                frequencyStep = 1;
                frequencyRange = range;
                frequency = 0;
                correlations = [];
                t = ((1:B)/obj.sampleRate).';
                
                for i = 1:frequencyStep:frequencyRange
                    f = frequencyOffset+frequencyStep*i;
                    corrSamples = subsamples .* exp(1i * 2 * pi * f * t);
                    [zscore, values] = obj.dllController.Acquire(corrSamples);
                    correlations = [correlations; values.']; % Tracking Correlation Buffers
                    if zscore > maxCorrelation
                       % obj.dllController.ShowCorrelation();
                        maxCorrelation = zscore;
                        delay = obj.dllController.nco_phase;
                        frequency = f;
                      %  disp(['Frequency: ', num2str(f), ' Delay: ', num2str(delay)]);
                    end
    
                end

                % Recalculate autocorrelation for max detected sequence to
                % set the DLL NCO Properties - Show Correlation
                corrSamples = subsamples .* exp(1i * 2 *pi * f * t);
                z = obj.dllController.AutoCorr(corrSamples);
                obj.dllController.ShowCorrelation();
                if showPlot
                    % Plot the 3D Mesh of the correlation Buffers
                    frequencies = linspace(frequencyOffset,frequencyOffset + frequencyRange, frequencyRange/frequencyStep).';
                    delays = linspace(0,1023,1023).';
                    mesh(frequencies, delays, correlations.');
                end

        end


        function [output] = ApplyCoarseFrequencyCorrection(obj,samples)
            output = zeros(length(samples),1);
            for n = 1:length(samples)
                output(n) = samples(n) * exp(1j*obj.nco_phase);
                obj.nco_phase = obj.nco_phase + (2*pi*obj.nco_freq/obj.sampleRate);
            end
        end


        % ProcessSubFrame() - Performs Total GPS Receiver Loop on provided
        % samples which includes estimated Frequency/Phase Correction
        % Followed by despreading, FLL/PLL application, and Value
        % extraction - when the frame is processed we update obj.t for
        % phase continuity - processes subframe size for 30 bits (600ms);
        function [values] = Track(obj,samples)

            values = [];
            vIdx = 1;
            baseband = zeros(length(samples),1);
            FRAMESIZE = obj.frameSize;
            % Apply Estimated Frequency Correction to the Samples
            samples = obj.ApplyCoarseFrequencyCorrection(samples);

            % Applies Receiever loop and estimate on 1 chip frames (1ms)
            for k = 1:1023*obj.samplesPerChip*FRAMESIZE:length(samples)

                A = k;
                B = k+1023*obj.samplesPerChip*FRAMESIZE - 1;

                if B > length(samples)
                    B = length(samples)-1;
                end
                
                baseband(A:B) = obj.CFO(samples(A:B));
                [~,~,integratedOutput] = obj.dllController.Update(baseband,A,B);
                values = [values; (integratedOutput)/(B-A)];
            end
            

        end


        %% Test Case Process Frame Function with Visualization for debugging
         % Max Samples is 1023*300*samplesPerChip as we allow a full subframe of processing max
         % ProcessSubFrame() - Performs Total GPS Receiver Loop on provided
        % samples which includes estimated Frequency/Phase Correction
        % Followed by despreading, FLL/PLL application, and Value
        % extraction - when the frame is processed we update obj.t for
        % phase continuity - processes subframe size for 30 bits (250ms);
        function [values] = TestTrack(obj,samples)

            % Timescope for the outputSignal
            values = [];
            scope = timescope('SampleRate', obj.sampleRate, 'TimeSpan', length(samples)*(1/obj.sampleRate), 'TimeSpanSource', "property");
            baseband = zeros(length(samples),1);
            FRAMESIZE = obj.frameSize;
            % Apply Estimated Frequency Correction to the Samples
            samples = obj.ApplyCoarseFrequencyCorrection(samples);

            % Applies Receiever loop and estimate on 1 chip frames (1ms)
            for k = 1:1023*obj.samplesPerChip*FRAMESIZE:length(samples)

                A = k;
                B = k+1023*obj.samplesPerChip*FRAMESIZE - 1;

                if B > length(samples)
                    B = length(samples)-1;
                end
                
                baseband(A:B) = obj.CFO(samples(A:B));
                [output,~,integratedOutput] = obj.dllController.Update(baseband,A,B);
                values = [values; (integratedOutput)/(B-A)];
                scope(output);
            end

            pause(5);
            
        end
    end
end
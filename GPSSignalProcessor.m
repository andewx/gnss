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
        cmloN                   % number of iterations for the coarse LO mode
        cmN                     % number of iterations for the coarse mode
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
            obj.dllController = GPSCodeDLL(obj.coder, obj.sampleRate, 4);
            obj.fllController = GPSCodeFLL(samplesPerChip, obj.sampleRate,initialFrequencyOffset);
            obj.pllController = GPSCodePLL(obj.sampleRate,0);
            obj.trackingMode = 1; % COARSE (LO CONFIGURE)
            obj.cmloN = 20; % Number of iterations for the coarse LO mode    
            obj.cmN = 20; % Number of iterations for the coarse mode
        end

        % Max Samples is 1023*300*samplesPerChip as we allow a full subframe of processing max
        function [values] = ProcessFrame(obj,samples)

            values = zeros(300,1);
            vIdx = 1;

            if length(samples) > 1023*obj.samplesPerChip*300
                % Apply the frequency and phase correction to the samples
                disp('Max Frame Samples Size Exceeded');
                return
            end

            % Apply the carrier wipe to the samples
            for k = 1:1023*obj.samplesPerChip:length(samples)

                k = obj.dllController.GetCodePhaseIndex() + k;
                % Check if we have enough samples for the current code chunk
                if k + 2*1023*obj.samplesPerChip - 1 > length(samples)
                    break;
                end

                subsamples = samples(k:k+2*1023*obj.samplesPerChip-1);

                %Apply Frequency and phase correction prior to the Code Tracking Loop
                subsamples = obj.pllController.Apply(obj.fllController.Apply(subsamples));

                % Get the code phase from the DLL controller
                [despreadSamples] = obj.dllController.Update(subsamples);
                
                value = sum(resample(despreadSamples,1,obj.samplesPerChip));
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
                        obj.pllController.PhaseError(despreadSamples);
                        % If the fine mode is not converging switch back to coarse mode acquistion

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



        %% Test Case Process Frame Function with Visualization for debugging
         % Max Samples is 1023*300*samplesPerChip as we allow a full subframe of processing max
         function [values] = TestProcessFrame(obj,samples)

            values = zeros(300,1);
            vIdx = 1;
            % Create spectrum visualization
            visualizer = dsp.SpectrumAnalyzer('SampleRate', obj.sampleRate, ...
                'PlotAsTwoSidedSpectrum', true, ...
                'YLimits', [-100 0], ...
                'Title', 'Spectrum Visualization', ...
                'ShowLegend', true, ...
                'ChannelNames', {'Signal Spectrum'});
            % Create a figure for the spectrum visualization
           

            if length(samples) > 1023*obj.samplesPerChip*300
                % Apply the frequency and phase correction to the samples
                disp('Max Frame Samples Size Exceeded');
                return
            end

            % Apply the carrier wipe to the samples
            for k = 1:1023*obj.samplesPerChip:length(samples)

                k = obj.dllController.GetCodePhaseIndex() + k;
                % Check if we have enough samples for the current code chunk
                if k + 2*1023*obj.samplesPerChip - 1 >= length(samples)
                    break;
                end

                subsamples = samples(k:k+2*1023*obj.samplesPerChip-1);

                %Apply Frequency and phase correction prior to the Code Tracking Loop
                subsamples = obj.pllController.Apply(obj.fllController.Apply(subsamples));
       
                % Get the code phase from the DLL controller
                [despreadSamples] = obj.dllController.Update(subsamples);
                
                % Visualize the despread samples
                visualizer(despreadSamples);
                value = sum(resample(despreadSamples,1,obj.samplesPerChip));
                if value > 0
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
                        obj.pllController.PhaseError(despreadSamples);
                        % If the fine mode is not converging switch back to coarse mode acquistion

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
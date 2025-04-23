classdef GPSSignalProcessor < handle
    properties
        satellite               % GPS satellite object
        coder                   % prn coder
        prn                     % calculated PRN code
        expandedPrn              % interpolated PRN code
        revPrn                    % reversed PRN code
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
        samplesPerChip         % number of samples per chip
        fllController           % FLL controller object
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
            obj.correlationBuffer = zeros(1023*samplesPerChip, 1);
            obj.samplesBuffer = zeros(3, 1023*samplesPerChip);
            obj.samplesBufferIndex = 1;
            obj.bufferIndex = 1;
            obj.dllController = GPSCodeDLL(0.1, 0.707, 0.5, 4, obj.sampleRate);
            obj.fllController = GPSCodeFLL(samplesPerChip, obj.sampleRate);
            % Interpolate the PRN code by samplesPerChip
            obj.expandedPrn = resample(obj.prn,samplesPerChip,1);
            obj.revPrn = fliplr(obj.expandedPrn);
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


        function obj = ProcessSamples(obj)
            % Process the samples in the buffer
            fllSamples = obj.fllController.Compute(obj.samplesBuffer(obj.bufferIndex, :));
            % Interpolate the samples
            

            % Calculate the correlation
            obj.AutoCorr(obj.samplesBuffer(obj.bufferIndex, :));

        end
        
        % Autocorrelation function assumes that the we are sampling a
        % single 1023 bit chip at a time with 1023 samples per chip
        % The early, prompt, and late signals are -0.5, 0.0, and 0.5
        % chips respectively. values is a [3 x 1] vector of the early, prompt, and late signals
        % indexes is a [3 x 1] vector of the indexes of the early, prompt, and late signals
       function [values, index] = AutoCorr(obj,samples)
            % Initialize the early, prompt, and late signals

            values = zeros(3, 1);

            % Calculate autocorrelation with reverse filter
            obj.correlationBuffer = filter(obj.revPrn, 1, samples);
            absCorrelation = abs(obj.correlationBuffer);
            idx = find(obj.correlationBuffer == max(absCorrelation), 1);
            promptIndex = length(obj.prn) + idx - 1;
            prompt = obj.correlationBuffer(promptIndex);
            earlyIndex = promptIndex - obj.samplesPerChip;
            early = obj.correlationBuffer(earlyIndex);
            lateIndex = promptIndex + obj.samplesPerChip;
            late = obj.correlationBuffer(lateIndex);
            % Store the values and indexes
            values(1) = early;
            values(2) = prompt;
            values(3) = late;
            index = promptIndex;

            % Update the buffer index
            obj.bufferIndex = mod(obj.bufferIndex, 3) + 1;
            
       end




    end
end
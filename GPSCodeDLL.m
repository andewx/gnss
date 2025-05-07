classdef GPSCodeDLL < handle
    properties
        sampleRate
        codeRate
        codeLength
        earlyCode
        lateCode
        correlationBuffer
        loopFilter
        prnCode
        promptCode
        samplesPerChip
        showBuffer
        nco_freq
        nco_phase

    end

    methods
        % DLL Code Phase Tracking Estimates the code phase as a fractional delay into the correlation index
        function obj = GPSCodeDLL(code, sampleRate)
            % Constructor for the GPSCodeDLL class
            obj.sampleRate = sampleRate;                                    % Sample rate
            obj.codeRate = 1.023e6;                                         % Code rate in Hz
            obj.codeLength = 1023;                                          % Length of the C/A code
            obj.prnCode = code;                                             % prompt code
            obj.samplesPerChip = sampleRate/obj.codeRate;                   % Number of samples per chip
            obj.loopFilter = GPSLoopFilterM(1/obj.codeRate, 0.7, 1e-3);   % Loop filter object
            %obj.loopFilter = GPSLoopFilter(1/obj.codeRate, 0.7,1e-3, sampleRate);
            obj.promptCode = (1 - 2 .* obj.prnCode)*1j;                     % Single Code
            obj.earlyCode = obj.promptCode;                                 % Early code
            obj.lateCode = obj.promptCode;                                  % Late code
            obj.showBuffer = true;                                          % Show sample buffer
            obj.nco_freq = 1/obj.samplesPerChip;                            % Advance per samples (in chips)
            obj.nco_phase = 0;                                              % Code Phase accumulator (in chips)

            % Apply Circular Shift to the Early Late Code
            % (1/2 chip) - for this reason only use multiples of two for
            % sampling rate and samples per chip we use 4
            chipdel = floor(obj.samplesPerChip/2);
            obj.earlyCode = circshift(obj.earlyCode,-chipdel);
            obj.lateCode = circshift(obj.lateCode, chipdel);
        end


        function ShowCorrelation(obj)
                figure;
                plot(abs(obj.correlationBuffer));
                title("Auto Correlation PRN");
                return;

        end


        % Autocorrelation function assumes that the we are sampling
        % two 1023 bit chips at a time with 1023 samples per chip - We
        % output a 1023 wide delay correlation buffer for visualization
        function [z,output] = AutoCorr(obj,samples)
            % Initialize the early, prompt, and late signals
            z = 0; %zscore for peak
            output = zeros(1023,1);
            spc = floor(obj.samplesPerChip);
            expandCode = obj.ExpandCode(obj.prnCode,spc);

            isamp = imag(samples);
            if ~isvector(isamp)
                return
            end
            
            obj.correlationBuffer = xcorr(expandCode, isamp);
            absCorr = abs(obj.correlationBuffer);
            [val, idx] = max(absCorr);
            promptIndex = idx;
            delay = idx - length(expandCode);

            if delay <= 0
                delay = length(expandCode) - delay;
            end

            % Delay Indexes should be from [-1023, 1023] and mapped back to
            % [0, 1023] as an equivalent delay
            for n = 1:2*length(expandCode)
                val = absCorr(n);
                didx  = (n-length(expandCode))/obj.samplesPerChip;
                if didx <= 0
                    didx = 1023 - abs(didx);
                end
                fdidx = floor(didx);
                fdidx = mod(fdidx, 1023) + 1;
                if val > output(fdidx)
                    output(fdidx) = val;
                end
            end

            phase = delay/obj.samplesPerChip;
            obj.nco_phase = phase;
            u = mean(output);
            o = std(output);
            z = (abs(val)-u)/o;
    
        end


        function [code] = ExpandCode(obj,prn, numSamples)
            code = zeros(length(prn)*numSamples,1);
            k = 1;
            for i = 1:numSamples:length(code)
                code(i:i+numSamples-1) = prn(k);
                k = k+1;
            end
        end


        function [z, output] = Acquire(obj,samples)
            dllN = obj.samplesPerChip*1023*2;
            z = 0;
            output = [];
            if length(samples) < dllN
                return
            end
            [z,output] = obj.AutoCorr(samples(1:dllN));
        end

        % Update provides the DLL routine by computing the autocorrelation
        % of the incoming samples and updating the code phase
        % updating the prn code rotation and then interpolating the samples according
        % to the code phase delay and finally despreading the incoming signal, the value
        % output is the integration of the despread signal
        function [output, phase, prompt] = Update(obj, samples,startIdx,endIdx)
            computeSamples = samples(startIdx:endIdx);
            [output,early,prompt,late] = obj.Despread(computeSamples);
            errSignal = 0.5*(sqrt(early-late)/sqrt(early + late));
            x = obj.loopFilter.Filter(imag(errSignal));
            obj.nco_freq = 1/obj.samplesPerChip + imag(x);
            currentPhase = obj.nco_phase;
            phase = obj.nco_freq;
        end
       

        % Mix and Integrate Multiplies Incoming Code to produce xE, xP, and
        % xL signals and integrates into an integrate and dump integrators
        function [output ,early, prompt, late] = Despread(obj, samples)
            xE = zeros(length(samples),1);
            output = zeros(length(samples),1);
            xL = zeros(length(samples),1);

            for i = 1:length(samples)
                chip_index = floor(obj.nco_phase) + 1;
                
                if chip_index > 1023
                    chip_index = 1;
                end

                if chip_index < 1 || chip_index > 1023
                    disp('wtf');
                end

                % Get code sample using nearest neighbor or interpolation (optional)
                esample = obj.earlyCode(chip_index);
                psample = obj.promptCode(chip_index);  % wrap around
                lsample = obj.lateCode(chip_index);  % wrap around
            
                % Multiply incoming signal with code_sample for despreading
                s = samples(i);
                xE(i) = s*esample;
                output(i) = s*psample;
                xL(i) = s*lsample;

                % --- Update NCO ---
                obj.nco_phase = obj.nco_phase + obj.nco_freq;
            
                % Wrap phase to avoid overflow (optional)
                if obj.nco_phase >= 1023
                    obj.nco_phase = obj.nco_phase - 1023;
                end
            end
            early = sum(xE);
            prompt = sum(output);
            late = sum(xL);
        end

    end 
end
function [output] = GPSCarrierWipe(samples, fs, frequencyOffset, phaseOffset, hasInitialized, samplesPerChip, codeDelay, code, wipeCode)
    % GPSCarrierWipe - Carrier wipe function for GPS signals
    %
    % Syntax: output = GPSCarrierWipe(code, samplesPerChip, sampleRate, samples, frequencyOffset, phaseOffset)
    %
    % Inputs:
    %   code - The code to be wiped
    %   samplesPerChip - Number of samples per chip
    %   sampleRate - Sample rate
    %   samples - Input samples
    %   frequencyOffset - Frequency offset
    %   phaseOffset - Phase offset
    %
    % Outputs:
    %   output - Wiped output signal

    % Initialize variables
    normalizedOffset = 1i * 2 * pi / fs; % Normalized offset

    if ~hasInitialized
        % We need to autocorrelate our code delay
        N = samplesPerChip * 1023; % Number of samples
        interpolatedCode = resample(code, samplesPerChip, 1); % Interpolate the code
        revCode = fliplr(interpolatedCode); % Reverse the code
        % Calculate autocorrelation with reverse filter
        obj.correlationBuffer = filter(revCode, 1, samples(1:N));
        absCorrelation = abs(obj.correlationBuffer);
        idx = find(obj.correlationBuffer == max(absCorrelation), 1);
        codeDelay = length(interpolatedCode) + idx - 1;
    end

    if wipeCode
        % Wipe the PRN coded carrier portion of the signal PRN code is 0,1 and needs to be mapped to -1,1
        % The code is a 1023 bit code, so we need to map it to -1,1
        code = 2 .* code - 1; % Map the code to -1,1
        % Rotate the code sequence by the code delay
        code = circshift(code, -codeDelay); % Shift the code by the code delay
        % Wipe the carrier
        for n = 1:(samplesPerChip*1023):length(samples)
            if n + samplesPerChip*1023 - 1 > length(samples)
                break;
            end
            output(n:(n+samplesPerChip*1023)) = samples(n:(n+samplesPerChip*1023)) .* exp(-normalizedOffset * (frequencyOffset + phaseOffset)) .* (-1*code(1:length(samples)-1)); % Wipe the carrier
        end
    else
        output = samples .* exp(-normalizedOffset * (frequencyOffset + phaseOffset)); % Wipe the carrier
    end
end
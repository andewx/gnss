classdef GPSCoder < handle
    properties
        prn
        flipPRN 
        P
        N
        prnTX
        offset
        data
        wordCount       % 30 bits per word
        epochCount      
        subframeCount   % 10 words per subframe
        frameCount      %5 subframes per frame
        superFrameCount %25 frames per superframe
        gpsStatus       % 1 = SEEK_FRAME_PREAMBLE; 2 = SEEK_SUBFRAME; 3 = SEEK_FRAME; 4 = SEEK_SUPERFRAME
        gpsHasLock      % 1 = has lock; 0 = no lock
        preamble
        searchPreamble
        currentBit
        subframe
        frame
        superFrame
        hasFrame;
    end
    methods
       % Generates BPSK Modulated Version of the C/A Code
       % framePreamble = 0x8B
       function obj = GPSCoder(prn, offset,data)
        obj.prn = prn;
        obj.epochCount = 0;
        obj.offset = offset;
        obj.data = data;
        bpsk1 = ones(1023, 1);
        bpsk0 = zeros(1023,1);
        obj.P = 1 - 2*xor(obj.prn, bpsk1);
        obj.N = 1 - 2*xor(obj.prn, bpsk0);
        obj.flipPRN = fliplr(obj.prn);
        obj.gpsStatus = 'SEEK_CHIP_LOCK';
        obj.gpsHasLock = 0;
        obj.preamble = [1 0 0 0 1 0 1 1]; % 10101111
        obj.currentBit = 0;
        obj.frame = [];   %1500 bits
        obj.superFrame = [];
        obj.searchPreamble = zeros(8,1);
        obj.hasFrame = 0;
    end
    
        % GPS C/A Code XOR with data bit in FIFO
        function out = ModulatePRN(obj)
            data_bit = obj.data(1);
            if data_bit == 1
                obj.prnTX = obj.P;
            else
                obj.prnTX = obj.N;
            end
            out = obj.prnTX;
            obj.epochCount = obj.epochCount + 1;
            if obj.epochCount > 1023
                obj.epochCount = 0;
            end
            obj.data = circshift(obj.data, -1);
        end

        % GPS C/A Code XOR with data bit in FIFO equivalant to demodulation of our signal
        function [out, offset] = CorrelateSamples(obj, samples)
                corr = filter(obj.flipPRN, 1, samples);
                % The correlation is 1ms long (1023 samples)
                % We need to find the peak in the correlation
                [val, index] = max(corr);
                if val < 0 % This means that the correlation is negative
                    out = 0;
                else
                    out = 1;
                end

                % The index is the location of the peak in the correlation
                % We need to find the offset in the samples
                offset = index - 1023;
                if offset < 0
                    offset = 0;
                end
                obj.offset = offset; %Delay synchronization by offset chips in ms
        end

 


        function out = RotateBit(obj, bit)
            % Rotate the bit to the next bit

        end
        function out = GetOffset(obj)
            out = obj.offset;
        end

        function out = GetEpoch(obj)
            out = obj.epochCount;
        end


    end


end
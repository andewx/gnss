classdef GPSReceiver < handle
    properties
        caCoder
        gpsStatus
        gpsHasLock
        preamble
        searchPreamble
        currentBit
        subframe
        frame
        superFrame
        hasFrame
        epochCount
        subframeCount
        frameCount
        superFrameCount
        differentialBits
        tow
        gpsWeek
        subframeIndex
        satelliteGPS
    end
    
    methods

        % Constructor
        function obj = GPSReceiver(caCoder, satID)
            obj.caCoder = caCoder;
            obj.gpsStatus = 'SEEK_CHIP_LOCK';
            obj.gpsHasLock = 0;
            obj.preamble = [1 0 0 0 1 0 1 1]; % 10101111
            obj.currentBit = 0;
            obj.frame = [];   %1500 bits
            obj.superFrame = [];
            obj.searchPreamble = zeros(8,1);
            obj.hasFrame = 0;
            obj.epochCount = 0;
            obj.subframeCount = 0;
            obj.frameCount = 0;
            obj.superFrameCount = 0;
            obj.subframe = [];
            obj.frame = [];
            obj.superFrame = [];
            obj.differentialBits = [0 0];
            obj.tow = 0;
            obj.gpsWeek = 0;
            obj.subframeIndex = 0;
            obj.satelliteGPS = GPSSatellite(satID);
        end

        function [hasLock] = HasChipLock(obj, chipOffset)
            hasLock = false;
            if chipOffset ~= 0
                obj.gpsStatus = 'SEEK_CHIP_LOCK';
                obj.gpsHasLock = 0;
                return;
            else
                hasLock = true;
            end
        end

        function [out, status] = SeekChipLock(obj, chipOffset, bit)
            % This function is used to find the chip lock
            obj.currentBit = bit;
            if HasChipLock(chipOffset)
                % We have a chip lock
                obj.gpsStatus = 'SEEK_BIT_LOCK';
                out = bit;
                status = obj.gpsStatus;
            else
                % We are still seeking the chip lock
                obj.gpsStatus = 'SEEK_CHIP_LOCK';
                out = 0;
                status = obj.gpsStatus;
            end
        end


        function [hasBitLock] = SeekBitLock(obj, chipOffset, bit)
            hasBitLock = false;
            if obj.HasChipLock(chipOffset)
                % We need to affirm that we are locked into a the correct bit timing epoch of 20ms
                if bit ~= obj.currentBit
                    % We have a bit lock
                    obj.gpsStatus = 'SEEK_PREAMBLE';
                    obj.gpsHasLock = 1;
                    obj.currentBit = bit;
                    obj.epochCount = 0;
                    obj.searchPreamble = zeros(8,1);
                    hasBitLock = true;
                else
                    % We are still seeking the bit lock
                    obj.currentBit = bit;
                end   
            end
        end

        function [bit] = ProcessBit(obj, chipOffset, bit)
            obj.currentBit = bit;
            if obj.HasChipLock(chipOffset)
                if mod(obj.epochCount, 20) == 0
                    % Rotate the bits into our frame
                    obj.frame = obj.frame(2:end);
                    obj.frame = [obj.frame bit];
                end
                obj.epochCount = obj.epochCount + 1;
                if obj.epochCount > 1023
                    obj.epochCount = 0;
                end
            end
        end

        % We use this to seek the preamble however we need to be careful
        % because the IS-GP-200M indicates the the data bits are hamming
        % encoded. There are indication that the preamble is not hamming encoded
        function [found] = SeekPreamble(obj, chipOffset, bit)
            found = false;
            % Rotate in our bits MSB first until we discover the preamble and copy that into our first subframe
            if obj.HasChipLock(chipOffset)
                % We rotate the last bit out of view and assume it is the differential parity bit
                prevBit = obj.searchPreamble(1);
                obj.differentialBits(1) = obj.differentialBits(2);
                obj.differentialBits(2) = prevBit;
                obj.searchPreamble = obj.searchPreamble(2:end);
                obj.searchPreamble = [obj.searchPreamble bit];
                modPreamble = obj.searchPreamble;

                if obj.differentialBits(2) == 1
                    compareBits = ones(8,1);
                    modPreamble = bitxor(obj.searchPreamble, compareBits);
                end
               
                if modPreamble == obj.preamble
                    % We have found the preamble
                    obj.frame = [];
                    obj.gpsStatus = 'ACCUMULATE_FRAMES';
                    obj.epochCount = 20*8;
                    obj.subframeCount = 0;
                    obj.frameCount = 0;
                    obj.superFrameCount = 0;
                    obj.frame = [obj.searchPreamble];
                    found = true;
                end
            end
        end

        %% -----------------------Process Frames---------------------------
        %------------------------------------------------------------------
        % If we recieve a subframe we won't know which index of the frame we're in but
        % this may not matter because we can retrieve the subframe ID from the HOW message
        function [hasSubframe, mSubframe] = ProcessSubframe(obj, chipOffset, bit)
            hasSubframe = false;
            mSubframe = [];
            if obj.HasChipLock(chipOffset)
                % Rotate in our bits MSB first until we discover the preamble and copy that into our first subframe
                if obj.epochCount == 300
                    % Fill our subframe and track
                    idxA = length(obj.frame) - 300;
                    mSubframe = obj.frame(idxA:end);

                    %% Todo: Process the Subframe by its index and store it into our list of 5 subframes at the appropriate index
                    %  Each subframe consists of 10 words we should process them in order or at least update our differential bits
                    for i = 1:10
                        [valid, message] = obj.ComputeWord(mSubframe(30*(i-1)+1:30*i));
                        if ~valid
                            disp('Subframe is not valid -  Parity Check Failed on word %d', i);
                        else
                            switch i
                                case 1
                                    % Process the TLM Message
                                    obj.ProcessTLM(message);
                                case 2
                                    % Process the HOW Message
                                    [valid, ~] = obj.ProcessHOW(message,mSubframe);
                                    if ~valid
                                        disp('Subframe is not valid - HOW Message Corrupted on word %d', i);
                                    end
                                otherwise
                                    % Process frame specific messages with the word index
                                    if obj.subframeIndex == 1
                                        % Process the Frame 1 Message
                                        [valid] = obj.ProcessFrame1(message, i);
                                        if ~valid
                                            disp('Subframe is not valid - Frame 1 Message Corrupted on word %d', i);
                                        end
                                    elseif obj.subframeIndex == 2
                                        obj.ProcessFrame2(message, i);          
                                    elseif obj.subframeIndex == 3
                                        obj.ProcessFrame3(message, i);
                                    elseif obj.subframeIndex == 4
                                        obj.ProcessFrame4(message, i);
                                    elseif obj.subframeIndex == 5
                                        obj.ProcessFrame5(message, i);
                                    else
                                        disp('Subframe is not valid - Unknown Subframe Index');
                                    end
                            end
                        end
                    end
                end
            end
        end


        % Process TLM Message from the TOW Word SV Words are MSB first
        % TLM Messages primarily contain the subframe preamble and the
        % SS/CS Interface for the Space Segment and Control Segment Signals
        function [valid] =  ProcessTLM(obj,word)
            disp ('TLM Received');
            valid = true;
        end

        % Process Handover Word Message from the TOW Word SV Words are MSB first
        % HOW Messages primarily contain the subframe preamble and the
        % SS/CS Interface for the Space Segment and Control Segment Signals
        % The HOW message is used to identify the subframe and frame index
        % See IS-GP-200M for more details section 20.3.3.2
        % Note that the 19 indicates A-S Mode for the satellite which alerts to Y mode
        function [valid, id] = ProcessHOW(obj, word, subframe)
            %% Compute Time Of Week Message for Next Subframe Time
            msgTow = word(1:17); %MSB First with two LSBs truncated to zero
            msgTow = [msgTow 0 0]; % Add two LSBs to the end
            obj.tow = bit2int(msgTow, 17);
            obj.tow = obj.tow * 4; % X1 Epochs

            %%  Compute Subframe ID and Miscellaneous Bit Data -- stores subframe in its index
            id = bit2int(word(20:22),3); %MSB First
            obj.subframe(id) = subframe;
            obj.subframeIndex = id;
            if id < 1 || id > 5
                valid = false;
                error('Subframe ID is out of range');
            end
        end

        % Words 3 through 10 of the subframes are navigation words and SV health
        % words used for navigation, clock correction, and ephemeris data
        % Bits 23 and 24 are two MSBs of the ten bit IODC terms
        function [valid] = ProcessFrame1(obj, word, index)
            valid = true;
            if obj.subframeIndex == 1 && index == 3
                uraIndex = bit2int(word(13:16),4); %MSB First
                % URA Index is used to determine the accuracy of the SV
                if uraIndex > 6
                    valid = false;
                    disp('Subframe URA Index is out of range see IS-GP-200M for details');
                    return;
                end
            else
                valid = false;
            end
        end

              % Words 3 through 10 of the subframes are navigation words and SV health
        % words used for navigation, clock correction, and ephemeris data
        function [valid] = ProcessFrame2(obj, word, index)
            valid = true;

            % Store our ephemeris data which spans multiwords
            m0bits = [];
            Abits = [];
            ebits = [];
            bigomegabits = [];
            iobits = [];
            omegabits = [];

            switch index
                case 1
                   %TLM message processed every frame
                case 2
                    %HOW Message processed every frame
                case 3
                    iodeBits = wor(1:8);
                    crsbits = word(9:24);
                    obj.satelliteGPS.ephemeris.IODE = bit2int(iodeBits);
                    obj.satelliteGPS.ephemeris.Crs = bit2int(crsbits);
                case 4
                    delNbits = word(1:16);
                    m0msb = word(17:24);
                    m0bits = [m0msb];
                    obj.satelliteGPS.ephemeris.delN = bit2int(delNbits);
                case 5
                    m0lsb = word(1:24);
                    m0bits = [m0bits m0lsb];
                    obj.satelliteGPS.ephemeris.M0 = bit2int(m0bits);
                case 6
                    emsb = word(17:24);
                    ebits = [emsb];
                    obj.satelliteGPS.ephemeris.Cuc = bit2int(word(1:16));
                case 7
                    elsb = word(1:24);
                    ebits = [ebits elsb];
                    obj.satelliteGPS.ephemeris.e = bit2int(ebits);
                case 8
                    abits = word(17:24);
                    obj.satelliteGPS.ephemeris.Cus = bit2int(word(1:16));
                case 9
                    abits = [abits word(1:24)];
                    obj.satelliteGPS.ephemeris.A = bit2int(abits);
                case 10
                    obj.satelliteGPS.ephemeris.toe = bit2int(word(1:16));
            end
        end


        % Words 3 through 10 of the subframes are navigation words and SV health
        % words used for navigation, clock correction, and ephemeris data
        function [valid] = ProcessFrame3(obj, word, index)
            valid = true;
             switch index
                case 1
                   %TLM message processed every frame
                case 2
                    %HOW Message processed every frame
                case 3
                    obj.satelliteGPS.ephemeris.Cic = bit2int(word(1:16));
                    om0bits = word(17:24);
                case 4
                  ombits = [om0bits word(1:24)];
                  obj.satelliteGPS.ephemeris.O0 = bit2int(ombits);
                case 5
                   i0bits = word(17:24);
                   obj.satelliteGPS.ephemeris.Cis = bit2int(word(1:16));
                case 6
                    i0bits = [i0bits word(1:24)];
                    obj.satelliteGPS.i0 = bit2int(i0bits);
                case 7
                    obj.satelliteGPS.ephemeris.Crc = bit2int(word(1:16));
                    omegabits = word(17:24);
                case 8
                    omegabits = [omegabits word(1:24)];
                    obj.satelliteGPS.ephemeris.o = bit2int(omegabits);
                case 9
                   obj.satelliteGPS.ephemeris.ODot = bit2int(word(1:24));
                case 10
                    obj.satelliteGPS.ephemeris.IDOT = bit2int(word(9:22));
                    iode = bit2int(word(1:8));
                    if iode ~= obj.satelliteGPS.ephemeris.IODE
                        disp("IODE within frame ephemeris data not matching")
                    end
                  
            end

        end



              % Words 3 through 10 of the subframes are navigation words and SV health
        % words used for navigation, clock correction, and ephemeris data
        function [valid] = ProcessFrame4(obj, word, index)
            valid = true;
        end



              % Words 3 through 10 of the subframes are navigation words and SV health
        % words used for navigation, clock correction, and ephemeris data
        function [valid] = ProcessFrame5(obj, word, index)
            valid = true;
        end

        % Parity bits are used to decode the 30 bit word message
        % Requires the differential bits to be valid, return 24 bit valid message
        function [valid, word] = ComputeWord(obj, subframe)
            valid = true;
            message = subframe(1:24);
            parity = subframe(25:30);
            
            if obj.differentialBits(2) == 1
                message = bitxor(message, obj.differentialBits(2));
            end

           % Check the parity bits
           computedParity = zeros(6,1);   
           computedParity(1) = mod(sum(mesage(1:23)+obj.differentialBits(1)),2);
           computedParity(2) = mod(sum(mesage(2:24)+obj.differentialBits(2)),2);
           computedParity(3) = mod(sum(mesage(1:22)+obj.differentialBits(1)),2);
           computedParity(4) = mod(sum(mesage(2:23)+obj.differentialBits(2)),2);
           computedParity(5) = mod(sum(mesage(1:24)+obj.differentialBits(2)),2);
           computedParity(6) = mod(sum(mesage(3:24)+obj.differentialBits(1)),2);

           if computedParity ~= parity
               valid = false;
           end

           word = message;
           obj.differentialBits(1) = subframe(29);
            obj.differentialBits(2) = subframe(30);

        end


        % GPS Samples Reciever Loop -- GPT is wrong here we will correct but use as a placeholder
        function GPSProcess(obj, samples)
            % This function is used to process the GPS samples
            % We need to correlate the samples with the PRN code
            % We need to find the chip lock and bit lock
            % We need to find the preamble and subframe
            % We need to process the TLM and HOW messages
            for i = 1:length(samples)
                sample = samples(i);
                chipOffset = obj.caCoder.CorrelateSamples(sample);
                bit = obj.SeekChipLock(chipOffset, sample);
                obj.ProcessBit(chipOffset, bit);
                obj.SeekPreamble(chipOffset, bit);
                [hasSubframe, mSubframe] = obj.ProcessSubframe(chipOffset, bit);
                if hasSubframe
                    obj.ProcessTLM(mSubframe);
                    obj.ProcessHOW(mSubframe);
                    obj.ProcessSVTimeScale(mSubframe);
                end
            end
        end


    end
end



% Class currently does nothing
classdef GPSTransmitter < handle

    properties
        satellite
        epoch
        coder
        preamble
        differentialBits
        systemClock
        weekNumber
        x1Epochs
        zCountBits
        currentSubframe
        frame
    end
    methods

        function obj = GPSTransmitter(id)
            obj.satellite = GPSSatellite(id);
            obj.coder = CACodeGenerator(id);
            obj.preamble = [1 0 0 0 1 0 1 1];
            obj.systemClock = datetime('now');
            obj.ComputeTime();
            obj.currentSubframe = mod((obj.systemClock.Day*24*10),5);
            obj.differentialBits = [0 0];
            obj.frame = [];
        end

        function obj = ComputeTime(obj)
            % ComputeWeekNumber computes the week number based on the time of week
            obj.systemClock = datetime('now');
            weekYears = floor((obj.systemClock.Year - 1980)/52);
            weekMonths = floor((obj.systemClock.Month - 1)/4);
            weekDays = floor(obj.systemClock.Day/7);
            obj.weekNumber = weekYears + weekMonths + weekDays;
            zCountWeeks = mod(obj.weekNumber, 1024);
            obj.currentSubframe = mod((obj.systemClock.Day*24*10),5); %6 second intervals beginning at start of week
            %X1 Epochs is the number of X1 epochs since the beginning of the time of week (1.5 seconds per epoch)
            elapsedSeconds = (obj.systemClock.Day-1)*24*3600 + obj.systemClock.Hour*3600 + obj.systemClock.Minute*60 + obj.systemClock.Second;
            obj.x1Epochs = floor(elapsedSeconds/1.5);
            weekBits = int2bit(zCountWeeks, 10);
            towBits = int2bit(obj.x1Epochs, 19);
            obj.zCountBits = [weekBits towBits];
        end

        function [bits] = GenerateRandomBits(obj, n)
            % GenerateRandomBits generates n random bits
            bits = randi([0 1], 1, n);
        end

        function [word] = ComputeWord(obj, bits)
            message = subframe(1:24);
            if length(bits) ~= 24
                error('Input bits must be 24 bits long');
            end
            
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

           word = [message computedParity];
           obj.differentialBits = [computedParity(5) computedParity(6)];
        end

        function [word] = GenerateRandomWord(obj)
            % GenerateRandomWord generates a random word
            % The word is 24 bits long, with 6 parity bits
            % The first 24 bits are generated randomly
            % The last 6 bits are parity bits
            randomBits = obj.GenerateRandomBits(24);
            word = obj.ComputeWord(randomBits);
        end

        %Generate our subframes, some parameters like LNAV data will only be simulated with
        %random bits to facilitate testing, Subframe 2 HOW words will be generated
        function [subframe] = GenerateSubframe(obj, subframeNumber)
            % GenerateSubframe generates a subframe based on the subframe number
            % Subframe 1: 10 bits of Z count, 19 bits of time of week, 5 bits of subframe number
            % Subframe 2: 24 bits of LNAV data
            % Subframe 3: 24 bits of LNAV data
            obj.ComputeTime();
            id = int2bit(subframeNumber, 3);
            subframeData = [];
            switch subframeNumber
                case 1
                    % Generate subframe 1
                    tlmWord = obj.ComputeWord([obj.preamble obj.GenerateRandomBits(16)]);
                    howWord = obj.ComputeWord([obj.zCountBits(11:27) 0 1 id 0 0]);
                    wnWord = obj.ComputeWord([obj.zCountBits(1:10) obj.GenerateRandomBits(14)]);
                    subframeData = [tlmWord howWord wnWord];
                    for i = 1:7
                        subframeData = [subframeData obj.ComputeWord(obj.GenerateRandomBits(24))];
                    end
                    
                case 2
                    % Generate subframe 2
                    tlmWord = obj.ComputeWord([obj.preamble obj.GenerateRandomBits(16)]);
                    howWord = obj.ComputeWord([obj.zCountBits(11:27) 0 1 id 0 0]);
                    subframeData = [tlmWord howWord];
                    for i = 1:8
                        subframeData = [subframeData obj.ComputeWord(obj.GenerateRandomBits(24))];
                    end
                case 3
                    % Generate subframe 2
                    tlmWord = obj.ComputeWord([obj.preamble obj.GenerateRandomBits(16)]);
                    howWord = obj.ComputeWord([obj.zCountBits(11:27) 0 1 id 0 0]);
                    subframeData = [tlmWord howWord];
                    for i = 1:8
                        subframeData = [subframeData obj.ComputeWord(obj.GenerateRandomBits(24))];
                    end
                otherwise
                     % Generate subframe 2
                     tlmWord = obj.ComputeWord([obj.preamble obj.GenerateRandomBits(16)]);
                     howWord = obj.ComputeWord([obj.zCountBits(11:27) 0 1 id 0 0]);
                     subframeData = [tlmWord howWord];
                     for i = 1:8
                         subframeData = [subframeData obj.ComputeWord(obj.GenerateRandomBits(24))];
                     end
            end
        end

        % GenerateFrame generates a frame based on the subframe number
        function [frame] = GenerateFrame(obj)
            % GenerateFrame generates a frame based on the subframe number
            % The frame is 1500 bits long, with 5 subframes of 24 bits each
            obj.ComputeTime();
            frame = [];
            for i = 1:5
                subframe = obj.GenerateSubframe(i);
                frame = [frame subframe];
            end
        end
    end
end
classdef InterpolationController < handle
    %Given a data frame for processing and mu index returns interpolation
    %filter ouptuts

    properties
        mu
        counter
        N
        samplesBeforeTrigger
    end

    methods
        % For our Interpolation Controller the N is the oversampling factor
        function obj = InterpolationController(N)
            %Creates instance of classa
            obj.mu = 0.0; obj.counter = 1;
            obj.N = N;
            obj.samplesBeforeTrigger = 0;
        end

        function [mu, strobe, delay] = Update(obj,errorSignal)
            obj.samplesBeforeTrigger = obj.samplesBeforeTrigger + 1;
            d = errorSignal + 1/obj.N;
            strobe = false;
            delay = 0;
     
            mu = 0;

            if obj.counter-d <= 0 
                strobe = true;
                mu = (obj.counter / d);
                obj.mu = mu;
                if obj.samplesBeforeTrigger > obj.N
                    delay = obj.samplesBeforeTrigger - obj.N;
                end

                %if mu is spiked from 0 to 1 on a va
                obj.samplesBeforeTrigger = 0;
            end  

               obj.counter = mod(obj.counter -d, 1);
        end

        function [mu] = GetError(obj)
            mu = obj.mu;
        end

    end
end
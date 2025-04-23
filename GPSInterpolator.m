classdef GPSInterpolator < handle
    %Given a data frame for processing and mu index returns interpolation
    %filter ouptuts

    properties
        mu
        data
        h
        taps;
        coeffs;
        alpha;
        filterType
    end

    methods

        % Interpolation is a 4 tap filter
        function obj = GPSInterpolator(filterType)
            mu = 1.0; obj.alpha = 0.5;
            obj.filterType = filterType;
            obj.coeffs = zeros(4,1);
            obj.mu = 0.0; 
            obj.h(1) = - (1/6) * mu * (1 - mu) * (2 - mu);
            obj.h(2) = (1/2) * (1 - mu) * (1 - mu) * (1 + mu);
            obj.h(3) = (1/2) * mu * mu * (3 - 2*mu);
            obj.h(4) = - (1/6) * mu * mu * (1 - mu);
            obj.taps = zeros(2,1);
   
            obj.coeffs(1) = obj.alpha*obj.mu*(obj.mu-1);
            obj.coeffs(2) =-obj.alpha*obj.mu^2 - (1 - obj.alpha)*obj.mu +1;
            obj.coeffs(3) = -obj.alpha*obj.mu^2 + (1 + obj.alpha)*obj.mu;
            obj.coeffs(4) = obj.alpha*obj.mu*(obj.mu-1);
        end

       

        % GetSample will get interpolate the given index with the user set
        % filterType as either "Farrow" or "PPF". If useTaps the function
        % will interpolate with a 4-TAP FIR buffer and shift in the sample
        % into the TAP buffer
        function sample = GetSample(obj, data, index, useTaps)
            sample = 0;
            if useTaps
                x = [data(index+1); data(index); obj.taps(2);  obj.taps(1)]; 
            else
                if index > 2 && index < (length(obj.data)-1)
                    x = [data(index-2);  data(index-1);   data(index);   data(index+1)];
                else
                    zd = complex(0,0);
                    if index < (length(obj.data)-1)
                     x = [data(index+1);  data(index);   zd;   zd];
                    else
                        x = [zd;data(index); zd;zd];
                    end
                    
                end
            end


            if obj.filterType == "Farrow"
                sample = sum(obj.h * x);
            else
                 sample = dot(obj.coeffs,x);
            end

            if useTaps
                obj.taps(1) = obj.taps(2);
                obj.taps(2) = sample;
            end

        end


        function samples = GetSamples(obj, data)
            samples = zeros(length(data),1);
            for i = 1:length(data)
                samples(i) = obj.GetSample(data, i, false);
            end
        end



        function SetData(obj, data)
            obj.data = data;
        end

  
        function UpdateTaps(obj, mu)

            obj.mu = mu;

            if obj.filterType == "Farrow"

                obj.h(1) = - (1/6) * mu * (1 - mu) * (2 - mu);
                obj.h(2) = (1/2) * (1 - mu) * (1 - mu) * (1 + mu);
                obj.h(3) = (1/2) * mu * mu * (3 - 2*mu);
                obj.h(4) = - (1/6) * mu * mu * (1 - mu);

            end

            if obj.filterType == "PPF"
                obj.coeffs(1) = obj.alpha*obj.mu*(obj.mu-1);
                obj.coeffs(2) =-obj.alpha*obj.mu^2 - (1 - obj.alpha)*obj.mu +1;
                obj.coeffs(3) = -obj.alpha*obj.mu^2 + (1 + obj.alpha)*obj.mu;
                obj.coeffs(4) = obj.alpha*obj.mu*(obj.mu-1);
            end

        end

        function UpdateMu(obj, value)
            obj.mu = value;
        end
    end
end
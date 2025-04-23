% Decode Octet - Needs Testing
% a - string octet i.e. "1440" which is bit clipped to lenBits
function [binSeq] = DecodeOctet(a, lenBits)
    binSeq = [];

    for i =1:length(a)

    char = a(i);
    bits = [0 0 0];
    switch char
        case '1'
            bits = [0 0 1];
        case '2'
            bits = [0 1 0];
        case '3'
            bits = [0 1 1];
        case '4'
            bits = [1 0 0];
        case '5'
            bits = [1 0 1];
        case '6'
            bits = [1 1 0];
        case '7'
            bits = [1 1 1];
    end

    binSeq = [binSeq, bits];
    end
    lenBin = length(binSeq);

    if lenBits <= lenBin
        binSeq = binSeq((lenBin-lenBits+1):end);
    else
        pzs = zeros(lenBits, 1);
        binSeq = [pzs, binSeq];
    end
end
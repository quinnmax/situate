function [output,counts,IA,IB] = unique_cell( input )
% [output,counts,IA,IB] = unique_cell( input );
%
% output, trimmed list
% counts, how many of each output were in the input
% IA index of elements of the input w/ respect to the output. ie, output(IA) = input. ie, group assignments
% IB index of elements of the output w/ respect to the input. ie, input(IB) = output

    %input = { {'a','b'}, {'a','b'}, {'a','b'}, {'a','b','c'}, {'d'} };
    
    already_seen = false(1,length(input));
    counts = [];
    output = {};
    IA     = zeros(1,length(input)); % index of elements of the input w/ respect to the output
    IB     = []; % index of elements of the output w/ respect to the input
    for i = 1:length(input)
        
        if ~already_seen(i)
            output(end+1) = input(i);
            IB(end+1) = i;
            IA(i) = length(output);
            counts(end+1) = 1;
            for j = i+1:length(input)
                if ~already_seen(j) && isequal( input(i), input(j) )
                    already_seen(j) = true;
                    counts(end) = counts(end) + 1;
                    IA(j) = length(IB);
                end
            end
        end
        
    end
    
    
    
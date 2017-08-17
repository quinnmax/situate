function [output,counts,IA,IB] = unique_cell( input )
% [output,counts,IA,IB] = unique_cell( input );
%
% output, trimmed list
% counts, how many of each output were in the input
% IA index of elements of the input w/ respect to the output. ie, input(IB) = output
% IB index of elements of the output w/ respect to the input. ie, output(IA) = input

    %input = { {'a','b'}, {'a','b'}, {'a','b'}, {'a','b','c'}, {'d'} };
    
    remove = false(1,length(input));
    counts = [];
    output = {};
    IA     = []; % index of elements of the input w/ respect to the output
    IB     = []; % index of elements of the output w/ respect to the input
    for i = 1:length(input)
        if ~remove(i)
            output(end+1) = input(i);
            IA(i) = length(output);
            IB(end+1) = i;
            counts(end+1) = 1;
            for j = i+1:length(input)
                if ~remove(j) && isequal( input(i), input(j) )
                    remove(j) = true;
                    counts(i) = counts(i) + 1;
                    IA(j) = IA(end);
                end
            end
        end
    end
    
    
    
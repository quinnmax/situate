function [value_counts, unq_in] = counts( input, unq_in )

    % [value_counts, unq_in] = counts( input, [unq_in] );
    %
    % returns the counts for unique elements of the input
    % if unq_in is provided, that order is used
    % if not, then the order can be pulled from the output

    input = reshape(input,[],1);
    
    if ~exist('unq_in','var')
        unq_in = unique( input );
    end
    unq_in = reshape(unq_in, 1, []);
    
    n = length(input);
    m = length(unq_in);
    if iscell(input)
        value_counts = zeros(1,length(unq_in));
        for ui = 1:length(unq_in)
            value_counts(ui) = sum( strcmp( unq_in(ui), input ) );
        end
    elseif isnumeric(input)
        value_counts = sum( eq( input*ones(1,m), ones(n,1)*unq_in) );
    else
        error('counts:needs_cell_or_numeric', 'counts:needs_cell_or_numeric inputs');
    end
    
end
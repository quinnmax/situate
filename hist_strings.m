function [h_out,unique_words,counts] = hist_strings( input, include_empties )

    % [h,unique_words,counts] = hist_strings( cell_of_strings, [inlcude_empties] );
    %
    % Draws a bar graph of counts of words in the input (cell of strings).
    % Empty cells are ignored and not counted unless [include_empties] is
    % set to true.

    if ~exist('include_empties','var') || isempty(include_empties)
        include_empties = false;
    end
    
    empty_inds = cellfun( @isempty, input );
    if include_empties
        input(inculde_empties) = 'empty';
    else
        input(include_empties) = [];
    end
    
    input(empty_inds) = [];
    
    unique_words = unique( input );
    counts = cellfun( @(x) sum(ismember(input,x)), unique_words );
    
    h = bar( 1:length(unique_words), counts );
    h.Parent.XTickLabel = unique_words;
    
    if nargout > 0
        h_out = h;
    end

end
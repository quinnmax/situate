function [p, r] = PR_analysis( dvars, is_pos )

% [precision, recall] = PR_analysis( decision_variables, is_positive_instance );

    n = length(dvars);
    
    [~,ordering] = sort(dvars,'descend');
    is_pos = is_pos(ordering);
    
    p = arrayfun( @(x) sum(  is_pos(1:x) ) / x, 1:n );
    r = arrayfun( @(x) sum(  is_pos(1:x) ), 1:n ) ./ sum( is_pos);
    
end
        
        
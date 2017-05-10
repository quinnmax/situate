function [counts, bin_bounds, input_assignments] = hist_bin_assignments( x, n )
%[counts, bin_bounds, input_assignments] = hist_bin_assignments( x, n );

    if ~exist('n','var') || isempty(n), n = 10; end
    
    min_val = min(x);
    max_val = max(x);
    bin_bounds = linspace( min_val, max_val, n+1 );
    bin_bounds(1) = -inf;
    bin_bounds(end) = inf;
    
    counts = zeros(1,n);
    input_assignments = zeros(1,length(x));
    for bi = 1:n
        cur_bin_inds = ge(x,bin_bounds(bi)) & lt(x,bin_bounds(bi+1));
        counts(bi) = sum( cur_bin_inds );
        input_assignments(cur_bin_inds) = bi;
    end
    
end
    
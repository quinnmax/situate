function y = center_surround( m )

    % y = center_surround( m );
    %
    % generates a 0 mean center surround cell with unit
    % variance
    %
    % it's composed of two blackman filters, 
    % the outer (negative) filter of diameter m, 
    % and the inner (positive) filter of diameter m/2
    %
    % see also:
    %   gabor.m

    persistent old_y;
    if size(old_y,1) == m
        y = old_y;
    else
        outer = -1 * blackman(m) * blackman(m)';
        inner =  1 * blackman(round(m/2)) * blackman(round(m/2))';
        inner = padarray_to(inner,[m,m]);
        inner = inner * abs(sum(outer(:)))/sum(inner(:));
        y = inner + outer;
        y = y/var(y(:));
        old_y = y;
    end
    
end

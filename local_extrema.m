function [y_sum, y_ex, rcs, ccs] = local_extrema( x, d, s )

    % [y_ex, y_sum, rcs, ccs] = local_extrema( x, d, s );
    % y contains local extrema of x
    % in a region with diameter d
    % sampled with an approximate step size of s
    %
    % the extremes are calculated relative to the mean of the input, so it
    % really only makes sense if some sort of trend removal is already taken
    % care of.
    %
    % y_ex is the proper local extreme, but is pretty noisy
    % y_sum is the sum of y_min and y_max, so overlap of extreme values will
    % cancel each other out a bit.
    % 
    % rcs and ccs hold row and column centers in the original pixel space
    

    x_mu = mean(x(:));
    x    = x - x_mu;

    [ x_max, rcs, ccs ] =  local_max(  x, d, s );
      x_min             = -local_max( -x, d, s );

    y_sum = x_min + x_max + x_mu;
    
    if nargout > 1

        y_ex = x_max;
        y_ex( abs(x_min) > x_max ) = x_min( abs(x_min) > x_max );
        y_ex = y_ex + x_mu; 
        
    end

    
end


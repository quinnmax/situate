function y = blackmann(r,c,d)

% y = blackmann(r,c,d);
%
% r rows
% c cols
% d layers (just repeated, not a curve like r and c)

    if nargin < 2; c = r; d = 1; end
    if nargin < 3; d = 1; end
    
    persistent cached
    [r_cached, c_cached, d_cached] = size(cached);
    if all( [r_cached c_cached d_cached] == [r c d] )
        y = cached;
    else
        y = repmat(  blackman(r) * blackman(c)', [1, 1, d] );
        cached = y;
    end
    
end

    
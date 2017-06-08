function y = logistic(x,h,k)

% y = 1 ./ ( 1 + exp( -h .* (x - k) ) );

    if ~exist('h','var')
        h = 1;
    end
    
    if ~exist('k','var')
        k = 0;
    end

    y = 1 ./ ( 1 + exp( -h .* (x - k) ) );

end
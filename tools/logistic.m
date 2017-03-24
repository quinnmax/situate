function y = logistic(x,b)

% y = logistic(t)
% y = 1./(1+exp(-t));
%
% y = logistic(x,b); 
% where length(x) == length(b)
%   y = 1./(1+exp(-1*sum(b.*x)));
% 
% y = logistic(x,b); 
% where length(x) == length(b)-1, ie, biased, then first b is bias
%   y = 1./(1+exp(-1*(b(1) + sum(b(2:end).*x))));
%
% y = logistic(x,b);
% where none of the rest are true, then arrayfun on each x

    if ~exist('b','var') || isempty(b)
        y = 1./(1+exp(-x));
    elseif length(b) == length(x)
        y = 1./(1+exp(-1*sum(b.*x)));
    elseif length(b) == length(x)+1
        y = 1./(1+exp(-1*(b(1) + sum(b(2:end).*x))));
    else
        y = arrayfun( @(t) logistic(t,b), x );
    end
    
end
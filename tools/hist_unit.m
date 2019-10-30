function [n,x] = hist_unit(y,m)
    
    % [n,x,h] = hist_unit(y,m);
    %
    % draws a histogram of data y with m bins, but scales the neights to sum to 1
    %
    % see also:
    %   hist_scaled
    %   hist_area
    %   hist_prctile
    
    
    if ~exist('m','var') || isempty(m)
        m = 10;
    end
    
    if ~exist('y','var') || isempty(y)
        warning('hist_unit in demo mode');
        y = randn(1000,1);
        figure;
        hist_unit(y,20);
        hold on;
        plot( linspace(-4,4,100), normpdf(linspace(-4,4,100)),'red','linewidth',3 );
        hold off;
        return;
    end
    
    [n,x] = hist(y,m);
    scalar = 1 ./ sum(n(:));
    n = n .* repmat(scalar,size(n,1),1);
    
    bar( x, n, 1 );
    % set(h, 'facecolor', [.5 .5 .75])
    
end
    
    
    
    
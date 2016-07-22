function [samples] = sample_1d( arg1, arg2, arg3 )



    % [samples] = sample_from_pdf( pdf_x, pdf_y, n );
    % [inds]    = sample_from_pdf( pdf_y, n );
    %
    % draw samples from a 1d empirical (discretized) pdf
    %
    % -if x is empty or if there are only two args, then indicies are
    % provided instead of x values.
    % -y must be provided
    % -if n is empty, then one sample is returned
    %
    % see also:
    %   sample_2d
    
    
    
    if nargin == 3
        x = arg1;
        y = arg2;
        n = arg3;
    end
    
    if nargin == 2
        y = arg1;
        n = arg2;
        x = 1:length(y);
    end
    
    if nargin == 1
        y = arg1;
        n = 1;
        x = 1:length(y);
    end
    
    if isempty(x)
        x = 1:length(y);
    end
    
    if isempty(n)
        n = 1;
    end
       
    
    
    cum_dist = cumsum(y) / sum(y);
        
    samples = zeros(1,n);
    for ni = 1:n
        samples(ni) = x( find( gt( cum_dist, rand() ), 1, 'first') );
    end
    
end














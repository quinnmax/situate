function [output, ratio] = imresize_px( input, pixels, args )

    % [output, linear_scaling_factor] = imresize_px( input, pixels, args );
    %
    % resize an image to an approximate number of pixels.
    % arg is passed on to imresize
    %
    % output is the resized image
    % linear_scaling_factor was the factor used to approximate the desired
    %   number of pixels
    

    rows = size(input,1);
    cols = size(input,2);
    
    ratio = sqrt( pixels / (rows*cols) );
    
    if nargin < 3
        output = imresize( input, ratio );
    else
        output = imresize( input, ratio, args );
    end
        
end
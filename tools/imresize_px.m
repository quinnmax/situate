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
    
    % doing this so we know for sure what the rows and cols will be, rather
    % than deferring to imresize logic
    ratio = sqrt( pixels / (rows*cols) );
    new_rows = round( rows * ratio );
    new_cols = round( cols * ratio );
    
    if nargin < 3
        output = imresize( input, [new_rows new_cols] );
    else
        output = imresize( input, [new_rows new_cols], args );
    end
        
end
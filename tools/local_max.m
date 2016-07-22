function [y,rcs,ccs] = local_max(x,d,s)



% [y,rcs,ccs] = local_max(x,d,s);
%   x is the input map. if there are multiple layers, all layers will be pooled over for a given spatial location
%   d is the diameter over which to take the max (diameter)
%   s is the number of pixels between sampling centers (step size)
%
%   if d is specified and s is not, s will default such that all pixels are
%   included in at least one neighborhood, and the overlap between circular
%   neighborhoods is minimized
%
%   y is the output map
%   rcs are the row coordinates of the centers with respect to x
%   ccs are the column coordinates of the centers with respect to x
%
%   also see local_extrema



% set parameters

    if ~exist('x','var') || isempty(x)
        x = double(imread('cameraman.tif'))/255;
        display('local_max in demo mode'); 
    end

    if ~exist('d','var') || isempty(d); d = round(size(x,1)/20); end
    if ~exist('s','var') || isempty(s); s = d/sqrt(2); end
   

  
% move x above zero so our mask works properly

    min_val = min(x(:));
    x = x - min_val;
    
    
    
% allocate for output

    y = zeros( round(size(x,1)/s), round(size(x,2)/s) );
    
    rcs = round( linspace( s/2, size(x,1)-s/2, size(y,1) ) );
    r0s = round( rcs - d/2 );
    rfs = r0s + d - 1;
    
    ccs = round( linspace( s/2, size(x,2)-s/2, size(y,2) ) );
    c0s = round( ccs - d/2 );
    cfs = c0s + d - 1;
    
    % for some reason the builtin padarray function is actually pretty
    % slow. since we're just using zeros anyway, we can just make a big
    % zero mat and plop the image into the middle of it
    xp = zeros( 2*d + size(x,1), 2*d + size(x,2), size(x,3) );
    xp(d+1:end-d,d+1:end-d,:) = x;
    
    r0s = r0s + d;
    rfs = rfs + d;
    c0s = c0s + d;
    cfs = cfs + d;
    
    % this global stuff is a little junky. should certainly be using
    % something prettier to save the few masks that will be needed
    % repeatedly. but using the global to cache the mask really does save a
    % bunch of repeated work.
    persistent saved_local_max_mask_collection
    if length(saved_local_max_mask_collection) >= d ...
        && size(saved_local_max_mask_collection{d},1) == d ...
        && size(saved_local_max_mask_collection{d},3) == size(x,3)
            mask = saved_local_max_mask_collection{d};
    else
        mask = repmat( disk(d), [1 1 size(x,3)] );
        if isempty(saved_local_max_mask_collection)
            saved_local_max_mask_collection = {};
        end
        saved_local_max_mask_collection{d} = mask;
    end
    
    
    
% tip toe through the tulips

    for i = 1:size(y,1)
    for j = 1:size(y,2)
    
        cur_chunk = xp(r0s(i):rfs(i),c0s(j):cfs(j),:);
        cur_chunk = mask .* cur_chunk;
        
        y(i,j) = max( cur_chunk(:) );
        
    end
    end
    
    
    
% return to original range
    
    y = y + min_val;
    
    
    
end
    
    
    

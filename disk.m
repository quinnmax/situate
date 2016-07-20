function z = disk( D, W )
% z = disk( D, W )
% a disk with approximate diameter D (in pixels) in a window of width W
% there's a little smoothing of the edge and values are doubles in 0,1
   
    if ~exist('W','var') || isempty(W)
        W = D;
    end
    if length(D) == 1; D(2) = D(1); end
    if length(W) == 1; W(2) = W(1); end
    
    
    % if we keep regenerating a disk for some reason, this should speed it
    % up
    persistent disk_cached;
    persistent disk_cached_args;
    if size(disk_cached,1) == W(1) && size(disk_cached,2) == W(2) && disk_cached_args.D(1) == D(1) && disk_cached_args.D(2) == D(2)
        z = disk_cached;
        return;
    end

    
    
    m  = 4;
    d1 = m * D(1);
    d2 = m * D(2);
    [x,y] = meshgrid(linspace(-1,1,d2), linspace(-1,1,d1));
    
    z = sqrt( x.^2 + y.^2 );
    z = lt(z,1);
    z = imresize(double(z),1/m,'bicubic');
    z = max(z,0);
    z = min(z,1);
    
    if min(size(z)) == 1; z(:,:) = 1; end;
    
    z = padarray( z, [ ceil((W(1)-D(1))/2) ceil((W(2)-D(2))/2) ] );
    z = z(1:W(1),1:W(2));
    
    disk_cached = z;
    disk_cached_args.D = D;
    
end
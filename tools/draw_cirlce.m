function [h,points] = draw_cirlce( c, r, arg )
% h = draw_cirlce( center_xy, radius, arg )

    if ~exist('c','var') || isempty( c )
        c = [0 0];
    end
    
    if ~exist('r','var') || isempty( r )
        r = 1;
    end
    
    n = 36;
    t = linspace(-pi,pi,n);
    if numel(r) == 1
        r(2) = r(1);
    end
    
    points = [c(1) + r(1) * cos(t)', c(2) + r(2) * sin(t)'];
    
    if ~exist('arg','var')
        h = plot( points(:,1), points(:,2) );
    else
        h = plot( points(:,1), points(:,2), arg );
    end
    
end
    
    
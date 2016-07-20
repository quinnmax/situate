function h = draw_box_r0rfc0cf( x, arg )

    if ~exist('arg','var') || isempty(arg), arg = []; end
    
    if numel(x)>4
        handle = draw_box(x(:,[3,1,4,2]), arg);
    else
        handle = draw_box(x([3 1 4 2]), arg);
    end
    
    if nargout > 0
        h = handle;
    end
    
end
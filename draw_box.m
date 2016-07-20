function h = draw_box(x, arg)

    % h = draw_box(x, arg);
    % x = [x0 y0 xf yf]
    % or 
    % x = [c0 r0 cf rf]
    %
    % arg is passed on to plot(x,y,arg)
    %
    % if x has multiple rows, they're each drawn, but it relies on a figure
    % hold from outside of the function. that is, if you don't call 
    % 'hold on' before calling 'draw_box', you'll just get a box for the
    % last row of 'x'.
    %
    % you might need to reorder columns with boxes_r0rfc0cf(:,[3,1,4,2])
    %
    % see also, draw_box_xywh, for boxes in [x y w h] format
   
    for i = 1:size(x,1)

        cs = [x(i,1) x(i,1) x(i,3) x(i,3) x(i,1)];
        rs = [x(i,2) x(i,4) x(i,4) x(i,2) x(i,2)];

        if ~exist('arg','var') || isempty(arg)
            h = plot(cs, rs);
        else
            h = plot(cs, rs, arg);
        end
        
    end
    
end

